import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dinetrack_2_1/core/services/auth_service.dart';
import 'package:dinetrack_2_1/core/services/supabase_service.dart';

/// ============================================================================
/// QR CODE SERVICE - Table Ordering System
/// ============================================================================
///
/// Handles QR code generation for tables, scanning for customers,
/// and table session management for group ordering.
///
/// QR Data Format (JSON):
/// {
///   "v": 1,                    // version
///   "e": "establishment_id",   // establishment UUID
///   "t": "table_id",           // table UUID
///   "n": 5,                    // table number
///   "s": "session_token"       // unique session for this seating
/// }
///
/// Code Compatibility: UserProfile lives ONLY in user_models.dart
/// ============================================================================

class QrCodeService {
  static final QrCodeService _instance = QrCodeService._internal();
  factory QrCodeService() => _instance;
  QrCodeService._internal();

  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  // --- QR Data Version ---
  static const int _qrVersion = 1;

  // ==========================================================================
  // QR CODE GENERATION (For Operators - Print/Display)
  // ==========================================================================

  /// Generates QR data payload for a table.
  String generateTableQrData({
    required String establishmentId,
    required String tableId,
    required int tableNumber,
  }) {
    final sessionToken = _generateSessionToken();
    final data = {
      'v': _qrVersion,
      'e': establishmentId,
      't': tableId,
      'n': tableNumber,
      's': sessionToken,
    };
    return jsonEncode(data);
  }

