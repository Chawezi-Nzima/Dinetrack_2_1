import 'package:dinetrack_2_1/core/services/notification_service.dart';
import 'package:dinetrack_2_1/core/services/qr_code_service.dart';
import 'package:dinetrack_2_1/shared/widgets/notification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// QR Scanner Screen for customers to scan table QR codes
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final QrCodeService _qrService = QrCodeService();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera
          MobileScanner(
            onDetect: (capture) {
              if (_isProcessing) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null) {
                  _handleScan(rawValue);
                  break;
                }
              }
            },
          ),
          // Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
          // Scan frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF667eea), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner markers
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(width: 30, height: 30, decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFF667eea), width: 4), left: BorderSide(color: Color(0xFF667eea), width: 4)),
                    )),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(width: 30, height: 30, decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFF667eea), width: 4), right: BorderSide(color: Color(0xFF667eea), width: 4)),
                    )),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(width: 30, height: 30, decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF667eea), width: 4), left: BorderSide(color: Color(0xFF667eea), width: 4)),
                    )),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(width: 30, height: 30, decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF667eea), width: 4), right: BorderSide(color: Color(0xFF667eea), width: 4)),
                    )),
                  ),
                ],
              ),
            ),
          ),
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const Text(
                    'Scan Table QR',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Point camera at the table QR code',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF667eea)),
                    SizedBox(height: 16),
                    Text('Joining table session...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleScan(String rawValue) async {
    setState(() => _isProcessing = true);

    try {
      // FIXED: Validate QR code against tables schema before parsing
      final tableData = await _validateQrCode(rawValue);
      if (tableData == null) {
        _showSnackBar('Invalid QR Code: This QR code is not recognized.');
        setState(() => _isProcessing = false);
        return;
      }

      // Parse QR data using validated table info
      final qrData = QrData(
        establishmentId: tableData['establishment_id'] as String,
        tableId: tableData['id'] as String,
        tableNumber: tableData['table_number'] as int,
        qrCode: rawValue,
      );

      // Create or join table session
      final sessionId = await _createOrJoinTableSession(qrData);

      if (sessionId != null && mounted) {
        Navigator.pop(context, {
          'establishment_id': qrData.establishmentId,
          'table_id': qrData.tableId,
          'table_number': qrData.tableNumber,
          'session_id': sessionId,
        });
      } else {
        _showSnackBar('Session Error: Could not join table session.');
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      debugPrint('QR scan error: $e');
      _showSnackBar('Error: Something went wrong. Please try again.');
      setState(() => _isProcessing = false);
    }
  }

  /// FIXED: Validate scanned QR against tables table schema
  /// Checks both qr_code (unique) and qr_code_data columns
  Future<Map<String, dynamic>?> _validateQrCode(String rawValue) async {
    try {
      // Try matching against qr_code (unique column) first
      final response = await _supabase
          .from('tables')
          .select()
          .eq('qr_code', rawValue)
          .eq('is_available', true)
          .maybeSingle();

      if (response != null) return response;

      // Fallback: try qr_code_data if stored differently
      final response2 = await _supabase
          .from('tables')
          .select()
          .eq('qr_code_data', rawValue)
          .eq('is_available', true)
          .maybeSingle();

      return response2;
    } catch (e) {
      debugPrint('QR validation error: $e');
      return null;
    }
  }

  /// FIXED: Create or join group session aligned with schema
  Future<String?> _createOrJoinTableSession(QrData qrData) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Error: Please login to join a table session.');
        return null;
      }

      // Check for existing active session for this table
      final existingSession = await _supabase
          .from('group_sessions')
          .select('id')
          .eq('establishment_id', qrData.establishmentId)
          .eq('status', 'active')
          .maybeSingle();

      String sessionId;

      if (existingSession != null) {
        // Join existing session
        sessionId = existingSession['id'] as String;

        // Add participant if not already joined
        await _supabase.from('group_session_participants').upsert({
          'session_id': sessionId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Create new session — FIXED: matches schema columns
        final newSession = await _supabase
            .from('group_sessions')
            .insert({
          'establishment_id': qrData.establishmentId,
          'created_by': userId,
          'status': 'active',  // FIXED: schema default, enum check
        })
            .select('id')
            .single();

        sessionId = newSession['id'] as String;

        // Add creator as first participant
        await _supabase.from('group_session_participants').insert({
          'session_id': sessionId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        });
      }

      // Update table occupancy
      await _supabase.from('tables').update({
        'occupied_at': DateTime.now().toIso8601String(),
        'last_activity_at': DateTime.now().toIso8601String(),
      }).eq('id', qrData.tableId);

      return sessionId;
    } catch (e) {
      debugPrint('Session creation error: $e');
      return null;
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
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
  }
}

/// FIXED: Schema-aligned QR data model
class QrData {
  final String establishmentId;
  final String tableId;
  final int tableNumber;
  final String? qrCode;

  QrData({
    required this.establishmentId,
    required this.tableId,
    required this.tableNumber,
    this.qrCode,
  });
}