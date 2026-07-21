import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/order_models.dart';
import '../../../core/models/user_models.dart';
import '../../../core/models/establishment_models.dart' as models;

/// ============================================================================
/// COMPREHENSIVE OPERATOR DASHBOARD
/// ============================================================================
///
/// A full-featured operator dashboard for restaurant staff with:
/// - Orders management (pending -> confirmed -> preparing -> ready -> served)
/// - Table management (toggle availability, view occupancy)
/// - Assist requests (real-time customer assistance alerts)
/// - Analytics overview (daily stats, revenue, order counts)
/// - Real-time subscriptions for live updates
/// - Search & filter functionality
/// - Staff profile & settings
///
/// Schema Consistency Notes:
/// - assist_requests: id, establishment_id, table_id, status, created_at
///   (NO request_type column - all requests are generic assistance)
/// - tables: is_available, occupied_at, last_activity_at, capacity
/// - orders: order_number (bigint), status (enum), updated_at
/// - users: full_name (not displayName)
/// - menu_items: has deleted_at (soft delete)
/// - staff_assignments: role enum for operator verification
/// ============================================================================

class OperatorHomePage extends StatefulWidget {
  const OperatorHomePage({super.key});

  @override
  State<OperatorHomePage> createState() => _OperatorHomePageState();
}

