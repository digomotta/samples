import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/shop_state.dart';
import 'widgets/chat_view.dart';

void main() {
  runApp(const ShoppingApp());
}

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ShopState(),
      child: MaterialApp(
        title: 'UCP Shopping',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const ChatShell(),
      ),
    );
  }
}

/// Chat-first shell — mirrors the React UCP chat-client.
class ChatShell extends StatelessWidget {
  const ChatShell({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.storefront,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
        title: const Text('Shopping Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New session',
            onPressed: () => context.read<ShopState>().newSession(),
          ),
        ],
      ),
      body: const ChatView(),
    );
  }
}
