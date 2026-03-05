"""Simple CORS proxy for Flutter web → A2A business agent.

Runs on port 8080, proxies all requests to the business agent on port 10999.
Adds CORS headers so Flutter web (port 5678) can call it.

Usage:
    python3 proxy.py
    # or: python3 proxy.py --agent-port 10999 --proxy-port 8080
"""

import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.request
import urllib.error


class ProxyHandler(BaseHTTPRequestHandler):
    agent_url = "http://localhost:10999"

    def _set_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, X-A2A-Extensions, UCP-Agent",
        )

    def do_OPTIONS(self):
        self.send_response(200)
        self._set_cors_headers()
        self.end_headers()

    def do_GET(self):
        """Proxy GET requests (e.g. /.well-known/ucp)."""
        try:
            url = f"{self.agent_url}{self.path}"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req) as resp:
                body = resp.read()
                self.send_response(resp.status)
                self._set_cors_headers()
                self.send_header("Content-Type", resp.getheader("Content-Type", "application/json"))
                self.end_headers()
                self.wfile.write(body)
        except urllib.error.URLError as e:
            self.send_response(502)
            self._set_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def do_POST(self):
        """Proxy POST requests (A2A JSON-RPC)."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)

            url = f"{self.agent_url}{self.path}"
            req = urllib.request.Request(url, data=body, method="POST")

            # Forward relevant headers.
            for header in ["Content-Type", "X-A2A-Extensions", "UCP-Agent"]:
                value = self.headers.get(header)
                if value:
                    req.add_header(header, value)

            with urllib.request.urlopen(req) as resp:
                resp_body = resp.read()
                self.send_response(resp.status)
                self._set_cors_headers()
                self.send_header("Content-Type", resp.getheader("Content-Type", "application/json"))
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.URLError as e:
            self.send_response(502)
            self._set_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def log_message(self, format, *args):
        print(f"[proxy] {args[0]}")


def main():
    parser = argparse.ArgumentParser(description="CORS proxy for A2A agent")
    parser.add_argument("--agent-port", type=int, default=10999)
    parser.add_argument("--proxy-port", type=int, default=8080)
    args = parser.parse_args()

    ProxyHandler.agent_url = f"http://localhost:{args.agent_port}"
    server = HTTPServer(("localhost", args.proxy_port), ProxyHandler)
    print(f"Proxy running on http://localhost:{args.proxy_port}")
    print(f"Forwarding to {ProxyHandler.agent_url}")
    server.serve_forever()


if __name__ == "__main__":
    main()
