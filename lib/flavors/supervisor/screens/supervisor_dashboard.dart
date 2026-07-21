import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/user_models.dart';
import '../../../core/models/order_models.dart';

/// ============================================================================
/// SUPERVISOR DASHBOARD
/// ============================================================================
///
/// A comprehensive supervisor/admin dashboard for restaurant management:
/// - Pending establishment approvals
/// - Staff management (operators, kitchen staff)
/// - Revenue analytics & reporting
/// - Order oversight across all establishments
/// - Real-time activity feed
/// - System settings
///
/// Code Compatibility: UserProfile lives ONLY in user_models.dart
/// ============================================================================

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard>
    with SingleTickerProviderStateMixin {

  // --- Services ---
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  // --- State ---
  UserProfile? _currentUser;
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _selectedIndex = 0;

  // --- Data ---
  List<Map<String, dynamic>> _pendingEstablishments = [];
  List<Map<String, dynamic>> _allEstablishments = [];
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic> _systemStats = {};

  // --- Search & Filter ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // --- Date formatters ---
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'MWK ');

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
    _searchController.dispose();
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _initialize() async {
    try {
      _currentUser = await _auth.getCurrentUserProfile();

      // Verify supervisor/admin access
      if (_currentUser != null && _currentUser!.userType != 'supervisor' && _currentUser!.userType != 'admin') {
        setState(() => _isLoading = false);
        _showError('Access denied. Supervisor privileges required.');
        return;
      }

      await _loadAllData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Initialization failed: $e');
    }
  }

  // --- Data Loading ---
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadPendingEstablishments(),
      _loadAllEstablishments(),
      _loadAllOrders(),
      _loadStaffList(),
      _loadSystemStats(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadAllData();
    setState(() => _isRefreshing = false);
    _showSnackBar('Data refreshed');
  }

  Future<void> _loadPendingEstablishments() async {
    try {
      final response = await _supabase.client
          .from('establishments')
          .select('*, users!owner_id(full_name, email, phone)')
          .eq('supervisor_approved', false)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      setState(() => _pendingEstablishments = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading pending establishments: $e');
    }
  }

  Future<void> _loadAllEstablishments() async {
    try {
      final response = await _supabase.client
          .from('establishments')
          .select('*, users!owner_id(full_name, email)')
          .order('created_at', ascending: false);

      setState(() => _allEstablishments = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading establishments: $e');
    }
  }

  Future<void> _loadAllOrders() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

      final response = await _supabase.client
          .from('orders')
          .select('*, establishments(name), users!customer_id(full_name)')
          .gte('created_at', startOfDay)
          .order('created_at', ascending: false)
          .limit(100);

      setState(() => _allOrders = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }
  }

  Future<void> _loadStaffList() async {
    try {
      final response = await _supabase.client
          .from('staff_assignments')
          .select('*, users!user_id(full_name, email, user_type), establishments(name)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      setState(() => _staffList = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading staff: $e');
    }
  }

  Future<void> _loadSystemStats() async {
    try {
      // Total establishments
      final establishmentsCount = await _supabase.client
          .from('establishments')
          .select('id');

      // Total users
      final usersCount = await _supabase.client
          .from('users')
          .select('id');

      // Today's total revenue
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final revenueResponse = await _supabase.client
          .from('orders')
          .select('total_amount')
          .gte('created_at', startOfDay)
          .inFilter('status', ['served', 'completed']);

      final totalRevenue = (revenueResponse as List).fold<double>(
        0.0,
            (sum, order) => sum + ((order['total_amount'] ?? 0) as num).toDouble(),
      );

      // Pending approvals
      final pendingCount = await _supabase.client
          .from('establishments')
          .select('id')
          .eq('supervisor_approved', false);

      setState(() => _systemStats = {
        'total_establishments': (establishmentsCount as List).length,
        'total_users': (usersCount as List).length,
        'today_revenue': totalRevenue,
        'pending_approvals': (pendingCount as List).length,
      });
    } catch (e) {
      debugPrint('Error loading system stats: $e');
    }
  }

  // --- Actions ---
  Future<void> _approveEstablishment(String establishmentId) async {
    try {
      await _supabase.client
          .from('establishments')
          .update({'supervisor_approved': true})
          .eq('id', establishmentId);

      _showSnackBar('Establishment approved');
      await _loadPendingEstablishments();
      await _loadSystemStats();
    } catch (e) {
      _showError('Failed to approve: $e');
    }
  }

  Future<void> _rejectEstablishment(String establishmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Establishment'),
          ],
        ),
        content: const Text('This will deactivate the establishment. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.client
            .from('establishments')
            .update({'is_active': false, 'supervisor_approved': false})
            .eq('id', establishmentId);

        _showSnackBar('Establishment rejected');
        await _loadPendingEstablishments();
        await _loadSystemStats();
      } catch (e) {
        _showError('Failed to reject: $e');
      }
    }
  }

  Future<void> _deactivateStaff(String assignmentId) async {
    try {
      await _supabase.client
          .from('staff_assignments')
          .update({'is_active': false})
          .eq('id', assignmentId);

      _showSnackBar('Staff deactivated');
      await _loadStaffList();
    } catch (e) {
      _showError('Failed to deactivate staff: $e');
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5))),
              SizedBox(height: 16),
              Text('Loading supervisor dashboard...', style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildOverviewView(),
            _buildApprovalsView(),
            _buildEstablishmentsView(),
            _buildOrdersView(),
            _buildStaffView(),
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
          const Text('Supervisor Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_currentUser != null)
            Text('Admin: ${_currentUser!.fullName ?? _currentUser!.email}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _isRefreshing ? null : _refreshData,
          icon: _isRefreshing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
        IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
      ],
    );
  }

  // =============================================================================
  // OVERVIEW VIEW
  // =============================================================================
  Widget _buildOverviewView() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSystemStatsCards(),
            const SizedBox(height: 24),
            if (_pendingEstablishments.isNotEmpty) ...[
              _buildPendingApprovalsSection(),
              const SizedBox(height: 24),
            ],
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatsCards() {
    final stats = [
      _StatData(
        title: 'Establishments',
        value: '${_systemStats['total_establishments'] ?? 0}',
        subtitle: '${_systemStats['pending_approvals'] ?? 0} pending',
        icon: Icons.store,
        color: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
      ),
      _StatData(
        title: 'Total Users',
        value: '${_systemStats['total_users'] ?? 0}',
        subtitle: 'Registered accounts',
        icon: Icons.people,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFD1FAE5),
      ),
      _StatData(
        title: 'Today\'s Revenue',
        value: 'MWK ${(_systemStats['today_revenue'] ?? 0.0).toStringAsFixed(0)}',
        subtitle: 'Across all establishments',
        icon: Icons.payments,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
      ),
      _StatData(
        title: 'Active Staff',
        value: '${_staffList.length}',
        subtitle: 'Assigned to establishments',
        icon: Icons.badge,
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

  Widget _buildPendingApprovalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Pending Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 1),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._pendingEstablishments.take(3).map((est) => _PendingEstablishmentCard(
          establishment: est,
          onApprove: () => _approveEstablishment(est['id']),
          onReject: () => _rejectEstablishment(est['id']),
        )),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_allOrders.isEmpty)
          _buildEmptyState('No orders today', Icons.receipt_long)
        else
          ..._allOrders.take(5).map((order) => _OrderActivityTile(order: order)),
      ],
    );
  }

  // =============================================================================
  // APPROVALS VIEW
  // =============================================================================
  Widget _buildApprovalsView() {
    if (_pendingEstablishments.isEmpty) {
      return _buildEmptyState('No pending approvals', Icons.check_circle);
    }

    return RefreshIndicator(
      onRefresh: _loadPendingEstablishments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingEstablishments.length,
        itemBuilder: (context, index) {
          final est = _pendingEstablishments[index];
          return _PendingEstablishmentCard(
            establishment: est,
            onApprove: () => _approveEstablishment(est['id']),
            onReject: () => _rejectEstablishment(est['id']),
          );
        },
      ),
    );
  }

  // =============================================================================
  // ESTABLISHMENTS VIEW
  // =============================================================================
  Widget _buildEstablishmentsView() {
    if (_allEstablishments.isEmpty) {
      return _buildEmptyState('No establishments found', Icons.store);
    }

    return RefreshIndicator(
      onRefresh: _loadAllEstablishments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allEstablishments.length,
        itemBuilder: (context, index) {
          final est = _allEstablishments[index];
          return _EstablishmentCard(establishment: est);
        },
      ),
    );
  }

  // =============================================================================
  // ORDERS VIEW
  // =============================================================================
  Widget _buildOrdersView() {
    if (_allOrders.isEmpty) {
      return _buildEmptyState('No orders found', Icons.receipt_long);
    }

    return RefreshIndicator(
      onRefresh: _loadAllOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allOrders.length,
        itemBuilder: (context, index) {
          final order = _allOrders[index];
          return _OrderActivityTile(order: order);
        },
      ),
    );
  }

  // =============================================================================
  // STAFF VIEW
  // =============================================================================
  Widget _buildStaffView() {
    if (_staffList.isEmpty) {
      return _buildEmptyState('No staff members found', Icons.people);
    }

    return RefreshIndicator(
      onRefresh: _loadStaffList,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _staffList.length,
        itemBuilder: (context, index) {
          final staff = _staffList[index];
          return _StaffCard(
            staff: staff,
            onDeactivate: () => _deactivateStaff(staff['id']),
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
          Text(message, style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
        ],
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
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: _pendingEstablishments.isNotEmpty,
            label: Text('${_pendingEstablishments.length}'),
            child: const Icon(Icons.approval),
          ),
          label: 'Approvals',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Venues'),
        const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
        const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Staff'),
      ],
    );
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: data.color)),
              const SizedBox(height: 2),
              Text(data.title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text(data.subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingEstablishmentCard extends StatelessWidget {
  final Map<String, dynamic> establishment;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingEstablishmentCard({
    required this.establishment,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final owner = establishment['users'] as Map<String, dynamic>?;
    final createdAt = establishment['created_at'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        establishment['name'] ?? 'Unnamed',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        owner?['full_name'] ?? owner?['email'] ?? 'Unknown owner',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (establishment['address'] != null)
              Text('${establishment['address']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            if (owner != null && owner['phone'] != null)
              Text('Phone: ${owner['phone']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.block, size: 18, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstablishmentCard extends StatelessWidget {
  final Map<String, dynamic> establishment;

  const _EstablishmentCard({required this.establishment});

  @override
  Widget build(BuildContext context) {
    final isApproved = establishment['supervisor_approved'] == true;
    final isActive = establishment['is_active'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.store,
            color: isApproved ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(establishment['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${isApproved ? 'Approved' : 'Pending'} - ${isActive ? 'Active' : 'Inactive'}',
          style: TextStyle(
            color: isApproved ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}

class _OrderActivityTile extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderActivityTile({required this.order});

  Color _statusColor(String status) {
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
    final status = order['status'] as String? ?? 'unknown';
    final establishment = order['establishments'] as Map<String, dynamic>?;
    final customer = order['users'] as Map<String, dynamic>?;
    final amount = (order['total_amount'] ?? 0.0) as num;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '#${order['order_number'] ?? order['id'].toString().substring(0, 4)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor(status), fontSize: 12),
          ),
        ),
        title: Text('MWK ${amount.toStringAsFixed(0)}'),
        subtitle: Text('${establishment?['name'] ?? 'Unknown'} - ${customer?['full_name'] ?? 'Guest'}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onDeactivate;

  const _StaffCard({required this.staff, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final user = staff['users'] as Map<String, dynamic>?;
    final establishment = staff['establishments'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
              child: Text(
                ((user?['full_name'] as String?) ?? 'U').isNotEmpty
                    ? ((user?['full_name'] as String?) ?? 'U')[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${staff['role'] ?? 'staff'} - ${establishment?['name'] ?? 'Unassigned'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  Text(user?['email'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: onDeactivate,
              icon: const Icon(Icons.person_remove, color: Colors.red),
              tooltip: 'Deactivate',
            ),
          ],
        ),
      ),
    );
  }
}