  /// Creates a QR code widget for display/printing.
  Widget buildQrCode({
    required String data,
    double size = 200,
    Color backgroundColor = Colors.white,
    Color foregroundColor = Colors.black,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            gapless: true,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  /// Generates a printable QR code card widget for table placement.
  Widget buildTableQrCard({
    required String establishmentName,
    required int tableNumber,
    required String qrData,
    String? establishmentLogo,
    String? wifiName,
    String? wifiPassword,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (establishmentLogo != null)
                CircleAvatar(
                  backgroundImage: NetworkImage(establishmentLogo),
                  radius: 20,
                )
              else
                const Icon(Icons.restaurant, size: 32, color: Color(0xFF4F46E5)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  establishmentName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // QR Code
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
          ),
          const SizedBox(height: 16),
          // Table Number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Table $tableNumber',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F46E5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan to order & pay',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          // WiFi Info
          if (wifiName != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text('WiFi: $wifiName', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                if (wifiPassword != null) ...[
                  const SizedBox(width: 12),
                  Text('Pass: $wifiPassword', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // QR CODE SCANNING (For Customers)
  // ==========================================================================

  /// Scans a QR code and returns the parsed data.
  /// Returns null if scan is cancelled or data is invalid.
  Future<QrScanResult?> scanQrCode(BuildContext context) async {
    final result = await Navigator.of(context).push<QrScanResult>(
      MaterialPageRoute(
        builder: (context) => const _QrScannerScreen(),
      ),
    );
    return result;
  }

  /// Parses raw QR string data into structured result.
  QrScanResult? parseQrData(String rawData) {
    try {
      final json = jsonDecode(rawData) as Map<String, dynamic>;

      // Validate version
      final version = json['v'] as int?;
      if (version == null || version > _qrVersion) {
        developer.log('Unsupported QR version: $version', name: 'QrCodeService');
        return null;
      }

      return QrScanResult(
        establishmentId: json['e'] as String,
        tableId: json['t'] as String,
        tableNumber: json['n'] as int,
        sessionToken: json['s'] as String,
        version: version,
      );
    } catch (e) {
      developer.log('Failed to parse QR data: $e', name: 'QrCodeService');
      return null;
    }
  }

  // ==========================================================================
  // TABLE SESSION MANAGEMENT
  // ==========================================================================

  /// Creates or joins a table session for group ordering.
  /// Returns the session ID that all customers at this table share.
  Future<String?> createOrJoinTableSession(QrScanResult qrData) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return null;

      // Check if there's an active session for this table
      final existingSession = await _supabase.client
          .from('table_sessions')
          .select()
          .eq('table_id', qrData.tableId)
          .eq('status', 'active')
          .maybeSingle();

      if (existingSession != null) {
        // Join existing session
        final sessionId = existingSession['id'] as String;

        // Add user to session participants
        await _supabase.client.from('session_participants').insert({
          'session_id': sessionId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        });

        return sessionId;
      }

      // Create new session
      final newSession = await _supabase.client
          .from('table_sessions')
          .insert({
        'table_id': qrData.tableId,
        'establishment_id': qrData.establishmentId,
        'session_token': qrData.sessionToken,
        'status': 'active',
        'created_by': userId,
      })
          .select()
          .single();

      final sessionId = newSession['id'] as String;

      // Add creator as first participant
      await _supabase.client.from('session_participants').insert({
        'session_id': sessionId,
        'user_id': userId,
        'is_host': true,
        'joined_at': DateTime.now().toIso8601String(),
      });

      return sessionId;
    } catch (e) {
      developer.log('Error creating/joining table session: $e', name: 'QrCodeService');
      return null;
    }
  }

  /// Gets all participants in a table session.
  Future<List<Map<String, dynamic>>> getSessionParticipants(String sessionId) async {
    try {
      final response = await _supabase.client
          .from('session_participants')
          .select('*, users(full_name, avatar_url)')
          .eq('session_id', sessionId)
          .eq('is_active', true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log('Error getting session participants: $e', name: 'QrCodeService');
      return [];
    }
  }

  /// Leaves the current table session.
  Future<void> leaveSession(String sessionId) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return;

      await _supabase.client
          .from('session_participants')
          .update({'is_active': false, 'left_at': DateTime.now().toIso8601String()})
          .eq('session_id', sessionId)
          .eq('user_id', userId);

      // Check if any participants remain
      final remaining = await _supabase.client
          .from('session_participants')
          .select('id')
          .eq('session_id', sessionId)
          .eq('is_active', true);

      if ((remaining as List).isEmpty) {
        // Close session if no one left
        await _supabase.client
            .from('table_sessions')
            .update({'status': 'closed', 'ended_at': DateTime.now().toIso8601String()})
            .eq('id', sessionId);
      }
    } catch (e) {
      developer.log('Error leaving session: $e', name: 'QrCodeService');
    }
  }

  /// Gets the active session for a table (if any).
  Future<Map<String, dynamic>?> getActiveSession(String tableId) async {
    try {
      return await _supabase.client
          .from('table_sessions')
          .select()
          .eq('table_id', tableId)
          .eq('status', 'active')
          .maybeSingle();
    } catch (e) {
      developer.log('Error getting active session: $e', name: 'QrCodeService');
      return null;
    }
  }

  // ==========================================================================
  // BATCH QR GENERATION (For Operators)
  // ==========================================================================

  /// Generates QR codes for all tables in an establishment.
  Future<List<TableQrData>> generateAllTableQrs(String establishmentId) async {
    try {
      final tables = await _supabase.getTables(establishmentId);
      final establishment = await _supabase.getEstablishment(establishmentId);
      final establishmentName = establishment?['name'] ?? 'Restaurant';

      return tables.map((table) {
        final qrData = generateTableQrData(
          establishmentId: establishmentId,
          tableId: table.id,
          tableNumber: table.tableNumber,
        );
        return TableQrData(
          table: table,
          qrData: qrData,
          establishmentName: establishmentName,
        );
      }).toList();
    } catch (e) {
      developer.log('Error generating table QR codes: $e', name: 'QrCodeService');
      return [];
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String _generateSessionToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (1000 + DateTime.now().microsecond % 9000);
    return 'sess_${timestamp}_$random';
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class QrScanResult {
  final String establishmentId;
  final String tableId;
  final int tableNumber;
  final String sessionToken;
  final int version;

  const QrScanResult({
    required this.establishmentId,
    required this.tableId,
    required this.tableNumber,
    required this.sessionToken,
    required this.version,
  });

  @override
  String toString() {
    return 'QrScanResult(table: $tableNumber, establishment: $establishmentId)';
  }
}

class TableQrData {
  final dynamic table;
  final String qrData;
  final String establishmentName;

  const TableQrData({
    required this.table,
    required this.qrData,
    required this.establishmentName,
  });
}

// =============================================================================
// QR SCANNER SCREEN
// =============================================================================

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _isScanning = true;
  String? _errorMessage;

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isScanning = false);

    final qrService = QrCodeService();
    final result = qrService.parseQrData(barcode.rawValue!);

    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _isScanning = true;
        _errorMessage = 'Invalid QR code. Please scan a valid table code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),

          // Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
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
                border: Border.all(color: const Color(0xFF4F46E5), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 48, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'Align QR code within frame',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Text(
                    'Scan Table QR',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}