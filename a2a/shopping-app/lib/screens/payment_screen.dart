import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_state.dart';
import '../widgets/checkout_summary.dart';

/// Payment confirmation screen — shows order summary and confirm button.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopState>();
    final checkout = shop.checkout;
    final theme = Theme.of(context);

    if (checkout == null) {
      return const Center(child: Text('No checkout in progress'));
    }

    return Column(
      children: [
        if (shop.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status badge.
              Center(
                child: Chip(
                  avatar: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Ready for Payment'),
                  backgroundColor:
                      theme.colorScheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              // Items summary.
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Items', style: theme.textTheme.titleMedium),
                      const Divider(height: 16),
                      for (final li in checkout.lineItems)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${li.quantity}x ${li.item.title}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Text(li.item.displayPrice),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Totals.
              CheckoutSummary(checkout: checkout),
              const SizedBox(height: 16),
              // Mock payment method.
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visa •••• 4242',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              'Expires 12/28',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (shop.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    shop.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: shop.isLoading ? null : shop.completeCheckout,
                icon: const Icon(Icons.shopping_bag),
                label: Text(
                  'Confirm Purchase'
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
