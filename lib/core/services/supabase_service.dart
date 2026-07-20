import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_models.dart';

/// Single entry point for all Supabase reads/writes.
///
/// This intentionally stays a "fat" service rather than being split into
/// five micro-services — for an app this size, one well-organized service
/// with clear section headers is easier to navigate than hunting across
/// files. AuthService and PaymentService stay separate since they have
/// genuinely distinct responsibilities.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  SupabaseClient get client => Supabase.instance.client;

  Future<void> postInit() async {
    developer.log('Supabase initialized: $supabaseUrl', name: 'SupabaseService');
  }

  // ==========================================================================
  // AUTH
  // ==========================================================================

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => client.auth.currentUser?.id;
  bool get isAuthenticated => client.auth.currentUser != null;

  Future<void> signOut() async => client.auth.signOut();

  Future<AuthResponse> signIn(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  /// Signs up a new user. The `public.users` row is created automatically
  /// by the `handle_new_auth_user` DB trigger — no manual insert needed.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String userType,
    String? fullName,
    String? phone,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: {
        'user_type': userType,
        'full_name': fullName ?? '',
        'phone': phone ?? '',
      },
    );
  }

  // ==========================================================================
  // USER PROFILE
  // ==========================================================================

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final response =
      await client.from('users').select().eq('id', user.id).single();
      return UserProfile.fromJson(response);
    } catch (e) {
      developer.log('Error fetching user profile: $e', name: 'SupabaseService');
      return null;
    }
  }

  // ==========================================================================
  // CATEGORIES
  // ==========================================================================

  /// Categories are global (shared across every establishment).
  Future<List<AppCategory>> getCategories() async {
    try {
      final response = await client
          .from('menu_categories')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return response.map((cat) => AppCategory.fromJson(cat)).toList();
    } catch (e) {
      developer.log('Error fetching categories: $e', name: 'SupabaseService');
      return [];
    }
  }

  // ==========================================================================
  // MENU ITEMS
  // ==========================================================================

  Future<List<MenuItem>> getMenuItemsByEstablishment(
      String establishmentId,
      ) async {
    try {
      final response = await client
          .from('menu_items')
          .select()
          .eq('establishment_id', establishmentId)
          .eq('is_available', true)
          .isFilter('deleted_at', null);

      return response.map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log('Error fetching menu items: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<List<MenuItem>> getMenuItemsByCategory(String categoryId) async {
    try {
      final response = await client
          .from('menu_items')
          .select()
          .eq('category_id', categoryId)
          .eq('is_available', true)
          .order('name');

      return response.map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log(
        'Error fetching menu items by category: $e',
        name: 'SupabaseService',
      );
      return [];
    }
  }

  Future<List<MenuItem>> searchMenuItems(
      String searchQuery, {
        String? establishmentId,
      }) async {
    try {
      var query = client
          .from('menu_items')
          .select()
          .eq('is_available', true)
          .ilike('name', '%$searchQuery%');

      if (establishmentId != null) {
        query = query.eq('establishment_id', establishmentId);
      }

      final response = await query;
      return response.map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log('Error searching menu items: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<List<MenuItem>> getAllMenuItems() async {
    try {
      final response = await client
          .from('menu_items')
          .select()
          .eq('is_available', true)
          .order('name');

      return response.map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log('Error fetching all menu items: $e', name: 'SupabaseService');
      return [];
    }
  }

  /// Bestsellers/recommended are now driven by tags (menu_item_tags +
  /// menu_item_tag_links) instead of boolean columns on menu_items.
  /// Pass 'bestseller' or 'recommended' as [tagName].
  Future<List<MenuItem>> getItemsByTag(
      String tagName, {
        String? establishmentId,
        int? limit,
      }) async {
    try {
      final tag = await client
          .from('menu_item_tags')
          .select('id')
          .eq('name', tagName)
          .maybeSingle();

      if (tag == null) return [];

      final links = await client
          .from('menu_item_tag_links')
          .select('menu_item_id')
          .eq('tag_id', tag['id']);

      final itemIds =
      (links as List).map((l) => l['menu_item_id'] as String).toList();
      if (itemIds.isEmpty) return [];

      var query = client
          .from('menu_items')
          .select()
          .inFilter('id', itemIds)
          .eq('is_available', true);

      if (establishmentId != null) {
        query = query.eq('establishment_id', establishmentId);
      }

      final response = limit != null ? await query.limit(limit) : await query;
      return response.map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log(
        'Error fetching items by tag "$tagName": $e',
        name: 'SupabaseService',
      );
      return [];
    }
  }

  Future<List<MenuItem>> getBestsellers({String? establishmentId}) {
    return getItemsByTag('bestseller', establishmentId: establishmentId);
  }

  Future<List<MenuItem>> getRecommended({String? establishmentId}) {
    return getItemsByTag('recommended', establishmentId: establishmentId, limit: 8);
  }

  // ==========================================================================
  // ESTABLISHMENTS
  // ==========================================================================

  Future<Map<String, dynamic>?> getEstablishment(String establishmentId) async {
    try {
      return await client
          .from('establishments')
          .select()
          .eq('id', establishmentId)
          .eq('is_active', true)
          .single();
    } catch (e) {
      developer.log('Error fetching establishment: $e', name: 'SupabaseService');
      return null;
    }
  }

  // ==========================================================================
  // OPERATOR / STAFF HELPERS
  // ==========================================================================

  /// Resolves the establishment the current user is staff/owner/kitchen for.
  /// Priority: staff_assignments -> ownership -> kitchen_assignments.
  Future<String?> getOperatorEstablishmentId() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final staffAssignment = await client
          .from('staff_assignments')
          .select('establishment_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();
      if (staffAssignment != null) {
        return staffAssignment['establishment_id']?.toString();
      }

      final ownedEstablishment = await client
          .from('establishments')
          .select('id')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .maybeSingle();
      if (ownedEstablishment != null) {
        // Auto-create a manager staff_assignment for the owner if missing,
        // so future staff-based RLS checks/queries work uniformly.
        await client.from('staff_assignments').upsert({
          'user_id': user.id,
          'establishment_id': ownedEstablishment['id'],
          'role': 'manager',
          'name': 'Owner',
          'is_active': true,
        });
        return ownedEstablishment['id']?.toString();
      }

      final kitchenAssignment = await client
          .from('kitchen_assignments')
          .select('establishment_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();
      if (kitchenAssignment != null) {
        return kitchenAssignment['establishment_id']?.toString();
      }

      return null;
    } catch (e) {
      developer.log(
        'Error resolving operator establishment: $e',
        name: 'SupabaseService',
      );
      return null;
    }
  }

  /// Creates a kitchen staff account without disrupting the current
  /// (operator) session, using a throwaway secondary client for the signup.
  /// The public.users row is created automatically via DB trigger.
  Future<void> createKitchenStaffAccount({
    required String establishmentId,
    required String email,
    required String password,
    required String fullName,
    required String station,
  }) async {
    final secondaryClient = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
    );

    try {
      final authResponse = await secondaryClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'user_type': 'kitchen'},
      );

      final newUserId = authResponse.user?.id;
      if (newUserId == null) {
        throw Exception('Failed to create kitchen account: no user returned');
      }

      // users row already exists via trigger — just link the assignment.
      await client.from('kitchen_assignments').insert({
        'user_id': newUserId,
        'establishment_id': establishmentId,
        'assigned_station': station,
        'is_active': true,
      });
    } catch (e) {
      developer.log('Error creating kitchen staff: $e', name: 'SupabaseService');
      rethrow;
    } finally {
      await secondaryClient.dispose();
    }
  }

  Future<void> removeKitchenStaff(String assignmentId) async {
    try {
      await client.from('kitchen_assignments').delete().eq('id', assignmentId);
    } catch (e) {
      developer.log('Error removing kitchen staff: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // FAVORITES
  // ==========================================================================

  Future<List<MenuItem>> getUserFavorites() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await client
          .from('user_favorites')
          .select('menu_items(*)')
          .eq('user_id', user.id);

      return (response as List)
          .map((json) => MenuItem.fromJson(json['menu_items']))
          .toList();
    } catch (e) {
      developer.log('Error fetching favorites: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<void> addToFavorites(String menuItemId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await client.from('user_favorites').insert({
      'user_id': user.id,
      'menu_item_id': menuItemId,
    });
  }

  Future<void> removeFromFavorites(String menuItemId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await client
        .from('user_favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('menu_item_id', menuItemId);
  }

  // ==========================================================================
  // CART & ORDERS
  // ==========================================================================

  Future<Map<String, dynamic>?> getActiveOrder() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final activeOrders = await client
        .from('orders')
        .select()
        .eq('customer_id', user.id)
        .inFilter('status', ['pending', 'confirmed'])
        .limit(1);

    return activeOrders.isEmpty ? null : activeOrders.first;
  }

  Future<void> addToCart(String menuItemId, int quantity) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final activeOrders = await client
        .from('orders')
        .select()
        .eq('customer_id', user.id)
        .inFilter('status', ['pending', 'confirmed'])
        .limit(1);

    String orderId;
    if (activeOrders.isEmpty) {
      final newOrder = await client
          .from('orders')
          .insert({
        'customer_id': user.id,
        'establishment_id': await _getDefaultEstablishmentId(),
        'table_id': await _getDefaultTableId(),
        'status': 'pending',
        'total_amount': 0,
      })
          .select()
          .single();
      orderId = newOrder['id'] as String;
    } else {
      orderId = activeOrders.first['id'] as String;
    }

    final menuItem = await client
        .from('menu_items')
        .select('price')
        .eq('id', menuItemId)
        .single();
    final price = (menuItem['price'] as num).toDouble();

    final existingItems = await client
        .from('order_items')
        .select()
        .eq('order_id', orderId)
        .eq('menu_item_id', menuItemId);

    if (existingItems.isNotEmpty) {
      final existing = existingItems.first;
      final newQuantity = (existing['quantity'] as int) + quantity;
      await client
          .from('order_items')
          .update({
        'quantity': newQuantity,
        'line_total': price * newQuantity,
      })
          .eq('id', existing['id']);
    } else {
      await client.from('order_items').insert({
        'order_id': orderId,
        'menu_item_id': menuItemId,
        'quantity': quantity,
        'unit_price': price,
        'line_total': price * quantity,
      });
    }

    await _updateOrderTotal(orderId);
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final activeOrders = await client
        .from('orders')
        .select()
        .eq('customer_id', user.id)
        .inFilter('status', ['pending', 'confirmed'])
        .limit(1);

    if (activeOrders.isEmpty) return [];
    final orderId = activeOrders.first['id'] as String;

    final response = await client
        .from('order_items')
        .select('*, menu_items(id, name, description, image_url, price)')
        .eq('order_id', orderId);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateCartItemQuantity(String orderItemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(orderItemId);
      return;
    }

    final orderItem = await client
        .from('order_items')
        .select('*, menu_items(price)')
        .eq('id', orderItemId)
        .single();

    final price = (orderItem['menu_items']['price'] as num).toDouble();

    await client
        .from('order_items')
        .update({
      'quantity': newQuantity,
      'line_total': price * newQuantity,
    })
        .eq('id', orderItemId);

    await _updateOrderTotal(orderItem['order_id'] as String);
  }

  Future<void> removeFromCart(String orderItemId) async {
    final orderItem = await client
        .from('order_items')
        .select('order_id')
        .eq('id', orderItemId)
        .single();

    await client.from('order_items').delete().eq('id', orderItemId);
    await _updateOrderTotal(orderItem['order_id'] as String);
  }

  Future<void> clearCart(String orderId) async {
    await client.from('order_items').delete().eq('order_id', orderId);
    await _updateOrderTotal(orderId);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await client.from('orders').update({'status': status}).eq('id', orderId);
  }

  Future<void> _updateOrderTotal(String orderId) async {
    final items = await client
        .from('order_items')
        .select('line_total')
        .eq('order_id', orderId);

    final total = items.fold<double>(
      0,
          (sum, item) => sum + (item['line_total'] as num).toDouble(),
    );

    await client.from('orders').update({'total_amount': total}).eq('id', orderId);
  }

  Future<String> _getDefaultEstablishmentId() async {
    final response = await client
        .from('establishments')
        .select('id')
        .eq('is_active', true)
        .limit(1);
    return response.isNotEmpty ? response.first['id'] as String : '';
  }

  Future<String> _getDefaultTableId() async {
    final establishmentId = await _getDefaultEstablishmentId();
    if (establishmentId.isEmpty) return '';

    final response = await client
        .from('tables')
        .select('id')
        .eq('establishment_id', establishmentId)
        .eq('is_available', true)
        .limit(1);
    return response.isNotEmpty ? response.first['id'] as String : '';
  }

  // ==========================================================================
  // REALTIME STREAMS
  // ==========================================================================

  Stream<List<MenuItem>> getMenuItemsStream() {
    return client
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map((json) => MenuItem.fromJson(json)).toList());
  }

  Stream<List<Map<String, dynamic>>> getOrderStream(String orderId) {
    return client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  // ==========================================================================
  // STORAGE / IMAGE UPLOADS
  // ==========================================================================

  String storagePublicUrl(String bucket, String path) {
    return '$supabaseUrl/storage/v1/object/public/$bucket/$path';
  }

  Future<String?> uploadProfileImage(List<int> bytes, String originalFileName) async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalFileName.split('.').last;
      final fileName = '${user.id}/$timestamp.$extension';
      final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      await client.storage.from('profile_images').uploadBinary(fileName, uint8Bytes);
      return client.storage.from('profile_images').getPublicUrl(fileName);
    } catch (e) {
      developer.log('Error uploading profile image: $e', name: 'SupabaseService');
      return null;
    }
  }

  Future<String?> uploadMenuItemImage(List<int> bytes, String originalFileName) async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalFileName.split('.').last;
      final fileName = '${user.id}/menu_item_$timestamp.$extension';
      final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      await client.storage.from('images').uploadBinary(fileName, uint8Bytes);
      return client.storage.from('images').getPublicUrl(fileName);
    } catch (e) {
      developer.log('Error uploading menu item image: $e', name: 'SupabaseService');
      return null;
    }
  }

  Future<String?> uploadRestaurantImage(File file, String establishmentId) async {
    try {
      final fileName =
          'restaurant_${establishmentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'restaurants/$fileName';

      await client.storage.from('images').upload(path, file);
      return storagePublicUrl('images', path);
    } catch (e) {
      developer.log('Error uploading restaurant image: $e', name: 'SupabaseService');
      rethrow;
    }
  }
}

/// In-memory PKCE storage used for the throwaway secondary client during
/// kitchen staff signup, so it never touches the operator's own session.
class _MemoryStorage extends GotrueAsyncStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getItem({required String key}) async => _storage[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _storage.remove(key);
  }
}