import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/shop_state.dart';
import 'screens/cart_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/checkout_form_screen.dart';
import 'screens/confirmation_screen.dart';
import 'screens/payment_screen.dart';
import 'widgets/chat_panel.dart';

void main() {
  runApp(const ShoppingApp());
}

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ShopState()..browseCatalog(),
      child: MaterialApp(
        title: 'UCP Shopping',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
          brightness: Brightness.light,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
          brightness: Brightness.dark,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        home: const ShoppingShell(),
      ),
    );
  }
}

/// App shell with AppBar, view switching, and agent chat panel.
class ShoppingShell extends StatelessWidget {
  const ShoppingShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(shop.currentView)),
        leading: _showBackButton(shop.currentView)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goBack(shop),
              )
            : null,
        actions: [
          if (shop.currentView == ShopView.catalog)
            Badge(
              label: Text('${shop.cartItemCount}'),
              isLabelVisible: shop.cartItemCount > 0,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: shop.showCart,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Main content.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildScreen(shop.currentView),
          ),
          // Chat panel overlay.
          if (shop.isChatOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: shop.closeChat,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
          // Sliding chat panel.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: shop.isChatOpen ? 0 : -(MediaQuery.of(context).size.height * 0.7),
            height: MediaQuery.of(context).size.height * 0.7,
            child: const ChatPanel(),
          ),
        ],
      ),
      // Agent FAB.
      floatingActionButton: shop.isChatOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: shop.toggleChat,
              icon: Badge(
                label: Text('${shop.messages.length}'),
                isLabelVisible: shop.messages.length > 1,
                child: const Icon(Icons.smart_toy),
              ),
              label: const Text('Ask Agent'),
            ),
    );
  }

  String _title(ShopView view) {
    return switch (view) {
      ShopView.catalog => 'SuperStore',
      ShopView.cart => 'Cart',
      ShopView.checkoutForm => 'Checkout',
      ShopView.payment => 'Payment',
      ShopView.confirmation => 'Order Confirmed',
    };
  }

  bool _showBackButton(ShopView view) {
    return view != ShopView.catalog && view != ShopView.confirmation;
  }

  void _goBack(ShopState shop) {
    switch (shop.currentView) {
      case ShopView.cart:
        shop.showCatalog();
      case ShopView.checkoutForm:
        shop.showCart();
      case ShopView.payment:
        shop.showCheckoutForm();
      default:
        break;
    }
  }

  Widget _buildScreen(ShopView view) {
    return switch (view) {
      ShopView.catalog => const CatalogScreen(key: ValueKey('catalog')),
      ShopView.cart => const CartScreen(key: ValueKey('cart')),
      ShopView.checkoutForm =>
        const CheckoutFormScreen(key: ValueKey('checkout')),
      ShopView.payment => const PaymentScreen(key: ValueKey('payment')),
      ShopView.confirmation =>
        const ConfirmationScreen(key: ValueKey('confirmation')),
    };
  }
}
