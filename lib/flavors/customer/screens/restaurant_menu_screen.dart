import 'package:dinetrack_2_1/core/models/user_models.dart';
import 'package:dinetrack_2_1/core/services/notification_service.dart';
import 'package:dinetrack_2_1/core/services/paychangu_inline_service.dart';
import 'package:dinetrack_2_1/flavors/customer/screens/paychangu_inline_checkout_screen.dart';
import 'package:dinetrack_2_1/shared/widgets/notification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'browse_restaurants_screen.dart';
import 'order_tracking_screen.dart';

/// Restaurant Menu Screen with Cart & Ordering
class RestaurantMenuScreen extends StatefulWidget {
  final Restaurant restaurant;
  final UserProfile? userProfile;
  final String? tableId;
  final int? tableNumber;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurant,
    this.userProfile,
    this.tableId,
    this.tableNumber,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<MenuCategory> _categories = [];
  List<MenuItem> _menuItems = [];
  Map<String, CartItem> _cart = {};
  bool _isLoading = true;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    try {
      // Load categories — FIXED: display_order (not sort_order)
      final catResponse = await _supabase
          .from('menu_categories')
          .select()
          .eq('is_active', true)
          .order('display_order');

      _categories = (catResponse as List<dynamic>)
          .map((json) => MenuCategory.fromJson(json))
          .toList();

      if (_categories.isNotEmpty) {
        _tabController = TabController(length: _categories.length, vsync: this);
      }

      // Load menu items — FIXED: join with category via menu_item_tag_links if needed
      final itemsResponse = await _supabase
          .from('menu_items')
          .select()
          .eq('establishment_id', widget.restaurant.id)
          .eq('is_available', true)
          .order('name');

      _menuItems = (itemsResponse as List<dynamic>)
          .map((json) => MenuItem.fromJson(json))
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading menu: $e');
      setState(() => _isLoading = false);
    }
  }

  double get _cartTotal => _cart.values.fold(
    0.0,
        (sum, item) => sum + (item.menuItem.price * item.quantity),
  );

  int get _cartItemCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(MenuItem item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.quantity++;
      } else {
        _cart[item.id] = CartItem(menuItem: item, quantity: 1);
      }
    });

    _showSnackBar('Added to Cart: ${item.name} added');
  }

  void _removeFromCart(String itemId) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        if (_cart[itemId]!.quantity > 1) {
          _cart[itemId]!.quantity--;
        } else {
          _cart.remove(itemId);
        }
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;

    setState(() => _isPlacingOrder = true);

    try {
      final userId = widget.userProfile?.id ?? _supabase.auth.currentUser?.id;
      if (userId == null) {
        _showError('Please login to place an order');
        return;
      }

      // Create order — FIXED: customer_id (not user_id), removed table_number
      final orderResponse = await _supabase.from('orders').insert({
        'customer_id': userId,
        'establishment_id': widget.restaurant.id,
        'table_id': widget.tableId,
        'status': 'pending',          // FIXED: schema default is 'pending'
        'payment_status': 'pending',
        'total_amount': _cartTotal,
        'special_instructions': '',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final orderId = orderResponse['id'] as String;

      // Create order items — FIXED: line_total (not total_price), removed name
      for (final entry in _cart.entries) {
        final cartItem = entry.value;
        final lineTotal = cartItem.menuItem.price * cartItem.quantity;
        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'menu_item_id': cartItem.menuItem.id,
          'quantity': cartItem.quantity,
          'unit_price': cartItem.menuItem.price,
          'line_total': lineTotal,    // FIXED: was 'total_price'
          'special_instructions': cartItem.specialInstructions,
        });
      }

      // Clear cart
      setState(() {
        _cart.clear();
        _isPlacingOrder = false;
      });

      // Show payment options
      _showPaymentSheet(orderId, _cartTotal);
    } catch (e) {
      debugPrint('Error placing order: $e');
      setState(() => _isPlacingOrder = false);
      _showError('Failed to place order. Please try again.');
    }
  }

  void _showPaymentSheet(String orderId, double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Payment Method',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: MWK ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, color: Color(0xFF667eea), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            // PayChangu Inline
            _buildPaymentOption(
              icon: Icons.credit_card,
              title: 'Pay with PayChangu',
              subtitle: 'Card, Airtel Money, TNM Mpamba',
              color: const Color(0xFF667eea),
              onTap: () => _payWithPayChangu(orderId, amount),
            ),
            const SizedBox(height: 12),
            // Cash
            _buildPaymentOption(
              icon: Icons.money,
              title: 'Pay Cash at Counter',
              subtitle: 'Pay when you pickup your order',
              color: const Color(0xFF11998e),
              onTap: () => _payWithCash(orderId),
            ),
            const SizedBox(height: 12),
            // DineCoins
            _buildPaymentOption(
              icon: Icons.monetization_on,
              title: 'Pay with DineCoins',
              subtitle: 'Use your loyalty points',
              color: const Color(0xFFFFD700),
              onTap: () => _payWithDineCoins(orderId, amount),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _payWithPayChangu(String orderId, double amount) async {
    Navigator.pop(context);

    final result = await Navigator.push<PayChanguPaymentResponse>(
      context,
      MaterialPageRoute(
        builder: (_) => PayChanguInlineCheckoutScreen(
          amount: amount,
          orderId: orderId,
          establishmentId: widget.restaurant.id,
          tableId: widget.tableId,
          userProfile: widget.userProfile,
          title: '${widget.restaurant.name} - Order Payment',
          description: 'Payment for your order at ${widget.restaurant.name}',
        ),
      ),
    );

    if (result?.success == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    }
  }

  Future<void> _payWithCash(String orderId) async {
    Navigator.pop(context);

    // FIXED: Update payment_method via payments table or orders if you have it
    // Schema doesn't have payment_method on orders directly — it's on payments table
    // For cash orders, you might want to insert into payments table instead
    await _supabase.from('orders').update({
      'payment_status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);

    _showSnackBar('Order Placed! Please pay MWK ${_cartTotal.toStringAsFixed(2)} at the counter.');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId),
      ),
    );
  }

  Future<void> _payWithDineCoins(String orderId, double amount) async {
    Navigator.pop(context);
    _showError('DineCoins payment coming soon!');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF1a1a2e),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.restaurant.coverImageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: const Color(0xFF667eea)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF667eea),
                      child: const Icon(Icons.restaurant, color: Colors.white, size: 48),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF1a1a2e).withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                widget.restaurant.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            bottom: _categories.isNotEmpty
                ? TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF667eea),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: _categories.map((c) => Tab(text: c.name)).toList(),
            )
                : null,
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Expanded(
              child: _categories.isNotEmpty
                  ? TabBarView(
                controller: _tabController,
                children: _categories.map((category) {
                  final items = _menuItems
                      .where((item) => item.categoryId == category.id)
                      .toList();
                  return _buildMenuList(items);
                }).toList(),
              )
                  : _buildMenuList(_menuItems),
            ),
            if (_cart.isNotEmpty) _buildCartBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(List<MenuItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No items in this category',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildMenuItemCard(items[index]),
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    final cartItem = _cart[item.id];
    final inCart = cartItem != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl ?? '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 80,
                height: 80,
                color: const Color(0xFF667eea).withOpacity(0.1),
                child: const Icon(Icons.restaurant, color: Color(0xFF667eea)),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: const Color(0xFF667eea).withOpacity(0.1),
                child: const Icon(Icons.restaurant, color: Color(0xFF667eea)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'MWK ${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    // REMOVED: isPopular badge — schema doesn't have is_popular
                  ],
                ),
              ],
            ),
          ),
          inCart
              ? Container(
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: Color(0xFF667eea), size: 18),
                  onPressed: () => _removeFromCart(item.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF667eea),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF667eea), size: 18),
                  onPressed: () => _addToCart(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          )
              : GestureDetector(
            onTap: () => _addToCart(item),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  const Icon(Icons.shopping_basket, color: Color(0xFF667eea)),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_cartItemCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_cartItemCount items',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  Text(
                    'MWK ${_cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1a1a2e)),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isPlacingOrder ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isPlacingOrder
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Place Order', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Models (Schema-Aligned) ─────────────────────────────────────────────────

class MenuCategory {
  final String id;
  final String name;
  final String? description;
  final int displayOrder;  // FIXED: was sortOrder

  MenuCategory({
    required this.id,
    required this.name,
    this.description,
    required this.displayOrder,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      displayOrder: json['display_order'] ?? 0,  // FIXED
    );
  }
}

class MenuItem {
  final String id;
  final String? categoryId;  // FIXED: nullable per schema
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  // REMOVED: isPopular — not in schema
  // REMOVED: allergens — use menu_item_tags instead

  MenuItem({
    required this.id,
    this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] ?? '',
      categoryId: json['category_id'],  // FIXED: can be null
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
    );
  }
}

class CartItem {
  final MenuItem menuItem;
  int quantity;
  String? specialInstructions;

  CartItem({required this.menuItem, this.quantity = 1, this.specialInstructions});
}