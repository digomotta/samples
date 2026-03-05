import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_state.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/checkout_summary.dart';

/// Cart screen showing line items, totals, and proceed-to-checkout button.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopState>();
    final checkout = shop.checkout;
    final theme = Theme.of(context);

    if (checkout == null || checkout.lineItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text('Your cart is empty', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: shop.showCatalog,
              child: const Text('Browse Products'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (shop.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: 8),
              // Line items.
              for (final lineItem in checkout.lineItems)
                CartItemTile(
                  lineItem: lineItem,
                  isLoading: shop.isLoading,
                  onRemove: () =>
                      shop.removeFromCheckout(lineItem.item.id),
                  onUpdateQuantity: (qty) =>
                      shop.updateQuantity(lineItem.item.id, qty),
                ),
              const SizedBox(height: 8),
              // Totals.
              CheckoutSummary(checkout: checkout),
              const SizedBox(height: 80),
            ],
          ),
        ),
        // Bottom bar.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: shop.isLoading ? null : shop.showCheckoutForm,
                icon: const Icon(Icons.payment),
                label: Text(
                  'Proceed to Checkout'
                  '${checkout.grandTotal != null ? ' (${checkout.grandTotal!.displayAmount})' : ''}',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
