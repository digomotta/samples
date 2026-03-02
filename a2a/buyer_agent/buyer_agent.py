"""Autonomous buyer agent for A2A UCP commerce.

Sends A2A JSON-RPC messages to a seller agent and completes a full
purchase autonomously: search -> add to cart -> shipping -> payment -> done.

Can run as a CLI tool or as an HTTP server with SSE for real-time
frontend integration.
"""

import asyncio
import json
import logging
import threading
import uuid
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

import click
import httpx
from dotenv import load_dotenv
from google import genai
from google.genai import types as genai_types

load_dotenv()

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

UCP_EXTENSION_URL = "https://ucp.dev/specification/reference?v=2026-01-11"
PROFILE_DIR = Path(__file__).parent / "profile"


# -- Profile server -----------------------------------------------------------


def _start_profile_server() -> int:
    """Serve agent_profile.json on a random port. Returns the port."""
    handler = partial(SimpleHTTPRequestHandler, directory=str(PROFILE_DIR))
    server = HTTPServer(("127.0.0.1", 0), handler)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log.info("Profile server on http://127.0.0.1:%d", port)
    return port


# -- A2A JSON-RPC -------------------------------------------------------------


async def _send_async(
    client: httpx.AsyncClient,
    endpoint: str,
    profile_url: str,
    parts: list[dict],
    context_id: str | None,
    task_id: str | None,
) -> dict:
    """Send an A2A message/send JSON-RPC request (async)."""
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
    resp = await client.post(
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


def _send(
    client: httpx.Client,
    endpoint: str,
    profile_url: str,
    parts: list[dict],
    context_id: str | None,
    task_id: str | None,
) -> dict:
    """Send an A2A message/send JSON-RPC request (sync)."""
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


# -- Response parsing ---------------------------------------------------------


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


# -- Payment ------------------------------------------------------------------


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


# -- LLM-powered reasoning ----------------------------------------------------

BUYER_SYSTEM_PROMPT = """\
You are a buyer agent. A human user will tell you what they want to \
buy. You then talk to a seller agent to fulfill that request.

The conversation has two kinds of participants:
- "user" messages come from the human telling you what they want.
- "model" messages (yours) are what you say to the seller agent.
- After each of your messages, you will see the seller's response \
  and the current state of the checkout.

Your job is to talk to the seller like a real customer: ask for \
products, choose items, add them to the cart, give shipping details, \
and complete the purchase.

When you need to provide shipping/delivery details, use:
  Name: Jane Smith
  Address: 456 Oak Ave, New York, NY 10001, US
  Email: jane.smith@example.com

## Signals
- When checkout status is "ready_for_complete", respond exactly: \
  __PAYMENT__
- When checkout status is "completed", respond exactly: __DONE__

## Guidelines
- Be conversational and natural.
- Only use product IDs the seller has mentioned.
- Pick the item that best matches what the user asked for.
- If something fails, try a different approach.
- Respond with ONLY your message to the seller. Nothing else.
"""

_genai_client: genai.Client | None = None


def _get_genai_client() -> genai.Client:
  """Lazy-init the Gemini client."""
  global _genai_client
  if _genai_client is None:
    _genai_client = genai.Client()
  return _genai_client


def _build_llm_contents(
  history: list[dict], parsed: dict,
) -> list[genai_types.Content]:
  """Build Gemini contents from conversation history + current state."""
  contents: list[genai_types.Content] = []
  for entry in history:
    # "user" = human request, "seller" = seller response → both map
    # to Gemini "user" role. "buyer" = our agent's messages → "model".
    role = "model" if entry["role"] == "buyer" else "user"
    contents.append(
      genai_types.Content(
        role=role,
        parts=[genai_types.Part(text=entry["text"])],
      )
    )

  # Append a summary of the current parsed state as the latest
  # "user" turn so the model knows where things stand.
  state_lines = [
    f"Seller responded. Checkout status: "
    f"{parsed.get('checkout_status', 'none')}.",
  ]
  if parsed["products"]:
    for p in parsed["products"]:
      pid = p.get("productID", "?")
      name = p.get("name", "?")
      price = (p.get("offers") or {}).get("price", "?")
      state_lines.append(f"  Product: {name} (ID: {pid}, ${price})")
  if parsed.get("checkout"):
    for li in parsed["checkout"].get("line_items", []):
      item = li.get("item", {})
      state_lines.append(
        f"  Cart item: {item.get('title', '?')} x{li.get('quantity', 1)}"
      )
  state_lines.append("What should I say next to the seller?")

  contents.append(
    genai_types.Content(
      role="user",
      parts=[genai_types.Part(text="\n".join(state_lines))],
    )
  )
  return contents


async def _llm_next_message(
  history: list[dict], goal: str, parsed: dict,
) -> str | None:
  """Use Gemini to decide the next buyer message (async)."""
  client = _get_genai_client()
  contents = _build_llm_contents(history, parsed)

  response = await client.aio.models.generate_content(
    model="gemini-2.5-flash",
    contents=contents,
    config=genai_types.GenerateContentConfig(
      system_instruction=f"{BUYER_SYSTEM_PROMPT}\n\nUser's goal: {goal}",
      temperature=0.2,
    ),
  )
  text = (response.text or "").strip()
  log.info("LLM decision: %s", text)

  if text == "__DONE__" or not text:
    return None
  return text


def _llm_next_message_sync(
  history: list[dict], goal: str, parsed: dict,
) -> str | None:
  """Use Gemini to decide the next buyer message (sync)."""
  client = _get_genai_client()
  contents = _build_llm_contents(history, parsed)

  response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=contents,
    config=genai_types.GenerateContentConfig(
      system_instruction=f"{BUYER_SYSTEM_PROMPT}\n\nUser's goal: {goal}",
      temperature=0.2,
    ),
  )
  text = (response.text or "").strip()
  log.info("LLM decision: %s", text)

  if text == "__DONE__" or not text:
    return None
  return text


