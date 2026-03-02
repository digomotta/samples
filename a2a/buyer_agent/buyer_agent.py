"""Autonomous buyer agent for A2A UCP commerce.

Sends A2A JSON-RPC messages to a seller agent and completes a full
purchase autonomously: search -> add to cart -> shipping -> payment -> done.
"""

import logging
import re
import threading
import uuid
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

import click
import httpx
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

UCP_EXTENSION_URL = "https://ucp.dev/specification/reference?v=2026-01-11"
PROFILE_DIR = Path(__file__).parent / "profile"


# ── Profile server ───────────────────────────────────────────────────────────


def _start_profile_server() -> int:
    """Serve agent_profile.json on a random port. Returns the port."""
    handler = partial(SimpleHTTPRequestHandler, directory=str(PROFILE_DIR))
    server = HTTPServer(("127.0.0.1", 0), handler)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log.info("Profile server on http://127.0.0.1:%d", port)
    return port


# ── A2A JSON-RPC ─────────────────────────────────────────────────────────────


def _send(
    client: httpx.Client,
    endpoint: str,
    profile_url: str,
    parts: list[dict],
    context_id: str | None,
    task_id: str | None,
) -> dict:
    """Send an A2A message/send JSON-RPC request."""
    msg: dict = {
        "role": "user",
        "parts": parts,
        "messageId": str(uuid.uuid4()),
        "kind": "message",
    }
    if context_id:
        msg["contextId"] = context_id
    if task_id:
        msg["taskId"] = task_id

    body = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": "message/send",
        "params": {"message": msg, "configuration": {"historyLength": 0}},
    }
    resp = client.post(
        endpoint,
        json=body,
        headers={
            "Content-Type": "application/json",
            "X-A2A-Extensions": UCP_EXTENSION_URL,
            "UCP-Agent": f'profile="{profile_url}"',
        },
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()


# ── Response parsing ─────────────────────────────────────────────────────────


def _parse(data: dict) -> dict:
    """Parse A2A response into structured result."""
    if "error" in data:
        return {
            "context_id": None,
            "task_id": None,
            "checkout": None,
            "checkout_status": None,
            "products": [],
            "text": f"Error: {data['error'].get('message', data['error'])}",
        }

    result = data.get("result", {})
    ctx = result.get("contextId")
    state = result.get("status", {}).get("state")
    tid = result.get("id") if state in ("working", "submitted", "input-required") else None

    parts = (
        result.get("parts")
        or result.get("status", {}).get("message", {}).get("parts", [])
    )

    lines: list[str] = []
    checkout = None
    products: list[dict] = []

    for p in parts:
        if "text" in p:
            lines.append(p["text"])
        elif "data" in p:
            d = p["data"]

            if "a2a.product_results" in d:
                pr = d["a2a.product_results"]
                if isinstance(pr, dict):
                    if pr.get("content"):
                        lines.append(str(pr["content"]))
                    for prod in pr.get("results", []):
                        products.append(prod)
                        name = prod.get("name", "?")
                        pid = prod.get("productID", "?")
                        offers = prod.get("offers") or {}
                        price = offers.get("price", "?")
                        curr = offers.get("priceCurrency", "USD")
                        lines.append(f"  Product: {name} | ID: {pid} | Price: {price} {curr}")

            if "a2a.ucp.checkout" in d:
                checkout = d["a2a.ucp.checkout"]
                lines.append(f"  Checkout status: {checkout.get('status')}")
                for li in checkout.get("line_items", []):
                    item = li.get("item", {})
                    lines.append(
                        f"  Cart: {item.get('title', '?')} x{li.get('quantity', 1)}"
                    )
                for t in checkout.get("totals", []):
                    label = t.get("display_text", t.get("type", ""))
                    lines.append(f"  {label}: {t.get('amount', 0)}")

    return {
        "context_id": ctx,
        "task_id": tid,
        "checkout": checkout,
        "checkout_status": checkout.get("status") if checkout else None,
        "products": products,
        "text": "\n".join(l for l in lines if l) or "(no text in response)",
    }


# ── Payment ──────────────────────────────────────────────────────────────────


def _payment_parts(checkout: dict) -> list[dict]:
    """Build DataParts with mock payment instrument to complete checkout."""
    handlers = checkout.get("payment", {}).get("handlers", [])
    handler = handlers[0] if handlers else {}
    return [
        {"type": "data", "data": {"action": "complete_checkout"}},
        {
            "type": "data",
            "data": {
                "a2a.ucp.checkout.payment_data": {
                    "id": "instr_1",
                    "type": "card",
                    "brand": "visa",
                    "last_digits": "4242",
                    "expiry_month": 12,
                    "expiry_year": 2027,
                    "handler_id": handler.get("id", "example_payment_provider"),
                    "handler_name": handler.get("name", "example.payment.provider"),
                    "credential": {
                        "type": "token",
                        "token": f"mock_token_{uuid.uuid4()}",
                    },
                },
                "a2a.ucp.checkout.risk_signals": {"data": "low_risk"},
            },
        },
    ]


# ── State machine ────────────────────────────────────────────────────────────

SHIPPING = (
    "My delivery details: first name John, last name Doe, "
    "street address 123 Main St, city San Francisco, state CA, "
    "postal code 94105, country US, email john.doe@example.com"
)


def _extract_product_ids(text: str) -> list[str]:
    """Extract product IDs from text like 'ID: BISC-001' or '(BISC-001)'."""
    return re.findall(r"(?:ID:\s*|[(\s])([A-Z][\w-]+\d+)", text)


def _next_message(parsed: dict, goal: str) -> str | None:
    """Decide the next buyer message based on the current state.

    Returns None when the flow is complete or payment should be sent.
    """
    status = parsed["checkout_status"]

    # Got structured products but no checkout yet → add first product
    if parsed["products"] and not parsed["checkout"]:
        pid = parsed["products"][0].get("productID", "BISC-001")
        return f"Add product {pid} to my checkout"

    # No structured products, but text mentions product IDs → add first one
    if not parsed["checkout"]:
        ids = _extract_product_ids(parsed["text"])
        if ids:
            return f"Add product {ids[0]} to my checkout"

    # Checkout exists and is incomplete → provide shipping details
    if status == "incomplete":
        items = parsed["checkout"].get("line_items", [])
        if items:
            return SHIPPING
        return None

    # ready_for_complete or completed → handled by caller
    return None


# ── Main ─────────────────────────────────────────────────────────────────────


@click.command()
@click.option("--seller-url", default="http://localhost:10999", help="Seller agent URL")
@click.option("--goal", default="buy some cookies", help="What to shop for")
def main(seller_url: str, goal: str):
    """Run the autonomous buyer agent."""
    profile_port = _start_profile_server()
    profile_url = f"http://127.0.0.1:{profile_port}/agent_profile.json"

    http = httpx.Client()
    context_id: str | None = None
    task_id: str | None = None
    last_checkout: dict | None = None

    print(f"\n{'='*60}")
    print(f"  Buyer Agent  |  Goal: {goal}")
    print(f"  Seller: {seller_url}")
    print(f"{'='*60}\n")

    buyer_text: str | None = goal

    for turn in range(10):
        if buyer_text is None:
            print("No next action available. Stopping.")
            break

        # Send buyer message
        print(f"[Buyer]  {buyer_text}")
        parts = [{"type": "text", "text": buyer_text}]
        resp = _send(http, seller_url, profile_url, parts, context_id, task_id)
        parsed = _parse(resp)

        context_id = parsed["context_id"] or context_id
        task_id = parsed["task_id"]
        if parsed["checkout"]:
            last_checkout = parsed["checkout"]

        print(f"[Seller] {parsed['text']}\n")

        # Done?
        if parsed["checkout_status"] == "completed":
            print("Order completed successfully!")
            break

        # Checkout ready → send payment
        if parsed["checkout_status"] == "ready_for_complete" and last_checkout:
            print("[Buyer]  Sending payment...\n")
            pay_parts = _payment_parts(last_checkout)
            resp = _send(http, seller_url, profile_url, pay_parts, context_id, task_id)
            parsed = _parse(resp)
            context_id = parsed["context_id"] or context_id

            print(f"[Seller] {parsed['text']}\n")

            if parsed["checkout_status"] == "completed":
                print("Order completed successfully!")
            else:
                print(f"Payment result: {parsed['checkout_status']}")
            break

        # Decide next message
        buyer_text = _next_message(parsed, goal)

    else:
        print("Reached max turns without completing purchase.")


if __name__ == "__main__":
    main()
