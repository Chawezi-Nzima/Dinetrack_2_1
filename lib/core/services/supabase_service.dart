// lib/core/services/supabase_service.dart

import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import '../models/user_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establishment_models.dart';
import '../models/menu_models.dart';
import '../models/order_models.dart';

/// Single entry point for all Supabase reads/writes.
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
  // USER PROFILE — Schema: users(id, email, full_name, phone, user_type,
  //                               dine_coins_balance, profile_image_url, ...)
  // ==========================================================================

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      // Try to fetch from public.users first
      final response = await client
          .from('users')
          .select('id, email, full_name, phone, user_type, dine_coins_balance, profile_image_url, created_at, updated_at')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        // Handle enum types from PostgreSQL — they may come as strings or objects
        final Map<String, dynamic> safeData = Map<String, dynamic>.from(response);

        // Ensure user_type is always a String (handle enum serialization)
        if (safeData['user_type'] != null) {
          safeData['user_type'] = safeData['user_type'].toString();
        }

        // Ensure dine_coins_balance is numeric
        if (safeData['dine_coins_balance'] != null) {
          safeData['dine_coins_balance'] = (safeData['dine_coins_balance'] as num).toDouble();
        }

        return UserProfile.fromJson(safeData);
      }

      // If no row in public.users, create from auth metadata (trigger may not have run)
      developer.log('No public.users row found for ${user.id}, using auth metadata fallback',
          name: 'SupabaseService');
      return _createProfileFromAuth(user);

    } on PostgrestException catch (e) {
      developer.log('PostgrestException fetching profile: ${e.message} (code: ${e.code})',
          name: 'SupabaseService');
      // RLS blocked or table doesn't exist — fallback to auth metadata
      if (user != null) return _createProfileFromAuth(user);
      return null;
    } catch (e, stackTrace) {
      developer.log('Error fetching user profile: $e\n$stackTrace', name: 'SupabaseService');
      // Last resort: create from auth metadata
      if (user != null) return _createProfileFromAuth(user);
      return null;
    }
  }

  /// Creates a UserProfile from auth user metadata when DB row is unavailable
  UserProfile _createProfileFromAuth(User user) {
    final meta = user.userMetadata ?? {};
    return UserProfile(
      id: user.id,
      email: user.email,
      fullName: meta['full_name'] as String? ?? meta['name'] as String?,
      phone: meta['phone'] as String?,
      profileImageUrl: meta['avatar_url'] as String?,
      userType: meta['user_type']?.toString() ?? 'customer',
      dineCoinsBalance: 0.0,
      createdAt: user.createdAt != null
          ? DateTime.tryParse(user.createdAt!)
          : null,
      updatedAt: null,
    );
  }

  Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? profileImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await client.from('users').update(updates).eq('id', userId);
    } catch (e) {
      developer.log('Error updating user profile: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // CATEGORIES — Schema: menu_categories
  // ==========================================================================

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
  // MENU ITEMS — Schema: menu_items
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

  Future<List<MenuItem>> getMenuItemsWithTags(String establishmentId) async {
    try {
      final items = await getMenuItemsByEstablishment(establishmentId);
      if (items.isEmpty) return items;

      final itemIds = items.map((item) => item.id).toList();
      final tagLinks = await client
          .from('menu_item_tag_links')
          .select('menu_item_id, menu_item_tags(name)')
          .inFilter('menu_item_id', itemIds);

      final tagMap = <String, List<String>>{};
      for (final link in tagLinks) {
        final itemId = link['menu_item_id'] as String;
        final tagName = link['menu_item_tags']?['name'] as String?;
        if (tagName != null) {
          tagMap.putIfAbsent(itemId, () => []).add(tagName);
        }
      }

      return items.map((item) {
        final tags = tagMap[item.id] ?? [];
        return MenuItem(
          id: item.id,
          name: item.name,
          price: item.price,
          description: item.description,
          imageUrl: item.imageUrl,
          categoryId: item.categoryId,
          establishmentId: item.establishmentId,
          isAvailable: item.isAvailable,
          rating: item.rating,
          preparationTime: item.preparationTime,
          tags: tags,
        );
      }).toList();
    } catch (e) {
      developer.log('Error getting menu items with tags: $e', name: 'SupabaseService');
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
      developer.log('Error fetching menu items by category: $e', name: 'SupabaseService');
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

      final itemIds = (links as List).map((l) => l['menu_item_id'] as String).toList();
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
      developer.log('Error fetching items by tag "$tagName": $e', name: 'SupabaseService');
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
  // ESTABLISHMENTS — Schema: establishments
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

  Future<List<Map<String, dynamic>>> getEstablishments({bool onlyActive = true}) async {
    try {
      var query = client.from('establishments').select('*, users!owner_id(email, profile_image_url)');

      if (onlyActive) {
        query = query.eq('is_active', true).eq('supervisor_approved', true);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log('Error fetching establishments: $e', name: 'SupabaseService');
      return [];
    }
  }

  // ==========================================================================
  // TABLES — Schema: tables
  // ==========================================================================

  Future<List<TableModel>> getTables(String establishmentId) async {
    try {
      final response = await client
          .from('tables')
          .select()
          .eq('establishment_id', establishmentId)
          .order('table_number');

      return (response as List).map((json) => TableModel.fromJson(json)).toList();
    } catch (e) {
      developer.log('Error fetching tables: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<TableModel?> getTableByNumber(String establishmentId, int tableNumber) async {
    try {
      final response = await client
          .from('tables')
          .select()
          .eq('establishment_id', establishmentId)
          .eq('table_number', tableNumber)
          .maybeSingle();

      if (response == null) return null;
      return TableModel.fromJson(response);
    } catch (e) {
      developer.log('Error fetching table: $e', name: 'SupabaseService');
      return null;
    }
  }

  Future<TableModel?> getTableById(String tableId) async {
    try {
      final response = await client
          .from('tables')
          .select()
          .eq('id', tableId)
          .maybeSingle();

      if (response == null) return null;
      return TableModel.fromJson(response);
    } catch (e) {
      developer.log('Error fetching table: $e', name: 'SupabaseService');
      return null;
    }
  }

  Future<void> updateTableAvailability(String tableId, bool isAvailable) async {
    try {
      await client
          .from('tables')
          .update({
        'is_available': isAvailable,
        'occupied_at': isAvailable ? null : DateTime.now().toIso8601String(),
        'last_activity_at': DateTime.now().toIso8601String(),
      })
          .eq('id', tableId);
    } catch (e) {
      developer.log('Error updating table availability: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // ORDERS — Schema: orders (uses customer_id, not user_id)
  // ==========================================================================

  Future<Map<String, dynamic>> createOrder({
    required String establishmentId,
    required String tableId,
    required String customerId,
    required double totalAmount,
    String? specialInstructions,
    String? groupSessionId,
  }) async {
    try {
      return await client
          .from('orders')
          .insert({
        'establishment_id': establishmentId,
        'table_id': tableId,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'special_instructions': specialInstructions,
        'group_session_id': groupSessionId,
        'status': 'pending',
        'payment_status': 'pending',
      })
          .select()
          .single();
    } catch (e) {
      developer.log('Error creating order: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> createOrderItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await client.from('order_items').insert(items);
    } catch (e) {
      developer.log('Error creating order items: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<Order?> getOrder(String orderId) async {
    try {
      final response = await client
          .from('orders')
          .select('*, order_items(*, menu_items(*))')
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return Order.fromJson(response);
    } catch (e) {
      developer.log('Error fetching order: $e', name: 'SupabaseService');
      return null;
    }
  }

  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final response = await client
          .from('orders')
          .select('*, order_items(*, menu_items(*))')
          .eq('customer_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      developer.log('Error fetching user orders: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<List<Order>> getEstablishmentOrders(String establishmentId) async {
    try {
      final response = await client
          .from('orders')
          .select('*, order_items(*, menu_items(*))')
          .eq('establishment_id', establishmentId)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      developer.log('Error fetching establishment orders: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<Map<String, dynamic>> getEstablishmentStats(String establishmentId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

      final todayOrdersResponse = await client
          .from('orders')
          .select('id')
          .eq('establishment_id', establishmentId)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);

      final todayOrders = (todayOrdersResponse as List).length;

      final revenueResponse = await client
          .from('orders')
          .select('total_amount')
          .eq('establishment_id', establishmentId)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .inFilter('status', ['served', 'completed']);

      final todayRevenue = (revenueResponse as List).fold<double>(
        0.0,
            (sum, order) => sum + ((order['total_amount'] ?? 0) as num).toDouble(),
      );

      final pendingResponse = await client
          .from('orders')
          .select('id')
          .eq('establishment_id', establishmentId)
          .inFilter('status', ['pending', 'confirmed']);

      final pendingOrders = (pendingResponse as List).length;

      final activeTablesResponse = await client
          .from('tables')
          .select('id')
          .eq('establishment_id', establishmentId)
          .eq('is_available', false);

      final activeTables = (activeTablesResponse as List).length;

      final completedResponse = await client
          .from('orders')
          .select('id')
          .eq('establishment_id', establishmentId)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .inFilter('status', ['served', 'completed']);

      final completedToday = (completedResponse as List).length;

      return {
        'today_orders': todayOrders,
        'today_revenue': todayRevenue,
        'pending_orders': pendingOrders,
        'active_tables': activeTables,
        'completed_today': completedToday,
      };
    } catch (e) {
      developer.log('Error fetching establishment stats: $e', name: 'SupabaseService');
      return {
        'today_orders': 0,
        'today_revenue': 0.0,
        'pending_orders': 0,
        'active_tables': 0,
        'completed_today': 0,
      };
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await client
          .from('orders')
          .update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', orderId);
    } catch (e) {
      developer.log('Error updating order status: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> updateOrderPaymentStatus(String orderId, String paymentStatus) async {
    try {
      await client
          .from('orders')
          .update({
        'payment_status': paymentStatus,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', orderId);
    } catch (e) {
      developer.log('Error updating order payment status: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> _updateOrderTotal(String orderId) async {
    try {
      final items = await client
          .from('order_items')
          .select('line_total')
          .eq('order_id', orderId);

      final total = items.fold<double>(
        0,
            (sum, item) => sum + (item['line_total'] as num).toDouble(),
      );

      await client.from('orders').update({'total_amount': total}).eq('id', orderId);
    } catch (e) {
      developer.log('Error updating order total: $e', name: 'SupabaseService');
    }
  }

  // ==========================================================================
  // CART — Implemented via orders + order_items with pending status
  // ==========================================================================

  Future<Map<String, dynamic>?> getActiveOrder(String userId) async {
    try {
      final activeOrders = await client
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .inFilter('status', ['pending', 'confirmed'])
          .limit(1);

      return activeOrders.isEmpty ? null : activeOrders.first;
    } catch (e) {
      developer.log('Error getting active order: $e', name: 'SupabaseService');
      return null;
    }
  }

  Future<String> getOrCreateActiveOrder(String userId, String establishmentId) async {
    try {
      final existing = await getActiveOrder(userId);
      if (existing != null) {
        return existing['id'] as String;
      }

      final newOrder = await client
          .from('orders')
          .insert({
        'customer_id': userId,
        'establishment_id': establishmentId,
        'status': 'pending',
        'payment_status': 'pending',
        'total_amount': 0,
      })
          .select()
          .single();

      return newOrder['id'] as String;
    } catch (e) {
      developer.log('Error getting/creating active order: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> addToCart({
    required String userId,
    required String establishmentId,
    required String menuItemId,
    required int quantity,
    String? specialInstructions,
  }) async {
    try {
      final orderId = await getOrCreateActiveOrder(userId, establishmentId);

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
          'special_instructions': specialInstructions ?? existing['special_instructions'],
        })
            .eq('id', existing['id']);
      } else {
        await client.from('order_items').insert({
          'order_id': orderId,
          'menu_item_id': menuItemId,
          'quantity': quantity,
          'unit_price': price,
          'line_total': price * quantity,
          'special_instructions': specialInstructions,
        });
      }

      await _updateOrderTotal(orderId);
    } catch (e) {
      developer.log('Error adding to cart: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCartItems(String userId) async {
    try {
      final activeOrder = await getActiveOrder(userId);
      if (activeOrder == null) return [];

      final orderId = activeOrder['id'] as String;
      final response = await client
          .from('order_items')
          .select('*, menu_items(id, name, description, image_url, price)')
          .eq('order_id', orderId);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting cart items: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<void> updateCartItemQuantity(String orderItemId, int newQuantity) async {
    try {
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
    } catch (e) {
      developer.log('Error updating cart item quantity: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> removeFromCart(String orderItemId) async {
    try {
      final orderItem = await client
          .from('order_items')
          .select('order_id')
          .eq('id', orderItemId)
          .single();

      await client.from('order_items').delete().eq('id', orderItemId);
      await _updateOrderTotal(orderItem['order_id'] as String);
    } catch (e) {
      developer.log('Error removing from cart: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      final activeOrder = await getActiveOrder(userId);
      if (activeOrder == null) return;

      final orderId = activeOrder['id'] as String;
      await client.from('order_items').delete().eq('order_id', orderId);
      await _updateOrderTotal(orderId);
    } catch (e) {
      developer.log('Error clearing cart: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // PAYMENTS — Schema: payments
  // ==========================================================================

  Future<Map<String, dynamic>> createPayment({
    required String orderId,
    required String payerCustomerId,
    required double amount,
    required String paymentMethod,
    double dineCoinsUsed = 0,
    String? providerPaymentId,
    String? checkoutUrl,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await client.from('payments').insert({
        'order_id': orderId,
        'payer_customer_id': payerCustomerId,
        'amount': amount,
        'payment_method': paymentMethod,
        'dine_coins_used': dineCoinsUsed,
        'status': 'pending',
        'provider_payment_id': providerPaymentId,
        'checkout_url': checkoutUrl,
        'idempotency_key': idempotencyKey,
        'metadata': metadata,
      }).select().single();
    } catch (e) {
      developer.log('Error creating payment: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPayment(String paymentId) async {
    try {
      return await client
          .from('payments')
          .select('*, orders(*)')
          .eq('id', paymentId)
          .maybeSingle();
    } catch (e) {
      developer.log('Error fetching payment: $e', name: 'SupabaseService');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserPayments(String userId) async {
    try {
      final response = await client
          .from('payments')
          .select('*, orders(*)')
          .eq('payer_customer_id', userId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error fetching user payments: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<void> updatePaymentStatus(String paymentId, String status) async {
    try {
      await client
          .from('payments')
          .update({'status': status})
          .eq('id', paymentId);
    } catch (e) {
      developer.log('Error updating payment status: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // DINECOINS — Schema: dinecoins_ledger
  // ==========================================================================

  Future<double> getDineCoinsBalance(String userId) async {
    try {
      final response = await client
          .from('dinecoins_ledger')
          .select('amount, transaction_type')
          .eq('user_id', userId);

      double balance = 0.0;
      for (final record in response) {
        final amount = (record['amount'] as num).toDouble();
        final type = record['transaction_type'] as String;
        if (type == 'credit') {
          balance += amount;
        } else if (type == 'debit') {
          balance -= amount;
        }
      }
      return balance;
    } catch (e) {
      developer.log('Error getting DineCoins balance: $e', name: 'SupabaseService');
      return 0.0;
    }
  }

  Future<void> _syncDineCoinsBalance(String userId) async {
    final balance = await getDineCoinsBalance(userId);
    await client
        .from('users')
        .update({'dine_coins_balance': balance})
        .eq('id', userId);
  }

  Future<void> addDineCoins({
    required String userId,
    String? establishmentId,
    required double amount,
    required String description,
  }) async {
    try {
      final data = <String, Object>{
        'user_id': userId,
        'amount': amount,
        'transaction_type': 'credit',
        'description': description,
      };
      if (establishmentId != null) {
        data['establishment_id'] = establishmentId;
      }

      await client.from('dinecoins_ledger').insert(data);
      await _syncDineCoinsBalance(userId);
    } catch (e) {
      developer.log('Error adding DineCoins: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> useDineCoins({
    required String userId,
    String? establishmentId,
    required double amount,
    required String description,
  }) async {
    try {
      final data = <String, Object>{
        'user_id': userId,
        'amount': amount,
        'transaction_type': 'debit',
        'description': description,
      };
      if (establishmentId != null) {
        data['establishment_id'] = establishmentId;
      }

      await client.from('dinecoins_ledger').insert(data);
      await _syncDineCoinsBalance(userId);
    } catch (e) {
      developer.log('Error using DineCoins: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // RESERVATIONS — Schema: reservations
  // ==========================================================================

  Future<Map<String, dynamic>> createReservation({
    required String establishmentId,
    required String customerId,
    required DateTime reservationTime,
    required int partySize,
    String? tableId,
    String? specialRequests,
  }) async {
    try {
      return await client.from('reservations').insert({
        'establishment_id': establishmentId,
        'customer_id': customerId,
        'reservation_time': reservationTime.toIso8601String(),
        'party_size': partySize,
        'table_id': tableId,
        'special_requests': specialRequests,
        'status': 'pending',
      }).select().single();
    } catch (e) {
      developer.log('Error creating reservation: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserReservations(String userId) async {
    try {
      final response = await client
          .from('reservations')
          .select('*, establishments(name)')
          .eq('customer_id', userId)
          .order('reservation_time', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error fetching user reservations: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getEstablishmentReservations(String establishmentId) async {
    try {
      final response = await client
          .from('reservations')
          .select('*, users:customer_id(full_name, email, phone)')
          .eq('establishment_id', establishmentId)
          .order('reservation_time', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error fetching establishment reservations: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<void> updateReservationStatus(String reservationId, String status) async {
    try {
      await client
          .from('reservations')
          .update({'status': status})
          .eq('id', reservationId);
    } catch (e) {
      developer.log('Error updating reservation status: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // ASSIST REQUESTS — Schema: assist_requests
  // ==========================================================================

  Future<void> createAssistRequest({
    required String establishmentId,
    required String tableId,
  }) async {
    try {
      await client.from('assist_requests').insert({
        'establishment_id': establishmentId,
        'table_id': tableId,
        'status': 'open',
      });
    } catch (e) {
      developer.log('Error creating assist request: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOpenAssistRequests(String establishmentId) async {
    try {
      final response = await client
          .from('assist_requests')
          .select('*, tables(table_number)')
          .eq('establishment_id', establishmentId)
          .eq('status', 'open')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error fetching assist requests: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<void> resolveAssistRequest(String requestId) async {
    try {
      await client
          .from('assist_requests')
          .update({'status': 'resolved'})
          .eq('id', requestId);
    } catch (e) {
      developer.log('Error resolving assist request: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // ==========================================================================
  // FAVORITES — Schema: user_favorites
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

  Future<bool> isFavorite(String menuItemId) async {
    final user = client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await client
          .from('user_favorites')
          .select('menu_item_id')
          .eq('user_id', user.id)
          .eq('menu_item_id', menuItemId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================================
  // OPERATOR / STAFF HELPERS
  // ==========================================================================

  Future<Map<String, dynamic>?> getStaffAssignment(String userId) async {
    try {
      final response = await client
          .from('staff_assignments')
          .select('role, establishment_id, is_active, name, email')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();
      return response;
    } catch (e) {
      developer.log('Error fetching staff assignment: $e', name: 'SupabaseService');
      return null;
    }
  }

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
      developer.log('Error resolving operator establishment: $e', name: 'SupabaseService');
      return null;
    }
  }

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
        .map((rows) => rows
        .where((row) => row['order_id'] == orderId)
        .cast<Map<String, dynamic>>()
        .toList());
  }

  Stream<Map<String, dynamic>> getOrderStatusStream(String orderId) {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.firstWhere((row) => row['id'] == orderId));
  }

  Stream<List<Map<String, dynamic>>> getAssistRequestsStream(String establishmentId) {
    return client
        .from('assist_requests')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
        .where((row) =>
    row['establishment_id'] == establishmentId &&
        row['status'] == 'open')
        .cast<Map<String, dynamic>>()
        .toList());
  }

  Stream<List<Map<String, dynamic>>> getEstablishmentOrdersStream(String establishmentId) {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
        .where((row) =>
    row['establishment_id'] == establishmentId &&
        row['status'] != 'completed' &&
        row['status'] != 'cancelled')
        .cast<Map<String, dynamic>>()
        .toList());
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

  Future<void> deleteFile(String bucket, String path) async {
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (e) {
      developer.log('Error deleting file: $e', name: 'SupabaseService');
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