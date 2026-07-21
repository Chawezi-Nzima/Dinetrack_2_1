import 'package:flutter/material.dart' hide Table;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/establishment_models.dart';

class TableSelector extends StatefulWidget {
  final String establishmentId;
  final Function(String) onTableSelected;

  const TableSelector({
    super.key,
    required this.establishmentId,
    required this.onTableSelected,
  });

  @override
  State<TableSelector> createState() => _TableSelectorState();
}

class _TableSelectorState extends State<TableSelector> {
  final SupabaseClient _supabase = Supabase.instance.client;  // FIXED: consistent with other files
  List<TableModel> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    try {
      // FIXED: Direct query aligned with schema columns
      final response = await _supabase
          .from('tables')
          .select()
          .eq('establishment_id', widget.establishmentId)
          .eq('is_available', true)
          .order('table_number');

      _tables = (response as List<dynamic>)
          .map((json) => TableModel.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading tables: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Error loading tables: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Your Table',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your table to place your order',
            style: TextStyle(
              color: Color(0xFF6B7280),
            ),
          ),
          const Divider(),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_tables.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No tables available'),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _tables.length,
                itemBuilder: (context, index) {
                  final table = _tables[index];
                  // FIXED: Check both is_available AND occupied_at for true availability
                  final isTrulyAvailable = table.isAvailable && table.occupiedAt == null;

                  return GestureDetector(
                    onTap: isTrulyAvailable
                        ? () {
                      widget.onTableSelected(table.id);
                      Navigator.pop(context);
                    }
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isTrulyAvailable
                            ? const Color(0xFFF8FAFC)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTrulyAvailable
                              ? const Color(0xFF4F46E5).withOpacity(0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isTrulyAvailable
                                ? Icons.table_restaurant
                                : Icons.table_restaurant_outlined,
                            color: isTrulyAvailable
                                ? const Color(0xFF4F46E5)
                                : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Table ${table.tableNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isTrulyAvailable
                                  ? const Color(0xFF1F2937)
                                  : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          // FIXED: Show capacity from schema
                          if (table.capacity != null)
                            Text(
                              '${table.capacity} seats',
                              style: TextStyle(
                                fontSize: 10,
                                color: isTrulyAvailable
                                    ? const Color(0xFF6B7280)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          if (!isTrulyAvailable)
                            Text(
                              table.occupiedAt != null ? 'Occupied' : 'Unavailable',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                              ),
                            ),
                          if (table.label != null && table.label!.isNotEmpty)
                            Text(
                              table.label!,
                              style: TextStyle(
                                fontSize: 10,
                                color: isTrulyAvailable
                                    ? const Color(0xFF6B7280)
                                    : Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}