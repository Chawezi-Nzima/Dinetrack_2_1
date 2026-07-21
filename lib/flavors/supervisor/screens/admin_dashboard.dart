import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/user_models.dart';

/// Admin Dashboard
/// Full system administration: users, establishments, menu, analytics, settings
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;

  // System stats
  int _totalUsers = 0;
  int _totalEstablishments = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0;
  int _activeSessions = 0;
  int _pendingOrders = 0;

  // Lists
  List<AdminUser> _users = [];
  List<AdminEstablishment> _establishments = [];
  List<AdminOrder> _recentOrders = [];
  List<SystemLog> _systemLogs = []; // mapped from notifications table

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      // System stats
      final usersCount = await _supabase.from('users').select('id');
      _totalUsers = (usersCount as List).length;

      final estCount = await _supabase.from('establishments').select('id');
      _totalEstablishments = (estCount as List).length;

      final ordersCount = await _supabase.from('orders').select('id');
      _totalOrders = (ordersCount as List).length;

      final revenue = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('payment_status', 'paid');
      _totalRevenue = (revenue as List<dynamic>).fold(0.0, (sum, r) => sum + ((r['total_amount'] ?? 0) as num));

      final activeTables = await _supabase
          .from('tables')
          .select('id')
          .eq('is_available', false);
      _activeSessions = (activeTables as List).length;

      final pending = await _supabase
          .from('orders')
          .select('id')
          .inFilter('status', ['pending', 'confirmed', 'preparing']);
      _pendingOrders = (pending as List).length;

      // Users
      final usersResponse = await _supabase
          .from('users')
          .select('id, email, full_name, user_type, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      _users = (usersResponse as List<dynamic>)
          .map((json) => AdminUser.fromJson(json))
          .toList();

      // Establishments
      final estResponse = await _supabase
          .from('establishments')
          .select('id, name, type, address, is_active, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      _establishments = (estResponse as List<dynamic>)
          .map((json) => AdminEstablishment.fromJson(json))
          .toList();

      // Recent orders
      final ordersResponse = await _supabase
          .from('orders')
          .select('id, total_amount, status, payment_status, created_at, establishments(name), users:customer_id(full_name)')
          .order('created_at', ascending: false)
          .limit(50);
      _recentOrders = (ordersResponse as List<dynamic>)
          .map((json) => AdminOrder.fromJson(json))
          .toList();

      // System logs
      // system_logs table doesn't exist in schema - using notifications
      final logsResponse = await _supabase
          .from('notifications')
          .select('id, title, body, type, priority, created_at')
          .order('created_at', ascending: false)
          .limit(100);
      _systemLogs = (logsResponse as List<dynamic>)
          .map((json) => SystemLog.fromJson(json))
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Admin dashboard error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            Text('System Administration', style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w400)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF667eea),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Restaurants', icon: Icon(Icons.restaurant)),
            Tab(text: 'Orders', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Logs', icon: Icon(Icons.terminal)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboard),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') _showSettingsDialog();
              if (value == 'backup') _showBackupDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('System Settings')),
              const PopupMenuItem(value: 'backup', child: Text('Backup Data')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const _LoadingSkeleton()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildRestaurantsTab(),
          _buildOrdersTab(),
          _buildLogsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: const Color(0xFF667eea),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  // ─── Overview Tab ──────────────────────────────────────────

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard('Total Users', '$_totalUsers', Icons.people, const Color(0xFF667eea), '+5% this week'),
            _buildStatCard('Restaurants', '$_totalEstablishments', Icons.restaurant, const Color(0xFF11998e), '+2 new'),
            _buildStatCard('Total Orders', '$_totalOrders', Icons.receipt_long, const Color(0xFFf093fb), 'All time'),
            _buildStatCard('Revenue', 'MWK ${_totalRevenue.toStringAsFixed(0)}', Icons.attach_money, const Color(0xFFfa709a), 'Lifetime'),
            _buildStatCard('Active Sessions', '$_activeSessions', Icons.qr_code, const Color(0xFF4facfe), 'Right now'),
            _buildStatCard('Pending Orders', '$_pendingOrders', Icons.pending_actions, Colors.orange, 'In queue'),
          ],
        ),
        const SizedBox(height: 24),
        // Revenue Chart
        _buildSectionTitle('Monthly Revenue Trend'),
        const SizedBox(height: 12),
        _buildRevenueChart(),
        const SizedBox(height: 24),
        // User Growth
        _buildSectionTitle('User Growth'),
        const SizedBox(height: 12),
        _buildUserGrowthChart(),
        const SizedBox(height: 24),
        // Quick Actions
        _buildSectionTitle('Quick Actions'),
        const SizedBox(height: 12),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1a1a2e))),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ]),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(['Jan','Feb','Mar','Apr','May','Jun'][value.toInt() % 6], style: TextStyle(fontSize: 11, color: Colors.grey.shade500)))),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [FlSpot(0, 12000), FlSpot(1, 15000), FlSpot(2, 18000), FlSpot(3, 14000), FlSpot(4, 22000), FlSpot(5, 28000)],
              isCurved: true,
              gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFF667eea).withOpacity(0.2), const Color(0xFF764ba2).withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text('W${value.toInt() + 1}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500))))),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(6, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: [45, 62, 78, 95, 120, 156][i].toDouble(), gradient: const LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]), borderRadius: BorderRadius.circular(4), width: 20)])),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionChip('Add Restaurant', Icons.add_business, const Color(0xFF667eea), () => _showCreateRestaurantDialog()),
        _buildActionChip('Add User', Icons.person_add, const Color(0xFF11998e), () => _showCreateUserDialog()),
        _buildActionChip('Manage Tiers', Icons.emoji_events, const Color(0xFFFFD700), () => _showManageTiersDialog()),
        _buildActionChip('Export Data', Icons.download, const Color(0xFFf093fb), () => _showExportDialog()),
        _buildActionChip('System Health', Icons.health_and_safety, const Color(0xFF4facfe), () => _showSystemHealth()),
      ],
    );
  }

  Widget _buildActionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))]),
      ),
    );
  }

  // ─── Users Tab ─────────────────────────────────────────────

  Widget _buildUsersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildSectionTitle('All Users'),
          TextButton.icon(onPressed: () => _showCreateUserDialog(), icon: const Icon(Icons.add, size: 18), label: const Text('Add User')),
        ]),
        const SizedBox(height: 12),
        ..._users.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(user.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(user.email, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Row(children: [
            _buildRoleBadge(user.userType),
            const SizedBox(width: 8),
            Text('Joined ${DateFormat('MMM d, yyyy').format(user.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ])),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _showEditUserDialog(user);
            if (value == 'toggle') _toggleUserStatus(user);
            if (value == 'delete') _showDeleteUserDialog(user);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),

            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ]),
    );
  }

  Widget _buildRoleBadge(String userType) {
    final colors = {'customer': Colors.blue, 'kitchen': Colors.orange, 'operator': Colors.purple, 'supervisor': Colors.teal, 'admin': Colors.red};
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (colors[userType] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(userType.toUpperCase(), style: TextStyle(color: colors[userType] ?? Colors.grey, fontSize: 10, fontWeight: FontWeight.w800)));
  }

  // ─── Restaurants Tab ───────────────────────────────────────

  Widget _buildRestaurantsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildSectionTitle('All Restaurants'),
          TextButton.icon(onPressed: () => _showCreateRestaurantDialog(), icon: const Icon(Icons.add, size: 18), label: const Text('Add Restaurant')),
        ]),
        const SizedBox(height: 12),
        ..._establishments.map((est) => _buildRestaurantCard(est)),
      ],
    );
  }

  Widget _buildRestaurantCard(AdminEstablishment est) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF667eea).withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.restaurant, color: Color(0xFF667eea))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(est.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(est.type, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.table_restaurant, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('Tables managed', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            const SizedBox(width: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: est.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(est.isActive ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: est.isActive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.w800))),
          ]),
        ])),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _showEditRestaurantDialog(est);
            if (value == 'tables') _showManageTablesDialog(est);
            if (value == 'menu') _showManageMenuDialog(est);
            if (value == 'toggle') _toggleRestaurantStatus(est);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'tables', child: Text('Manage Tables')),
            const PopupMenuItem(value: 'menu', child: Text('Manage Menu')),
            PopupMenuItem(value: 'toggle', child: Text(est.isActive ? 'Deactivate' : 'Activate')),
          ],
        ),
      ]),
    );
  }

  // ─── Orders Tab ────────────────────────────────────────────

  Widget _buildOrdersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Recent Orders'),
        const SizedBox(height: 12),
        ..._recentOrders.map((order) => _buildOrderCard(order)),
      ],
    );
  }

  Widget _buildOrderCard(AdminOrder order) {
    final statusColors = {'pending': Colors.orange, 'confirmed': Colors.blue, 'preparing': const Color(0xFF667eea), 'ready': Colors.green, 'served': Colors.teal, 'completed': const Color(0xFF11998e), 'cancelled': Colors.red};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: (statusColors[order.status] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Center(child: Text('#${order.id.substring(0, 4).toUpperCase()}', style: TextStyle(color: statusColors[order.status] ?? Colors.grey, fontWeight: FontWeight.w800, fontSize: 12)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(order.establishmentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('MWK ${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF667eea))),
          ]),
          Text('By ${order.customerName}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: (statusColors[order.status] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(order.status.toUpperCase(), style: TextStyle(color: statusColors[order.status] ?? Colors.grey, fontSize: 10, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Text(DateFormat('MMM d, h:mm a').format(order.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ])),
      ]),
    );
  }

  // ─── Logs Tab ──────────────────────────────────────────────

  Widget _buildLogsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('System Notifications'),
        const SizedBox(height: 12),
        ..._systemLogs.map((log) => _buildLogCard(log)),
      ],
    );
  }

  Widget _buildLogCard(SystemLog log) {
    final levelColors = {'info': Colors.blue, 'warning': Colors.orange, 'error': Colors.red, 'debug': Colors.grey};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: levelColors[log.level] ?? Colors.grey, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (log.details != null) Text(log.details!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text('${log.source} • ${DateFormat('MMM d, h:mm:ss a').format(log.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ])),
      ]),
    );
  }

  // ─── Dialogs & Actions ─────────────────────────────────────

  void _showCreateDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Create New'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.restaurant, color: Color(0xFF667eea)), title: const Text('Restaurant'), onTap: () { Navigator.pop(context); _showCreateRestaurantDialog(); }),
      ListTile(leading: const Icon(Icons.person, color: Color(0xFF11998e)), title: const Text('User'), onTap: () { Navigator.pop(context); _showCreateUserDialog(); }),
      ListTile(leading: const Icon(Icons.menu_book, color: Color(0xFFf093fb)), title: const Text('Menu Category'), onTap: () { Navigator.pop(context); }),
    ])));
  }

  void _showCreateUserDialog() {
    final emailController = TextEditingController();
    final fullNameController = TextEditingController();
    String selectedUserType = 'customer';

    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Create User'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: fullNameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: selectedUserType, decoration: const InputDecoration(labelText: 'User Type', border: OutlineInputBorder()), items: ['customer', 'kitchen', 'operator', 'supervisor', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(), onChanged: (v) => selectedUserType = v!),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(onPressed: () async { /* create user via Supabase Auth */ Navigator.pop(context); _loadDashboard(); }, child: const Text('Create')),
    ]));
  }

  void _showCreateRestaurantDialog() {
    final nameController = TextEditingController();
    final typeController = TextEditingController(text: 'restaurant');
    final addressController = TextEditingController();

    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Create Restaurant'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Type (restaurant/cafe/bar)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()), maxLines: 2),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(onPressed: () async { /* create logic */ Navigator.pop(context); _loadDashboard(); }, child: const Text('Create')),
    ]));
  }

  void _showEditUserDialog(AdminUser user) {}
  void _showDeleteUserDialog(AdminUser user) {}
  void _toggleUserStatus(AdminUser user) async {
    // Schema: users table uses soft delete via deleted_at
    await _supabase.from('users').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
    _loadDashboard();
  }
  void _showEditRestaurantDialog(AdminEstablishment est) {}
  void _showManageTablesDialog(AdminEstablishment est) {}
  void _showManageMenuDialog(AdminEstablishment est) {}
  void _toggleRestaurantStatus(AdminEstablishment est) async {
    await _supabase.from('establishments').update({'is_active': !est.isActive}).eq('id', est.id);
    _loadDashboard();
  }
  void _showSettingsDialog() {}
  void _showBackupDialog() {}
  void _showManageTiersDialog() {}
  void _showExportDialog() {}
  void _showSystemHealth() {}

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1a1a2e)));
  }
}

