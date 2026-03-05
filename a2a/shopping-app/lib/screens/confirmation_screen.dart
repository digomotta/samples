import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_state.dart';

/// Order confirmation screen — shown after successful checkout.
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopState>();
    final checkout = shop.checkout;
    final order = checkout?.order;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon.
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Order Confirmed!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you for your purchase',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (order != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row(theme, 'Order ID', order.id),
                      if (checkout?.grandTotal != null)
                        _row(theme, 'Total',
                            checkout!.grandTotal!.displayAmount),
                      if (checkout?.lineItems != null)
                        _row(theme, 'Items',
                            '${checkout!.lineItems.length} item(s)'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: shop.newSession,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
