import 'dart:convert';
import 'package:dinetrack_2_1/core/models/user_models.dart';
import 'package:dinetrack_2_1/core/services/notification_service.dart';
import 'package:dinetrack_2_1/core/services/paychangu_inline_service.dart';
import 'package:dinetrack_2_1/shared/widgets/notification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// PayChangu Inline Checkout Screen
/// Loads the PayChangu popup.js checkout inside a WebView
class PayChanguInlineCheckoutScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  final String? establishmentId;
  final String? tableId;
  final String title;
  final String description;
  final UserProfile? userProfile;
  final Function(PayChanguPaymentResponse)? onComplete;

  const PayChanguInlineCheckoutScreen({
    super.key,
    required this.amount,
    required this.orderId,
    this.establishmentId,
    this.tableId,
    this.title = 'DineOrder Payment',
    this.description = 'Complete your order payment',
    this.userProfile,
    this.onComplete,
  });

  @override
  State<PayChanguInlineCheckoutScreen> createState() => _PayChanguInlineCheckoutScreenState();
}

class _PayChanguInlineCheckoutScreenState extends State<PayChanguInlineCheckoutScreen> {
  late final WebViewController _controller;
  final PayChanguInlineService _service = PayChanguInlineService();
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _txRef;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // Generate tx_ref
    _txRef = 'DINE-${DateTime.now().millisecondsSinceEpoch}-${widget.orderId.substring(0, 8)}';

    // Parse full name into first and last name
    final nameParts = _parseFullName(widget.userProfile?.fullName);

    // Create payment request
    final request = PayChanguPaymentRequest(
      txRef: _txRef,
      amount: widget.amount,
      currency: 'MWK',
      email: widget.userProfile?.email ?? 'guest@dineorder.app',
      firstName: nameParts.$1,
      lastName: nameParts.$2,
      title: widget.title,
      description: widget.description,
      meta: {
        'order_id': widget.orderId,
        'establishment_id': widget.establishmentId,
        'table_id': widget.tableId,
        'payer_customer_id': widget.userProfile?.id,  // FIXED: matches schema column name
      },
    );

    // Generate HTML content
    final htmlContent = _service.getCheckoutHtml(request);

