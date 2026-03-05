/// A total line (subtotal, tax, shipping, discount, total).
class CheckoutTotal {
  final String type;
  final String displayText;
  final int amount;

  const CheckoutTotal({
    required this.type,
    required this.displayText,
    required this.amount,
  });

  factory CheckoutTotal.fromJson(Map<String, dynamic> json) {
    return CheckoutTotal(
      type: json['type'] as String? ?? '',
      displayText: json['display_text'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
    );
  }

  String get displayAmount {
    final dollars = amount / 100;
    return '\$${dollars.toStringAsFixed(2)}';
  }
}

/// An item inside a line item.
class CheckoutItem {
  final String id;
  final String title;
  final int price;
  final String? imageUrl;

  const CheckoutItem({
    required this.id,
    required this.title,
    required this.price,
    this.imageUrl,
  });

  factory CheckoutItem.fromJson(Map<String, dynamic> json) {
    return CheckoutItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
    );
  }

  String get displayPrice {
    final dollars = price / 100;
    return '\$${dollars.toStringAsFixed(2)}';
  }
}

/// A line item in the checkout.
class LineItem {
  final String id;
  final CheckoutItem item;
  final int quantity;
  final List<CheckoutTotal> totals;

  const LineItem({
    required this.id,
    required this.item,
    required this.quantity,
    this.totals = const [],
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'] as Map<String, dynamic>? ?? {};
    final totalsList = json['totals'] as List<dynamic>? ?? [];
    return LineItem(
      id: json['id'] as String? ?? '',
      item: CheckoutItem.fromJson(itemJson),
      quantity: json['quantity'] as int? ?? 0,
      totals: totalsList
          .map((e) => CheckoutTotal.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Order confirmation after completed checkout.
class OrderConfirmation {
  final String id;
  final String? permalinkUrl;

  const OrderConfirmation({required this.id, this.permalinkUrl});

  factory OrderConfirmation.fromJson(Map<String, dynamic> json) {
    return OrderConfirmation(
      id: json['id'] as String? ?? '',
      permalinkUrl: json['permalink_url'] as String?,
    );
  }
}

/// Payment handler info.
class PaymentHandler {
  final String id;
  final String name;
  final Map<String, dynamic>? config;

  const PaymentHandler({
    required this.id,
    required this.name,
    this.config,
  });

  factory PaymentHandler.fromJson(Map<String, dynamic> json) {
    return PaymentHandler(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      config: json['config'] as Map<String, dynamic>?,
    );
  }
}

/// Payment section of a checkout.
class Payment {
  final List<PaymentHandler> handlers;
  final String? selectedInstrumentId;

  const Payment({this.handlers = const [], this.selectedInstrumentId});

  factory Payment.fromJson(Map<String, dynamic> json) {
    final handlersList = json['handlers'] as List<dynamic>? ?? [];
    return Payment(
      handlers: handlersList
          .map((e) => PaymentHandler.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedInstrumentId: json['selected_instrument_id'] as String?,
    );
  }
}

/// The full checkout object returned by the business agent.
class Checkout {
  final String id;
  final List<LineItem> lineItems;
  final String currency;
  final String status;
  final List<CheckoutTotal> totals;
  final String? continueUrl;
  final Payment? payment;
  final OrderConfirmation? order;

  const Checkout({
    required this.id,
    required this.lineItems,
    this.currency = 'USD',
    this.status = 'incomplete',
    this.totals = const [],
    this.continueUrl,
    this.payment,
    this.order,
  });

  factory Checkout.fromJson(Map<String, dynamic> json) {
    final items = json['line_items'] as List<dynamic>? ?? [];
    final totalsList = json['totals'] as List<dynamic>? ?? [];
    final paymentJson = json['payment'] as Map<String, dynamic>?;
    final orderJson = json['order'] as Map<String, dynamic>?;
    return Checkout(
      id: json['id'] as String? ?? '',
      lineItems: items
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'incomplete',
      totals: totalsList
          .map((e) => CheckoutTotal.fromJson(e as Map<String, dynamic>))
          .toList(),
      continueUrl: json['continue_url'] as String?,
      payment: paymentJson != null ? Payment.fromJson(paymentJson) : null,
      order: orderJson != null
          ? OrderConfirmation.fromJson(orderJson)
          : null,
    );
  }

  /// Find the "total" line in totals.
  CheckoutTotal? get grandTotal {
    try {
      return totals.firstWhere((t) => t.type == 'total');
    } catch (_) {
      return null;
    }
  }

  bool get isReadyForComplete => status == 'ready_for_complete';
  bool get isCompleted => status == 'completed';
  bool get isIncomplete => status == 'incomplete';
}
