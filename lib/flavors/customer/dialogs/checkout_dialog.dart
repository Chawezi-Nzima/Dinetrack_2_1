import 'package:flutter/material.dart';
import '../../../core/models/menu_models.dart';

class CheckoutDialog extends StatefulWidget {
  final Map<String, CartItem> cartItems;
  final double cartTotal;
  final String tableId;
  final double dineCoinsBalance;
  final Function({
  required String paymentMethod,
  required double dineCoinsUsed,
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
  double _dineCoinsToUse = 0;
  final TextEditingController _dineCoinsController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _dineCoinsToUse = widget.dineCoinsBalance > widget.cartTotal
        ? widget.cartTotal
        : widget.dineCoinsBalance;
    _dineCoinsController.text = _dineCoinsToUse.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _dineCoinsController.dispose();
    super.dispose();
  }

  double get _finalAmount {
    if (_selectedPaymentMethod == 'dine_coins') {
      return widget.cartTotal - _dineCoinsToUse;
    }
    return widget.cartTotal;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
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
              'Table ${widget.tableId.substring(0, 8)}',
              style: const TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
            const Divider(),

            // Items summary
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
                ),
                if (widget.dineCoinsBalance > 0)
                  const SizedBox(width: 8),
                if (widget.dineCoinsBalance > 0)
                  _buildPaymentOption(
                    'DineCoins',
                    'dine_coins',
                    Icons.star,
                  ),
              ],
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
                            onChanged: (value) {
                              final amount = double.tryParse(value) ?? 0;
                              final maxAmount = widget.dineCoinsBalance > widget.cartTotal
                                  ? widget.cartTotal
                                  : widget.dineCoinsBalance;
                              setState(() {
                                _dineCoinsToUse = amount.clamp(0, maxAmount);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final maxAmount = widget.dineCoinsBalance > widget.cartTotal
                                ? widget.cartTotal
                                : widget.dineCoinsBalance;
                            _dineCoinsController.text = maxAmount.toStringAsFixed(0);
                            setState(() => _dineCoinsToUse = maxAmount);
                          },
                          child: const Text('Max'),
                        ),
                      ],
                    ),
                    if (_dineCoinsToUse > 0)
                      Text(
                        'You will pay MWK ${_finalAmount.toStringAsFixed(0)} after using DineCoins',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w500,
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
                    onPressed: _isProcessing ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
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
                        : Text(
                      'Place Order',
                      style: const TextStyle(
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
    );
  }

  Widget _buildPaymentOption(String label, String value, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPaymentMethod = value),
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
    );
  }

  void _placeOrder() async {
    setState(() => _isProcessing = true);

    try {
      final result = await widget.onPlaceOrder(
        paymentMethod: _selectedPaymentMethod,
        dineCoinsUsed: _selectedPaymentMethod == 'dine_coins' ? _dineCoinsToUse : 0,
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