import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/order_models.dart';
import '../../../core/models/user_models.dart';

/// ============================================================================
/// KITCHEN DISPLAY SYSTEM (KDS)
/// ============================================================================
///
/// A full-featured Kitchen Display System for restaurant kitchen staff with:
/// - Grid layout of order cards optimized for kitchen environment
/// - Color coding: Yellow = confirmed (not started), Blue = preparing
/// - Sound notifications on new orders (toggleable)
/// - Real-time Supabase subscriptions for instant updates
/// - Order status progression: confirmed -> preparing -> ready
/// - Special instructions highlighted in warning box
/// - Order detail modal with full item breakdown
/// - Staff profile display
/// - Pull-to-refresh
///
/// Code Compatibility: UserProfile lives ONLY in user_models.dart
/// ============================================================================

class HomeKitchen extends StatefulWidget {
  const HomeKitchen({super.key});

  @override
  State<HomeKitchen> createState() => _HomeKitchenState();
}

class _HomeKitchenState extends State<HomeKitchen>
    with SingleTickerProviderStateMixin {

  // --- Services ---
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- State ---
  String? _establishmentId;
  UserProfile? _currentUser;
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _soundEnabled = true;
  bool _isSubscribed = false;

  // --- Filter ---
  String _statusFilter = 'all'; // 'all', 'confirmed', 'preparing'

  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // --- Date formatter ---
  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    _unsubscribeFromRealtime();
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _initialize() async {
    try {
      _currentUser = await _auth.getCurrentUserProfile();
      _establishmentId = await _supabase.getOperatorEstablishmentId();

      if (_establishmentId == null) {
        setState(() => _isLoading = false);
        return;
      }

      await _loadOrders();
      _subscribeToRealtimeUpdates();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Initialization failed: $e');
    }
  }

  // --- Real-time Subscriptions ---
  void _subscribeToRealtimeUpdates() {
    if (_establishmentId == null || _isSubscribed) return;

    try {
      _supabase.client
          .channel('kitchen_orders_${_establishmentId}')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'establishment_id',
          value: _establishmentId!,
        ),
        callback: (payload) {
          _handleRealtimeUpdate(payload);
        },
      )
          .subscribe();

      setState(() => _isSubscribed = true);
    } catch (e) {
      debugPrint('Realtime subscription error: $e');
    }
  }

  void _unsubscribeFromRealtime() {
    if (_establishmentId == null) return;
    try {
      _supabase.client
          .channel('kitchen_orders_${_establishmentId}')
          .unsubscribe();
    } catch (e) {
      debugPrint('Unsubscribe error: $e');
    }
  }

  void _handleRealtimeUpdate(dynamic payload) {
    if (!mounted) return;

    // Check if it's a new order
    final eventType = payload.eventType;
    if (eventType == PostgresChangeEvent.insert) {
      if (_soundEnabled) {
        _playNotificationSound();
      }
      _showNewOrderSnackBar();
    }

    _loadOrders();
  }

  // --- Sound Notifications ---
  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/waiter_call.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _showNewOrderSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white),
            SizedBox(width: 8),
            Text('New order received!'),
          ],
        ),
        backgroundColor: Color(0xFF4F46E5),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    );
  }

  // --- Data Loading ---
  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final allOrders = await _supabase.getEstablishmentOrders(_establishmentId!);
      // Kitchen only sees confirmed and preparing orders
      setState(() {
        _orders = allOrders.where((o) {
          return o.status == 'confirmed' || o.status == 'preparing';
        }).toList();
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading orders: $e');
    }
  }

  Future<void> _refreshOrders() async {
    setState(() => _isRefreshing = true);
    await _loadOrders();
    setState(() => _isRefreshing = false);
    _showSnackBar('Orders refreshed');
  }

  void _applyFilter() {
    _filteredOrders = _statusFilter == 'all'
        ? _orders
        : _orders.where((o) => o.status == _statusFilter).toList();
  }

  void _setStatusFilter(String status) {
    setState(() {
      _statusFilter = status;
      _applyFilter();
    });
  }

  // --- Actions ---
  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      await _supabase.updateOrderStatus(orderId, status);
      _showSnackBar('Order marked as ${status.toUpperCase()}');
      await _loadOrders();
    } catch (e) {
      _showError('Failed to update: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _unsubscribeFromRealtime();
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // --- UI Helpers ---
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
              SizedBox(height: 16),
              Text('Loading kitchen orders...', style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        )
            : _orders.isEmpty
            ? _buildEmptyState()
            : _buildOrdersView(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kitchen Display',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_currentUser != null)
            Text(
              'Chef: ${_currentUser!.displayName}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
      actions: [
        if (_isSubscribed)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        IconButton(
          onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
          tooltip: _soundEnabled ? 'Sound On' : 'Sound Off',
        ),
        IconButton(
          onPressed: _isRefreshing ? null : _refreshOrders,
          icon: _isRefreshing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _KitchenFilterChip(
                  label: 'All (${_orders.length})',
                  isSelected: _statusFilter == 'all',
                  onTap: () => _setStatusFilter('all'),
                ),
                const SizedBox(width: 8),
                _KitchenFilterChip(
                  label: 'New (${_orders.where((o) => o.status == 'confirmed').length})',
                  isSelected: _statusFilter == 'confirmed',
                  onTap: () => _setStatusFilter('confirmed'),
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                _KitchenFilterChip(
                  label: 'Preparing (${_orders.where((o) => o.status == 'preparing').length})',
                  isSelected: _statusFilter == 'preparing',
                  onTap: () => _setStatusFilter('preparing'),
                  color: const Color(0xFF4F46E5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu, size: 80, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          const Text(
            'No orders to prepare',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for new orders...',
            style: TextStyle(color: const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersView() {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.82,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          return _KitchenOrderCard(
            order: order,
            onMarkReady: () => _updateOrderStatus(order.id, 'ready'),
            onStartPreparing: order.status == 'confirmed'
                ? () => _updateOrderStatus(order.id, 'preparing')
                : null,
            onTap: () => _showOrderDetails(order),
          );
        },
      ),
    );
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order.orderNumber ?? order.id.substring(0, 6)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    _KitchenStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Received at ${_timeFormat.format(order.createdAt ?? DateTime.now())}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const Divider(height: 32),
                const Text(
                  'Items to Prepare',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...order.items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                  title: Text(
                    item.menuItem?.name ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: item.menuItem?.description != null
                      ? Text(item.menuItem!.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
                      : null,
                )),
                const Divider(height: 32),
                if (order.specialInstructions != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Special Instructions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.specialInstructions!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (order.status == 'confirmed')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(order.id, 'preparing');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('START PREPARING'),
                    ),
                  )
                else if (order.status == 'preparing')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(order.id, 'ready');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('MARK AS READY'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// WIDGET COMPONENTS
// =============================================================================

class _KitchenFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _KitchenFilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = color ?? const Color(0xFF4F46E5);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _KitchenStatusBadge extends StatelessWidget {
  final String status;

  const _KitchenStatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'confirmed': return const Color(0xFFF59E0B);
      case 'preparing': return const Color(0xFF4F46E5);
      case 'ready': return const Color(0xFF10B981);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _KitchenOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onMarkReady;
  final VoidCallback? onStartPreparing;
  final VoidCallback onTap;

  const _KitchenOrderCard({
    required this.order,
    required this.onMarkReady,
    this.onStartPreparing,
    required this.onTap,
  });

  Color get _cardColor {
    switch (order.status) {
      case 'confirmed': return const Color(0xFFFEF3C7);
      case 'preparing': return const Color(0xFFDBEAFE);
      default: return Colors.grey.shade100;
    }
  }

  Color get _statusColor {
    switch (order.status) {
      case 'confirmed': return const Color(0xFFF59E0B);
      case 'preparing': return const Color(0xFF4F46E5);
      default: return Colors.grey;
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = order.status == 'confirmed';

    return Card(
      color: _cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${order.orderNumber ?? order.id.substring(0, 6)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),
              Text(
                'Received: ${_formatTime(order.createdAt?.toIso8601String())}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 12),

              // Items
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  itemBuilder: (context, i) {
                    final item = order.items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.menuItem?.name ?? 'Unknown',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Special instructions
              if (order.specialInstructions != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.specialInstructions!,
                          style: const TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Actions
              if (isConfirmed && onStartPreparing != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onStartPreparing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('START PREPARING'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onMarkReady,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('MARK READY'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}