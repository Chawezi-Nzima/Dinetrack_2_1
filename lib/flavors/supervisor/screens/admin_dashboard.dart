import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/user_models.dart';

// ═══════════════════════════════════════════════════════════════
// RESPONSIVE BREAKPOINTS & UTILITIES
// ═══════════════════════════════════════════════════════════════

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double wideDesktop = 1600;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= wideDesktop;

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobile) return ScreenType.mobile;
    if (width < tablet) return ScreenType.tablet;
    if (width < desktop) return ScreenType.desktop;
    return ScreenType.wideDesktop;
  }

  static int getStatsCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 2;
    if (width < Breakpoints.mobile) return 2;
    if (width < Breakpoints.tablet) return 3;
    if (width < Breakpoints.desktop) return 4;
    if (width < Breakpoints.wideDesktop) return 4;
    return 6;
  }

  static int getListColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.tablet) return 1;
    if (width < Breakpoints.desktop) return 2;
    return 3;
  }
}

enum ScreenType { mobile, tablet, desktop, wideDesktop }

class ResponsiveSpacing {
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return 12;
    if (width < Breakpoints.tablet) return 20;
    if (width < Breakpoints.desktop) return 32;
    if (width < Breakpoints.wideDesktop) return 48;
    return 64;
  }

  static double getSectionPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return 16;
    if (width < Breakpoints.tablet) return 24;
    if (width < Breakpoints.desktop) return 32;
    return 40;
  }

  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.desktop) return width;
    if (width < Breakpoints.wideDesktop) return 1200;
    return 1600;
  }

  static double getCardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return 12;
    if (width < Breakpoints.tablet) return 16;
    return 20;
  }
}

