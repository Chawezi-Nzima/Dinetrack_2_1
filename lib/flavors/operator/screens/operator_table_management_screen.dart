import 'package:dinetrack_2_1/core/services/qr_code_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';


/// Operator Table Management Screen
/// Manage tables, generate QR codes, view table status, handle reservations
class OperatorTableManagementScreen extends StatefulWidget {
  final String establishmentId;

  const OperatorTableManagementScreen({super.key, required this.establishmentId});

  @override
  State<OperatorTableManagementScreen> createState() => _OperatorTableManagementScreenState();
}

class _OperatorTableManagementScreenState extends State<OperatorTableManagementScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final QrCodeService _qrService = QrCodeService();
  late TabController _tabController;
  List<OperatorTable> _tables = [];
  List<TableReservation> _reservations = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load tables
      final tablesResponse = await _supabase
          .from('tables')
          .select('*, sessions:table_sessions!inner(status, user_id, created_at)')
          .eq('establishment_id', widget.establishmentId)
          .order('table_number');

      _tables = (tablesResponse as List<dynamic>)
          .map((json) => OperatorTable.fromJson(json))
          .toList();

      // Load reservations
      final reservationsResponse = await _supabase
          .from('reservations')
          .select('*, users:customer_id(full_name, phone)')
          .eq('establishment_id', widget.establishmentId)
          .gte('reservation_time', DateTime.now().toIso8601String())
          .order('reservation_time');

      _reservations = (reservationsResponse as List<dynamic>)
          .map((json) => TableReservation.fromJson(json))
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading tables: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTable() async {
    final numberController = TextEditingController();
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '4');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Table'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Table Number', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Table Name (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: capacityController, decoration: const InputDecoration(labelText: 'Capacity', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Table')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('tables').insert({
          'establishment_id': widget.establishmentId,
          'table_number': int.parse(numberController.text),
          'label': nameController.text.isEmpty ? null : nameController.text,
          'capacity': int.parse(capacityController.text),
          'is_available': true,
        });
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Table #${numberController.text} has been added.'),
              backgroundColor: const Color(0xFF667eea),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error adding table: $e');
      }
    }
  }

  Future<void> _generateQRForTable(OperatorTable table) async {
    setState(() => _isGenerating = true);

    try {
      final qrData = _qrService.generateTableQrData(
        establishmentId: widget.establishmentId,
        tableId: table.id,
        tableNumber: table.number,
      );

      // Update table with QR data
      await _supabase.from('tables').update({
        'qr_code_data': qrData,
        'last_activity_at': DateTime.now().toIso8601String(),
      }).eq('id', table.id);

      setState(() => _isGenerating = false);

      if (mounted) {
        _showQRDialog(table, qrData);
      }
    } catch (e) {
      debugPrint('Error generating QR: $e');
      setState(() => _isGenerating = false);
    }
  }

  void _showQRDialog(OperatorTable table, String qrData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF667eea).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: qrData, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Table #${table.number}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (table.label != null) Text(table.label!, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Capacity: ${table.capacity} people', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () { /* print logic */ },
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _toggleTableStatus(OperatorTable table) async {
    await _supabase.from('tables').update({
      'is_available': !table.isAvailable,
      'last_activity_at': DateTime.now().toIso8601String(),
    }).eq('id', table.id);
    _loadData();
  }

  Future<void> _deleteTable(OperatorTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Table?'),
        content: Text('Are you sure you want to delete Table #${table.number}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('tables').delete().eq('id', table.id);
      _loadData();
    }
  }

  Future<void> _updateReservationStatus(String reservationId, String status) async {
    await _supabase.from('reservations').update({
      'status': status,
    }).eq('id', reservationId);
    _loadData();
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
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Table Management', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          Text('Manage tables, QR codes & reservations', style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w400)),
        ]),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF667eea),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            _buildTab('Tables', _tables.where((t) => t.isAvailable).length, const Color(0xFF667eea)),
            _buildTab('Floor Plan', 0, Colors.orange),
            _buildTab('Reservations', _reservations.where((r) => r.status == 'pending').length, Colors.green),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const _LoadingSkeleton()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildTablesTab(),
          _buildFloorPlanTab(),
          _buildReservationsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTable,
        backgroundColor: const Color(0xFF667eea),
        icon: const Icon(Icons.add),
        label: const Text('Add Table'),
      ),
    );
  }

  Widget _buildTab(String label, int count, Color color) {
    return Tab(
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
        ],
      ]),
    );
  }

  Widget _buildTablesTab() {
    if (_tables.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.table_restaurant_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('No tables yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)), const SizedBox(height: 8), Text('Add your first table to get started', style: TextStyle(color: Colors.grey.shade400))]));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats row
        Row(children: [
          _buildTableStat('Total Tables', '${_tables.length}', Icons.table_restaurant, const Color(0xFF667eea)),
          const SizedBox(width: 12),
          _buildTableStat('Occupied', '${_tables.where((t) => t.isOccupied).length}', Icons.people, Colors.orange),
          const SizedBox(width: 12),
          _buildTableStat('Available', '${_tables.where((t) => !t.isOccupied && t.isAvailable).length}', Icons.check_circle, Colors.green),
        ]),
        const SizedBox(height: 20),
        // Table grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _tables.length,
          itemBuilder: (context, index) => _buildTableCard(_tables[index]),
        ),
      ],
    );
  }

  Widget _buildTableStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1a1a2e))),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildTableCard(OperatorTable table) {
    final statusColor = table.isOccupied ? Colors.orange : table.isAvailable ? Colors.green : Colors.grey;
    final statusText = table.isOccupied ? 'OCCUPIED' : table.isAvailable ? 'AVAILABLE' : 'INACTIVE';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
        border: table.isOccupied ? Border.all(color: Colors.orange.shade300, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${table.number}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1a1a2e))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (table.label != null) Text(table.label!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.people, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('Capacity: ${table.capacity}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ]),

                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _generateQRForTable(table),
                        icon: _isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.qr_code, size: 16),
                        label: const Text('QR', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(table.isAvailable ? Icons.toggle_on : Icons.toggle_off, color: table.isAvailable ? Colors.green : Colors.grey),
                      onPressed: () => _toggleTableStatus(table),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _deleteTable(table),
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

  Widget _buildFloorPlanTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.view_quilt, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Floor Plan View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Drag and drop tables to arrange your floor plan', style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildReservationsTab() {
    if (_reservations.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('No reservations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)), const SizedBox(height: 8), Text('Reservations will appear here', style: TextStyle(color: Colors.grey.shade400))]));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Upcoming Reservations'),
        const SizedBox(height: 12),
        ..._reservations.map((res) => _buildReservationCard(res)),
      ],
    );
  }

  Widget _buildReservationCard(TableReservation res) {
    final statusColors = {'pending': Colors.orange, 'confirmed': const Color(0xFF667eea), 'seated': Colors.green, 'completed': const Color(0xFF11998e), 'cancelled': Colors.red};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: const Color(0xFF667eea).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${res.reservationTime.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF667eea))),
            Text('${res.reservationTime.month}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(res.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${res.partySize} guests • Table #${res.tableNumber ?? "TBD"}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text('${_formatTime(res.reservationTime)} • ${res.phone ?? "No phone"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (statusColors[res.status] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(res.status.toUpperCase(), style: TextStyle(color: statusColors[res.status] ?? Colors.grey, fontSize: 10, fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          if (res.status == 'pending')
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.check, color: Colors.green, size: 20), onPressed: () => _updateReservationStatus(res.id, 'confirmed'), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => _updateReservationStatus(res.id, 'cancelled'), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
            ]),
        ]),
      ]),
    );
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1a1a2e)));
  }
}

