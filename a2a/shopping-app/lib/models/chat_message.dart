/// A message in the agent chat.
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final bool isLoading;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    this.text = '',
    this.isLoading = false,
    required this.timestamp,
  });

  factory ChatMessage.user(String text) => ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}-user',
        role: ChatRole.user,
        text: text,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.agent(String text) => ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}-agent',
        role: ChatRole.agent,
        text: text,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.loading() => ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}-loading',
        role: ChatRole.agent,
        isLoading: true,
        timestamp: DateTime.now(),
      );
}

enum ChatRole { user, agent }
