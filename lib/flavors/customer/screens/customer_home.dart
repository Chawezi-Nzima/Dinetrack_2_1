import 'package:dinetrack_2_1/flavors/customer/screens/customer_profile_screen.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/menu_models.dart';
import '../../../core/models/user_models.dart';
import '../../../core/models/order_models.dart';
import '../../../core/routing/role_based_router.dart';
import '../../../main.dart';
import '../widgets/category_grid.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/cart_bottom_sheet.dart';
import '../widgets/search_bar.dart' as app_search;
import '../widgets/table_selector.dart';
import '../dialogs/checkout_dialog.dart';
import '../dialogs/item_detail_dialog.dart';
import 'favorites_screen.dart';
import 'order_history_screen.dart';

class CustomerHome extends StatefulWidget {
  final String? establishmentId;
  final String? tableNumber;

  const CustomerHome({
    super.key,
    this.establishmentId,
    this.tableNumber,
  });

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  // State
  List<AppCategory> _categories = [];
  List<MenuItem> _allItems = [];
  List<MenuItem> _filteredItems = [];
  Map<String, CartItem> _cart = {};
  List<String> _favorites = [];
  UserProfile? _userProfile;
  String? _selectedTableId;
  String? _selectedEstablishmentId;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  int _currentIndex = 0;
  bool _isProcessingOrder = false;

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  // Getters
  int get _cartItemCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get _cartTotal => _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      // 1. Get establishment ID
      _selectedEstablishmentId = widget.establishmentId ?? await _getDefaultEstablishment();

      if (_selectedEstablishmentId == null) {
        throw Exception('No establishment found');
      }

      // 2. Load data
      await Future.wait([
        _loadCategories(),
        _loadMenuItems(),
        _loadFavorites(),
        _loadUserProfile(),
        _loadCartItems(),
      ]);

