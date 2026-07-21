import 'package:flutter/material.dart';
import '../../../core/models/menu_models.dart';

class ItemDetailDialog extends StatefulWidget {
  final MenuItem item;
  final bool isFavorite;
  final Function(int, String?) onAddToCart;
  final VoidCallback onToggleFavorite;

  const ItemDetailDialog({
    super.key,
    required this.item,
    required this.isFavorite,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  @override
  State<ItemDetailDialog> createState() => _ItemDetailDialogState();
}

class _ItemDetailDialogState extends State<ItemDetailDialog> {
  static const int _maxQuantity = 99;

  int _quantity = 1;
  final TextEditingController _instructionsController = TextEditingController();

  bool get _isAvailable => widget.item.isAvailable;

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  void _incrementQuantity() {
    if (_quantity >= _maxQuantity) return;
    setState(() => _quantity++);
  }

  void _decrementQuantity() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            // Image
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: _isAvailable ? 1.0 : 0.4,
                      child: Image.network(
                        widget.item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.fastfood,
                          color: Color(0xFF94A3B8),
                          size: 60,
                        ),
                      ),
                    ),
                  )
                      : Opacity(
                    opacity: _isAvailable ? 1.0 : 0.4,
                    child: const Icon(
                      Icons.fastfood,
                      color: Color(0xFF94A3B8),
                      size: 60,
                    ),
                  ),
                ),
                if (!_isAvailable)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'CURRENTLY UNAVAILABLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Name & Favorite
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    widget.onToggleFavorite();
                    setState(() {});
                  },
                  icon: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: widget.isFavorite ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),

            // Description
            if (widget.item.description != null && widget.item.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.item.description!,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Price
            Row(
              children: [
                Text(
                  'MWK ${widget.item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                if (!_isAvailable) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Sold Out',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Special instructions
            TextField(
              controller: _instructionsController,
              enabled: _isAvailable,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Special instructions (optional)',
                hintText: 'e.g., no onions, extra spicy',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 8),

            // Quantity selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: (_isAvailable && _quantity > 1) ? _decrementQuantity : null,
                      icon: const Icon(Icons.remove),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: (_isAvailable && _quantity < _maxQuantity)
                          ? _incrementQuantity
                          : null,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Add to cart button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isAvailable
                    ? () {
                  widget.onAddToCart(
                    _quantity,
                    _instructionsController.text.trim().isNotEmpty
                        ? _instructionsController.text.trim()
                        : null,
                  );
                  Navigator.pop(context);
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isAvailable
                      ? 'Add to Cart - MWK ${(widget.item.price * _quantity).toStringAsFixed(0)}'
                      : 'Currently Unavailable',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}