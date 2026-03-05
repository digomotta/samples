# UCP Shopping App

A standalone Flutter shopping app that communicates with UCP business agents via the A2A (Agent-to-Agent) JSON-RPC protocol.

## Overview

This app is a UCP client reference implementation — a visual e-commerce frontend that talks directly to any A2A-compatible business agent using the UCP extension for structured commerce data.

### Features

- **Product catalog** — browse and search products from the business agent
- **Cart management** — add, remove, update quantities
- **Checkout flow** — customer details, shipping address, payment
- **Order confirmation** — completed order with order ID

### Architecture

```
┌──────────────────────────────┐
│  Flutter Shopping App        │
│                              │
│  Catalog → Cart → Checkout   │
│                              │
│  ┌────────────────────────┐  │
│  │  Dart A2A Client       │  │
│  │  (JSON-RPC + UCP)      │  │
│  └──────────┬─────────────┘  │
└─────────────┼────────────────┘
              │ A2A JSON-RPC + UCP-Agent header
              ▼
   ┌─────────────────────┐
   │ Business Agent      │
   │ (e.g. SuperStore)   │
   │ localhost:10999      │
   └─────────────────────┘
```

## Prerequisites

- Flutter 3.x
- A running UCP A2A business agent (e.g. the SuperStore agent)

## Quick Start

### 1. Start the business agent

```bash
cd ../business_agent
uv sync
uv run business_agent  # Starts on port 10999
```

### 2. Serve the buyer profile

The app needs its UCP buyer profile served at a URL. From the shopping-app directory:

```bash
cd a2a/shopping-app/assets
python3 -m http.server 3100
# Profile available at http://localhost:3100/buyer_profile.json
```

### 3. Run the shopping app

From the shopping-app directory (in another terminal):

```bash
cd a2a/shopping-app
flutter run -d chrome
```

To use a different agent URL or profile URL:

```bash
flutter run -d chrome \
  --dart-define=AGENT_URL=http://localhost:10999 \
  --dart-define=UCP_PROFILE_URL=http://localhost:3100/buyer_profile.json
```

## Project Structure

```
lib/
  a2a/
    a2a_client.dart         # A2A JSON-RPC client with UCP extension
  config/
    app_config.dart         # App configuration (agent URL, profile URL)
  models/
    product.dart            # Product and ProductResults models
    checkout.dart           # Checkout, LineItem, Payment, Order models
    shop_state.dart         # App state (ChangeNotifier + Provider)
  screens/
    catalog_screen.dart     # Product search and grid
    cart_screen.dart        # Cart with quantity controls
    checkout_form_screen.dart # Customer details form
    payment_screen.dart     # Payment confirmation
    confirmation_screen.dart # Order success
  widgets/
    product_card.dart       # Product display card
    cart_item_tile.dart     # Cart line item with controls
    checkout_summary.dart   # Order totals display
assets/
  buyer_profile.json        # UCP buyer capability profile
```

## A2A Protocol

The app communicates via JSON-RPC 2.0 `message/send` requests:

```json
{
  "jsonrpc": "2.0",
  "id": "...",
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"type": "text", "text": "Search for strawberries"}],
      "messageId": "...",
      "contextId": "...",
      "kind": "message"
    }
  }
}
```

Headers include:
- `X-A2A-Extensions`: UCP extension URI
- `UCP-Agent`: buyer profile URL for capability negotiation
