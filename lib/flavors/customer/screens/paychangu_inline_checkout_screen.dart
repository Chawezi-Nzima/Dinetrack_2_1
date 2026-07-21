import 'dart:convert';
import 'dart:async';
import 'package:dinetrack_2_1/core/models/user_models.dart';
import 'package:dinetrack_2_1/core/services/paychangu_inline_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PayChangu Hosted Checkout Screen
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
  final PayChanguInlineService _service = PayChanguInlineService();
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _txRef;
  String? _checkoutUrl;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initiateCheckout();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiateCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _txRef = 'DINE-${DateTime.now().millisecondsSinceEpoch}-${widget.orderId.substring(0, 8)}';

    final nameParts = _parseFullName(widget.userProfile?.fullName);

    try {
      // Step 1: Create pending payment in DB
      await _createPendingPayment();

      // Step 2: Call Edge Function to get checkout URL
      debugPrint('Calling paychangu-initiate with tx_ref: $_txRef');

      // FIX: Use .rest instead of .http
      final response = await Supabase.instance.client.functions.invoke(
        'paychangu-initiate',
        body: {
          'amount': widget.amount,
          'currency': 'MWK',
          'email': widget.userProfile?.email ?? 'guest@dineorder.app',
          'first_name': nameParts.$1,
          'last_name': nameParts.$2,
          'tx_ref': _txRef,
          'callback_url': 'https://boqgamdpxjejneyjnsgz.supabase.co/v1/paychangu-webhook',
          'return_url': 'https://dinetrack.app/payment/return?tx_ref=$_txRef',
          'meta': {
            'order_id': widget.orderId,
            'establishment_id': widget.establishmentId,
            'table_id': widget.tableId,
            'payer_customer_id': widget.userProfile?.id,
          },
        },
      );

      debugPrint('Edge function response: ${response.data}');
      final data = response.data as Map<String, dynamic>?;

      if (data == null) {
        throw Exception('Empty response from server');
      }

      if (data['success'] == true) {
        _checkoutUrl = data['checkout_url'] as String?;
        if (_checkoutUrl == null || _checkoutUrl!.isEmpty) {
          throw Exception('No checkout URL returned');
        }
        if (mounted) {
          setState(() => _isLoading = false);
          _launchCheckout();
        }
      } else {
        final errorMsg = data['error'] ?? data['message'] ?? 'Failed to initiate checkout';
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      debugPrint('Checkout initiation error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

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

    await _service.createPendingPayment(
      orderId: widget.orderId,
      amount: widget.amount,
      txRef: _txRef!,
      payerCustomerId: userId,
      establishmentId: widget.establishmentId ?? '',
      tableId: widget.tableId ?? '',
      paymentMethod: 'paychangu',
      idempotencyKey: _txRef!,
    );
  }

  Future<void> _launchCheckout() async {
    if (_checkoutUrl == null) return;

    final uri = Uri.parse(_checkoutUrl!);
    debugPrint('Launching checkout URL: $_checkoutUrl');

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      _startPolling();
    } else {
      setState(() {
        _errorMessage = 'Could not open checkout URL. Please try again.';
      });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || _isProcessing) {
        timer.cancel();
        return;
      }

      try {
        final status = await _service.getPaymentStatus(_txRef!);
        final paymentStatus = status?['status'] as String?;

        if (paymentStatus == 'paid' || paymentStatus == 'success') {
          timer.cancel();
          _handlePaymentSuccess();
        } else if (paymentStatus == 'failed') {
          timer.cancel();
          _handlePaymentFailed('Payment failed');
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });

    Timer(const Duration(minutes: 10), () {
      _pollingTimer?.cancel();
      if (mounted && !_isProcessing) {
        setState(() {
          _errorMessage = 'Payment timed out. Please try again.';
        });
      }
    });
  }

  Future<void> _handlePaymentSuccess() async {
    if (_isProcessing) return;
    if (!mounted) return;
    setState(() => _isProcessing = true);

    await _service.updatePaymentStatus(
      txRef: _txRef!,
      status: 'paid',
    );

    if (!mounted) return;

    final response = PayChanguPaymentResponse.success(
      txRef: _txRef!,
      amount: widget.amount,
    );

    _showSnackBar('Payment Successful! MWK ${widget.amount.toStringAsFixed(2)}');

    if (widget.onComplete != null) {
      widget.onComplete!(response);
    }

    Navigator.pop(context, response);
  }

  Future<void> _handlePaymentFailed(String message) async {
    if (!mounted) return;

    await _service.updatePaymentStatus(
      txRef: _txRef!,
      status: 'failed',
    );

    if (!mounted) return;

    final response = PayChanguPaymentResponse.error(message);

    _showSnackBar('Payment Failed: $message');

    if (widget.onComplete != null) {
      widget.onComplete!(response);
    }

    Navigator.pop(context, response);
  }

  bool _hasPopped = false;

  void _handleCancelled() {
    if (_hasPopped) return;
    _hasPopped = true;

    _pollingTimer?.cancel();

    if (!mounted) return;

    final response = PayChanguPaymentResponse.cancelled();

    _showSnackBar('Payment Cancelled');

    if (widget.onComplete != null) {
      widget.onComplete!(response);
    }

    Navigator.of(context, rootNavigator: true).pop(response);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
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
          onPressed: _handleCancelled,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                ),
              ],
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Show error if any
    if (_errorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Checkout Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _errorMessage = null);
              _initiateCheckout();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _handleCancelled,
            child: const Text('Go Back'),
          ),
        ],
      );
    }

    // Loading state
    if (_isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Preparing checkout...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we set up your secure payment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      );
    }

    // Processing / waiting state
    if (_isProcessing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verifying payment...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please complete the payment in the opened window',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    }

    // Default: checkout opened
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.open_in_new,
          size: 64,
          color: Color(0xFF667eea),
        ),
        const SizedBox(height: 24),
        const Text(
          'Checkout Opened',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Complete your payment in the new browser window.\n\nAmount: MWK ${widget.amount.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _launchCheckout,
          icon: const Icon(Icons.refresh),
          label: const Text('Reopen Checkout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _handleCancelled,
          child: const Text('Cancel Payment'),
        ),
      ],
    );
  }
}