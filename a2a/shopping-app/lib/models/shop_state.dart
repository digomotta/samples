import 'package:flutter/foundation.dart';

import '../a2a/a2a_client.dart';
import '../a2a/mock_a2a_client.dart';
import '../config/app_config.dart';
import 'chat_message.dart';
import 'checkout.dart';

/// Chat-first shopping state — mirrors the React UCP chat-client.
///
/// The entire shopping experience is conversational: user talks to the agent,
/// agent responds with text + structured data (products, checkout) inline.
class ShopState extends ChangeNotifier {
  ShopState({A2AClient? client})
      : _client =
            client ?? (AppConfig.useMock ? MockA2AClient() : A2AClient());

  final A2AClient _client;

  // --- State ---
  final List<ChatMessage> _messages = [
    ChatMessage.agent(
      'Hello! I am your Shopping Assistant. How can I help you?',
    ),
  ];
  bool _isLoading = false;
  Checkout? _lastCheckout;

  // --- Getters ---
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  Checkout? get lastCheckout => _lastCheckout;

  /// Index of the last message that contains a checkout (for action buttons).
  int get lastCheckoutIndex =>
      _messages.lastIndexWhere((m) => m.hasCheckout);

  // --- Chat actions ---

  /// Send a free-text message to the agent.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _addUserMessage(text);
    await _callAgent(text);
  }

  /// User tapped "Add to Checkout" on a product card.
  Future<void> addToCheckout(String productId) async {
    if (_isLoading) return;
    _addUserMessage('Add to checkout', isUserAction: true);
    await _callAgentRaw(() => _client.addToCheckout(productId));
  }

  /// User tapped "Start Payment" on a checkout card.
  Future<void> startPayment() async {
    if (_isLoading) return;
    _addUserMessage('Start payment', isUserAction: true);
    await _callAgentRaw(() => _client.startPayment());
  }

  /// User tapped "Complete Payment" on a ready checkout.
  Future<void> completePayment() async {
    if (_isLoading) return;
    _addUserMessage('Confirm purchase', isUserAction: true);
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
        'token': 'tok_mock_${DateTime.now().millisecondsSinceEpoch}',
      },
    };
    await _callAgentRaw(() => _client.completeCheckout(paymentInstrument));
  }

  /// Reset and start over.
  void newSession() {
    _client.resetSession();
    _messages.clear();
    _messages.add(ChatMessage.agent(
      'Hello! I am your Shopping Assistant. How can I help you?',
    ));
    _lastCheckout = null;
    _isLoading = false;
    notifyListeners();
  }

  // --- Internal ---

  void _addUserMessage(String text, {bool isUserAction = false}) {
    _messages.add(ChatMessage.user(text, isUserAction: isUserAction));
    _messages.add(ChatMessage.loading());
    _isLoading = true;
    notifyListeners();
  }

  /// Call agent with a text message.
  Future<void> _callAgent(String text) async {
    try {
      final response = await _client.sendMessage(text);
      _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  /// Call agent with a raw A2A method.
  Future<void> _callAgentRaw(Future<A2AResponse> Function() call) async {
    try {
      final response = await call();
      _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleResponse(A2AResponse response) {
    _messages.removeWhere((m) => m.isLoading);

    if (response.hasCheckout) {
      _lastCheckout = response.checkout;
    }

    final hasContent = (response.text != null && response.text!.isNotEmpty) ||
        response.hasProducts ||
        response.hasCheckout;

    if (hasContent) {
      _messages.add(ChatMessage.agent(
        response.text ?? '',
        products: response.products?.results,
        checkout: response.checkout,
      ));
    } else {
      _messages.add(ChatMessage.agent(
        "I'm not sure how to help with that. "
        "Try asking me to search for products or browse the catalog.",
      ));
    }

    _isLoading = false;
    notifyListeners();
  }

  void _handleError(Object e) {
    _messages.removeWhere((m) => m.isLoading);
    final msg = e is A2AException
        ? 'Sorry, something went wrong: ${e.message}'
        : 'Sorry, something went wrong. Please try again.';
    _messages.add(ChatMessage.agent(msg));
    _isLoading = false;
    notifyListeners();
  }
}
