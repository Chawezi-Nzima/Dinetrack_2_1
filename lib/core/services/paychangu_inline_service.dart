import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// PayChangu Inline Checkout configuration
class PayChanguInlineConfig {
  final String publicKey;
  final String secretKey;
  final bool isTestMode;
  final String? callbackUrl;
  final String? returnUrl;

  const PayChanguInlineConfig({
    required this.publicKey,
    required this.secretKey,
    this.isTestMode = true,
    this.callbackUrl,
    this.returnUrl,
  });

  /// Your test credentials pre-configured
  factory PayChanguInlineConfig.test() {
    return const PayChanguInlineConfig(
      publicKey: 'PUB-TEST-YcEtbrqAEIaF5TmSWYGoD6bUNsWUOsrT',
      secretKey: 'SEC-TEST-awHuCpW5cLHMeMSCf9Swix4qo6qj9mXH',
      isTestMode: true,
      callbackUrl: 'https://boqgamdpxjejneyjnsgz.supabase.co/functions/v1/paychangu-callback',
      returnUrl: 'https://boqgamdpxjejneyjnsgz.supabase.co/functions/v1/paychangu-return',
    );
  }
}

/// PayChangu payment request for inline checkout
class PayChanguPaymentRequest {
  final String txRef;
  final double amount;
  final String currency;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String title;
  final String description;
  final String? logoUrl;
  final Map<String, dynamic>? meta;

  PayChanguPaymentRequest({
    String? txRef,
    required this.amount,
    this.currency = 'MWK',
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.title = 'DineOrder Payment',
    this.description = 'Payment for your order',
    this.logoUrl,
    this.meta,
  }) : txRef = txRef ?? _generateTxRef();

  static String _generateTxRef() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'DINE-$timestamp-$random';
  }

  Map<String, dynamic> toJson() {
    return {
      'public_key': null,
      'tx_ref': txRef,
      'amount': amount,
      'currency': currency,
      'callback_url': null,
      'return_url': null,
      'customer': {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        if (phone != null) 'phone_number': phone,
      },
      'customization': {
        'title': title,
        'description': description,
        if (logoUrl != null) 'logo': logoUrl,
      },
      if (meta != null) 'meta': meta,
    };
  }
}

/// PayChangu payment response
class PayChanguPaymentResponse {
  final bool success;
  final String? txRef;
  final String? status;
  final String? message;
  final String? reference;
  final double? amount;
  final Map<String, dynamic>? rawData;

  const PayChanguPaymentResponse({
    required this.success,
    this.txRef,
    this.status,
    this.message,
    this.reference,
    this.amount,
    this.rawData,
  });

  factory PayChanguPaymentResponse.success({
    required String txRef,
    String? status,
    String? reference,
    double? amount,
    Map<String, dynamic>? rawData,
  }) {
    return PayChanguPaymentResponse(
      success: true,
      txRef: txRef,
      status: status ?? 'success',
      reference: reference,
      amount: amount,
      rawData: rawData,
    );
  }

  factory PayChanguPaymentResponse.error(String message) {
    return PayChanguPaymentResponse(
      success: false,
      status: 'error',
      message: message,
    );
  }

  factory PayChanguPaymentResponse.cancelled() {
    return const PayChanguPaymentResponse(
      success: false,
      status: 'cancelled',
      message: 'Payment was cancelled by user',
    );
  }
}

/// PayChangu Inline Checkout Service
/// Uses WebView to load the PayChangu popup.js inline checkout
class PayChanguInlineService {
  static final PayChanguInlineService _instance = PayChanguInlineService._internal();
  factory PayChanguInlineService() => _instance;
  PayChanguInlineService._internal();