class _OperatorHomePageState extends State<OperatorHomePage>
    with SingleTickerProviderStateMixin {

  // --- Services ---
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  // --- State ---
  String? _establishmentId;
  UserProfile? _currentUser;
  String? _staffRole;
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  List<Map<String, dynamic>> _assistRequests = [];
  List<models.TableModel> _tables = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _selectedIndex = 0;

  // --- Search & Filter ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // --- Stats ---
  int _todayOrderCount = 0;
  double _todayRevenue = 0.0;
  int _pendingOrdersCount = 0;
  int _activeTablesCount = 0;
  int _completedTodayCount = 0;

  // --- Real-time ---
  bool _isSubscribed = false;

  // --- Date formatters ---
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

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
    _searchController.addListener(_onSearchChanged);
    _initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _unsubscribeFromRealtime();
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _initialize() async {
    try {
      _currentUser = await _auth.getCurrentUserProfile();

      if (_currentUser == null) {
        setState(() => _isLoading = false);
        _showError('User not authenticated. Please login again.');
        return;
      }

      // Verify staff assignment and role per schema: staff_assignments table
      final staffInfo = await _supabase.getStaffAssignment(_currentUser!.id);
      if (staffInfo == null) {
        setState(() => _isLoading = false);
        _showError('No staff assignment found. Contact admin.');
        return;
      }

      _staffRole = staffInfo['role'] as String?;
      _establishmentId = staffInfo['establishment_id'] as String?;

      if (_establishmentId == null) {
        setState(() => _isLoading = false);
        _showError('No establishment assigned. Contact admin.');
        return;
      }

      await _loadAllData();
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
      // Subscribe to orders table changes
      _supabase.client
          .channel('operator_orders_${_establishmentId}')
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
          _handleRealtimeUpdate('order', payload);
        },
      )
          .subscribe();

      // Subscribe to assist requests
      _supabase.client
          .channel('operator_assist_${_establishmentId}')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'assist_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'establishment_id',
          value: _establishmentId!,
        ),
        callback: (payload) {
          _handleRealtimeUpdate('assist', payload);
        },
      )
          .subscribe();

      // Subscribe to table changes
      _supabase.client
          .channel('operator_tables_${_establishmentId}')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tables',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'establishment_id',
          value: _establishmentId!,
        ),
        callback: (payload) {
          _handleRealtimeUpdate('table', payload);
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
          .channel('operator_orders_${_establishmentId}')
          .unsubscribe();
      _supabase.client
          .channel('operator_assist_${_establishmentId}')
          .unsubscribe();
      _supabase.client
          .channel('operator_tables_${_establishmentId}')
          .unsubscribe();
    } catch (e) {
      debugPrint('Unsubscribe error: $e');
    }
  }

  void _handleRealtimeUpdate(String type, dynamic payload) {
    if (!mounted) return;

    String message;
    switch (type) {
      case 'order':
        message = 'Order updated';
        _loadOrders();
        _loadStats();
        break;
      case 'assist':
        message = 'New assist request';
        _loadAssistRequests();
        break;
      case 'table':
        message = 'Table status changed';
        _loadTables();
        break;
      default:
        message = 'Update received';
    }

    _showSnackBar(message, duration: const Duration(seconds: 2));
  }

  // --- Data Loading ---
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadOrders(),
      _loadAssistRequests(),
      _loadTables(),
      _loadStats(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadAllData();
    setState(() => _isRefreshing = false);
    _showSnackBar('Data refreshed');
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _supabase.getEstablishmentOrders(_establishmentId!);
      setState(() {
        _orders = orders;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }
  }

  Future<void> _loadAssistRequests() async {
    try {
      // Per schema: assist_requests has id, establishment_id, table_id, status, created_at
      // Join with tables to get table_number for display
      final response = await _supabase.client
          .from('assist_requests')
          .select('id, table_id, status, created_at, tables(table_number)')
          .eq('establishment_id', _establishmentId!)
          .eq('status', 'open')
          .order('created_at', ascending: false);

      setState(() => _assistRequests = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading assist requests: $e');
    }
  }

  Future<void> _loadTables() async {
    try {
      final tables = await _supabase.getTables(_establishmentId!);
      setState(() => _tables = tables);
    } catch (e) {
      debugPrint('Error loading tables: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _supabase.getEstablishmentStats(_establishmentId!);
      setState(() {
        _todayOrderCount = stats['today_orders'] ?? 0;
        _todayRevenue = (stats['today_revenue'] ?? 0.0).toDouble();
        _pendingOrdersCount = stats['pending_orders'] ?? 0;
        _activeTablesCount = stats['active_tables'] ?? 0;
        _completedTodayCount = stats['completed_today'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  // --- Search & Filter ---
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredOrders = _orders.where((order) {
      final searchMatch = _searchQuery.isEmpty ||
          order.orderNumber?.toString().toLowerCase().contains(_searchQuery) == true ||
          order.items.any((item) =>
          item.menuItem?.name.toLowerCase().contains(_searchQuery) == true);

      final statusMatch = _statusFilter == 'all' || order.status == _statusFilter;

      return searchMatch && statusMatch;
    }).toList();
  }

  void _setStatusFilter(String status) {
    setState(() {
      _statusFilter = status;
      _applyFilters();
    });
  }

  // --- Actions ---
  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      // Update both status and updated_at per schema
      await _supabase.client
          .from('orders')
          .update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', orderId);

      _showSnackBar('Order updated to ${status.toUpperCase()}');
      await _loadOrders();
      await _loadStats();
    } catch (e) {
      _showError('Failed to update order: $e');
    }
  }

  Future<void> _resolveAssistRequest(String requestId) async {
    try {
      // Per schema: assist_requests has status column
      await _supabase.client
          .from('assist_requests')
          .update({'status': 'resolved'})
          .eq('id', requestId);

      _showSnackBar('Assist request resolved');
      await _loadAssistRequests();
    } catch (e) {
      _showError('Failed to resolve request: $e');
    }
  }

  Future<void> _toggleTableAvailability(String tableId, bool currentlyAvailable) async {
    try {
      final now = DateTime.now().toIso8601String();
      final updates = <String, dynamic>{
        'is_available': !currentlyAvailable,
        'last_activity_at': now,
      };

      // Per schema: occupied_at tracks when table became occupied
      if (currentlyAvailable) {
        // Table is becoming occupied
        updates['occupied_at'] = now;
      } else {
        // Table is becoming available - clear occupied_at
        updates['occupied_at'] = null;
      }

      await _supabase.client
          .from('tables')
          .update(updates)
          .eq('id', tableId);

      await _loadTables();
      await _loadStats();
    } catch (e) {
      _showError('Failed to update table: $e');
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

  // --- Status Helpers ---
  static String _nextStatus(String current) {
    switch (current) {
      case 'pending': return 'confirmed';
      case 'confirmed': return 'preparing';
      case 'preparing': return 'ready';
      case 'ready': return 'served';
      default: return 'completed';
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'preparing': return 'Preparing';
      case 'ready': return 'Ready';
      case 'served': return 'Served';
      default: return status;
    }
  }

  // --- UI Helpers ---
  void _showSnackBar(String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {},
        ),
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
              SizedBox(height: 16),
              Text('Loading dashboard...', style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
      );
    }

    if (_establishmentId == null) {
      return _buildNoEstablishmentView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboardView(),
            _buildOrdersView(),
            _buildTablesView(),
            _buildAssistView(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
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
            'Operator Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_currentUser != null)
          // Per schema: users table has full_name, not displayName
            Text(
              'Welcome, ${_currentUser!.fullName ?? _currentUser!.email}',
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
          onPressed: _isRefreshing ? null : _refreshData,
          icon: _isRefreshing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }

  Widget _buildNoEstablishmentView() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined, size: 80, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 24),
            const Text(
              'No Establishment Assigned',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact your administrator to get assigned to an establishment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // DASHBOARD VIEW
  // =============================================================================
  Widget _buildDashboardView() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentOrdersSection(),
            const SizedBox(height: 24),
            _buildTableStatusOverview(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      _StatData(
        title: 'Today\'s Orders',
        value: '$_todayOrderCount',
        subtitle: '$_completedTodayCount completed',
        icon: Icons.receipt_long,
        color: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
      ),
      _StatData(
        title: 'Revenue',
        value: 'MWK ${_todayRevenue.toStringAsFixed(0)}',
        subtitle: 'Today\'s total',
        icon: Icons.payments,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFD1FAE5),
      ),
      _StatData(
        title: 'Pending',
        value: '$_pendingOrdersCount',
        subtitle: 'Need attention',
        icon: Icons.pending_actions,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
      ),
      _StatData(
        title: 'Active Tables',
        value: '$_activeTablesCount',
        subtitle: 'Currently occupied',
        icon: Icons.table_restaurant,
        color: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFEE2E2),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _StatCard(data: stats[index]),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.receipt,
                label: 'View Orders',
                color: const Color(0xFF4F46E5),
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.table_restaurant,
                label: 'Manage Tables',
                color: const Color(0xFF10B981),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.notifications,
                label: 'Assist',
                color: const Color(0xFFF59E0B),
                badgeCount: _assistRequests.length,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentOrdersSection() {
    final recentOrders = _orders.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 1),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentOrders.isEmpty)
          _buildEmptyState('No orders yet', Icons.receipt_long)
        else
          ...recentOrders.map((order) => _OrderListTile(
            order: order,
            onTap: () => _showOrderDetails(order),
          )),
      ],
    );
  }

  Widget _buildTableStatusOverview() {
    final availableCount = _tables.where((t) => t.isAvailable).length;
    final occupiedCount = _tables.where((t) => !t.isAvailable).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Table Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 2),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatusPill(
                label: 'Available',
                count: availableCount,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusPill(
                label: 'Occupied',
                count: occupiedCount,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =============================================================================
  // ORDERS VIEW
  // =============================================================================
  Widget _buildOrdersView() {
    return Column(
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search orders...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _statusFilter == 'all',
                      onTap: () => _setStatusFilter('all'),
                    ),
                    _FilterChip(
                      label: 'Pending',
                      isSelected: _statusFilter == 'pending',
                      onTap: () => _setStatusFilter('pending'),
                      color: Colors.orange,
                    ),
                    _FilterChip(
                      label: 'Confirmed',
                      isSelected: _statusFilter == 'confirmed',
                      onTap: () => _setStatusFilter('confirmed'),
                      color: Colors.blue,
                    ),
                    _FilterChip(
                      label: 'Preparing',
                      isSelected: _statusFilter == 'preparing',
                      onTap: () => _setStatusFilter('preparing'),
                      color: Colors.indigo,
                    ),
                    _FilterChip(
                      label: 'Ready',
                      isSelected: _statusFilter == 'ready',
                      onTap: () => _setStatusFilter('ready'),
                      color: Colors.green,
                    ),
                    _FilterChip(
                      label: 'Served',
                      isSelected: _statusFilter == 'served',
                      onTap: () => _setStatusFilter('served'),
                      color: Colors.teal,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Orders List
        Expanded(
          child: _filteredOrders.isEmpty
              ? _buildEmptyState(
            _searchQuery.isNotEmpty || _statusFilter != 'all'
                ? 'No orders match your filters'
                : 'No active orders',
            Icons.receipt_long,
          )
              : RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return _OrderCard(
                  order: order,
                  onStatusUpdate: (status) => _updateOrderStatus(order.id, status),
                  onTap: () => _showOrderDetails(order),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // =============================================================================
  // TABLES VIEW
  // =============================================================================
  Widget _buildTablesView() {
    if (_tables.isEmpty) {
      return _buildEmptyState('No tables configured', Icons.table_restaurant);
    }

    return RefreshIndicator(
      onRefresh: _loadTables,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _tables.length,
        itemBuilder: (context, index) {
          final table = _tables[index];
          return _TableCard(
            table: table,
            onToggle: () => _toggleTableAvailability(table.id, table.isAvailable),
          );
        },
      ),
    );
  }

  // =============================================================================
  // ASSIST VIEW
  // =============================================================================
  Widget _buildAssistView() {
    if (_assistRequests.isEmpty) {
      return _buildEmptyState('No assist requests', Icons.notifications_none);
    }

    return RefreshIndicator(
      onRefresh: _loadAssistRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assistRequests.length,
        itemBuilder: (context, index) {
          final request = _assistRequests[index];
          return _AssistRequestCard(
            request: request,
            onResolve: () => _resolveAssistRequest(request['id'] as String),
          );
        },
      ),
    );
  }

  // =============================================================================
  // SHARED COMPONENTS
  // =============================================================================
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
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
                      // Per schema: order_number is bigint (int), not string
                      'Order #${order.orderNumber ?? order.id.substring(0, 6)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Placed at ${_formatTime(order.createdAt?.toIso8601String())}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const Divider(height: 32),
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...order.items.map((item) {
                  // Handle soft-deleted menu items per schema (deleted_at exists)
                  final isDeleted = item.menuItem?.deletedAt != null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
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
                      item.menuItem?.name ?? 'Unknown Item',
                      style: isDeleted
                          ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      )
                          : null,
                    ),
                    subtitle: isDeleted
                        ? const Text(
                      'Item no longer available',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    )
                        : null,
                    trailing: Text(
                      'MWK ${item.lineTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
                const Divider(height: 32),
                if (order.specialInstructions != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note_alt, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.specialInstructions!,
                            style: TextStyle(color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                      'MWK ${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (order.status != 'served' && order.status != 'completed')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(order.id, _nextStatus(order.status));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('MARK AS ${_statusLabel(_nextStatus(order.status)).toUpperCase()}'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      selectedItemColor: const Color(0xFF4F46E5),
      unselectedItemColor: const Color(0xFF9CA3AF),
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: _pendingOrdersCount > 0,
            label: Text('$_pendingOrdersCount'),
            child: const Icon(Icons.receipt_long),
          ),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: _activeTablesCount > 0,
            label: Text('$_activeTablesCount'),
            child: const Icon(Icons.table_restaurant),
          ),
          label: 'Tables',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: _assistRequests.isNotEmpty,
            label: Text('${_assistRequests.length}'),
            child: const Icon(Icons.notifications),
          ),
          label: 'Assist',
        ),
      ],
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoString);
      return _timeFormat.format(date);
    } catch (_) {
      return 'Unknown';
    }
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class _StatData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  _StatData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

// =============================================================================
// WIDGET COMPONENTS
// =============================================================================

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                data.subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? badgeCount;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = color ?? const Color(0xFF4F46E5);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'confirmed': return const Color(0xFF3B82F6);
      case 'preparing': return const Color(0xFF6366F1);
      case 'ready': return const Color(0xFF10B981);
      case 'served': return const Color(0xFF14B8A6);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _OrderListTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderListTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            // Per schema: order_number is bigint
            '#${order.orderNumber ?? order.id.substring(0, 4)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
          ),
        ),
        title: Text('MWK ${order.totalAmount.toStringAsFixed(0)}'),
        subtitle: Text('${order.items.length} items - ${order.status.toUpperCase()}'),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final ValueChanged<String> onStatusUpdate;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onStatusUpdate,
    required this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFFEF3C7);
      case 'confirmed': return const Color(0xFFDBEAFE);
      case 'preparing': return const Color(0xFFE0E7FF);
      case 'ready': return const Color(0xFFD1FAE5);
      case 'served': return const Color(0xFFDBEAFE);
      default: return Colors.grey.shade100;
    }
  }

  String _nextStatus(String current) => _OperatorHomePageState._nextStatus(current);
  String _statusLabel(String status) => _OperatorHomePageState._statusLabel(status);

  @override
  Widget build(BuildContext context) {
    final nextStatus = _nextStatus(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _statusColor(order.status),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  // Per schema: order_number is bigint
                  '#${order.orderNumber ?? order.id.substring(0, 6)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MWK ${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      _statusLabel(order.status),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...order.items.map((item) {
                    // Handle soft-deleted menu items per schema
                    final isDeleted = item.menuItem?.deletedAt != null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.menuItem?.name ?? 'Unknown',
                              style: isDeleted
                                  ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              )
                                  : null,
                            ),
                          ),
                          Text('MWK ${item.lineTotal.toStringAsFixed(0)}'),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (order.specialInstructions != null)
                        Expanded(
                          child: Text(
                            'Note: ${order.specialInstructions}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: () => onStatusUpdate(nextStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('MARK ${_statusLabel(nextStatus).toUpperCase()}'),
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
}

class _TableCard extends StatelessWidget {
  final models.TableModel table;
  final VoidCallback onToggle;

  const _TableCard({required this.table, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isOccupied = !table.isAvailable;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isOccupied ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOccupied ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: (isOccupied ? Colors.red : Colors.green).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOccupied ? Icons.event_busy : Icons.event_available,
              color: isOccupied ? Colors.red : Colors.green,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Table ${table.tableNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOccupied ? Colors.red : Colors.green,
              ),
            ),
            Text(
              isOccupied ? 'Occupied' : 'Available',
              style: TextStyle(
                fontSize: 12,
                color: isOccupied ? Colors.red.withOpacity(0.7) : Colors.green.withOpacity(0.7),
              ),
            ),
            // Per schema: capacity is integer DEFAULT 4
            if (table.capacity != null) ...[
              const SizedBox(height: 4),
              Text(
                'Seats ${table.capacity}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssistRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onResolve;

  const _AssistRequestCard({required this.request, required this.onResolve});

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
    // Per schema: assist_requests has table_id (FK to tables)
    // We joined with tables to get table_number in _loadAssistRequests
    final tableData = request['tables'] as Map<String, dynamic>?;
    final tableNum = tableData?['table_number'] ?? 'Unknown';
    final createdAt = request['created_at'] as String?;

    // Per schema: NO request_type column exists
    // All assist requests are generic assistance
    const requestIcon = Icons.support_agent;
    const requestLabel = 'Assistance needed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFFEF3C7),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(requestIcon, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Table $tableNum',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(requestLabel, style: TextStyle(color: Colors.grey)),
                  Text(
                    'Requested at ${_formatTime(createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onResolve,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Resolve'),
            ),
          ],
        ),
      ),
    );
  }
}
