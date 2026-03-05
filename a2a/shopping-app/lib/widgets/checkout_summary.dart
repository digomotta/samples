import 'package:flutter/material.dart';

import '../models/checkout.dart';

/// Displays checkout totals (subtotal, shipping, tax, total).
class CheckoutSummary extends StatelessWidget {
  const CheckoutSummary({super.key, required this.checkout});

  final Checkout checkout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Summary', style: theme.textTheme.titleMedium),
            const Divider(height: 24),
            for (final total in checkout.totals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      total.displayText,
                      style: total.type == 'total'
                          ? theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                    Text(
                      total.displayAmount,
                      style: total.type == 'total'
                          ? theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            )
                          : theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
