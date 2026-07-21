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
  int _quantity = 1;
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
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
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: widget.item.imageUrl != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.fastfood,
                    color: Color(0xFF94A3B8),
                    size: 60,
                  ),
                ),
              )
                  : const Icon(
                Icons.fastfood,
                color: Color(0xFF94A3B8),
                size: 60,
              ),
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
            if (widget.item.description != null)
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
            Text(
              'MWK ${widget.item.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F46E5),
              ),
            ),

            const SizedBox(height: 16),

            // Special instructions
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Special instructions (optional)',
                hintText: 'e.g., no onions, extra spicy',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 16),

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
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
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
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
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
                onPressed: () {
                  widget.onAddToCart(
                    _quantity,
                    _instructionsController.text.isNotEmpty
                        ? _instructionsController.text
                        : null,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Add to Cart - MWK ${(widget.item.price * _quantity).toStringAsFixed(0)}',
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