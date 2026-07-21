import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/menu_models.dart';

/// Minimum amount PayChangu will process (matches PayChangu's own
/// "Amount must be greater than 50" rejection).
const double kPayChanguMinimumAmount = 50.0;

class CheckoutDialog extends StatefulWidget {
  final Map<String, CartItem> cartItems;
  final double cartTotal;
  final String tableId;
  final double dineCoinsBalance;
  final Function({
  required String paymentMethod,
  required double dineCoinsUsed,
  required String? remainderPaymentMethod,
  }) onPlaceOrder;

  const CheckoutDialog({
    super.key,
    required this.cartItems,
    required this.cartTotal,
    required this.tableId,
    required this.dineCoinsBalance,
    required this.onPlaceOrder,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _selectedPaymentMethod = 'cash';
  String _remainderPaymentMethod = 'cash'; // used only when dine_coins doesn't cover total
  double _dineCoinsToUse = 0;
  final TextEditingController _dineCoinsController = TextEditingController();
  bool _isProcessing = false;

  double get _maxUsableDineCoins =>
      widget.dineCoinsBalance > widget.cartTotal ? widget.cartTotal : widget.dineCoinsBalance;

  bool get _payChanguEligible => widget.cartTotal >= kPayChanguMinimumAmount;

  @override
  void initState() {
    super.initState();
    _dineCoinsToUse = _maxUsableDineCoins;
    _dineCoinsController.text = _dineCoinsToUse.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _dineCoinsController.dispose();
    super.dispose();
  }

  double get _finalAmount {
    if (_selectedPaymentMethod == 'dine_coins') {
      final remaining = widget.cartTotal - _dineCoinsToUse;
      return remaining < 0 ? 0 : remaining;
    }
    return widget.cartTotal;
  }

  bool get _hasRemainderAfterDineCoins =>
      _selectedPaymentMethod == 'dine_coins' && _finalAmount > 0;

  /// Whether the currently selected configuration can actually be submitted.
  bool get _canPlaceOrder {
    if (widget.cartTotal <= 0) return false;
    if (_selectedPaymentMethod == 'paychangu' && !_payChanguEligible) return false;
    if (_hasRemainderAfterDineCoins &&
        _remainderPaymentMethod == 'paychangu' &&
        _finalAmount < kPayChanguMinimumAmount) {
      return false;
    }
    return true;
  }

  String _safeTableLabel() {
    final id = widget.tableId;
    if (id.isEmpty) return 'N/A';
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm Order',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Table ${_safeTableLabel()}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
              const Divider(),

              // Items summary
              if (widget.cartItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Your cart is empty.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              else
                Column(
                  children: widget.cartItems.entries.map((entry) {
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.menuItem.name}',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'MWK ${item.totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const Divider(),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'MWK ${widget.cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Payment method
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPaymentOption(
                    'Cash',
                    'cash',
                    Icons.money,
                  ),
                  const SizedBox(width: 8),
                  _buildPaymentOption(
                    'PayChangu',
                    'paychangu',
                    Icons.credit_card,
                    disabled: !_payChanguEligible,
                  ),
                  if (widget.dineCoinsBalance > 0) ...[
                    const SizedBox(width: 8),
                    _buildPaymentOption(
                      'DineCoins',
                      'dine_coins',
                      Icons.star,
                    ),
                  ],
                ],
              ),

              if (!_payChanguEligible)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'PayChangu requires a minimum order of MWK ${kPayChanguMinimumAmount.toStringAsFixed(0)}.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),

              // DineCoins input
              if (_selectedPaymentMethod == 'dine_coins') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available: ${widget.dineCoinsBalance.toStringAsFixed(0)} DineCoins',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dineCoinsController,
                              decoration: const InputDecoration(
                                labelText: 'DineCoins to use',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              // FIXED: digits-only, prevents garbage input
                              // (letters, decimals, negative signs) that
                              // used to silently parse to 0 or NaN.
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) {
                                final amount = double.tryParse(value) ?? 0;
                                setState(() {
                                  _dineCoinsToUse = amount.clamp(0, _maxUsableDineCoins);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _dineCoinsController.text = _maxUsableDineCoins.toStringAsFixed(0);
                              setState(() => _dineCoinsToUse = _maxUsableDineCoins);
                            },
                            child: const Text('Max'),
                          ),
                        ],
                      ),
                      if (_hasRemainderAfterDineCoins) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Remaining balance: MWK ${_finalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pay remaining balance with:',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildRemainderOption('Cash', 'cash'),
                            const SizedBox(width: 8),
                            _buildRemainderOption(
                              'PayChangu',
                              'paychangu',
                              disabled: _finalAmount < kPayChanguMinimumAmount,
                            ),
                          ],
                        ),
                        if (_remainderPaymentMethod == 'paychangu' &&
                            _finalAmount < kPayChanguMinimumAmount)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Remaining balance is below the MWK ${kPayChanguMinimumAmount.toStringAsFixed(0)} PayChangu minimum — choose Cash instead.',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                            ),
                          ),
                      ] else if (_selectedPaymentMethod == 'dine_coins' && _finalAmount == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Fully covered by DineCoins — no further payment needed.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_isProcessing || !_canPlaceOrder) ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Place Order',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
      String label,
      String value,
      IconData icon, {
        bool disabled = false,
      }) {
    final isSelected = _selectedPaymentMethod == value;

    return Expanded(
      child: GestureDetector(
        onTap: disabled
            ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PayChangu requires a minimum order of MWK ${kPayChanguMinimumAmount.toStringAsFixed(0)}.',
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
            : () => setState(() => _selectedPaymentMethod = value),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4F46E5).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : Colors.grey,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : Colors.grey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemainderOption(String label, String value, {bool disabled = false}) {
    final isSelected = _remainderPaymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : () => setState(() => _remainderPaymentMethod = value),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _placeOrder() async {
    if (!_canPlaceOrder) return;

    setState(() => _isProcessing = true);

    try {
      final result = await widget.onPlaceOrder(
        paymentMethod: _selectedPaymentMethod,
        dineCoinsUsed: _selectedPaymentMethod == 'dine_coins' ? _dineCoinsToUse : 0,
        remainderPaymentMethod:
        _hasRemainderAfterDineCoins ? _remainderPaymentMethod : null,
      );

      if (mounted) {
        // For PayChangu, close dialog and return result to caller
        // The caller (customer_home) will handle navigation
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}