# -- Buyer Session (async, for HTTP server) -----------------------------------


class BuyerSession:
    """Manages an autonomous buyer agent session with SSE streaming."""

    def __init__(self, goal: str, seller_url: str, profile_url: str):
        self.goal = goal
        self.seller_url = seller_url
        self.profile_url = profile_url
        self._intervention_queue: asyncio.Queue[str] = asyncio.Queue()
        self._paused = asyncio.Event()
        self._paused.set()  # not paused initially
        self._stopped = False
        self.context_id: str | None = None
        self.task_id: str | None = None
        self.last_checkout: dict | None = None
        self.history: list[dict] = []

    def pause(self):
        self._paused.clear()

    def resume(self):
        self._paused.set()

    def stop(self):
        self._stopped = True
        self._paused.set()  # unblock if paused

    def intervene(self, message: str):
        self._intervention_queue.put_nowait(message)
        # If paused, resume to process the intervention
        self._paused.set()

    async def run(self):
        """Async generator yielding events for each turn."""
        async with httpx.AsyncClient() as client:
            # Emit the user's goal as a user message first,
            # then ask the LLM to formulate the first message
            # to the seller.
            yield {
                "type": "human_intervention",
                "turn": 0,
                "text": self.goal,
            }
            self.history.append({"role": "user", "text": self.goal})

            # LLM decides what to say to the seller based on
            # the user's goal (no seller response yet).
            initial_parsed = {
                "checkout_status": None,
                "checkout": None,
                "products": [],
                "text": "",
            }
            buyer_text: str | None = await _llm_next_message(
                self.history, self.goal, initial_parsed,
            )

            for turn in range(20):
                # Check if paused
                await self._paused.wait()
                if self._stopped:
                    yield {"type": "status", "turn": turn, "text": "Session stopped."}
                    break

                # Check for human intervention
                try:
                    intervention = self._intervention_queue.get_nowait()
                    buyer_text = intervention
                    yield {
                        "type": "human_intervention",
                        "turn": turn,
                        "text": intervention,
                    }
                except asyncio.QueueEmpty:
                    pass

                if buyer_text is None:
                    yield {"type": "status", "turn": turn, "text": "No next action. Stopping."}
                    break

                # Emit buyer message event
                yield {"type": "buyer_message", "turn": turn, "text": buyer_text}

                # Track buyer message in history
                self.history.append({"role": "buyer", "text": buyer_text})

                # Send to seller
                parts = [{"type": "text", "text": buyer_text}]
                try:
                    resp = await _send_async(
                        client, self.seller_url, self.profile_url,
                        parts, self.context_id, self.task_id,
                    )
                except Exception as e:
                    yield {"type": "error", "turn": turn, "text": str(e)}
                    break

                parsed = _parse(resp)
                self.context_id = parsed["context_id"] or self.context_id
                self.task_id = parsed["task_id"]
                if parsed["checkout"]:
                    self.last_checkout = parsed["checkout"]

                # Track seller response in history
                self.history.append({
                    "role": "seller",
                    "text": parsed["text"],
                })

                yield {
                    "type": "seller_response",
                    "turn": turn,
                    "text": parsed["text"],
                    "parsed": parsed,
                }

                # Done?
                if parsed["checkout_status"] == "completed":
                    yield {"type": "status", "turn": turn, "text": "Order completed successfully!"}
                    break

                # Checkout ready -> send payment
                if parsed["checkout_status"] == "ready_for_complete" and self.last_checkout:
                    yield {"type": "buyer_message", "turn": turn, "text": "Sending payment..."}

                    pay_parts = _payment_parts(self.last_checkout)
                    try:
                        resp = await _send_async(
                            client, self.seller_url, self.profile_url,
                            pay_parts, self.context_id, self.task_id,
                        )
                    except Exception as e:
                        yield {"type": "error", "turn": turn, "text": str(e)}
                        break

                    parsed = _parse(resp)
                    self.context_id = parsed["context_id"] or self.context_id

                    yield {
                        "type": "seller_response",
                        "turn": turn,
                        "text": parsed["text"],
                        "parsed": parsed,
                    }

                    if parsed["checkout_status"] == "completed":
                        yield {"type": "status", "turn": turn, "text": "Order completed successfully!"}
                    else:
                        yield {"type": "status", "turn": turn, "text": f"Payment result: {parsed['checkout_status']}"}
                    break

                # Ask LLM what to do next
                buyer_text = await _llm_next_message(
                    self.history, self.goal, parsed,
                )

                # Handle payment sentinel from LLM
                if buyer_text == "__PAYMENT__" and self.last_checkout:
                    yield {"type": "buyer_message", "turn": turn, "text": "Sending payment..."}

                    pay_parts = _payment_parts(self.last_checkout)
                    try:
                        resp = await _send_async(
                            client, self.seller_url, self.profile_url,
                            pay_parts, self.context_id, self.task_id,
                        )
                    except Exception as e:
                        yield {"type": "error", "turn": turn, "text": str(e)}
                        break

                    parsed = _parse(resp)
                    self.context_id = parsed["context_id"] or self.context_id

                    yield {
                        "type": "seller_response",
                        "turn": turn,
                        "text": parsed["text"],
                        "parsed": parsed,
                    }

                    if parsed["checkout_status"] == "completed":
                        yield {"type": "status", "turn": turn, "text": "Order completed successfully!"}
                    else:
                        yield {"type": "status", "turn": turn, "text": f"Payment result: {parsed['checkout_status']}"}
                    break
            else:
                yield {"type": "status", "turn": 20, "text": "Reached max turns without completing purchase."}