  final PayChanguInlineConfig _config = PayChanguInlineConfig.test();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Build checkout HTML with embedded PayChangu popup.js
  String getCheckoutHtml(PayChanguPaymentRequest request) {
    final requestJson = jsonEncode(request.toJson());
    final pk = _config.publicKey;
    final cb = _config.callbackUrl ?? '';
    final ret = _config.returnUrl ?? '';
    final amt = request.amount.toStringAsFixed(2);
    final cur = request.currency;
    final ref = request.txRef;

    final html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html lang="en">');
    html.writeln('<head>');
    html.writeln('  <meta charset="UTF-8">');
    html.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">');
    html.writeln('  <title>PayChangu Checkout</title>');
    html.writeln('  <style>');
    html.writeln('    * { margin: 0; padding: 0; box-sizing: border-box; }');
    html.writeln('    body {');
    html.writeln('      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;');
    html.writeln('      background: linear-gradient(135deg, rgb(102,126,234) 0%, rgb(118,75,162) 100%);');
    html.writeln('      min-height: 100vh;');
    html.writeln('      display: flex;');
    html.writeln('      align-items: center;');
    html.writeln('      justify-content: center;');
    html.writeln('      padding: 20px;');
    html.writeln('    }');
    html.writeln('    .container {');
    html.writeln('      background: white;');
    html.writeln('      border-radius: 20px;');
    html.writeln('      padding: 40px 30px;');
    html.writeln('      max-width: 400px;');
    html.writeln('      width: 100%;');
    html.writeln('      text-align: center;');
    html.writeln('      box-shadow: 0 20px 60px rgba(0,0,0,0.3);');
    html.writeln('    }');
    html.writeln('    .logo {');
    html.writeln('      width: 60px; height: 60px;');
    html.writeln('      background: linear-gradient(135deg, rgb(102,126,234), rgb(118,75,162));');
    html.writeln('      border-radius: 16px;');
    html.writeln('      margin: 0 auto 20px;');
    html.writeln('      display: flex;');
    html.writeln('      align-items: center;');
    html.writeln('      justify-content: center;');
    html.writeln('      color: white;');
    html.writeln('      font-size: 28px; font-weight: bold;');
    html.writeln('    }');
    html.writeln('    h1 { font-size: 22px; color: rgb(26,26,46); margin-bottom: 8px; }');
    html.writeln('    .subtitle { color: rgb(136,136,136); font-size: 14px; margin-bottom: 30px; }');
    html.writeln('    .amount-box {');
    html.writeln('      background: rgb(248,249,250);');
    html.writeln('      border-radius: 16px;');
    html.writeln('      padding: 24px;');
    html.writeln('      margin-bottom: 24px;');
    html.writeln('    }');
    html.writeln('    .amount-label { color: rgb(136,136,136); font-size: 13px; margin-bottom: 8px; }');
    html.writeln('    .amount-value { font-size: 36px; font-weight: 800; color: rgb(26,26,46); }');
    html.writeln('    .amount-currency { font-size: 18px; color: rgb(102,126,234); }');
    html.writeln('    .tx-ref { color: rgb(170,170,170); font-size: 12px; margin-top: 12px; font-family: monospace; }');
    html.writeln('    .pay-btn {');
    html.writeln('      background: linear-gradient(135deg, rgb(102,126,234), rgb(118,75,162));');
    html.writeln('      color: white; border: none;');
    html.writeln('      padding: 16px 32px;');
    html.writeln('      border-radius: 14px;');
    html.writeln('      font-size: 16px; font-weight: 700;');
    html.writeln('      cursor: pointer; width: 100%;');
    html.writeln('      transition: transform 0.2s, box-shadow 0.2s;');
    html.writeln('    }');
    html.writeln('    .pay-btn:hover {');
    html.writeln('      transform: translateY(-2px);');
    html.writeln('      box-shadow: 0 8px 25px rgba(102,126,234,0.4);');
    html.writeln('    }');
    html.writeln('    .pay-btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }');
    html.writeln('    .secure-note {');
    html.writeln('      margin-top: 20px;');
    html.writeln('      color: rgb(170,170,170);');
    html.writeln('      font-size: 12px;');
    html.writeln('      display: flex;');
    html.writeln('      align-items: center;');
    html.writeln('      justify-content: center;');
    html.writeln('      gap: 6px;');
    html.writeln('    }');
    html.writeln('    .loading { display: none; margin-top: 20px; }');
    html.writeln('    .loading.active { display: block; }');
    html.writeln('    .spinner {');
    html.writeln('      width: 40px; height: 40px;');
    html.writeln('      border: 3px solid rgb(243,243,243);');
    html.writeln('      border-top: 3px solid rgb(102,126,234);');
    html.writeln('      border-radius: 50%;');
    html.writeln('      animation: spin 1s linear infinite;');
    html.writeln('      margin: 0 auto 12px;');
    html.writeln('    }');
    html.writeln('    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }');
    html.writeln('    .test-badge {');
    html.writeln('      background: rgb(255,243,205);');
    html.writeln('      color: rgb(133,100,4);');
    html.writeln('      padding: 6px 12px;');
    html.writeln('      border-radius: 8px;');
    html.writeln('      font-size: 11px; font-weight: 600;');
    html.writeln('      margin-bottom: 16px;');
    html.writeln('      display: inline-block;');
    html.writeln('    }');
    html.writeln('  </style>');
    html.writeln('</head>');
    html.writeln('<body>');
    html.writeln('  <div class="container">');
    html.writeln('    <div class="test-badge">TEST MODE</div>');
    html.writeln('    <div class="logo">D</div>');
    html.writeln('    <h1>Complete Payment</h1>');
    html.writeln('    <p class="subtitle">Secure checkout powered by PayChangu</p>');
    html.writeln('    <div class="amount-box">');
    html.writeln('      <div class="amount-label">Amount to Pay</div>');
    html.writeln('      <div class="amount-value">');
    html.writeln('        <span class="amount-currency">$cur</span> $amt');
    html.writeln('      </div>');
    html.writeln('      <div class="tx-ref">Ref: $ref</div>');
    html.writeln('    </div>');
    html.writeln('    <button class="pay-btn" id="payBtn" onclick="makePayment()">Pay Now</button>');
    html.writeln('    <div class="loading" id="loading">');
    html.writeln('      <div class="spinner"></div>');
    html.writeln('      <p style="color: rgb(136,136,136); font-size: 14px;">Processing payment...</p>');
    html.writeln('    </div>');
    html.writeln('    <div class="secure-note">');
    html.writeln('      <span>Secured by PayChangu SSL Encryption</span>');
    html.writeln('    </div>');
    html.writeln('  </div>');
    html.writeln('');
    html.writeln('  <script src="https://in.paychangu.com/js/popup.js"></script>');
    html.writeln('  <script>');
    html.writeln('    const paymentConfig = $requestJson;');
    html.writeln('    paymentConfig.public_key = "$pk";');
    html.writeln('    paymentConfig.callback_url = "$cb";');
    html.writeln('    paymentConfig.return_url = "$ret";');
    html.writeln('');
    html.writeln('    function makePayment() {');
    html.writeln('      const btn = document.getElementById("payBtn");');
    html.writeln('      const loading = document.getElementById("loading");');
    html.writeln('      btn.disabled = true;');
    html.writeln('      loading.classList.add("active");');
    html.writeln('');
    html.writeln('      PaychanguCheckout({');
    html.writeln('        ...paymentConfig,');
    html.writeln('        onClose: function() {');
    html.writeln('          btn.disabled = false;');
    html.writeln('          loading.classList.remove("active");');
    html.writeln('          if (window.PayChanguBridge) {');
    html.writeln('            window.PayChanguBridge.postMessage(JSON.stringify({type:"cancelled"}));');
    html.writeln('          }');
    html.writeln('        }');
    html.writeln('      });');
    html.writeln('    }');
    html.writeln('');
    html.writeln('    window.addEventListener("message", function(event) {');
    html.writeln('      if (event.data && event.data.type === "paychangu_payment_status") {');
    html.writeln('        const status = event.data.status;');
    html.writeln('        const txRef = event.data.tx_ref;');
    html.writeln('        const reference = event.data.reference;');
    html.writeln('        if (window.PayChanguBridge) {');
    html.writeln('          window.PayChanguBridge.postMessage(JSON.stringify({');
    html.writeln('            type: status,');
    html.writeln('            tx_ref: txRef,');
    html.writeln('            reference: reference,');
    html.writeln('            data: event.data');
    html.writeln('          }));');
    html.writeln('        }');
    html.writeln('      }');
    html.writeln('    });');
    html.writeln('');
    html.writeln('    var originalPushState = history.pushState;');
    html.writeln('    history.pushState = function() {');
    html.writeln('      originalPushState.apply(this, arguments);');
    html.writeln('      checkUrlForPaymentStatus();');
    html.writeln('    };');
    html.writeln('');
    html.writeln('    function checkUrlForPaymentStatus() {');
    html.writeln('      const urlParams = new URLSearchParams(window.location.search);');
    html.writeln('      const status = urlParams.get("status");');
    html.writeln('      const txRef = urlParams.get("tx_ref");');
    html.writeln('      if (status && txRef && window.PayChanguBridge) {');
    html.writeln('        window.PayChanguBridge.postMessage(JSON.stringify({');
    html.writeln('          type: status,');
    html.writeln('          tx_ref: txRef');
    html.writeln('        }));');
    html.writeln('      }');
    html.writeln('    }');
    html.writeln('');
    html.writeln('    window.addEventListener("popstate", checkUrlForPaymentStatus);');
    html.writeln('    checkUrlForPaymentStatus();');
    html.writeln('  </script>');
    html.writeln('</body>');
    html.writeln('</html>');

    return html.toString();
  }

