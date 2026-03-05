import 'package:flutter/material.dart';

import '../models/checkout.dart';

/// Displays a single line item in the cart with quantity controls.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.lineItem,
    required this.onRemove,
    required this.onUpdateQuantity,
    this.isLoading = false,
  });

  final LineItem lineItem;
  final VoidCallback onRemove;
  final ValueChanged<int> onUpdateQuantity;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = lineItem.item;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(theme),
                      )
                    : _placeholder(theme),
              ),
            ),
            const SizedBox(width: 12),
            // Info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.displayPrice,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Quantity controls.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: isLoading
                      ? null
                      : () {
                          if (lineItem.quantity > 1) {
                            onUpdateQuantity(lineItem.quantity - 1);
                          } else {
                            onRemove();
                          }
                        },
                ),
                Text(
                  '${lineItem.quantity}',
                  style: theme.textTheme.titleSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: isLoading
                      ? null
                      : () => onUpdateQuantity(lineItem.quantity + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 24,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
