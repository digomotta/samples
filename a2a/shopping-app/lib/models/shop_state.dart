import 'package:flutter/foundation.dart';

import '../a2a/a2a_client.dart';
import 'checkout.dart';
import 'product.dart';

/// Centralized shopping state — drives the entire app.
class ShopState extends ChangeNotifier {
  ShopState({A2AClient? client}) : _client = client ?? A2AClient();

  final A2AClient _client;

  // --- State ---
  List<Product> _products = [];
  Checkout? _checkout;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  ShopView _currentView = ShopView.catalog;

  // --- Getters ---
  List<Product> get products => _products;
  Checkout? get checkout => _checkout;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  ShopView get currentView => _currentView;

  int get cartItemCount {
    if (_checkout == null) return 0;
    return _checkout!.lineItems.fold(0, (sum, li) => sum + li.quantity);
  }

  // --- Navigation ---
  void showCatalog() {
    _currentView = ShopView.catalog;
    notifyListeners();
  }

  void showCart() {
    _currentView = ShopView.cart;
    notifyListeners();
  }

  void showCheckoutForm() {
    _currentView = ShopView.checkoutForm;
    notifyListeners();
  }

  void showConfirmation() {
    _currentView = ShopView.confirmation;
    notifyListeners();
  }

  // --- Actions ---

  Future<void> browseCatalog() async {
    await _run(() async {
      final response = await _client.browseCatalog();
      if (response.hasProducts) {
        _products = response.products!.results;
      }
    });
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    await _run(() async {
      final response = await _client.searchProducts(query);
      if (response.hasProducts) {
        _products = response.products!.results;
      } else {
        _products = [];
      }
    });
  }

  Future<void> addToCheckout(String productId, {int quantity = 1}) async {
    await _run(() async {
      final response = await _client.addToCheckout(
        productId,
        quantity: quantity,
      );
      if (response.hasCheckout) {
        _checkout = response.checkout;
      }
    });
  }

  Future<void> removeFromCheckout(String productId) async {
    await _run(() async {
      final response = await _client.removeFromCheckout(productId);
      if (response.hasCheckout) {
        _checkout = response.checkout;
      }
    });
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    await _run(() async {
      final response = await _client.updateCheckout(productId, quantity);
      if (response.hasCheckout) {
        _checkout = response.checkout;
      }
    });
  }

  Future<void> updateCustomerDetails({
    required String firstName,
    required String lastName,
    required String email,
    required String streetAddress,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    await _run(() async {
      final response = await _client.updateCustomerDetails(
        firstName: firstName,
        lastName: lastName,
        email: email,
        streetAddress: streetAddress,
        city: city,
        state: state,
        postalCode: postalCode,
      );
      if (response.hasCheckout) {
        _checkout = response.checkout;
        if (_checkout!.isReadyForComplete) {
          _currentView = ShopView.payment;
        }
      }
    });
  }

  Future<void> completeCheckout() async {
    await _run(() async {
      // Mock payment instrument for demo.
      final paymentInstrument = {
        'id': 'mock_card_001',
        'type': 'card',
        'brand': 'visa',
        'last_digits': '4242',
        'expiry_month': 12,
        'expiry_year': 2028,
        'handler_id': 'example_payment_provider',
        'handler_name': 'example.payment.provider',
        'credential': {
          'type': 'payment_token',
          'token': 'tok_mock_demo_${DateTime.now().millisecondsSinceEpoch}',
        },
      };
      final response = await _client.completeCheckout(paymentInstrument);
      if (response.hasCheckout) {
        _checkout = response.checkout;
        if (_checkout!.isCompleted) {
          _currentView = ShopView.confirmation;
        }
      }
    });
  }

  /// Start a new shopping session.
  void newSession() {
    _client.resetSession();
    _products = [];
    _checkout = null;
    _error = null;
    _searchQuery = '';
    _currentView = ShopView.catalog;
    notifyListeners();
    browseCatalog();
  }

  // --- Internal ---

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on A2AException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Something went wrong: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// The current view/screen of the shopping flow.
enum ShopView {
  catalog,
  cart,
  checkoutForm,
  payment,
  confirmation,
}