    // Platform-specific params
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF667eea))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            _showError('Failed to load checkout. Please try again.');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Intercept callback/return URLs
            if (url.contains('paychangu-callback') || url.contains('paychangu-return')) {
              final uri = Uri.parse(url);
              final status = uri.queryParameters['status'];
              final txRef = uri.queryParameters['tx_ref'];
              if (status != null && txRef != null) {
                _handlePaymentStatus(status, txRef);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'PayChanguBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      );

    // Android-specific: Enable payment request for mobile money
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;

    // Load the HTML content
    _controller.loadHtmlString(htmlContent, baseUrl: 'https://paychangu.com');

    // Create pending payment record
    _createPendingPayment();
  }

  /// Parse full name into (firstName, lastName) tuple
  (String, String) _parseFullName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return ('Guest', 'User');
    }
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) {
      return (parts[0], 'User');
    }
    return (parts.first, parts.skip(1).join(' '));
  }

  Future<void> _createPendingPayment() async {
    final userId = widget.userProfile?.id;
    if (userId == null || _txRef == null) return;

    // FIXED: Pass all schema-required fields
    await _service.createPendingPayment(
      orderId: widget.orderId,
      amount: widget.amount,                    // FIXED: required by schema
      txRef: _txRef!,
      payerCustomerId: userId,                   // FIXED: was userId, now matches schema column
      establishmentId: widget.establishmentId,
      tableId: widget.tableId,
      paymentMethod: 'card',                     // FIXED: not 'cash' — PayChangu is card/mobile money
      idempotencyKey: _txRef,                   // FIXED: prevents duplicates
    );
  }

  void _handleJavaScriptMessage(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;
      final txRef = data['tx_ref'] as String?;

      switch (type) {
        case 'success':
          _handlePaymentSuccess(txRef, data['reference'] as String?);
          break;
        case 'failed':
          _handlePaymentFailed(txRef, data['message'] as String?);
          break;
        case 'cancelled':
          _handlePaymentCancelled();
          break;
      }
    } catch (e) {
      debugPrint('Error handling JS message: $e');
    }
  }

  void _handlePaymentStatus(String status, String txRef) {
    switch (status) {
      case 'success':
        _handlePaymentSuccess(txRef, null);
        break;
      case 'failed':
        _handlePaymentFailed(txRef, 'Payment failed');
        break;
      case 'cancelled':
        _handlePaymentCancelled();
        break;
    }
  }

  Future<void> _handlePaymentSuccess(String? txRef, String? reference) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final effectiveTxRef = txRef ?? _txRef;
    if (effectiveTxRef == null) {
      _showError('Transaction reference missing');
      return;
    }

    // Update payment status — FIXED: use schema-aligned status
    await _service.updatePaymentStatus(
      txRef: effectiveTxRef,
      status: 'paid',                           // FIXED: schema uses 'paid' not 'success'
      reference: reference,
    );

    // Verify server-side
    final verification = await _service.verifyTransaction(effectiveTxRef);

    if (mounted) {
      final response = PayChanguPaymentResponse.success(
        txRef: effectiveTxRef,
        reference: reference,
        amount: widget.amount,
      );

      _showSnackBar('Payment Successful! MWK ${widget.amount.toStringAsFixed(2)} paid successfully.');

      if (widget.onComplete != null) {
        widget.onComplete!(response);
      }

      Navigator.pop(context, response);
    }
  }

  Future<void> _handlePaymentFailed(String? txRef, String? message) async {
    final effectiveTxRef = txRef ?? _txRef;
    if (effectiveTxRef != null) {
      await _service.updatePaymentStatus(
        txRef: effectiveTxRef,
        status: 'failed',                       // FIXED: matches schema enum
      );
    }

    if (mounted) {
      final response = PayChanguPaymentResponse.error(
        message ?? 'Payment failed. Please try again.',
      );

      _showSnackBar('Payment Failed: ${message ?? 'Your payment could not be processed.'}');

      if (widget.onComplete != null) {
        widget.onComplete!(response);
      }
    }
  }

  void _handlePaymentCancelled() {
    if (mounted) {
      final response = PayChanguPaymentResponse.cancelled();

      _showSnackBar('Payment Cancelled: You cancelled the payment. You can retry anytime.');

      if (widget.onComplete != null) {
        widget.onComplete!(response);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF667eea),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        title: const Text(
          'Secure Checkout',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _handlePaymentCancelled();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF667eea),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading secure checkout...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  margin: EdgeInsets.all(32),
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Verifying payment...',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please do not close this screen',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simplified Pay Now button widget that launches inline checkout
class PayChanguPayButton extends StatelessWidget {
  final double amount;
  final String orderId;
  final String? establishmentId;
  final String? tableId;
  final UserProfile? userProfile;
  final String buttonText;
  final VoidCallback? onBeforePayment;
  final Function(PayChanguPaymentResponse)? onComplete;

  const PayChanguPayButton({
    super.key,
    required this.amount,
    required this.orderId,
    this.establishmentId,
    this.tableId,
    this.userProfile,
    this.buttonText = 'Pay Now',
    this.onBeforePayment,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _launchCheckout(context),
      icon: const Icon(Icons.payment),
      label: Text(buttonText),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  Future<void> _launchCheckout(BuildContext context) async {
    onBeforePayment?.call();

    final result = await Navigator.push<PayChanguPaymentResponse>(
      context,
      MaterialPageRoute(
        builder: (_) => PayChanguInlineCheckoutScreen(
          amount: amount,
          orderId: orderId,
          establishmentId: establishmentId,
          tableId: tableId,
          userProfile: userProfile,
          onComplete: onComplete,
        ),
      ),
    );

    if (result != null && onComplete != null) {
      onComplete!(result);
    }
  }
}