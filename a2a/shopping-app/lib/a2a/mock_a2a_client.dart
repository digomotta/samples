import '../models/checkout.dart';
import '../models/product.dart';
import 'a2a_client.dart';

/// Mock A2A client that works without a running business agent.
/// Uses the same product catalog as the SuperStore agent.
class MockA2AClient extends A2AClient {
  MockA2AClient() : super(agentBaseUrl: 'mock://');

  final List<Product> _catalog = _buildCatalog();
  final List<_CartEntry> _cart = [];
  String? _checkoutId;
  String _status = 'incomplete';
  OrderConfirmation? _order;

  @override
  Future<A2AResponse> browseCatalog() async {
    await _simulateDelay();
    return A2AResponse(
      products: ProductResults(results: _catalog),
      raw: {},
    );
  }

  @override
  Future<A2AResponse> searchProducts(String query) async {
    await _simulateDelay();
    final keywords = query.toLowerCase().split(' ');
    final matches = _catalog.where((p) {
      final haystack =
          '${p.name} ${p.description ?? ''} ${p.category ?? ''}'.toLowerCase();
      return keywords.any((kw) => haystack.contains(kw));
    }).toList();
    return A2AResponse(
      products: ProductResults(
        results: matches,
        content: matches.isEmpty ? 'No products found' : null,
      ),
      text: matches.isEmpty ? 'No products found for "$query"' : null,
      raw: {},
    );
  }

  @override
  Future<A2AResponse> addToCheckout(
    String productId, {
    int quantity = 1,
  }) async {
    await _simulateDelay();
    _checkoutId ??= 'mock-${DateTime.now().millisecondsSinceEpoch}';
    final existing = _cart.where((e) => e.productId == productId).firstOrNull;
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _cart.add(_CartEntry(productId: productId, quantity: quantity));
    }
    _status = 'incomplete';
    return A2AResponse(checkout: _buildCheckout(), raw: {});
  }

  @override
  Future<A2AResponse> removeFromCheckout(String productId) async {
    await _simulateDelay();
    _cart.removeWhere((e) => e.productId == productId);
    _status = 'incomplete';
    return A2AResponse(checkout: _buildCheckout(), raw: {});
  }

  @override
  Future<A2AResponse> updateCheckout(String productId, int quantity) async {
    await _simulateDelay();
    final entry = _cart.where((e) => e.productId == productId).firstOrNull;
    if (entry != null) {
      entry.quantity = quantity;
    }
    _status = 'incomplete';
    return A2AResponse(checkout: _buildCheckout(), raw: {});
  }

  @override
  Future<A2AResponse> getCheckout() async {
    await _simulateDelay();
    return A2AResponse(checkout: _buildCheckout(), raw: {});
  }

  @override
  Future<A2AResponse> sendMessage(String text) async {
    // Route text messages to the appropriate action.
    final lower = text.toLowerCase();
    if (lower.contains('all available') || lower.contains('browse')) {
      return browseCatalog();
    }
    if (lower.contains('search for')) {
      final query = lower.replaceFirst('search for ', '');
      return searchProducts(query);
    }
    return browseCatalog();
  }

  @override
  Future<A2AResponse> updateCustomerDetails({
    required String firstName,
    required String lastName,
    required String email,
    required String streetAddress,
    required String city,
    required String state,
    required String postalCode,
    String country = 'US',
  }) async {
    await _simulateDelay();
    _status = 'ready_for_complete';
    return A2AResponse(checkout: _buildCheckout(), raw: {});
  }

  @override
  Future<A2AResponse> startPayment() async {
    await _simulateDelay();
    if (_cart.isEmpty) {
      return A2AResponse(text: 'Cart is empty', raw: {});
    }
    _status = 'ready_for_complete';
    return A2AResponse(checkout: _buildCheckout(), raw: {});
  }

  @override
  Future<A2AResponse> completeCheckout(
    Map<String, dynamic> paymentInstrument,
  ) async {
    await _simulateDelay();
    _status = 'completed';
    _order = OrderConfirmation(
      id: 'ORD-$_checkoutId',
      permalinkUrl: 'https://example.com/order?id=ORD-$_checkoutId',
    );
    final checkout = _buildCheckout();
    // Reset for next session.
    _cart.clear();
    _checkoutId = null;
    _status = 'incomplete';
    return A2AResponse(checkout: checkout, raw: {});
  }

  @override
  void resetSession() {
    _cart.clear();
    _checkoutId = null;
    _status = 'incomplete';
    _order = null;
  }

  // --- Helpers ---

  Future<void> _simulateDelay() =>
      Future.delayed(const Duration(milliseconds: 300));

  Product? _findProduct(String productId) {
    return _catalog.where((p) => p.productId == productId).firstOrNull;
  }

  Checkout _buildCheckout() {
    final lineItems = <LineItem>[];
    int subtotal = 0;

    for (final entry in _cart) {
      final product = _findProduct(entry.productId);
      if (product == null) continue;

      final priceStr = product.price ?? '0';
      final unitPrice = (double.tryParse(priceStr) ?? 0) * 100;
      final unitPriceCents = unitPrice.round();
      final lineTotal = unitPriceCents * entry.quantity;
      subtotal += lineTotal;

      lineItems.add(LineItem(
        id: 'li-${entry.productId}',
        item: CheckoutItem(
          id: entry.productId,
          title: product.name,
          price: unitPriceCents,
          imageUrl: product.images.isNotEmpty ? product.images.first : null,
        ),
        quantity: entry.quantity,
        totals: [
          CheckoutTotal(
            type: 'total',
            displayText: 'Total',
            amount: lineTotal,
          ),
        ],
      ));
    }

    final shipping = _status == 'ready_for_complete' || _status == 'completed'
        ? 500
        : 0;
    final tax = _status == 'ready_for_complete' || _status == 'completed'
        ? (subtotal * 0.1).round()
        : 0;
    final total = subtotal + shipping + tax;

    final totals = <CheckoutTotal>[
      CheckoutTotal(type: 'subtotal', displayText: 'Subtotal', amount: subtotal),
      if (shipping > 0)
        CheckoutTotal(
            type: 'fulfillment', displayText: 'Shipping', amount: shipping),
      if (tax > 0)
        CheckoutTotal(type: 'tax', displayText: 'Tax', amount: tax),
      CheckoutTotal(type: 'total', displayText: 'Total', amount: total),
    ];

    return Checkout(
      id: _checkoutId ?? 'no-checkout',
      lineItems: lineItems,
      currency: 'USD',
      status: _status,
      totals: totals,
      payment: Payment(handlers: [
        PaymentHandler(
          id: 'example_payment_provider',
          name: 'example.payment.provider',
          config: {'business_id': '1234567890'},
        ),
      ]),
      order: _order,
    );
  }
}