# -- HTTP Server (Starlette + SSE) -------------------------------------------

_sessions: dict[str, BuyerSession] = {}


def create_app(profile_url: str):
    """Create a Starlette ASGI app for the buyer agent."""
    from starlette.applications import Starlette
    from starlette.middleware.cors import CORSMiddleware
    from starlette.requests import Request
    from starlette.responses import JSONResponse
    from starlette.routing import Route
    from sse_starlette.sse import EventSourceResponse

    async def start_session(request: Request):
        body = await request.json()
        goal = body.get("goal", "buy some cookies")
        seller_url = body.get("seller_url", "http://localhost:10999")
        session_id = str(uuid.uuid4())
        session = BuyerSession(goal, seller_url, profile_url)
        _sessions[session_id] = session
        return JSONResponse({"session_id": session_id})

    async def events(request: Request):
        session_id = request.path_params["session_id"]
        session = _sessions.get(session_id)
        if not session:
            return JSONResponse({"error": "Session not found"}, status_code=404)

        async def event_generator():
            async for event in session.run():
                yield {
                    "event": event["type"],
                    "data": json.dumps(event),
                }
            # Clean up after session completes
            _sessions.pop(session_id, None)

        return EventSourceResponse(event_generator())

    async def intervene(request: Request):
        session_id = request.path_params["session_id"]
        session = _sessions.get(session_id)
        if not session:
            return JSONResponse({"error": "Session not found"}, status_code=404)
        body = await request.json()
        message = body.get("message", "")
        session.intervene(message)
        return JSONResponse({"ok": True})

    async def pause_session(request: Request):
        session_id = request.path_params["session_id"]
        session = _sessions.get(session_id)
        if not session:
            return JSONResponse({"error": "Session not found"}, status_code=404)
        session.pause()
        return JSONResponse({"ok": True, "paused": True})

    async def resume_session(request: Request):
        session_id = request.path_params["session_id"]
        session = _sessions.get(session_id)
        if not session:
            return JSONResponse({"error": "Session not found"}, status_code=404)
        session.resume()
        return JSONResponse({"ok": True, "paused": False})

    routes = [
        Route("/start", start_session, methods=["POST"]),
        Route("/events/{session_id}", events),
        Route("/intervene/{session_id}", intervene, methods=["POST"]),
        Route("/pause/{session_id}", pause_session, methods=["POST"]),
        Route("/resume/{session_id}", resume_session, methods=["POST"]),
    ]

    app = Starlette(routes=routes)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    return app