// ─── Models ─────────────────────────────────────────────────

class AdminUser {
  final String id;
  final String email;
  final String fullName;
  final String userType;
  final DateTime createdAt;

  AdminUser({required this.id, required this.email, required this.fullName, required this.userType, required this.createdAt});
  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] ?? '',
    email: json['email'] ?? '',
    fullName: json['full_name'] ?? '',
    userType: json['user_type'] ?? 'customer',
    createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
  );
  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

class AdminEstablishment {
  final String id;
  final String name;
  final String type;
  final bool isActive;

  AdminEstablishment({required this.id, required this.name, required this.type, required this.isActive});
  factory AdminEstablishment.fromJson(Map<String, dynamic> json) => AdminEstablishment(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: json['type'] ?? 'restaurant',
    isActive: json['is_active'] ?? true,
  );
}

class AdminOrder {
  final String id;
  final String establishmentName;
  final String customerName;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  AdminOrder({required this.id, required this.establishmentName, required this.customerName, required this.totalAmount, required this.status, required this.createdAt});
  factory AdminOrder.fromJson(Map<String, dynamic> json) => AdminOrder(
    id: json['id'] ?? '',
    establishmentName: json['establishments']?['name'] ?? 'Unknown',
    customerName: json['users']?['full_name'] ?? 'Unknown',
    totalAmount: (json['total_amount'] ?? 0).toDouble(),
    status: json['status'] ?? 'pending',
    createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
  );
}

class SystemLog {
  final String id;
  final String level;
  final String message;
  final String? details;
  final String source;
  final DateTime createdAt;

  SystemLog({required this.id, required this.level, required this.message, this.details, required this.source, required this.createdAt});
  factory SystemLog.fromJson(Map<String, dynamic> json) => SystemLog(
    id: json['id'] ?? '',
    level: json['priority'] ?? 'normal',
    message: json['body'] ?? '',
    details: json['title'],
    source: json['type'] ?? 'system',
    createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
  );
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4, children: List.generate(6, (_) => Container(decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)))))]);
  }
}