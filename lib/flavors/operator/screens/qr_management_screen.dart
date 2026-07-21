import 'package:dinetrack_2_1/core/services/qr_code_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/user_models.dart';
import '../../../core/models/establishment_models.dart' as models;


/// ============================================================================
/// QR CODE MANAGEMENT SCREEN (Operator)
/// ============================================================================
///
/// Schema Consistency:
/// - Uses staff_assignments table for operator verification
/// - Uses tables table (table_number, label, is_available, qr_code_data, etc.)
/// - TableQrData is defined in qr_code_service.dart (not redefined here)
/// ============================================================================
///
/// Allows operators to:
/// - View all table QR codes
/// - Print/download QR codes
/// - Regenerate session tokens
/// - Preview QR code cards
///
/// Code Compatibility: UserProfile lives ONLY in user_models.dart
/// ============================================================================

class QrManagementScreen extends StatefulWidget {
  const QrManagementScreen({super.key});

  @override
  State<QrManagementScreen> createState() => _QrManagementScreenState();
}

class _QrManagementScreenState extends State<QrManagementScreen> {
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();
  final QrCodeService _qrService = QrCodeService();

  UserProfile? _currentUser;
  String? _establishmentId;
  List<models.TableModel> _tables = [];
  List<TableQrData> _tableQrData = [];
  bool _isLoading = true;
  int? _selectedTableIndex;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _currentUser = await _auth.getCurrentUserProfile();

      if (_currentUser == null) {
        _showError('User not authenticated. Please login again.');
        setState(() => _isLoading = false);
        return;
      }

      // Verify staff assignment per schema: staff_assignments table
      final staffInfo = await _supabase.getStaffAssignment(_currentUser!.id);
      if (staffInfo == null) {
        _showError('No staff assignment found. Contact admin.');
        setState(() => _isLoading = false);
        return;
      }

      _establishmentId = staffInfo['establishment_id'] as String?;

      if (_establishmentId != null) {
        await _loadTables();
      }
    } catch (e) {
      _showError('Initialization failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTables() async {
    try {
      _tables = await _supabase.getTables(_establishmentId!);
      _tableQrData = await _qrService.generateAllTableQrs(_establishmentId!);
    } catch (e) {
      debugPrint('Error loading tables: $e');
    }
  }

  Future<void> _regenerateQr(String tableId, int tableNumber) async {
    try {
      final newQrData = _qrService.generateTableQrData(
        establishmentId: _establishmentId!,
        tableId: tableId,
        tableNumber: tableNumber,
      );

      // Update the local data
      final index = _tableQrData.indexWhere((t) => t.table.id == tableId);
      if (index != -1) {
        setState(() {
          _tableQrData[index] = TableQrData(
            table: _tableQrData[index].table,
            qrData: newQrData,
            establishmentName: _tableQrData[index].establishmentName,
          );
        });
      }

      _showSnackBar('QR code regenerated for Table $tableNumber');
    } catch (e) {
      _showError('Failed to regenerate QR: $e');
    }
  }

  void _showQrPreview(TableQrData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
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
                _qrService.buildTableQrCard(
                  establishmentName: data.establishmentName,
                  tableNumber: data.table.tableNumber,
                  qrData: data.qrData,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: data.qrData));
                          _showSnackBar('QR data copied to clipboard');
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _regenerateQr(data.table.id, data.table.tableNumber),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Table QR Codes'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadTables,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tableQrData.isEmpty
          ? _buildEmptyState()
          : _buildQrGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code, size: 64, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          const Text('No tables configured', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text('Add tables to generate QR codes', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildQrGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _tableQrData.length,
      itemBuilder: (context, index) {
        final data = _tableQrData[index];
        return _QrCard(
          data: data,
          onTap: () => _showQrPreview(data),
          onRegenerate: () => _regenerateQr(data.table.id, data.table.tableNumber),
        );
      },
    );
  }
}

class _QrCard extends StatelessWidget {
  final TableQrData data;
  final VoidCallback onTap;
  final VoidCallback onRegenerate;

  const _QrCard({
    required this.data,
    required this.onTap,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: QrImageView(
                  data: data.qrData,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Table ${data.table.tableNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: onRegenerate,
                    icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF4F46E5)),
                    tooltip: 'Regenerate',
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: data.qrData));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20, color: Color(0xFF4F46E5)),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}