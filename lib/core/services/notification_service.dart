import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dinetrack_2_1/core/services/auth_service.dart';
import 'package:dinetrack_2_1/core/services/supabase_service.dart';

/// ============================================================================
/// NOTIFICATION SERVICE - Supabase Realtime (NO Firebase)
/// ============================================================================
///
/// Pure Supabase-based notification system using:
/// - Realtime subscriptions to 'notifications' table
/// - In-app notification overlay with badge counts
/// - Local notification history with read/unread status
/// - Push to specific users, roles, or broadcast
///
/// Database Schema Required:
/// CREATE TABLE notifications (
///   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
///   user_id UUID REFERENCES users(id) NULL,       -- NULL = broadcast
///   role VARCHAR(20) NULL,                          -- 'operator', 'kitchen', etc.
///   establishment_id UUID NULL,                   -- NULL = global
///   title VARCHAR(255) NOT NULL,
///   body TEXT NOT NULL,
///   type VARCHAR(50) NOT NULL,                      -- 'order', 'payment', 'assist', 'system'
///   data JSONB NULL,                                -- extra payload
///   is_read BOOLEAN DEFAULT FALSE,
///   is_dismissed BOOLEAN DEFAULT FALSE,
///   priority VARCHAR(20) DEFAULT 'normal',          -- 'low', 'normal', 'high', 'urgent'
///   created_at TIMESTAMPTZ DEFAULT NOW(),
///   read_at TIMESTAMPTZ NULL
/// );
///
/// CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
/// CREATE INDEX idx_notifications_role ON notifications(role, is_read);
///
/// Code Compatibility: UserProfile lives ONLY in user_models.dart
/// ============================================================================

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  // --- State ---
  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get urgentCount => _notifications.where((n) => n.priority == NotificationPriority.urgent && !n.isRead).length;

  bool _isSubscribed = false;
  RealtimeChannel? _realtimeChannel;

  // --- Callbacks ---
  void Function(AppNotification)? onNewNotification;
  void Function(int unreadCount)? onUnreadCountChanged;

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initialize the notification service and subscribe to realtime updates.
  Future<void> initialize() async {
    if (_isSubscribed) return;
    await _loadNotifications();
    _subscribeToRealtime();
    _isSubscribed = true;
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }

  // ==========================================================================
  // REALTIME SUBSCRIPTIONS (Supabase - NO Firebase)
  // ==========================================================================

  void _subscribeToRealtime() {
    final userId = _auth.currentUserId;
    if (userId == null) return;

    try {
      _realtimeChannel = _supabase.client
          .channel('notifications_$userId')
          .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          _handleNewNotification(payload.newRecord);
        },
      )
          .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'role',
          value: _auth.userType ?? '',
        ),
        callback: (payload) {
          _handleNewNotification(payload.newRecord);
        },
      )
          .subscribe();

      developer.log('Notification realtime subscribed', name: 'NotificationService');
    } catch (e) {
      developer.log('Realtime subscription error: $e', name: 'NotificationService');
    }
  }

  void _unsubscribeFromRealtime() {
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
      _isSubscribed = false;
    } catch (e) {
      developer.log('Unsubscribe error: $e', name: 'NotificationService');
    }
  }

  void _handleNewNotification(Map<String, dynamic> data) {
    final notification = AppNotification.fromJson(data);

    // Add to list if not already present
    if (!_notifications.any((n) => n.id == notification.id)) {
      _notifications.insert(0, notification);
      notifyListeners();

      // Trigger callbacks
      onNewNotification?.call(notification);
      onUnreadCountChanged?.call(unreadCount);

      developer.log('New notification: ${notification.title}', name: 'NotificationService');
    }
  }

  // ==========================================================================
  // DATA LOADING
  // ==========================================================================

  Future<void> _loadNotifications() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return;

      final response = await _supabase.client
          .from('notifications')
          .select()
          .or('user_id.eq.$userId,role.eq.${_auth.userType ?? ''}')
          .eq('is_dismissed', false)
          .order('created_at', ascending: false)
          .limit(50);

      final loaded = (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();

      _notifications.clear();
      _notifications.addAll(loaded);
      notifyListeners();
      onUnreadCountChanged?.call(unreadCount);
    } catch (e) {
      developer.log('Error loading notifications: $e', name: 'NotificationService');
    }
  }

  Future<void> refreshNotifications() async {
    await _loadNotifications();
  }

  // ==========================================================================
  // NOTIFICATION ACTIONS
  // ==========================================================================

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
        onUnreadCountChanged?.call(unreadCount);
      }
    } catch (e) {
      developer.log('Error marking as read: $e', name: 'NotificationService');
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return;

      await _supabase.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .or('user_id.eq.$userId,role.eq.${_auth.userType ?? ''}')
          .eq('is_read', false);

      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      notifyListeners();
      onUnreadCountChanged?.call(0);
    } catch (e) {
      developer.log('Error marking all as read: $e', name: 'NotificationService');
    }
  }

  /// Dismiss a notification (hides it permanently).
  Future<void> dismissNotification(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .update({'is_dismissed': true})
          .eq('id', notificationId);

      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      onUnreadCountChanged?.call(unreadCount);
    } catch (e) {
      developer.log('Error dismissing notification: $e', name: 'NotificationService');
    }
  }

  /// Delete old notifications (cleanup).
  Future<void> deleteOldNotifications({int daysOld = 30}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: daysOld));
      await _supabase.client
          .from('notifications')
          .delete()
          .lt('created_at', cutoff.toIso8601String());

      await _loadNotifications();
    } catch (e) {
      developer.log('Error deleting old notifications: $e', name: 'NotificationService');
    }
  }

  // ==========================================================================
  // SENDING NOTIFICATIONS (For internal use by other services)
  // ==========================================================================

  /// Send a notification to a specific user.
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? data,
  }) async {
    await _sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      priority: priority,
      data: data,
    );
  }

  /// Send a notification to all users with a specific role.
  static Future<void> sendToRole({
    required String role,
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
    NotificationPriority priority = NotificationPriority.normal,
    String? establishmentId,
    Map<String, dynamic>? data,
  }) async {
    await _sendNotification(
      role: role,
      establishmentId: establishmentId,
      title: title,
      body: body,
      type: type,
      priority: priority,
      data: data,
    );
  }

  /// Broadcast a notification to all users.
  static Future<void> broadcast({
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? data,
  }) async {
    await _sendNotification(
      title: title,
      body: body,
      type: type,
      priority: priority,
      data: data,
    );
  }

  static Future<void> _sendNotification({
    String? userId,
    String? role,
    String? establishmentId,
    required String title,
    required String body,
    required NotificationType type,
    required NotificationPriority priority,
    Map<String, dynamic>? data,
  }) async {
    try {
      final supabase = SupabaseService();
      await supabase.client.from('notifications').insert({
        'user_id': userId,
        'role': role,
        'establishment_id': establishmentId,
        'title': title,
        'body': body,
        'type': type.name,
        'priority': priority.name,
        'data': data,
      });
    } catch (e) {
      developer.log('Error sending notification: $e', name: 'NotificationService');
    }
  }
}

// =============================================================================
// NOTIFICATION MODEL
// =============================================================================

enum NotificationType {
  order,
  payment,
  assist,
  system,
  promotion,
  reservation,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

class AppNotification {
  final String id;
  final String? userId;
  final String? role;
  final String? establishmentId;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final bool isRead;
  final bool isDismissed;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    this.userId,
    this.role,
    this.establishmentId,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    this.data,
    this.isRead = false,
    this.isDismissed = false,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      role: json['role'] as String?,
      establishmentId: json['establishment_id'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      priority: NotificationPriority.values.firstWhere(
            (e) => e.name == json['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      isDismissed: json['is_dismissed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
    );
  }

  AppNotification copyWith({
    bool? isRead,
    bool? isDismissed,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      role: role,
      establishmentId: establishmentId,
      title: title,
      body: body,
      type: type,
      priority: priority,
      data: data,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.urgent:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.normal:
        return const Color(0xFF4F46E5);
      case NotificationPriority.low:
        return Colors.grey;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case NotificationType.order:
        return Icons.receipt_long;
      case NotificationType.payment:
        return Icons.payments;
      case NotificationType.assist:
        return Icons.support_agent;
      case NotificationType.system:
        return Icons.info;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.reservation:
        return Icons.event;
    }
  }
}