class _CartEntry {
  final String productId;
  int quantity;

  _CartEntry({required this.productId, required this.quantity});
}

/// Builds the same catalog as the SuperStore business agent.
List<Product> _buildCatalog() {
  return [
    Product(
      productId: 'BISC-001',
      name: 'Chocochip Cookies',
      description: 'Freshly baked Chocochip Cookies',
      images: ['http://localhost:10999/images/cookies.jpg'],
      brandName: 'CookieCo',
      price: '4.99',
      priceCurrency: 'USD',
      category: 'Groceries > Snacks > Cookies & Biscuits',
    ),
    Product(
      productId: 'STRAW-001',
      name: 'Fresh Strawberries',
      description: 'Sweet and juicy fresh strawberries, 1 lb.',
      images: ['http://localhost:10999/images/strawberries.jpg'],
      brandName: 'FarmFresh',
      price: '4.49',
      priceCurrency: 'USD',
      category: 'Groceries > Fresh Produce > Fruits',
    ),
    Product(
      productId: 'CHIPS-001',
      name: 'Classic Potato Chips',
      description: 'Crispy and salty classic potato chips, family size.',
      images: ['http://localhost:10999/images/chips.jpg'],
      brandName: 'SaltySnacks',
      price: '3.79',
      priceCurrency: 'USD',
      category: 'Groceries > Snacks > Chips & Crisps',
    ),
    Product(
      productId: 'SW-CHIPS-001',
      name: 'Baked Sweet Potato Chips',
      description: 'Crispy and salty sweet potato chips, family size.',
      images: ['http://localhost:10999/images/chips.jpg'],
      brandName: 'SaltySnacks',
      price: '4.79',
      priceCurrency: 'USD',
      category: 'Groceries > Snacks > Chips & Crisps',
    ),
    Product(
      productId: 'O-COOKIES-001',
      name: 'Classic Oat Cookies',
      description: 'Freshly baked Oat Cookies',
      images: ['http://localhost:10999/images/oat_cookies.jpg'],
      brandName: 'CookieCo',
      price: '5.99',
      priceCurrency: 'USD',
      category: 'Groceries > Snacks > Cookies & Biscuits',
    ),
    Product(
      productId: 'NUTRIBAR-001',
      name: 'Nutri-Bar',
      description:
          'A healthy and nutritious snack bar, packed with nuts and seeds.',
      images: ['http://localhost:10999/images/nutribar.jpg'],
      brandName: 'HealthEats',
      price: '2.99',
      priceCurrency: 'USD',
      category: 'Groceries > Health & Nutrition Bars',
    ),
  ];
}
