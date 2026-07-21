import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/menu_models.dart';
import '../widgets/menu_item_card.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(MenuItem, {int quantity, String? specialInstructions}) onAddToCart;

  const FavoritesScreen({
    super.key,
    required this.onAddToCart,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final SupabaseService _supabase = SupabaseService();
  List<MenuItem> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final items = await _supabase.getUserFavorites();
      setState(() {
        _favorites = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final item = _favorites[index];
          return MenuItemCard(
            item: item,
            isFavorite: true,
            onTap: () => _showItemDetail(item),
            onAddToCart: () => widget.onAddToCart(item, quantity: 1),
            onToggleFavorite: () => _toggleFavorite(item),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start saving your favorite items',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDetail(MenuItem item) {
    // Show detail dialog - simplified
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('MWK ${item.price.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onAddToCart(item, quantity: 1);
                      Navigator.pop(context);
                    },
                    child: const Text('Add to Cart'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(MenuItem item) async {
    try {
      await _supabase.removeFromFavorites(item.id);
      setState(() {
        _favorites.removeWhere((fav) => fav.id == item.id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove favorite'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}