  /// Verify a transaction server-side using PayChangu API
  Future<PayChanguPaymentResponse> verifyTransaction(String txRef) async {
    try {
      final url = 'https://api.paychangu.com/verify-payment/$txRef';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${_config.secretKey}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']?['status'] ?? data['status'];

        if (status == 'success') {
          return PayChanguPaymentResponse.success(
            txRef: txRef,
            status: status,
            reference: data['data']?['reference'] ?? data['reference'],
            amount: (data['data']?['amount'] ?? data['amount'])?.toDouble(),
            rawData: data,
          );
        } else {
          return PayChanguPaymentResponse.error(
            data['message'] ?? 'Payment verification failed',
          );
        }
      } else {
        return PayChanguPaymentResponse.error(
          'Verification failed: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('PayChangu verification error: $e');
      return PayChanguPaymentResponse.error('Network error: $e');
    }
  }

  /// Create a payment record in Supabase before checkout
  /// FIXED: Aligned with payments table schema
  Future<String?> createPendingPayment({
    required String orderId,
    required double amount,
    required String txRef,
    required String payerCustomerId,        // FIXED: was userId, matches schema column name
    String? establishmentId,
    String? tableId,
    String paymentMethod = 'card',            // FIXED: not 'cash' — PayChangu is card/mobile money
    String? idempotencyKey,                  // FIXED: prevents duplicate payments
  }) async {
    try {
      final response = await _supabase.from('payments').insert({
        'order_id': orderId,
        'payer_customer_id': payerCustomerId,   // FIXED: was 'user_id'
        'establishment_id': establishmentId,
        'amount': amount,                         // FIXED: schema requires this
        'currency': 'MWK',
        'status': 'pending',                      // FIXED: matches payment_status enum
        'payment_method': paymentMethod,          // FIXED: schema column exists
        'idempotency_key': idempotencyKey ?? txRef, // FIXED: prevents duplicates
        'metadata': {
          'table_id': tableId,
          'source': 'paychangu_inline',
        },
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      return response['id'] as String?;
    } catch (e) {
      debugPrint('Error creating pending payment: $e');
      return null;
    }
  }

  /// Update payment status after callback
  /// FIXED: Status values aligned with schema payment_status enum
  Future<bool> updatePaymentStatus({
    required String txRef,
    required String status,                    // 'pending', 'paid', 'failed', 'refunded'
    String? reference,
    String? providerPaymentId,                 // FIXED: maps to schema column
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,                        // FIXED: 'paid' not 'success'
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (reference != null) {
        updates['provider_payment_id'] = reference;  // FIXED: schema column name
      }
      if (providerPaymentId != null) {
        updates['provider_payment_id'] = providerPaymentId;
      }
      if (metadata != null) {
        updates['metadata'] = metadata;
      }

      await _supabase.from('payments').update(updates).eq('tx_ref', txRef);

      return true;
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      return false;
    }
  }

  /// Get payment by tx_ref
  Future<Map<String, dynamic>?> getPaymentByTxRef(String txRef) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('tx_ref', txRef)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error fetching payment: $e');
      return null;
    }
  }
}