# -- CLI entry points ---------------------------------------------------------


@click.command()
@click.option("--seller-url", default="http://localhost:10999", help="Seller agent URL")
@click.option("--goal", default="buy some cookies", help="What to shop for")
@click.option("--serve", is_flag=True, default=False, help="Run as HTTP server with SSE")
@click.option("--port", default=11000, help="HTTP server port (with --serve)")
def main(seller_url: str, goal: str, serve: bool, port: int):
    """Run the autonomous buyer agent."""
    profile_port = _start_profile_server()
    profile_url = f"http://127.0.0.1:{profile_port}/agent_profile.json"

    if serve:
        import uvicorn
        app = create_app(profile_url)
        log.info("Buyer agent server starting on port %d", port)
        uvicorn.run(app, host="0.0.0.0", port=port)
        return

    # Original CLI mode
    http = httpx.Client()
    context_id: str | None = None
    task_id: str | None = None
    last_checkout: dict | None = None
    history: list[dict] = []

    print(f"\n{'='*60}")
    print(f"  Buyer Agent (LLM)  |  Goal: {goal}")
    print(f"  Seller: {seller_url}")
    print(f"{'='*60}\n")

    # Show user's goal, then let LLM decide first message to seller
    print(f"[User]   {goal}")
    history.append({"role": "user", "text": goal})
    initial_parsed = {
        "checkout_status": None,
        "checkout": None,
        "products": [],
        "text": "",
    }
    buyer_text: str | None = _llm_next_message_sync(
        history, goal, initial_parsed,
    )

    for turn in range(10):
        if buyer_text is None:
            print("No next action available. Stopping.")
            break

        # Send buyer message
        print(f"[Buyer]  {buyer_text}")
        history.append({"role": "buyer", "text": buyer_text})
        parts = [{"type": "text", "text": buyer_text}]
        resp = _send(http, seller_url, profile_url, parts, context_id, task_id)
        parsed = _parse(resp)

        context_id = parsed["context_id"] or context_id
        task_id = parsed["task_id"]
        if parsed["checkout"]:
            last_checkout = parsed["checkout"]

        print(f"[Seller] {parsed['text']}\n")
        history.append({"role": "seller", "text": parsed["text"]})

        # Done?
        if parsed["checkout_status"] == "completed":
            print("Order completed successfully!")
            break

        # Checkout ready -> send payment
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

        # Ask LLM what to do next
        buyer_text = _llm_next_message_sync(history, goal, parsed)

        # Handle payment sentinel from LLM
        if buyer_text == "__PAYMENT__" and last_checkout:
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

    else:
        print("Reached max turns without completing purchase.")


if __name__ == "__main__":
    main()
