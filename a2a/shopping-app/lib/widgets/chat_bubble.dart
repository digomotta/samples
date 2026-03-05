import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/checkout.dart';
import '../models/product.dart';

/// A single chat message — text, product cards, checkout, or loading.
/// Mirrors the React ChatMessage component.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.isLastCheckout = false,
    this.onAddToCart,
    this.onStartPayment,
    this.onCompletePayment,
  });

  final ChatMessage message;
  final bool isLastCheckout;
  final ValueChanged<String>? onAddToCart;
  final VoidCallback? onStartPayment;
  final VoidCallback? onCompletePayment;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    // Loading indicator.
    if (message.isLoading) return _TypingIndicator();

    // User message.
    if (isUser) return _UserBubble(text: message.text);

    // Agent message — can have text + products + checkout.
    return _AgentMessage(
      message: message,
      isLastCheckout: isLastCheckout,
      onAddToCart: onAddToCart,
      onStartPayment: onStartPayment,
      onCompletePayment: onCompletePayment,
    );
  }
}

// ─── User bubble ─────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

// ─── Agent message (text + products + checkout) ──────────────────────────────

class _AgentMessage extends StatelessWidget {
  const _AgentMessage({
    required this.message,
    required this.isLastCheckout,
    this.onAddToCart,
    this.onStartPayment,
    this.onCompletePayment,
  });

  final ChatMessage message;
  final bool isLastCheckout;
  final ValueChanged<String>? onAddToCart;
  final VoidCallback? onStartPayment;
  final VoidCallback? onCompletePayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent avatar.
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          // Content.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shopping Assistant',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                // Text bubble.
                if (message.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                // Product cards (horizontal scroll).
                if (message.hasProducts)
                  _ProductCarousel(
                    products: message.products!,
                    onAddToCart: onAddToCart,
                  ),
                // Checkout card.
                if (message.hasCheckout)
                  _CheckoutCard(
                    checkout: message.checkout!,
                    isLastCheckout: isLastCheckout,
                    onStartPayment: onStartPayment,
                    onCompletePayment: onCompletePayment,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing indicator ────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.smart_toy,
                size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: child,
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Product carousel (horizontal scroll, like React chat-client) ────────────

class _ProductCarousel extends StatelessWidget {
  const _ProductCarousel({required this.products, this.onAddToCart});

  final List<Product> products;
  final ValueChanged<String>? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 280,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final product = products[index];
            return _InlineProductCard(
              product: product,
              onAddToCart: () => onAddToCart?.call(product.productId),
            );
          },
        ),
      ),
    );
  }
}

class _InlineProductCard extends StatelessWidget {
  const _InlineProductCard({required this.product, this.onAddToCart});

  final Product product;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image.
            SizedBox(
              height: 120,
              width: double.infinity,
              child: product.images.isNotEmpty
                  ? Image.network(
                      product.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder(theme),
                    )
                  : _imgPlaceholder(theme),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.brandName != null)
                    Text(
                      product.brandName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.displayPrice,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'In Stock',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAddToCart,
                      child: const Text('Add to Checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── Checkout card (inline, like React Checkout component) ───────────────────

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.checkout,
    required this.isLastCheckout,
    this.onStartPayment,
    this.onCompletePayment,
  });

  final Checkout checkout;
  final bool isLastCheckout;
  final VoidCallback? onStartPayment;
  final VoidCallback? onCompletePayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grandTotal = checkout.grandTotal;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header.
              Row(
                children: [
                  Icon(Icons.shopping_cart, size: 20,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    checkout.isCompleted
                        ? 'Order Confirmed'
                        : 'Checkout Summary',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Order ID.
              if (checkout.order != null) ...[
                const Divider(height: 16),
                Text(
                  'Order ID: ${checkout.order!.id}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const Divider(height: 16),
              // Line items.
              for (final li in checkout.lineItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      // Item image.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: li.item.imageUrl != null
                              ? Image.network(
                                  li.item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _itemPlaceholder(theme),
                                )
                              : _itemPlaceholder(theme),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              li.item.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Qty: ${li.quantity}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        li.item.displayPrice,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 16),
              // Totals.
              for (final total in checkout.totals.where(
                  (t) => t.type != 'total' && t.amount > 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(total.displayText,
                          style: theme.textTheme.bodySmall),
                      Text(total.displayAmount,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              if (grandTotal != null) ...[
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      grandTotal.displayText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      grandTotal.displayAmount,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
              // Checkout ID.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Checkout ID: ${checkout.id}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // Action buttons (only on the last checkout message).
              if (isLastCheckout && !checkout.isCompleted) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    if (checkout.continueUrl != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const Text('Go to Checkout'),
                        ),
                      ),
                    if (checkout.continueUrl != null)
                      const SizedBox(width: 8),
                    if (!checkout.isReadyForComplete && onStartPayment != null)
                      Expanded(
                        child: FilledButton(
                          onPressed: onStartPayment,
                          child: const Text('Start Payment'),
                        ),
                      ),
                    if (checkout.isReadyForComplete &&
                        onCompletePayment != null)
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: onCompletePayment,
                          child: const Text('Complete Payment'),
                        ),
                      ),
                  ],
                ),
              ],
              // Order permalink.
              if (checkout.order?.permalinkUrl != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Order'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.image, size: 20,
          color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
