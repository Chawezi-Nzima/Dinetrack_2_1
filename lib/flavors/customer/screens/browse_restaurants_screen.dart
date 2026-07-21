import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dinetrack_2_1/core/models/user_models.dart';
import '../../../core/services/qr_code_service.dart';
import '../screens/restaurant_menu_screen.dart';
import '../screens/qr_scanner_screen.dart';

/// Browse Restaurants Screen
/// Landing page for logged-in customers with no pending QR scan
class BrowseRestaurantsScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const BrowseRestaurantsScreen({super.key, this.userProfile});

  @override
  State<BrowseRestaurantsScreen> createState() => _BrowseRestaurantsScreenState();
}

class _BrowseRestaurantsScreenState extends State<BrowseRestaurantsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Restaurant> _restaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Fast Food', 'Fine Dining', 'Cafe', 'Bar', 'Local'];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('establishments')
          .select('*, tables:tables(count)')
          .eq('is_active', true)
          .order('name');

      setState(() {
        _restaurants = (response as List<dynamic>)
            .map((json) => Restaurant.fromJson(json))
            .toList();
        _filteredRestaurants = _restaurants;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading restaurants: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterRestaurants() {
    setState(() {
      _filteredRestaurants = _restaurants.where((r) {
        final matchesSearch = _searchQuery.isEmpty ||
            r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            r.cuisine.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCategory = _selectedCategory == 'All' || r.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // App Bar with Search
          SliverAppBar(
            expandedHeight: 180,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF1a1a2e),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${widget.userProfile?.displayName ?? 'Guest'}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Discover Restaurants',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            // Scan QR Button
                            GestureDetector(
                              onTap: () => _scanQRCode(context),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                                    SizedBox(height: 4),
                                    Text(
                                      'Scan QR',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Search Bar
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              _searchQuery = value;
                              _filterRestaurants();
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search restaurants, cuisines...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                              prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Category Chips
          SliverToBoxAdapter(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _filterRestaurants();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF667eea) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF1a1a2e),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Restaurant List
          _isLoading
              ? const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
              : _filteredRestaurants.isEmpty
              ? SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No restaurants found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildRestaurantCard(_filteredRestaurants[index]),
                childCount: _filteredRestaurants.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    return GestureDetector(
      onTap: () => _openRestaurantMenu(restaurant),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: restaurant.coverImageUrl ?? '',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      child: const Icon(Icons.restaurant, size: 48, color: Color(0xFF667eea)),
                    ),
                  ),
                ),
                // Rating badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.rating}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                // Open/Closed badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: restaurant.isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      restaurant.isOpen ? 'OPEN' : 'CLOSED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1a1a2e),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          restaurant.cuisine,
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryTime,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.table_restaurant, size: 16, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '${restaurant.tableCount} tables',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Min: MWK ${restaurant.minOrder.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRestaurantMenu(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantMenuScreen(
          restaurant: restaurant,
          userProfile: widget.userProfile,
        ),
      ),
    );
  }

  Future<void> _scanQRCode(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      // Handle QR scan result - navigate to table session
      final establishmentId = result['establishment_id'];
      final tableId = result['table_id'];
      final tableNumber = result['table_number'];

      // Find the restaurant
      final restaurant = _restaurants.firstWhere(
            (r) => r.id == establishmentId,
        orElse: () => Restaurant(
          id: establishmentId,
          name: 'Unknown Restaurant',
          cuisine: '',
          description: '',
          address: '',
          rating: 0,
          isOpen: true,
          deliveryTime: '',
          minOrder: 0,
          tableCount: 0,
          category: '',
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantMenuScreen(
            restaurant: restaurant,
            userProfile: widget.userProfile,
            tableId: tableId,
            tableNumber: tableNumber,
          ),
        ),
      );
    }
  }
}

// ─── Restaurant Model ───────────────────────────────────────

class Restaurant {
  final String id;
  final String name;
  final String cuisine;
  final String description;
  final String address;
  final double rating;
  final bool isOpen;
  final String deliveryTime;
  final double minOrder;
  final int tableCount;
  final String category;
  final String? coverImageUrl;
  final String? logoUrl;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.description,
    required this.address,
    required this.rating,
    required this.isOpen,
    required this.deliveryTime,
    required this.minOrder,
    required this.tableCount,
    required this.category,
    this.coverImageUrl,
    this.logoUrl,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      cuisine: json['cuisine_type'] ?? json['cuisine'] ?? 'General',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] ?? 4.0).toDouble(),
      isOpen: json['is_open'] ?? json['is_active'] ?? true,
      deliveryTime: json['delivery_time'] ?? '15-30 min',
      minOrder: (json['min_order_amount'] ?? 0).toDouble(),
      tableCount: json['tables']?[0]?['count'] ?? json['table_count'] ?? 0,
      category: json['category'] ?? 'Local',
      coverImageUrl: json['cover_image_url'],
      logoUrl: json['logo_url'],
    );
  }
}