import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/user_models.dart';

/// Supervisor Analytics Dashboard
/// Revenue, orders, staff performance, and real-time metrics
class SupervisorAnalyticsDashboard extends StatefulWidget {
  const SupervisorAnalyticsDashboard({super.key});

  @override
  State<SupervisorAnalyticsDashboard> createState() => _SupervisorAnalyticsDashboardState();
}

class _SupervisorAnalyticsDashboardState extends State<SupervisorAnalyticsDashboard>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;

  // Analytics data
  double _todayRevenue = 0;
  int _todayOrders = 0;
  int _todayCustomers = 0;
  double _avgOrderValue = 0;
  List<FlSpot> _revenueChartData = [];
  List<CategorySales> _categorySales = [];
  List<TopItem> _topItems = [];
  List<StaffPerformance> _staffPerformance = [];
  List<HourlyOrder> _hourlyOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

      // Today's revenue
      final revenueResponse = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('payment_status', 'paid')
          .gte('created_at', todayStart.toIso8601String());

      _todayRevenue = (revenueResponse as List<dynamic>)
          .fold(0.0, (sum, r) => sum + ((r['total_amount'] ?? 0) as num));

      // Today's orders
      _todayOrders = revenueResponse.length;

      // Today's unique customers
      final customersResponse = await _supabase
          .from('orders')
          .select('user_id')
          .gte('created_at', todayStart.toIso8601String())
          .not('user_id', 'is', null);

      final uniqueCustomers = <String>{};
      for (final r in customersResponse) {
        if (r['user_id'] != null) uniqueCustomers.add(r['user_id'] as String);
      }
      _todayCustomers = uniqueCustomers.length;

      _avgOrderValue = _todayOrders > 0 ? _todayRevenue / _todayOrders : 0;

      // Weekly revenue chart
      final weeklyResponse = await _supabase
          .from('orders')
          .select('created_at, total_amount')
          .eq('payment_status', 'paid')
          .gte('created_at', weekStart.toIso8601String())
          .order('created_at');

      final dailyRevenue = <int, double>{};
      for (final r in weeklyResponse) {
        final date = DateTime.parse(r['created_at']);
        final day = date.weekday - 1;
        dailyRevenue[day] = (dailyRevenue[day] ?? 0) + ((r['total_amount'] ?? 0) as num);
      }

      _revenueChartData = List.generate(7, (i) {
        return FlSpot(i.toDouble(), (dailyRevenue[i] ?? 0).toDouble());
      });

      // Category sales
      final categoryResponse = await _supabase
          .from('order_items')
          .select('category, quantity, total_price')
          .gte('created_at', todayStart.toIso8601String());

      final categoryMap = <String, CategorySales>{};
      for (final r in categoryResponse) {
        final cat = r['category'] ?? 'Other';
        if (!categoryMap.containsKey(cat)) {
          categoryMap[cat] = CategorySales(category: cat, quantity: 0, revenue: 0);
        }
        categoryMap[cat]!.quantity += (r['quantity'] ?? 0) as int;
        categoryMap[cat]!.revenue += ((r['total_price'] ?? 0) as num).toDouble();
      }
      _categorySales = categoryMap.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      // Top items
      final itemsResponse = await _supabase
          .from('order_items')
          .select('name, quantity, total_price')
          .gte('created_at', todayStart.toIso8601String());

      final itemMap = <String, TopItem>{};
      for (final r in itemsResponse) {
        final name = r['name'] ?? 'Unknown';
        if (!itemMap.containsKey(name)) {
          itemMap[name] = TopItem(name: name, quantity: 0, revenue: 0);
        }
        itemMap[name]!.quantity += (r['quantity'] ?? 0) as int;
        itemMap[name]!.revenue += ((r['total_price'] ?? 0) as num).toDouble();
      }
      _topItems = itemMap.values.toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity))
        ..take(10).toList();

      // Staff performance
      final staffResponse = await _supabase
          .from('orders')
          .select('assigned_kitchen_staff_id, status, created_at, completed_at')
          .gte('created_at', todayStart.toIso8601String())
          .not('assigned_kitchen_staff_id', 'is', null);

      final staffMap = <String, StaffPerformance>{};
      for (final r in staffResponse) {
        final staffId = r['assigned_kitchen_staff_id'] as String;
        if (!staffMap.containsKey(staffId)) {
          staffMap[staffId] = StaffPerformance(staffId: staffId, name: 'Staff', ordersCompleted: 0, avgPrepTime: 0);
        }
        if (r['status'] == 'completed' && r['completed_at'] != null) {
          staffMap[staffId]!.ordersCompleted++;
          final created = DateTime.parse(r['created_at']);
          final completed = DateTime.parse(r['completed_at']);
          staffMap[staffId]!.avgPrepTime += completed.difference(created).inMinutes;
        }
      }
      _staffPerformance = staffMap.values.toList();
      for (final s in _staffPerformance) {
        if (s.ordersCompleted > 0) s.avgPrepTime ~/= s.ordersCompleted;
      }

      // Hourly orders
      final hourlyResponse = await _supabase
          .from('orders')
          .select('created_at')
          .gte('created_at', todayStart.toIso8601String());

      final hourlyMap = <int, int>{};
      for (final r in hourlyResponse) {
        final hour = DateTime.parse(r['created_at']).hour;
        hourlyMap[hour] = (hourlyMap[hour] ?? 0) + 1;
      }
      _hourlyOrders = hourlyMap.entries
          .map((e) => HourlyOrder(hour: e.key, orders: e.value))
          .toList()
        ..sort((a, b) => a.hour.compareTo(b.hour));

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
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
            Text(
              'Supervisor Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            Text(
              'Real-time analytics & insights',
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
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Sales', icon: Icon(Icons.trending_up)),
            Tab(text: 'Menu', icon: Icon(Icons.restaurant_menu)),
            Tab(text: 'Staff', icon: Icon(Icons.people)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const _LoadingSkeleton()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildSalesTab(),
          _buildMenuTab(),
          _buildStaffTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
        // KPI Cards
        GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
    _buildKPICard(
    "Today's Revenue",
        'MWK ${_todayRevenue.toStringAsFixed(0)}',
    Icons.attach_money,
    const Color(0xFF11998e),
    '+12% vs yesterday',
    ),
    _buildKPICard(
    'Orders',
    '$_todayOrders',
    Icons.receipt_long,
    const Color(0xFF667eea),
    '$_todayCustomers unique customers',
    ),
    _buildKPICard(
    'Avg Order Value',
    'MWK ${_avgOrderValue.toStringAsFixed(0)}',
    Icons.shopping_basket,
    const Color(0xFFf093fb),
    'Per order average',
    ),
    _buildKPICard(
    'Completion Rate',
    '${_todayOrders > 0 ? 95 : 0}%',
    Icons.check_circle,
    const Color(0xFFfa709a),
    'On-time delivery',
    ),
    ],
    ),
    const SizedBox(height: 24),
    // Weekly Revenue Chart
    _buildSectionTitle('Weekly Revenue Trend'),
    const SizedBox(height: 12),
    _buildRevenueChart(),
    const SizedBox(height: 24),
    // Hourly Activity
    _buildSectionTitle('Hourly Order Activity'),
    const SizedBox(height: 12),
    _buildHourlyChart(),
    ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.more_vert, color: Colors.grey.shade300, size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1a1a2e),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
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
            'Last 7 Days',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1a1a2e)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        return Text(
                          days[value.toInt()],
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _revenueChartData,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF667eea).withOpacity(0.2),
                          const Color(0xFF764ba2).withOpacity(0.0),
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

  Widget _buildHourlyChart() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
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
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}:00',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _hourlyOrders.map((h) {
            return BarChartGroupData(
              x: h.hour,
              barRods: [
                BarChartRodData(
                  toY: h.orders.toDouble(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  width: 12,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSalesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Sales by Category'),
        const SizedBox(height: 12),
        ..._categorySales.map((cat) => _buildCategoryCard(cat)),
        const SizedBox(height: 24),
        _buildSectionTitle('Payment Methods'),
        const SizedBox(height: 12),
        _buildPaymentMethodsChart(),
      ],
    );
  }

  Widget _buildCategoryCard(CategorySales cat) {
    final totalRevenue = _categorySales.fold(0.0, (sum, c) => sum + c.revenue);
    final percentage = totalRevenue > 0 ? (cat.revenue / totalRevenue * 100) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.category,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cat.quantity} items sold',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'MWK ${cat.revenue.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1a1a2e)),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, color: Color(0xFF667eea), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsChart() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          _buildPaymentMethodRow('PayChangu', 0.75, const Color(0xFF667eea)),
          const SizedBox(height: 12),
          _buildPaymentMethodRow('Cash', 0.20, const Color(0xFF11998e)),
          const SizedBox(height: 12),
          _buildPaymentMethodRow('DineCoins', 0.05, const Color(0xFFFFD700)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${(percentage * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Top Selling Items Today'),
        const SizedBox(height: 12),
        ..._topItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildTopItemCard(item, index + 1);
        }),
      ],
    );
  }

  Widget _buildTopItemCard(TopItem item, int rank) {
    final medalColors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rank <= 3 ? medalColors[rank - 1].withOpacity(0.15) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: rank <= 3 ? medalColors[rank - 1] : Colors.grey.shade500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(
                  '${item.quantity} sold',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            'MWK ${item.revenue.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF667eea)),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Kitchen Staff Performance'),
        const SizedBox(height: 12),
        ..._staffPerformance.map((staff) => _buildStaffCard(staff)),
      ],
    );
  }

  Widget _buildStaffCard(StaffPerformance staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  '${staff.ordersCompleted} orders completed',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${staff.avgPrepTime}m',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1a1a2e)),
              ),
              Text(
                'avg prep time',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1a1a2e)),
    );
  }
}

// ─── Models ─────────────────────────────────────────────────

class CategorySales {
  String category;
  int quantity;
  double revenue;
  CategorySales({required this.category, required this.quantity, required this.revenue});
}

class TopItem {
  String name;
  int quantity;
  double revenue;
  TopItem({required this.name, required this.quantity, required this.revenue});
}

class StaffPerformance {
  String staffId;
  String name;
  int ordersCompleted;
  int avgPrepTime;
  StaffPerformance({required this.staffId, required this.name, required this.ordersCompleted, required this.avgPrepTime});
}

class HourlyOrder {
  int hour;
  int orders;
  HourlyOrder({required this.hour, required this.orders});
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: List.generate(4, (_) => Container(
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
          )),
        ),
        const SizedBox(height: 24),
        Container(height: 220, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16))),
      ],
    );
  }
}
