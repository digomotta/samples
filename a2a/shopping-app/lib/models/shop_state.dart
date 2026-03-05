import 'package:flutter/foundation.dart';

import '../a2a/a2a_client.dart';
import '../a2a/mock_a2a_client.dart';
import '../config/app_config.dart';
import 'chat_message.dart';
import 'checkout.dart';
import 'product.dart';

/// Centralized shopping state — drives the entire app.
///
/// Supports two modes:
/// 1. Manual — user clicks buttons directly
/// 2. Agentic — user chats with the agent, UI updates automatically
class ShopState extends ChangeNotifier {
  ShopState({A2AClient? client})
      : _client =
            client ?? (AppConfig.useMock ? MockA2AClient() : A2AClient());

  final A2AClient _client;

  // --- State ---
  List<Product> _products = [];
  Checkout? _checkout;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  ShopView _currentView = ShopView.catalog;

  // --- Chat state ---
  final List<ChatMessage> _messages = [
    ChatMessage.agent(
      "Hi! I'm your shopping assistant. Tell me what you'd like "
      "to buy, or ask me to browse the catalog.",
    ),
  ];
  bool _isChatOpen = false;

  // --- Getters ---
  List<Product> get products => _products;
  Checkout? get checkout => _checkout;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  ShopView get currentView => _currentView;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isChatOpen => _isChatOpen;

  int get cartItemCount {
    if (_checkout == null) return 0;
    return _checkout!.lineItems.fold(0, (sum, li) => sum + li.quantity);
  }

  // --- Chat ---

  void toggleChat() {
    _isChatOpen = !_isChatOpen;
    notifyListeners();
  }

  void openChat() {
    _isChatOpen = true;
    notifyListeners();
  }

  void closeChat() {
    _isChatOpen = false;
    notifyListeners();
  }

  /// Send a user message to the agent and process the response.
  /// This is the core agentic flow — the agent's response drives the UI.
  Future<void> sendChatMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message.
    _messages.add(ChatMessage.user(text));
    _messages.add(ChatMessage.loading());
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client.sendMessage(text);

      // Remove loading indicator.
      _messages.removeWhere((m) => m.isLoading);

      // Process structured data from the response.
      _processAgentResponse(response, text);

