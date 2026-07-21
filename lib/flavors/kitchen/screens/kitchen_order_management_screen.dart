import 'package:dinetrack_2_1/core/services/notification_service.dart';
import 'package:dinetrack_2_1/shared/widgets/notification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/models/user_models.dart';

/// Kitchen Order Management Screen
/// Real-time order queue with status updates, prep timers, and completion tracking
class KitchenOrderManagementScreen extends StatefulWidget {
  const KitchenOrderManagementScreen({super.key});

  @override
  State<KitchenOrderManagementScreen> createState() => _KitchenOrderManagementScreenState();
}

class _KitchenOrderManagementScreenState extends State<KitchenOrderManagementScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<KitchenOrder> _pendingOrders = [];
  List<KitchenOrder> _preparingOrders = [];
  List<KitchenOrder> _readyOrders = [];
  bool _isLoading = true;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
    _subscribeToOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      // FIXED: Schema-aligned query — customer_id (not user_id), no table_number on orders
      final response = await _supabase
          .from('orders')
          .select('*, items:order_items(*), table:tables(table_number, label)')
          .inFilter('status', ['confirmed', 'preparing', 'ready'])
          .order('created_at', ascending: true);

      final orders = (response as List<dynamic>)
          .map((json) => KitchenOrder.fromJson(json))
          .toList();

      setState(() {
        _pendingOrders = orders.where((o) => o.status == 'confirmed').toList();
        _preparingOrders = orders.where((o) => o.status == 'preparing').toList();
        _readyOrders = orders.where((o) => o.status == 'ready').toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToOrders() {
    _ordersChannel = _supabase
        .channel('kitchen_orders')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.inFilter,
        column: 'status',
        value: ['confirmed', 'preparing', 'ready'],
      ),
      callback: (payload) {
        _loadOrders();
      },
    )
        .subscribe();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, {String? note}) async {
    try {
      // FIXED: Schema-aligned update — no ready_at (not in schema)
      await _supabase.from('orders').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Add timeline event — FIXED: use notifications table (no order_timeline in schema)
      await _supabase.from('notifications').insert({
        'user_id': _supabase.auth.currentUser?.id,
        'title': 'Order $newStatus',
        'body': note ?? 'Order status updated to $newStatus',
        'type': 'order',
        'data': {
          'order_id': orderId,
          'status': newStatus,
          'performed_by': _supabase.auth.currentUser?.id,
        },
      });

      // Notify customer — FIXED: customer_id (not user_id)
      final order = await _supabase
          .from('orders')
          .select('customer_id, table:tables(table_number)')
          .eq('id', orderId)
          .single();

      if (order != null && order['customer_id'] != null) {
        String title, body;
        switch (newStatus) {
          case 'preparing':
            title = 'Order Confirmed';
            body = 'Your order is now being prepared!';
            break;
          case 'ready':
            title = 'Order Ready!';
            body = 'Your order is ready for pickup!';
            break;
          default:
            title = 'Order Update';
            body = 'Your order status has been updated.';
        }

        await _supabase.from('notifications').insert({
          'user_id': order['customer_id'],  // FIXED: customer_id
          'title': title,
          'body': body,
          'type': 'order',
          'priority': newStatus == 'ready' ? 'high' : 'normal',
          'data': {'order_id': orderId, 'status': newStatus},
        });
      }

      _loadOrders();

      if (mounted) {
        _showSnackBar('Status Updated: Order moved to ${newStatus.toUpperCase()}');
      }
    } catch (e) {
      debugPrint('Error updating order: $e');
      if (mounted) {
        _showSnackBar('Error: Failed to update order status');
      }
    }
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
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kitchen Orders',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            Text(
              'Manage incoming orders in real-time',
              style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF667eea),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            _buildTab('New', _pendingOrders.length, Colors.orange),
            _buildTab('Preparing', _preparingOrders.length, const Color(0xFF667eea)),
            _buildTab('Ready', _readyOrders.length, Colors.green),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const _LoadingSkeleton()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(_pendingOrders, 'confirmed'),
          _buildOrderList(_preparingOrders, 'preparing'),
          _buildOrderList(_readyOrders, 'ready'),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderList(List<KitchenOrder> orders, String currentStatus) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              currentStatus == 'confirmed' ? Icons.receipt_long_outlined :
              currentStatus == 'preparing' ? Icons.restaurant_outlined :
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              currentStatus == 'confirmed' ? 'No new orders' :
              currentStatus == 'preparing' ? 'Nothing being prepared' :
              'No orders ready',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'Orders will appear here automatically',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index], currentStatus),
    );
  }

  Widget _buildOrderCard(KitchenOrder order, String currentStatus) {
    final isUrgent = order.isUrgent;
    final elapsed = order.elapsedTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: isUrgent
            ? Border.all(color: Colors.red.shade300, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red.shade50 : const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUrgent
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '#${order.tableNumber ?? "?"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #${order.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (isUrgent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'URGENT',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.itemCount} items • ${elapsed.inMinutes}m ago',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(currentStatus),
              ],
            ),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: order.items.map((item) => _buildItemRow(item)).toList(),
            ),
          ),
          // Special instructions
          if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.specialInstructions!,
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (currentStatus == 'confirmed')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateOrderStatus(order.id, 'preparing'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Preparing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                if (currentStatus == 'preparing') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(order.id),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateOrderStatus(order.id, 'ready'),
                      icon: const Icon(Icons.check),
                      label: const Text('Mark Ready'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
                if (currentStatus == 'ready')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateOrderStatus(order.id, 'served'),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark Served'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF11998e),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${item.quantity}x',
                style: const TextStyle(
                  color: Color(0xFF667eea),
                  fontWeight: FontWeight.w700,
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
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                if (item.specialInstructions != null)
                  Text(
                    item.specialInstructions!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'MWK ${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF667eea),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final colors = {
      'confirmed': Colors.orange,
      'preparing': const Color(0xFF667eea),
      'ready': Colors.green,
    };
    final labels = {
      'confirmed': 'NEW',
      'preparing': 'PREPARING',
      'ready': 'READY',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors[status]?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labels[status] ?? status.toUpperCase(),
        style: TextStyle(
          color: colors[status],
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _showCancelDialog(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order? The customer will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateOrderStatus(orderId, 'cancelled', note: 'Cancelled by kitchen staff');
    }
  }
}

// ─── Models (Schema-Aligned) ─────────────────────────────────────────────────

class KitchenOrder {
  final String id;
  final String? customerId;    // FIXED: was userId, matches schema
  final int? tableNumber;      // From joined tables table
  final String status;
  final List<OrderItem> items;
  final String? specialInstructions;
  final DateTime createdAt;
  final double totalAmount;

  const KitchenOrder({
    required this.id,
    this.customerId,
    this.tableNumber,
    required this.status,
    required this.items,
    this.specialInstructions,
    required this.createdAt,
    required this.totalAmount,
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    return KitchenOrder(
      id: json['id'] ?? '',
      customerId: json['customer_id'],  // FIXED: was user_id
      tableNumber: json['table']?['table_number'] ?? json['table']?['number'],  // FIXED: schema column name
      status: json['status'] ?? 'confirmed',
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e))
          .toList() ??
          [],
      specialInstructions: json['special_instructions'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  Duration get elapsedTime => DateTime.now().difference(createdAt);
  bool get isUrgent => elapsedTime.inMinutes > 20 && status == 'confirmed';
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? specialInstructions;

  const OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.specialInstructions,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',  // FIXED: schema doesn't have name on order_items
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['line_total'] ?? 0).toDouble(),  // FIXED: was total_price
      specialInstructions: json['special_instructions'],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(3, (_) => Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
      )),
    );
  }
}