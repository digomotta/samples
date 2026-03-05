import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/checkout.dart';
import '../models/product.dart';

/// Lightweight A2A JSON-RPC client that talks to a UCP business agent.
///
/// Sends `message/send` JSON-RPC requests with UCP extension headers.
/// Parses structured UCP responses (product results, checkout data).
class A2AClient {
  A2AClient({
    String? agentBaseUrl,
    String? ucpProfileUrl,
    http.Client? httpClient,
  })  : _agentBaseUrl = agentBaseUrl ?? AppConfig.agentBaseUrl,
        _ucpProfileUrl = ucpProfileUrl ?? AppConfig.ucpProfileUrl,
        _httpClient = httpClient ?? http.Client();

  final String _agentBaseUrl;
  final String _ucpProfileUrl;
  final http.Client _httpClient;

  /// Current context ID for the A2A session.
  String? _contextId;

  /// Current task ID for active tasks.
  String? _taskId;

  String? get contextId => _contextId;

  /// Send a text message to the business agent.
  Future<A2AResponse> sendMessage(String text) {
    final parts = [
      {'type': 'text', 'text': text},
    ];
    return _sendRequest(parts);
  }

  /// Send structured data (e.g. payment data) to the agent.
  Future<A2AResponse> sendData(List<Map<String, dynamic>> dataParts) {
    final parts = dataParts
        .map((d) => {'type': 'data', 'data': d})
        .toList();
    return _sendRequest(parts);
  }

  /// Send a mix of text and data parts.
  Future<A2AResponse> sendParts(List<Map<String, dynamic>> parts) {
    return _sendRequest(parts);
  }

  /// Browse the full catalog.
  Future<A2AResponse> browseCatalog() {
    return sendMessage('Show me all available products');
  }

  /// Search products by query.
  Future<A2AResponse> searchProducts(String query) {
    return sendMessage('Search for $query');
  }

  /// Add a product to checkout.
  Future<A2AResponse> addToCheckout(String productId, {int quantity = 1}) {
    final payload = jsonEncode({
      'action': 'add_to_checkout',
      'product_id': productId,
      'quantity': quantity,
    });
    return sendMessage(payload);
  }

  /// Remove a product from checkout.
  Future<A2AResponse> removeFromCheckout(String productId) {
    final payload = jsonEncode({
      'action': 'remove_from_checkout',
      'product_id': productId,
    });
    return sendMessage(payload);
  }

  /// Update quantity of a product in checkout.
  Future<A2AResponse> updateCheckout(String productId, int quantity) {
    final payload = jsonEncode({
      'action': 'update_checkout',
      'product_id': productId,
      'quantity': quantity,
    });
    return sendMessage(payload);
  }

  /// Get current checkout state.
  Future<A2AResponse> getCheckout() {
    return sendMessage('Show me my current checkout');
  }

  /// Update customer details and trigger payment readiness.
  Future<A2AResponse> updateCustomerDetails({
    required String firstName,
    required String lastName,
    required String email,
    required String streetAddress,
    required String city,
    required String state,
    required String postalCode,
    String country = 'US',
  }) {
    final payload = jsonEncode({
      'action': 'update_customer_details',
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'street_address': streetAddress,
      'address_locality': city,
      'address_region': state,
      'postal_code': postalCode,
      'address_country': country,
    });
    return sendMessage(payload);
  }

  /// Start the payment process.
  Future<A2AResponse> startPayment() {
    final payload = jsonEncode({'action': 'start_payment'});
    return sendMessage(payload);
  }

  /// Complete checkout with payment instrument data.
  Future<A2AResponse> completeCheckout(
      Map<String, dynamic> paymentInstrument) {
    final parts = <Map<String, dynamic>>[
      {'type': 'data', 'data': {'action': 'complete_checkout'}},
      {
        'type': 'data',
        'data': {
          'a2a.ucp.checkout.payment_data': paymentInstrument,
          'a2a.ucp.checkout.risk_signals': {'data': 'sample_risk_data'},
        },
      },
    ];
    return _sendRequest(parts);
  }

