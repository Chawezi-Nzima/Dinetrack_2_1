import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/user_models.dart';

/// Order status enum matching database values
enum OrderStatus {
  placed,
  confirmed,
  preparing,
  ready,
  served,
  completed,
  cancelled,
}

/// Payment status enum
enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
  cancelled,
}

/// Order item model
class OrderItem {
  final String id;
  final String menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? specialInstructions;
  final String? imageUrl;

  const OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.specialInstructions,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      menuItemId: json['menu_item_id'] ?? '',
      name: json['name'] ?? 'Unknown Item',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      specialInstructions: json['special_instructions'],
      imageUrl: json['image_url'],
    );
  }
}

/// Order model with full tracking info
class Order {
  final String id;
  final String? customerId;
  final String? establishmentId;
  final String? tableId;
  final int? tableNumber;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentReference;
  final double totalAmount;
  final double? taxAmount;
  final double? tipAmount;
  final List<OrderItem> items;
  final String? specialInstructions;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final DateTime? estimatedReadyAt;
  final String? assignedKitchenStaffId;
  final String? receiptId;
  final Map<String, dynamic>? metadata;

  const Order({
    required this.id,
    this.customerId,
    this.establishmentId,
    this.tableId,
    this.tableNumber,
    required this.status,
    required this.paymentStatus,
    this.paymentReference,
    required this.totalAmount,
    this.taxAmount,
    this.tipAmount,
    required this.items,
    this.specialInstructions,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.estimatedReadyAt,
    this.assignedKitchenStaffId,
    this.receiptId,
    this.metadata,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      customerId: json['customer_id'],
      establishmentId: json['establishment_id'],
      tableId: json['table_id'],
      tableNumber: json['table_number'],
      status: _parseOrderStatus(json['status']),
      paymentStatus: _parsePaymentStatus(json['payment_status']),
      paymentReference: json['payment_reference'],
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      taxAmount: json['tax_amount']?.toDouble(),
      tipAmount: json['tip_amount']?.toDouble(),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      specialInstructions: json['special_instructions'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      estimatedReadyAt: json['estimated_ready_at'] != null
          ? DateTime.parse(json['estimated_ready_at'])
          : null,
      assignedKitchenStaffId: json['assigned_kitchen_staff_id'],
      receiptId: json['receipt_id'],
      metadata: json['metadata'],
    );
  }

  static OrderStatus _parseOrderStatus(String? status) {
    switch (status) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'served':
        return OrderStatus.served;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.placed;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }

  /// Get human-readable status label
  String get statusLabel {
    switch (status) {
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.served:
        return 'Served';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Get payment status label
  String get paymentStatusLabel {
    switch (paymentStatus) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Check if order can be cancelled
  bool get canCancel =>
      status == OrderStatus.placed || status == OrderStatus.confirmed;

  /// Check if order is active (not completed/cancelled)
  bool get isActive =>
      status != OrderStatus.completed && status != OrderStatus.cancelled;

  /// Calculate estimated ready time based on queue
  DateTime? get estimatedReadyTime {
    if (estimatedReadyAt != null) return estimatedReadyAt;
    if (status == OrderStatus.ready || status.index >= OrderStatus.ready.index) {
      return null;
    }
    return createdAt.add(const Duration(minutes: 15));
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    switch (status) {
      case OrderStatus.placed:
        return 0.1;
      case OrderStatus.confirmed:
        return 0.25;
      case OrderStatus.preparing:
        return 0.5;
      case OrderStatus.ready:
        return 0.75;
      case OrderStatus.served:
        return 0.9;
      case OrderStatus.completed:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }
}

/// Order timeline event
class OrderTimelineEvent {
  final String id;
  final String orderId;
  final String status;
  final String? note;
  final String? performedBy;
  final DateTime createdAt;

  const OrderTimelineEvent({
    required this.id,
    required this.orderId,
    required this.status,
    this.note,
    this.performedBy,
    required this.createdAt,
  });

  factory OrderTimelineEvent.fromJson(Map<String, dynamic> json) {
    return OrderTimelineEvent(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      status: json['status'] ?? '',
      note: json['note'],
      performedBy: json['performed_by'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Order Tracking Service
class OrderTrackingService {
  static final OrderTrackingService _instance = OrderTrackingService._internal();
  factory OrderTrackingService() => _instance;
  OrderTrackingService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _orderChannel;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Stream of orders for current user — uses customer_id per schema
  Stream<List<Order>> get userOrdersStream {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Order.fromJson(json)).toList());
  }

  /// Stream of active orders for current user
  Stream<List<Order>> get activeOrdersStream {
    return userOrdersStream.map(
          (orders) => orders.where((o) => o.isActive).toList(),
    );
  }

  /// Stream of order history (completed/cancelled)
  Stream<List<Order>> get orderHistoryStream {
    return userOrdersStream.map(
          (orders) => orders.where((o) => !o.isActive).toList(),
    );
  }

  /// Get a single order by ID
  Future<Order?> getOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, items:order_items(*)')
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching order: $e');
      return null;
    }
  }

  /// Subscribe to real-time updates for a specific order
  void subscribeToOrder(
      String orderId,
      Function(Order) onUpdate,
      ) {
    _orderChannel?.unsubscribe();

    _orderChannel = _supabase
        .channel('order_$orderId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: orderId,
      ),
      callback: (payload) {
        final order = Order.fromJson(payload.newRecord);
        onUpdate(order);
      },
    )
        .subscribe();
  }

  /// Unsubscribe from order updates
  void unsubscribeFromOrder() {
    _orderChannel?.unsubscribe();
    _orderChannel = null;
  }

  /// Get order timeline/history
  Future<List<OrderTimelineEvent>> getOrderTimeline(String orderId) async {
    try {
      final response = await _supabase
          .from('order_timeline')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((json) => OrderTimelineEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching order timeline: $e');
      return [];
    }
  }

  /// Request order cancellation (before preparation starts)
  Future<bool> requestCancellation(String orderId, {String? reason}) async {
    try {
      final order = await getOrder(orderId);
      if (order == null || !order.canCancel) {
        return false;
      }

      await _supabase.from('orders').update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Add timeline event
      await _supabase.from('order_timeline').insert({
        'order_id': orderId,
        'status': 'cancelled',
        'note': reason ?? 'Cancelled by customer',
        'performed_by': _currentUserId,
      });

      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  /// Re-order from a previous order
  Future<String?> reorder(String orderId) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) return null;

      final userId = _currentUserId;
      if (userId == null) return null;

      // Create new order with same items — uses customer_id per schema
      final newOrderData = <String, Object>{
        'customer_id': userId,
        'status': 'placed',
        'payment_status': 'pending',
        'total_amount': order.totalAmount,
        'metadata': <String, Object>{
          'reordered_from': orderId,
          'reordered_at': DateTime.now().toIso8601String(),
        },
      };

      if (order.establishmentId != null) {
        newOrderData['establishment_id'] = order.establishmentId!;
      }
      if (order.tableId != null) {
        newOrderData['table_id'] = order.tableId!;
      }
      if (order.tableNumber != null) {
        newOrderData['table_number'] = order.tableNumber!;
      }
      if (order.specialInstructions != null) {
        newOrderData['special_instructions'] = order.specialInstructions!;
      }

      final newOrderResponse = await _supabase
          .from('orders')
          .insert(newOrderData)
          .select()
          .single();

      final newOrderId = newOrderResponse['id'] as String;

      // Copy order items
      for (final item in order.items) {
        final itemData = <String, Object>{
          'order_id': newOrderId,
          'menu_item_id': item.menuItemId,
          'name': item.name,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.totalPrice,
        };

        if (item.specialInstructions != null) {
          itemData['special_instructions'] = item.specialInstructions!;
        }

        await _supabase.from('order_items').insert(itemData);
      }

      return newOrderId;
    } catch (e) {
      debugPrint('Error reordering: $e');
      return null;
    }
  }

  /// Get ETA for an order based on kitchen queue
  Future<Duration?> getEstimatedWaitTime(String orderId) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) return null;

      final aheadCount = await _supabase
          .from('orders')
          .select('id')
          .eq('establishment_id', order.establishmentId!)
          .inFilter('status', ['placed', 'confirmed', 'preparing'])
          .lt('created_at', order.createdAt.toIso8601String())
          .count();

      final minutes = (aheadCount.count ?? 0) * 5 + 10;
      return Duration(minutes: minutes);
    } catch (e) {
      debugPrint('Error calculating ETA: $e');
      return const Duration(minutes: 15);
    }
  }

  /// Dispose resources
  void dispose() {
    unsubscribeFromOrder();
  }
}