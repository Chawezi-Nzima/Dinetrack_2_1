import 'package:dinetrack_2_1/core/services/notification_service.dart';
import 'package:dinetrack_2_1/core/services/order_tracking_service.dart';
import 'package:dinetrack_2_1/shared/widgets/notification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Order Tracking Screen with real-time updates
class OrderTrackingScreen extends StatefulWidget {
  final String? orderId;
  final Order? initialOrder;

  const OrderTrackingScreen({
    super.key,
    this.orderId,
    this.initialOrder,
  }) : assert(orderId != null || initialOrder != null);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  final OrderTrackingService _trackingService = OrderTrackingService();
  Order? _order;
  List<OrderTimelineEvent> _timeline = [];
  bool _isLoading = true;
  bool _isCancelling = false;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);

    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
    } else if (widget.orderId != null) {
      _order = await _trackingService.getOrder(widget.orderId!);
    }

    if (_order != null) {
      _timeline = await _trackingService.getOrderTimeline(_order!.id);
      _trackingService.subscribeToOrder(_order!.id, (updatedOrder) {
        if (mounted) {
          setState(() {
            _order = updatedOrder;
            _progressController.animateTo(updatedOrder.progress);
          });
          _loadTimeline();
        }
      });
      _progressController.value = _order!.progress;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadTimeline() async {
    if (_order == null) return;
    final timeline = await _trackingService.getOrderTimeline(_order!.id);
    if (mounted) setState(() => _timeline = timeline);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _trackingService.unsubscribeFromOrder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_order != null && _order!.isActive)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrder,
            ),
        ],
      ),
      body: _isLoading
          ? const _LoadingSkeleton()
          : _order == null
          ? const _EmptyState()
          : RefreshIndicator(
        onRefresh: _loadOrder,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildProgressTracker()),
            SliverToBoxAdapter(child: _buildOrderDetails()),
            SliverToBoxAdapter(child: _buildItemsList()),
            SliverToBoxAdapter(child: _buildTimeline()),
            if (_order!.canCancel)
              SliverToBoxAdapter(child: _buildCancelButton()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getStatusColors(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColors()[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Order #${_order!.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              _buildPaymentBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _order!.statusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_order!.estimatedReadyTime != null && _order!.isActive)
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Est. ready: ${_formatTime(_order!.estimatedReadyTime!)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            'Placed on ${DateFormat('MMM d, yyyy • h:mm a').format(_order!.createdAt)}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge() {
    Color color;
    IconData icon;
    switch (_order!.paymentStatus) {
      case PaymentStatus.paid:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case PaymentStatus.failed:
        color = Colors.red;
        icon = Icons.error;
        break;
      case PaymentStatus.refunded:
        color = Colors.orange;
        icon = Icons.replay;
        break;
      default:
        color = Colors.amber;
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            _order!.paymentStatusLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Color> _getStatusColors() {
    switch (_order!.status) {
      case OrderStatus.placed:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case OrderStatus.confirmed:
        return [const Color(0xFF11998e), const Color(0xFF38ef7d)];
      case OrderStatus.preparing:
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      case OrderStatus.ready:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case OrderStatus.served:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
      case OrderStatus.completed:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case OrderStatus.cancelled:
        return [const Color(0xFFff6b6b), const Color(0xFFee5a5a)];
    }
  }

  Widget _buildProgressTracker() {
    final steps = [
      _Step('Placed', OrderStatus.placed, Icons.receipt_long),
      _Step('Confirmed', OrderStatus.confirmed, Icons.thumb_up),
      _Step('Preparing', OrderStatus.preparing, Icons.restaurant),
      _Step('Ready', OrderStatus.ready, Icons.delivery_dining),
      _Step('Served', OrderStatus.served, Icons.check_circle),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 90,
            child: Row(
              children: List.generate(steps.length * 2 - 1, (index) {
                if (index.isOdd) {
                  final stepIndex = index ~/ 2;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _order!.status.index >= steps[stepIndex + 1].status.index
                            ? _getStatusColors()[0]
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }
                final step = steps[index ~/ 2];
                final isActive = _order!.status.index >= step.status.index;
                final isCurrent = _order!.status == step.status;

                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: isCurrent ? 48 : 40,
                      height: isCurrent ? 48 : 40,
                      decoration: BoxDecoration(
                        color: isActive ? _getStatusColors()[0] : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: _getStatusColors()[0], width: 3)
                            : null,
                        boxShadow: isCurrent
                            ? [
                          BoxShadow(
                            color: _getStatusColors()[0].withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                            : null,
                      ),
                      child: Icon(
                        step.icon,
                        color: isActive ? Colors.white : Colors.grey.shade400,
                        size: isCurrent ? 22 : 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? Colors.black87 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          if (_order!.status == OrderStatus.preparing)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressController.value,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(_getStatusColors()[0]),
                  minHeight: 6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Table', 'Table ${_order!.tableNumber ?? "N/A"}'),
          _buildDetailRow('Items', '${_order!.items.length} items'),
          _buildDetailRow('Subtotal', 'MWK ${_order!.totalAmount.toStringAsFixed(2)}'),
          if (_order!.taxAmount != null)
            _buildDetailRow('Tax', 'MWK ${_order!.taxAmount!.toStringAsFixed(2)}'),
          if (_order!.tipAmount != null)
            _buildDetailRow('Tip', 'MWK ${_order!.tipAmount!.toStringAsFixed(2)}'),
          const Divider(height: 24),
          _buildDetailRow(
            'Total',
            'MWK ${_order!.totalAmount.toStringAsFixed(2)}',
            isBold: true,
            valueColor: const Color(0xFF667eea),
          ),
          if (_order!.paymentReference != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Ref: ${_order!.paymentReference}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items Ordered',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ..._order!.items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.restaurant, color: Color(0xFF667eea)),
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
                const SizedBox(height: 4),
                Text(
                  'MWK ${item.unitPrice.toStringAsFixed(2)} x ${item.quantity}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'MWK ${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF667eea),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_timeline.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...List.generate(_timeline.length, (index) {
            final event = _timeline[index];
            final isLast = index == _timeline.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 50,
                        color: Colors.grey.shade200,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.status.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (event.note != null)
                        Text(
                          event.note!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, h:mm a').format(event.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _isCancelling ? null : _showCancelDialog,
        icon: _isCancelling
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.cancel_outlined),
        label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Order'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade700,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.red.shade200),
          ),
        ),
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to cancel this order? This action cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
          ],
        ),
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

    if (confirmed == true && _order != null) {
      setState(() => _isCancelling = true);
      final success = await _trackingService.requestCancellation(
        _order!.id,
        reason: reasonController.text.isNotEmpty ? reasonController.text : null,
      );
      setState(() => _isCancelling = false);

      if (success && mounted) {
        _showSnackBar('Order Cancelled: Your order has been cancelled successfully.');
      } else if (mounted) {
        _showSnackBar('Cannot Cancel: This order can no longer be cancelled.');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.inMinutes < 1) return 'Any moment now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    return DateFormat('h:mm a').format(time);
  }
}

// ─── Supporting Widgets ─────────────────────────────────────

class _Step {
  final String label;
  final OrderStatus status;
  final IconData icon;
  _Step(this.label, this.status, this.icon);
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Order not found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "The order you're looking for doesn't exist or has been removed.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}