  /// Reset session (clear context/task IDs).
  void resetSession() {
    _contextId = null;
    _taskId = null;
  }

  /// Core: send a JSON-RPC 2.0 `message/send` request.
  Future<A2AResponse> _sendRequest(List<Map<String, dynamic>> parts) async {
    final messageId = _generateId();

    final params = <String, dynamic>{
      'message': {
        'role': 'user',
        'parts': parts,
        'messageId': messageId,
        'kind': 'message',
        if (_contextId != null) 'contextId': _contextId,
        if (_taskId != null) 'taskId': _taskId,
      },
      'configuration': {
        'historyLength': 0,
      },
    };

    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': _generateId(),
      'method': 'message/send',
      'params': params,
    });

    final headers = {
      'Content-Type': 'application/json',
      'X-A2A-Extensions': AppConfig.ucpExtensionUri,
      'UCP-Agent': 'profile="$_ucpProfileUrl"',
    };

    debugPrint('A2A → POST $_agentBaseUrl');
    debugPrint('A2A → body: ${body.length > 200 ? '${body.substring(0, 200)}...' : body}');

    final response = await _httpClient.post(
      Uri.parse(_agentBaseUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      debugPrint('A2A ← error: ${response.statusCode} ${response.body}');
      throw A2AException(
        'Request failed with status ${response.statusCode}',
        response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    debugPrint('A2A ← response received');

    // Update session IDs.
    final result = data['result'] as Map<String, dynamic>?;
    if (result != null) {
      if (result['contextId'] != null) {
        _contextId = result['contextId'] as String;
      }
      final status = result['status'] as Map<String, dynamic>?;
      final state = status?['state'] as String?;
      if (result['id'] != null &&
          (state == 'working' ||
              state == 'submitted' ||
              state == 'input-required')) {
        _taskId = result['id'] as String;
      } else {
        _taskId = null;
      }
    }

    return A2AResponse.fromJson(data);
  }

  String _generateId() {
    // Simple UUID-like ID.
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${now.toRadixString(36)}-${now.hashCode.toRadixString(36)}';
  }
}

/// Parsed response from the A2A agent.
class A2AResponse {
  final String? text;
  final ProductResults? products;
  final Checkout? checkout;
  final Map<String, dynamic> raw;

  const A2AResponse({
    this.text,
    this.products,
    this.checkout,
    required this.raw,
  });

  factory A2AResponse.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    final responseParts = result?['parts'] as List<dynamic>? ??
        (result?['status'] as Map<String, dynamic>?)?['message']
                ?['parts'] as List<dynamic>? ??
            [];

    String textBuffer = '';
    ProductResults? products;
    Checkout? checkout;

    for (final part in responseParts) {
      final partMap = part as Map<String, dynamic>;

      if (partMap.containsKey('text')) {
        final t = partMap['text'] as String;
        textBuffer += textBuffer.isEmpty ? t : '\n$t';
      }

      final data = partMap['data'] as Map<String, dynamic>?;
      if (data != null) {
        if (data.containsKey('a2a.product_results')) {
          final pr = data['a2a.product_results'] as Map<String, dynamic>;
          products = ProductResults.fromJson(pr);
          if (pr['content'] != null) {
            final c = pr['content'] as String;
            textBuffer += textBuffer.isEmpty ? c : '\n$c';
          }
        }
        if (data.containsKey('a2a.ucp.checkout')) {
          final co = data['a2a.ucp.checkout'] as Map<String, dynamic>;
          checkout = Checkout.fromJson(co);
        }
      }
    }

    return A2AResponse(
      text: textBuffer.isEmpty ? null : textBuffer,
      products: products,
      checkout: checkout,
      raw: json,
    );
  }

  bool get hasProducts => products != null && products!.results.isNotEmpty;
  bool get hasCheckout => checkout != null;
}

/// Exception thrown by the A2A client.
class A2AException implements Exception {
  final String message;
  final int? statusCode;

  const A2AException(this.message, [this.statusCode]);

  @override
  String toString() => 'A2AException: $message (status: $statusCode)';
}
