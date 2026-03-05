import 'checkout.dart';
import 'product.dart';

/// A message in the agent chat — can contain text, products, checkout, or a
/// combination (like the React chat-client).
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final List<Product>? products;
  final Checkout? checkout;
  final bool isLoading;
  final bool isUserAction;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    this.text = '',
    this.products,
    this.checkout,
    this.isLoading = false,
    this.isUserAction = false,
    required this.timestamp,
  });

  factory ChatMessage.user(String text, {bool isUserAction = false}) =>
      ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}-user',
        role: ChatRole.user,
        text: text,
        isUserAction: isUserAction,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.agent(
    String text, {
    List<Product>? products,
    Checkout? checkout,
  }) =>
      ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}-agent',
        role: ChatRole.agent,
        text: text,
        products: products,
        checkout: checkout,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.loading() => ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}-loading',
        role: ChatRole.agent,
        isLoading: true,
        timestamp: DateTime.now(),
      );

  bool get hasProducts => products != null && products!.isNotEmpty;
  bool get hasCheckout => checkout != null;
}

enum ChatRole { user, agent }