// ─── Models ─────────────────────────────────────────────────

class OperatorTable {
  final String id;
  final int number;  // maps to table_number in schema
  final String? label;  // maps to label in schema
  final int capacity;
  final bool isAvailable;  // maps to is_available in schema
  final String? qrCodeData;  // maps to qr_code_data in schema
  final DateTime? occupiedAt;  // maps to occupied_at in schema

  OperatorTable({
    required this.id,
    required this.number,
    this.label,
    required this.capacity,
    required this.isAvailable,
    this.qrCodeData,
    this.occupiedAt,
  });

  factory OperatorTable.fromJson(Map<String, dynamic> json) {
    return OperatorTable(
      id: json['id'] ?? '',
      number: json['table_number'] ?? 0,
      label: json['label'],
      capacity: json['capacity'] ?? 4,
      isAvailable: json['is_available'] ?? true,
      qrCodeData: json['qr_code_data'],
      occupiedAt: json['occupied_at'] != null
          ? DateTime.parse(json['occupied_at'])
          : null,
    );
  }

  bool get isOccupied => occupiedAt != null || !isAvailable;
}



class TableReservation {
  final String id;
  final String customerName;
  final String? phone;
  final int partySize;  // maps to party_size in schema
  final int? tableNumber;
  final DateTime reservationTime;  // maps to reservation_time in schema
  final String status;
  final String? specialRequests;  // maps to special_requests in schema

  TableReservation({
    required this.id,
    required this.customerName,
    this.phone,
    required this.partySize,
    this.tableNumber,
    required this.reservationTime,
    required this.status,
    this.specialRequests,
  });

  factory TableReservation.fromJson(Map<String, dynamic> json) {
    return TableReservation(
      id: json['id'] ?? '',
      customerName: json['users']?['full_name'] ?? 'Unknown',
      phone: json['users']?['phone'] ?? json['phone'],
      partySize: json['party_size'] ?? 2,
      tableNumber: json['table_id'] != null ? null : null,
      reservationTime: DateTime.parse(json['reservation_time'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'pending',
      specialRequests: json['special_requests'],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [Row(children: [Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)))), const SizedBox(width: 12), Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)))), const SizedBox(width: 12), Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14))))]), const SizedBox(height: 20), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85, children: List.generate(4, (_) => Container(decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)))))]);
  }
}