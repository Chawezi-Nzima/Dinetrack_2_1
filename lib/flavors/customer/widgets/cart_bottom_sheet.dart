import 'package:flutter/material.dart';
import '../../../core/models/menu_models.dart';

class CartBottomSheet extends StatelessWidget {
  final Map<String, CartItem> cartItems;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onRemoveItem;
  final VoidCallback onClearCart;
  final VoidCallback onCheckout;

  const CartBottomSheet({
    super.key,
    required this.cartItems,
    required this.onUpdateQuantity,
    required this.onRemoveItem,
    required this.onClearCart,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final total = cartItems.values.fold(
      0.0,
          (sum, item) => sum + item.totalPrice,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Cart',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: onClearCart,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),

          // Items
          Expanded(
            child: ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final entry = cartItems.entries.elementAt(index);
                final item = entry.value;
                return _buildCartItem(item);
              },
            ),
          ),

          const Divider(),

          // Total & Checkout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'MWK ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: total > 0 ? onCheckout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50,
              height: 50,
              color: const Color(0xFFF1F5F9),
              child: item.menuItem.imageUrl != null
                  ? Image.network(
                item.menuItem.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fastfood,
                  color: Color(0xFF94A3B8),
                ),
              )
                  : const Icon(
                Icons.fastfood,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'MWK ${item.menuItem.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (item.specialInstructions != null)
                  Text(
                    'Note: ${item.specialInstructions}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFF59E0B),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Quantity controls
          Row(
            children: [
              IconButton(
                onPressed: item.quantity > 1
                    ? () => onUpdateQuantity(item.menuItem.id, item.quantity - 1)
                    : null,
                icon: const Icon(Icons.remove, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onUpdateQuantity(item.menuItem.id, item.quantity + 1),
                icon: const Icon(Icons.add, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}