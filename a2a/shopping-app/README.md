# UCP Shopping App

A standalone Flutter shopping app that communicates with UCP business agents via the A2A (Agent-to-Agent) JSON-RPC protocol. Chat-first experience matching the React UCP chat-client.

## Quick Start

You need **3 terminals**:

### Terminal 1: Start the business agent

```bash
cd a2a/business_agent
uv sync
uv run business_agent
# Running on http://localhost:10999
```

### Terminal 2: Start the CORS proxy

```bash
cd a2a/shopping-app
python3 proxy.py
# Proxy on http://localhost:8080 → agent on http://localhost:10999
```

### Terminal 3: Run the Flutter app

```bash
cd a2a/shopping-app
flutter run -d chrome
```

### Mock mode (no agent needed)

```bash
flutter run -d chrome --dart-define=USE_MOCK=true
```

## Architecture

```
Flutter App (chrome)  →  CORS Proxy (:8080)  →  Business Agent (:10999)
   chat UI               proxy.py               SuperStore (A2A + UCP)
```

The app sends A2A JSON-RPC `message/send` requests with UCP extension headers.
The proxy adds CORS headers so the browser allows cross-origin requests.

## Features

- **Chat-first UI** — conversational shopping experience
- **Inline product cards** — horizontal carousel with images, prices, "Add to Checkout"
- **Inline checkout cards** — line items, totals, Start/Complete Payment buttons
- **Real A2A protocol** — JSON-RPC 2.0 with UCP extension
- **Mock mode** — works without a running agent for development

## Project Structure

```
lib/
  a2a/
    a2a_client.dart         # A2A JSON-RPC client with UCP headers
    mock_a2a_client.dart    # Mock client for offline development
  config/
    app_config.dart         # Agent URL, profile URL, mock toggle
  models/
    chat_message.dart       # Chat message with products/checkout
    checkout.dart           # Checkout, LineItem, Payment, Order
    product.dart            # Product and ProductResults
    shop_state.dart         # Chat-first state management
  widgets/
    chat_bubble.dart        # Message bubbles with inline products/checkout
    chat_input.dart         # Text input bar
    chat_view.dart          # Full-screen chat view
proxy.py                    # CORS proxy for Flutter web → business agent
assets/
  buyer_profile.json        # UCP buyer capability profile
```