      // Add agent text response.
      final agentText = _buildAgentReply(response);
      if (agentText.isNotEmpty) {
        _messages.add(ChatMessage.agent(agentText));
      }
    } on A2AException catch (e) {
      _messages.removeWhere((m) => m.isLoading);
      _messages.add(ChatMessage.agent('Sorry, something went wrong: ${e.message}'));
      _error = e.message;
    } catch (e) {
      _messages.removeWhere((m) => m.isLoading);
      _messages.add(ChatMessage.agent('Sorry, something went wrong.'));
      _error = 'Something went wrong: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Process the agent response and update the UI state accordingly.
  void _processAgentResponse(A2AResponse response, String userQuery) {
    // Products → show catalog.
    if (response.hasProducts) {
      _products = response.products!.results;
      _currentView = ShopView.catalog;
    }

    // Checkout → navigate to the right screen based on status.
    if (response.hasCheckout) {
      _checkout = response.checkout;
      if (_checkout!.isCompleted) {
        _currentView = ShopView.confirmation;
      } else if (_checkout!.isReadyForComplete) {
        _currentView = ShopView.payment;
      } else if (_checkout!.lineItems.isNotEmpty) {
        _currentView = ShopView.cart;
      }
    }
  }

  /// Build a human-readable agent reply from the response.
  String _buildAgentReply(A2AResponse response) {
    final parts = <String>[];

    // Text from agent.
    if (response.text != null && response.text!.isNotEmpty) {
      parts.add(response.text!);
    }

    // Product results summary.
    if (response.hasProducts) {
      final count = response.products!.results.length;
      if (parts.isEmpty) {
        parts.add('I found $count product${count != 1 ? 's' : ''} for you.');
      }
    }

    // Checkout status updates.
    if (response.hasCheckout) {
      final co = response.checkout!;
      if (co.isCompleted && co.order != null) {
        parts.add(
          '🎉 Order confirmed! Your order ID is ${co.order!.id}.',
        );
      } else if (co.isReadyForComplete) {
        parts.add(
          '✅ Your order is ready! Total: ${co.grandTotal?.displayAmount ?? 'N/A'}. '
          'Tap "Confirm Purchase" to complete.',
        );
      } else if (co.lineItems.isNotEmpty) {
        final itemCount =
            co.lineItems.fold<int>(0, (sum, li) => sum + li.quantity);
        parts.add(
          '🛒 Cart updated: $itemCount item${itemCount != 1 ? 's' : ''}. '
          'Total: ${co.grandTotal?.displayAmount ?? 'N/A'}.',
        );
      }
    }

    if (parts.isEmpty) {
      parts.add("I'm here to help! Try asking me to search for something.");
    }

    return parts.join('\n\n');
  }

  // --- Navigation ---
  void showCatalog() {
    _currentView = ShopView.catalog;
    notifyListeners();
  }

  void showCart() {
    _currentView = ShopView.cart;
    notifyListeners();
  }

  void showCheckoutForm() {
    _currentView = ShopView.checkoutForm;
    notifyListeners();
  }

  void showConfirmation() {
    _currentView = ShopView.confirmation;
    notifyListeners();
  }

  // --- Manual actions (still available for direct UI interaction) ---

  Future<void> browseCatalog() async {
    await _run(() async {
      final response = await _client.browseCatalog();
      if (response.hasProducts) {
        _products = response.products!.results;
      }
    });
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    await _run(() async {
      final response = await _client.searchProducts(query);
      if (response.hasProducts) {
        _products = response.products!.results;
      } else {
        _products = [];
      }
    });
  }

  Future<void> addToCheckout(String productId, {int quantity = 1}) async {
    await _run(() async {
      final response = await _client.addToCheckout(
        productId,
        quantity: quantity,
      );
      if (response.hasCheckout) {
        _checkout = response.checkout;
      }
    });
  }

  Future<void> removeFromCheckout(String productId) async {
    await _run(() async {
      final response = await _client.removeFromCheckout(productId);
      if (response.hasCheckout) {
        _checkout = response.checkout;
      }
    });
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    await _run(() async {
      final response = await _client.updateCheckout(productId, quantity);
      if (response.hasCheckout) {
        _checkout = response.checkout;
      }
    });
  }

  Future<void> updateCustomerDetails({
    required String firstName,
    required String lastName,
    required String email,
    required String streetAddress,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    await _run(() async {
      final response = await _client.updateCustomerDetails(
        firstName: firstName,
        lastName: lastName,
        email: email,
        streetAddress: streetAddress,
        city: city,
        state: state,
        postalCode: postalCode,
      );
      if (response.hasCheckout) {
        _checkout = response.checkout;
        if (_checkout!.isReadyForComplete) {
          _currentView = ShopView.payment;
        }
      }
    });
  }

  Future<void> completeCheckout() async {
    await _run(() async {
      final paymentInstrument = {
        'id': 'mock_card_001',
        'type': 'card',
        'brand': 'visa',
        'last_digits': '4242',
        'expiry_month': 12,
        'expiry_year': 2028,
        'handler_id': 'example_payment_provider',
        'handler_name': 'example.payment.provider',
        'credential': {
          'type': 'payment_token',
          'token': 'tok_mock_demo_${DateTime.now().millisecondsSinceEpoch}',
        },
      };
      final response = await _client.completeCheckout(paymentInstrument);
      if (response.hasCheckout) {
        _checkout = response.checkout;
        if (_checkout!.isCompleted) {
          _currentView = ShopView.confirmation;
        }
      }
    });
  }

  /// Start a new shopping session.
  void newSession() {
    _client.resetSession();
    _products = [];
    _checkout = null;
    _error = null;
    _searchQuery = '';
    _currentView = ShopView.catalog;
    _messages.clear();
    _messages.add(ChatMessage.agent(
      "Hi! I'm your shopping assistant. What would you like to buy?",
    ));
    notifyListeners();
    browseCatalog();
  }

  // --- Internal ---

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on A2AException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Something went wrong: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// The current view/screen of the shopping flow.
enum ShopView {
  catalog,
  cart,
  checkoutForm,
  payment,
  confirmation,
}