      // 3. Resolve table
      if (widget.tableNumber != null) {
        _selectedTableId = await _resolveTableId(widget.tableNumber!);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load: $e');
    }
  }

  Future<String?> _getDefaultEstablishment() async {
    try {
      final response = await _supabase.client
          .from('establishments')
          .select('id')
          .eq('is_active', true)
          .eq('supervisor_approved', true)
          .limit(1)
          .single();

      return response['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await _supabase.getCategories();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadMenuItems() async {
    try {
      _allItems = await _supabase.getMenuItemsWithTags(_selectedEstablishmentId!);
      _filteredItems = _allItems;
    } catch (e) {
      debugPrint('Error loading menu items: $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final items = await _supabase.getUserFavorites();
      _favorites = items.map((item) => item.id).toList();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      _userProfile = await _supabase.getCurrentUserProfile();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadCartItems() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return;

      final items = await _supabase.getCartItems(userId);
      for (final item in items) {
        final menuItem = MenuItem.fromJson(item['menu_items'] as Map<String, dynamic>);
        _cart[menuItem.id] = CartItem(
          menuItem: menuItem,
          quantity: item['quantity'] as int,
          specialInstructions: item['special_instructions'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Error loading cart items: $e');
    }
  }

  Future<String?> _resolveTableId(String tableNumber) async {
    try {
      // Try as table number first
      final num = int.tryParse(tableNumber);
      if (num != null) {
        final response = await _supabase.client
            .from('tables')
            .select('id')
            .eq('establishment_id', _selectedEstablishmentId!)
            .eq('table_number', num)
            .maybeSingle();

        if (response != null) {
          return response['id'] as String;
        }
      }

      // Try as UUID
      final response = await _supabase.client
          .from('tables')
          .select('id')
          .eq('establishment_id', _selectedEstablishmentId!)
          .eq('id', tableNumber)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      debugPrint('Error resolving table: $e');
      return null;
    }
  }

  void _searchItems(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems.where((item) {
          final name = item.name.toLowerCase();
          final desc = item.description?.toLowerCase() ?? '';
          final search = query.toLowerCase();
          return name.contains(search) || desc.contains(search);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchItems('');
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════════════════

  /// Shows a confirmation dialog, then signs out and returns to login.
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444)),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      await _auth.signOut();

      if (mounted) {
        // Navigate to login and clear the entire navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to sign out: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════

  Future<void> _addToCart(MenuItem item, {int quantity = 1, String? specialInstructions}) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) {
        _showError('Please login to add items to cart');
        return;
      }

      await _supabase.addToCart(
        userId: userId,
        establishmentId: _selectedEstablishmentId!,
        menuItemId: item.id,
        quantity: quantity,
        specialInstructions: specialInstructions,
      );

      setState(() {
        if (_cart.containsKey(item.id)) {
          final existing = _cart[item.id]!;
          _cart[item.id] = CartItem(
            menuItem: item,
            quantity: existing.quantity + quantity,
            specialInstructions: specialInstructions ?? existing.specialInstructions,
          );
        } else {
          _cart[item.id] = CartItem(
            menuItem: item,
            quantity: quantity,
            specialInstructions: specialInstructions,
          );
        }
      });

      _showSnackBar('${item.name} added to cart');
    } catch (e) {
      _showError('Failed to add to cart: $e');
    }
  }

  Future<void> _removeFromCart(String itemId) async {
    try {
      await _supabase.removeFromCart(itemId);
      setState(() {
        _cart.remove(itemId);
      });
    } catch (e) {
      _showError('Failed to remove from cart: $e');
    }
  }

  Future<void> _updateCartQuantity(String itemId, int newQuantity) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return;

      final cartItems = await _supabase.getCartItems(userId);
      final orderItem = cartItems.firstWhere(
            (item) => item['menu_items']['id'] == itemId,
        orElse: () => {},
      );

      if (orderItem.isEmpty) {
        if (newQuantity <= 0) {
          setState(() => _cart.remove(itemId));
        }
        return;
      }

      if (newQuantity <= 0) {
        await _supabase.removeFromCart(orderItem['id'] as String);
        setState(() => _cart.remove(itemId));
      } else {
        await _supabase.updateCartItemQuantity(orderItem['id'] as String, newQuantity);
        setState(() {
          if (_cart.containsKey(itemId)) {
            final item = _cart[itemId]!;
            _cart[itemId] = CartItem(
              menuItem: item.menuItem,
              quantity: newQuantity,
              specialInstructions: item.specialInstructions,
            );
          }
        });
      }
    } catch (e) {
      _showError('Failed to update quantity: $e');
    }
  }

  Future<void> _clearCart() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return;

      await _supabase.clearCart(userId);
      setState(() => _cart.clear());
      _showSnackBar('Cart cleared');
    } catch (e) {
      _showError('Failed to clear cart: $e');
    }
  }

  Future<void> _toggleFavorite(MenuItem item) async {
    final isFavorite = _favorites.contains(item.id);

    setState(() {
      if (isFavorite) {
        _favorites.remove(item.id);
      } else {
        _favorites.add(item.id);
      }
    });

    try {
      if (isFavorite) {
        await _supabase.removeFromFavorites(item.id);
      } else {
        await _supabase.addToFavorites(item.id);
      }
    } catch (e) {
      setState(() {
        if (isFavorite) {
          _favorites.add(item.id);
        } else {
          _favorites.remove(item.id);
        }
      });
      _showError('Failed to update favorites');
    }
  }

  Future<void> _showCart() async {
    if (_selectedTableId == null) {
      final tableId = await _showTableSelector();
      if (tableId == null) return;
      setState(() => _selectedTableId = tableId);
    }

    if (_cart.isEmpty) {
      _showSnackBar('Your cart is empty');
      return;
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CartBottomSheet(
        cartItems: _cart,
        onUpdateQuantity: _updateCartQuantity,
        onRemoveItem: _removeFromCart,
        onClearCart: _clearCart,
        onCheckout: _showCheckoutDialog,
      ),
    );

    if (result == true) {
      setState(() {});
    }
  }

  Future<String?> _showTableSelector() async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TableSelector(
        establishmentId: _selectedEstablishmentId!,
        onTableSelected: (tableId) => Navigator.pop(context, tableId),
      ),
    );
  }

  Future<void> _showCheckoutDialog() async {
    if (_selectedTableId == null) {
      final tableId = await _showTableSelector();
      if (tableId == null) return;
      setState(() => _selectedTableId = tableId);
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CheckoutDialog(
        cartItems: _cart,
        cartTotal: _cartTotal,
        tableId: _selectedTableId!,
        dineCoinsBalance: _userProfile?.dineCoinsBalance ?? 0,
        onPlaceOrder: _placeOrder,
      ),
    );

    if (result != null && result['success'] == true) {
      await _clearCart();
      final orderId = result['orderId'] as String?;
      _showSnackBar('Order placed successfully! Order #${orderId?.substring(0, 8) ?? 'N/A'}');
    }
  }

  Future<void> _placeOrder({
    required String paymentMethod,
    required double dineCoinsUsed,
  }) async {
    if (_isProcessingOrder) return;
    setState(() => _isProcessingOrder = true);

    try {
      final userId = _auth.currentUserId;
      if (userId == null) throw Exception('Please login to place an order');

      // 1. Create order
      final orderData = <String, Object>{
        'establishment_id': _selectedEstablishmentId!,
        'table_id': _selectedTableId!,
        'customer_id': userId,
        'status': 'pending',
        'payment_status': 'pending',
        'total_amount': _cartTotal,
      };

      final specialInstructions = _getSpecialInstructions();
      if (specialInstructions != null) {
        orderData['special_instructions'] = specialInstructions;
      }

      final orderResponse = await _supabase.client
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      // 2. Create order items
      final orderItems = _cart.entries.map((entry) {
        final item = entry.value;
        final itemData = <String, Object>{
          'order_id': orderId,
          'menu_item_id': item.menuItem.id,
          'quantity': item.quantity,
          'unit_price': item.menuItem.price,
          'line_total': item.totalPrice,
        };
        if (item.specialInstructions != null) {
          itemData['special_instructions'] = item.specialInstructions!;
        }
        return itemData;
      }).toList();

      await _supabase.client.from('order_items').insert(orderItems);

      // 3. Handle payment
      final finalAmount = paymentMethod == 'dine_coins'
          ? _cartTotal - dineCoinsUsed
          : _cartTotal;

      // Record payment
      await _supabase.client.from('payments').insert({
        'order_id': orderId,
        'amount': finalAmount > 0 ? finalAmount : 0,
        'payment_method': paymentMethod,
        'dine_coins_used': dineCoinsUsed,
        'status': paymentMethod == 'dine_coins' && finalAmount <= 0
            ? 'paid'
            : 'pending',
        'payer_customer_id': userId,
      });

      // 4. Handle DineCoins usage
      if (paymentMethod == 'dine_coins' && dineCoinsUsed > 0) {
        await _supabase.useDineCoins(
          userId: userId,
          establishmentId: _selectedEstablishmentId,
          amount: dineCoinsUsed,
          description: 'Payment for order $orderId',
        );
      }

      // 5. Update order status if fully paid with DineCoins
      if (paymentMethod == 'dine_coins' && finalAmount <= 0) {
        await _supabase.updateOrderPaymentStatus(orderId, 'paid');
      }

      // 6. Mark table as occupied
      if (_selectedTableId != null) {
        await _supabase.updateTableAvailability(_selectedTableId!, false);
      }

      if (mounted) {
        Navigator.pop(context, {'success': true, 'orderId': orderId});
      }
    } catch (e) {
      _showError('Failed to place order: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => _isProcessingOrder = false);
    }
  }

  String? _getSpecialInstructions() {
    final instructions = _cart.values
        .where((item) => item.specialInstructions != null && item.specialInstructions!.isNotEmpty)
        .map((item) => '${item.menuItem.name}: ${item.specialInstructions}')
        .join('\n');

    return instructions.isNotEmpty ? instructions : null;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(
          onAddToCart: _addToCart,
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerProfileScreen(),
      ),
    );
  }

  void _navigateToOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrderHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            app_search.SearchBar(
              controller: _searchController,
              onSearch: _searchItems,
              onClear: _clearSearch,
            ),
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _buildMainContent(),
            ),
          ],
        ),
      ),
      floatingActionButton: _cart.isNotEmpty && !_isProcessingOrder
          ? FloatingActionButton.extended(
        onPressed: _showCart,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: Stack(
          children: [
            const Icon(Icons.shopping_cart),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '$_cartItemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        label: Text('MWK ${_cartTotal.toStringAsFixed(0)}'),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'DT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DineTrack',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (_selectedTableId != null)
                  FutureBuilder(
                    future: _supabase.client
                        .from('tables')
                        .select('table_number')
                        .eq('id', _selectedTableId!)
                        .maybeSingle(),
                    builder: (context, snapshot) {
                      final tableNum = snapshot.data?['table_number'];
                      return Text(
                        'Table $tableNum',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          // ── DINE COINS BALANCE ──
          if (_userProfile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_userProfile!.dineCoinsBalance.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          // ── LOGOUT BUTTON ──
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout,
                color: Color(0xFF6B7280),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_categories.isEmpty && _allItems.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      slivers: [
        if (_categories.isNotEmpty)
          SliverToBoxAdapter(
            child: CategoryGrid(
              categories: _categories,
              onCategoryTap: (category) {
                setState(() {
                  _filteredItems = _allItems
                      .where((item) => item.categoryId == category.id)
                      .toList();
                });
              },
              onSeeAll: () {
                setState(() {
                  _filteredItems = _allItems;
                });
              },
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final item = _filteredItems[index];
                return MenuItemCard(
                  item: item,
                  isFavorite: _favorites.contains(item.id),
                  onTap: () => _showItemDetail(item),
                  onAddToCart: () => _addToCart(item, quantity: 1),
                  onToggleFavorite: () => _toggleFavorite(item),
                );
              },
              childCount: _filteredItems.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'No items found for "$_searchQuery"',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Clear Search'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return MenuItemCard(
            item: item,
            isFavorite: _favorites.contains(item.id),
            onTap: () => _showItemDetail(item),
            onAddToCart: () => _addToCart(item, quantity: 1),
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
          const Icon(
            Icons.restaurant_menu,
            size: 64,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          const Text(
            'No items available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for menu items',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) {
          _navigateToFavorites();
        } else if (index == 2) {
          _navigateToOrders();
        } else if (index == 3) {
          _navigateToProfile();
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF4F46E5),
      unselectedItemColor: const Color(0xFF9CA3AF),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_border),
          activeIcon: Icon(Icons.favorite),
          label: 'Favorites',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          activeIcon: Icon(Icons.history),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  void _showItemDetail(MenuItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ItemDetailDialog(
        item: item,
        isFavorite: _favorites.contains(item.id),
        onAddToCart: (quantity, instructions) {
          _addToCart(item, quantity: quantity, specialInstructions: instructions);
        },
        onToggleFavorite: () => _toggleFavorite(item),
      ),
    );
  }
}