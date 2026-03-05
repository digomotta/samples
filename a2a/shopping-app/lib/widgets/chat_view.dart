import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_state.dart';
import 'chat_bubble.dart';
import 'chat_input.dart';

/// Full-screen chat view — the main app experience.
class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopState>();
    final messages = shop.messages;
    final lastCheckoutIdx = shop.lastCheckoutIndex;

    // Auto-scroll when messages change.
    _scrollToBottom();

    return Column(
      children: [
        // Messages list.
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return ChatBubble(
                message: msg,
                isLastCheckout: index == lastCheckoutIdx,
                onAddToCart: (productId) => shop.addToCheckout(productId),
                onStartPayment: shop.startPayment,
                onCompletePayment: shop.completePayment,
              );
            },
          ),
        ),
        // Input bar.
        ChatInput(
          isLoading: shop.isLoading,
          onSend: shop.sendMessage,
        ),
      ],
    );
  }
}