// ═══════════════════════════════════════════════════════════════
// ADMIN DASHBOARD
// ═══════════════════════════════════════════════════════════════

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
  List<SystemLog> _systemLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
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

      final usersResponse = await _supabase
          .from('users')
          .select('id, email, full_name, user_type, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      _users = (usersResponse as List<dynamic>)
          .map((json) => AdminUser.fromJson(json))
          .toList();

      final estResponse = await _supabase
          .from('establishments')
          .select('id, name, type, address, is_active, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      _establishments = (estResponse as List<dynamic>)
          .map((json) => AdminEstablishment.fromJson(json))
          .toList();

      final ordersResponse = await _supabase
          .from('orders')
          .select('id, total_amount, status, payment_status, created_at, establishments(name), users:customer_id(full_name)')
          .order('created_at', ascending: false)
          .limit(50);
      _recentOrders = (ordersResponse as List<dynamic>)
          .map((json) => AdminOrder.fromJson(json))
          .toList();

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
      debugPrint('Admin dashboard error: \$e');
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
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;

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
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: const Color(0xFF667eea),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // OVERVIEW TAB — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final isTablet = screenType == ScreenType.tablet;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);
        final statsCount = Breakpoints.getStatsCrossAxisCount(context);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: statsCount,
                      childAspectRatio: isDesktop ? 1.6 : (isTablet ? 1.5 : 1.4),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      final stats = [
                        {'title': 'Total Users', 'value': '\$_totalUsers', 'icon': Icons.people, 'color': const Color(0xFF667eea), 'subtitle': '+5% this week'},
                        {'title': 'Restaurants', 'value': '\$_totalEstablishments', 'icon': Icons.restaurant, 'color': const Color(0xFF11998e), 'subtitle': '+2 new'},
                        {'title': 'Total Orders', 'value': '\$_totalOrders', 'icon': Icons.receipt_long, 'color': const Color(0xFFf093fb), 'subtitle': 'All time'},
                        {'title': 'Revenue', 'value': 'MWK \${_totalRevenue.toStringAsFixed(0)}', 'icon': Icons.attach_money, 'color': const Color(0xFFfa709a), 'subtitle': 'Lifetime'},
                        {'title': 'Active Sessions', 'value': '\$_activeSessions', 'icon': Icons.qr_code, 'color': const Color(0xFF4facfe), 'subtitle': 'Right now'},
                        {'title': 'Pending Orders', 'value': '\$_pendingOrders', 'icon': Icons.pending_actions, 'color': Colors.orange, 'subtitle': 'In queue'},
                      ];
                      return _buildStatCard(
                        stats[index]['title'] as String,
                        stats[index]['value'] as String,
                        stats[index]['icon'] as IconData,
                        stats[index]['color'] as Color,
                        stats[index]['subtitle'] as String,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Charts Row — responsive
                  isDesktop
                      ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildRevenueChart()),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildUserGrowthChart()),
                    ],
                  )
                      : Column(
                    children: [
                      _buildRevenueChart(),
                      const SizedBox(height: 16),
                      _buildUserGrowthChart(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildSectionTitle('Quick Actions'),
                  const SizedBox(height: 12),
                  _buildQuickActions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
    final cardPadding = ResponsiveSpacing.getCardPadding(context);

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 10 : 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isDesktop ? 24 : 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: isDesktop ? 11 : 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1a1a2e),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
    final cardPadding = ResponsiveSpacing.getCardPadding(context);

    return Container(
      height: isDesktop ? 280 : 220,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Revenue Trend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1a1a2e),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Last 6 months',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF667eea),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'][value.toInt() % 6],
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 12000),
                      FlSpot(1, 15000),
                      FlSpot(2, 18000),
                      FlSpot(3, 14000),
                      FlSpot(4, 22000),
                      FlSpot(5, 28000),
                    ],
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF667eea).withValues(alpha: 0.2),
                          const Color(0xFF764ba2).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
    final cardPadding = ResponsiveSpacing.getCardPadding(context);

    return Container(
      height: isDesktop ? 280 : 180,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Growth',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1a1a2e),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        'W\${value.toInt() + 1}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  6,
                      (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: [45, 62, 78, 95, 120, 156][i].toDouble(),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        width: isDesktop ? 28 : 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;

    final actions = [
      {'label': 'Add Restaurant', 'icon': Icons.add_business, 'color': const Color(0xFF667eea), 'onTap': () => _showCreateRestaurantDialog()},
      {'label': 'Add User', 'icon': Icons.person_add, 'color': const Color(0xFF11998e), 'onTap': () => _showCreateUserDialog()},
      {'label': 'Manage Tiers', 'icon': Icons.emoji_events, 'color': const Color(0xFFFFD700), 'onTap': () => _showManageTiersDialog()},
      {'label': 'Export Data', 'icon': Icons.download, 'color': const Color(0xFFf093fb), 'onTap': () => _showExportDialog()},
      {'label': 'System Health', 'icon': Icons.health_and_safety, 'color': const Color(0xFF4facfe), 'onTap': () => _showSystemHealth()},
    ];

    if (isDesktop) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions.map((a) => _buildActionChip(
          a['label'] as String,
          a['icon'] as IconData,
          a['color'] as Color,
          a['onTap'] as VoidCallback,
        )).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions.map((a) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildActionChip(
            a['label'] as String,
            a['icon'] as IconData,
            a['color'] as Color,
            a['onTap'] as VoidCallback,
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // USERS TAB — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUsersTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final isTablet = screenType == ScreenType.tablet;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);
        final listColumns = Breakpoints.getListColumns(context);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('All Users'),
                      if (isDesktop)
                        ElevatedButton.icon(
                          onPressed: () => _showCreateUserDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _showCreateUserDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add User'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Users grid
                  listColumns > 1
                      ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: listColumns,
                      childAspectRatio: isDesktop ? 3.5 : 3.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _users.length,
                    itemBuilder: (context, index) => _buildUserCard(_users[index]),
                  )
                      : Column(
                    children: _users.map((user) => _buildUserCard(user)).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserCard(AdminUser user) {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
    final cardPadding = ResponsiveSpacing.getCardPadding(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 56 : 48,
            height: isDesktop ? 56 : 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                user.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isDesktop ? 18 : 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isDesktop ? 16 : 15,
                  ),
                ),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildRoleBadge(user.userType),
                    const SizedBox(width: 8),
                    Text(
                      "Joined \${DateFormat('MMM d, yyyy').format(user.createdAt)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _showEditUserDialog(user);
              if (value == 'delete') _showDeleteUserDialog(user);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String userType) {
    final colors = {
      'customer': Colors.blue,
      'kitchen': Colors.orange,
      'operator': Colors.purple,
      'supervisor': Colors.teal,
      'admin': Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (colors[userType] ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        userType.toUpperCase(),
        style: TextStyle(
          color: colors[userType] ?? Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RESTAURANTS TAB — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRestaurantsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);
        final listColumns = Breakpoints.getListColumns(context);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('All Restaurants'),
                      if (isDesktop)
                        ElevatedButton.icon(
                          onPressed: () => _showCreateRestaurantDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Restaurant'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _showCreateRestaurantDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Restaurant'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  listColumns > 1
                      ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: listColumns,
                      childAspectRatio: isDesktop ? 3.5 : 3.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _establishments.length,
                    itemBuilder: (context, index) => _buildRestaurantCard(_establishments[index]),
                  )
                      : Column(
                    children: _establishments.map((est) => _buildRestaurantCard(est)).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestaurantCard(AdminEstablishment est) {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
    final cardPadding = ResponsiveSpacing.getCardPadding(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 56 : 48,
            height: isDesktop ? 56 : 48,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant, color: Color(0xFF667eea)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  est.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isDesktop ? 16 : 15,
                  ),
                ),
                Text(
                  est.type,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.table_restaurant, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Tables managed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: est.isActive
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        est.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: est.isActive ? Colors.green : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
              PopupMenuItem(
                value: 'toggle',
                child: Text(est.isActive ? 'Deactivate' : 'Activate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ORDERS TAB — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOrdersTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);
        final listColumns = Breakpoints.getListColumns(context);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Recent Orders'),
                  const SizedBox(height: 16),

                  // Desktop: Data table view
                  isDesktop && listColumns > 1
                      ? _buildOrdersDataTable()
                      : listColumns > 1
                      ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: listColumns,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _recentOrders.length,
                    itemBuilder: (context, index) => _buildOrderCard(_recentOrders[index]),
                  )
                      : Column(
                    children: _recentOrders.map((order) => _buildOrderCard(order)).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersDataTable() {
    final statusColors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': const Color(0xFF667eea),
      'ready': Colors.green,
      'served': Colors.teal,
      'completed': const Color(0xFF11998e),
      'cancelled': Colors.red,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)),
          columns: const [
            DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Restaurant', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: _recentOrders.take(20).map((order) => DataRow(
            cells: [
              DataCell(Text('#\${order.id.substring(0, 4).toUpperCase()}')),
              DataCell(Text(order.establishmentName)),
              DataCell(Text(order.customerName)),
              DataCell(Text('MWK \${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF667eea)))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (statusColors[order.status] ?? Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColors[order.status] ?? Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              DataCell(Text(DateFormat('MMM d, h:mm a').format(order.createdAt))),
            ],
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderCard(AdminOrder order) {
    final statusColors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': const Color(0xFF667eea),
      'ready': Colors.green,
      'served': Colors.teal,
      'completed': const Color(0xFF11998e),
      'cancelled': Colors.red,
    };
    final cardPadding = ResponsiveSpacing.getCardPadding(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (statusColors[order.status] ?? Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '#\${order.id.substring(0, 4).toUpperCase()}',
                style: TextStyle(
                  color: statusColors[order.status] ?? Colors.grey,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.establishmentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'MWK \${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ],
                ),
                Text(
                  'By \${order.customerName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (statusColors[order.status] ?? Colors.grey).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColors[order.status] ?? Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, h:mm a').format(order.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGS TAB — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLogsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('System Notifications'),
                  const SizedBox(height: 16),

                  // Desktop: Full-width log rows
                  isDesktop
                      ? _buildDesktopLogsView()
                      : Column(
                    children: _systemLogs.map((log) => _buildLogCard(log)).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLogsView() {
    final levelColors = {
      'info': Colors.blue,
      'warning': Colors.orange,
      'error': Colors.red,
      'debug': Colors.grey,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _systemLogs.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey.shade100,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final log = _systemLogs[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: levelColors[log.level] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    log.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (log.details != null)
                  Expanded(
                    flex: 2,
                    child: Text(
                      log.details!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (levelColors[log.level] ?? Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.level.toUpperCase(),
                    style: TextStyle(
                      color: levelColors[log.level] ?? Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  DateFormat('MMM d, h:mm:ss a').format(log.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard(SystemLog log) {
    final levelColors = {
      'info': Colors.blue,
      'warning': Colors.orange,
      'error': Colors.red,
      'debug': Colors.grey,
    };
    final cardPadding = ResponsiveSpacing.getCardPadding(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: levelColors[log.level] ?? Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (log.details != null)
                  Text(
                    log.details!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  "\${log.source} • \${DateFormat('MMM d, h:mm:ss a').format(log.createdAt)}",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DIALOGS & ACTIONS
  // ═══════════════════════════════════════════════════════════════

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create New'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant, color: Color(0xFF667eea)),
              title: const Text('Restaurant'),
              onTap: () {
                Navigator.pop(context);
                _showCreateRestaurantDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF11998e)),
              title: const Text('User'),
              onTap: () {
                Navigator.pop(context);
                _showCreateUserDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Color(0xFFf093fb)),
              title: const Text('Menu Category'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog() {
    final emailController = TextEditingController();
    final fullNameController = TextEditingController();
    String selectedUserType = 'customer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedUserType,
                decoration: const InputDecoration(
                  labelText: 'User Type',
                  border: OutlineInputBorder(),
                ),
                items: ['customer', 'kitchen', 'operator', 'supervisor', 'admin']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                    .toList(),
                onChanged: (v) => selectedUserType = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _loadDashboard();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateRestaurantDialog() {
    final nameController = TextEditingController();
    final typeController = TextEditingController(text: 'restaurant');
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Restaurant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type (restaurant/cafe/bar)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _loadDashboard();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(AdminUser user) {}
  void _showDeleteUserDialog(AdminUser user) {}
  void _toggleUserStatus(AdminUser user) async {
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
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;

    return Text(
      title,
      style: TextStyle(
        fontSize: isDesktop ? 22 : 18,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1a1a2e),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════

class AdminUser {
  final String id;
  final String email;
  final String fullName;
  final String userType;
  final DateTime createdAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    required this.createdAt,
  });

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
      return '\${parts[0][0]}\${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

class AdminEstablishment {
  final String id;
  final String name;
  final String type;
  final bool isActive;

  AdminEstablishment({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

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

  AdminOrder({
    required this.id,
    required this.establishmentName,
    required this.customerName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

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

  SystemLog({
    required this.id,
    required this.level,
    required this.message,
    this.details,
    required this.source,
    required this.createdAt,
  });

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
    final statsCount = Breakpoints.getStatsCrossAxisCount(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: statsCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: List.generate(
            6,
                (_) => Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
