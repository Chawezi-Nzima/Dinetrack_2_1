import 'package:dinetrack_2_1/core/services/notification_service.dart';
import 'package:dinetrack_2_1/flavors/customer/screens/notification_center_screen.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// NOTIFICATION BADGE & OVERLAY
/// ============================================================================
///
/// Wraps the app to provide:
/// - Real-time notification badge on navigation items
/// - In-app toast notifications for new alerts
/// - Notification bell with unread count
/// - Tap to open NotificationCenterScreen
///
/// Usage: Wrap your Scaffold or BottomNav with NotificationOverlay
///
/// NO Firebase - Pure Supabase Realtime
/// ============================================================================

class NotificationOverlay extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, int unreadCount, VoidCallback onTap)? badgeBuilder;

  const NotificationOverlay({
    super.key,
    required this.child,
    this.badgeBuilder,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  final NotificationService _notificationService = NotificationService();
  final List<AppNotification> _toastQueue = [];
  AppNotification? _currentToast;

  @override
  void initState() {
    super.initState();
    _notificationService.onNewNotification = _handleNewNotification;
    _notificationService.onUnreadCountChanged = _onUnreadCountChanged;
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _notificationService.onNewNotification = null;
    _notificationService.onUnreadCountChanged = null;
    super.dispose();
  }

  void _handleNewNotification(AppNotification notification) {
    if (notification.priority == NotificationPriority.urgent ||
        notification.priority == NotificationPriority.high) {
      _showToast(notification);
    }
  }

  void _onUnreadCountChanged(int count) {
    // Badge count is handled by listening to NotificationService
    if (mounted) setState(() {});
  }

  void _showToast(AppNotification notification) {
    setState(() {
      if (_currentToast == null) {
        _currentToast = notification;
      } else {
        _toastQueue.add(notification);
      }
    });

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          if (_toastQueue.isNotEmpty) {
            _currentToast = _toastQueue.removeAt(0);
          } else {
            _currentToast = null;
          }
        });
      }
    });
  }

  void _dismissToast() {
    if (mounted) {
      setState(() {
        if (_toastQueue.isNotEmpty) {
          _currentToast = _toastQueue.removeAt(0);
        } else {
          _currentToast = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Toast overlay
        if (_currentToast != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _NotificationToast(
              notification: _currentToast!,
              onDismiss: _dismissToast,
              onTap: () {
                _dismissToast();
                _openNotificationCenter(context);
              },
            ),
          ),
      ],
    );
  }

  void _openNotificationCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NotificationCenterScreen()),
    );
  }
}

// =============================================================================
// NOTIFICATION TOAST WIDGET
// =============================================================================

class _NotificationToast extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationToast({
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: notification.priorityColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: notification.priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(notification.typeIcon, color: notification.priorityColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// NOTIFICATION BADGE ICON
// =============================================================================

class NotificationBadgeIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const NotificationBadgeIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: size),
          // Use AnimatedBuilder or StreamBuilder for real-time updates
          _NotificationBadge(),
        ],
      ),
    );
  }
}

class _NotificationBadge extends StatefulWidget {
  @override
  State<_NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<_NotificationBadge> {
  final NotificationService _service = NotificationService();
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _service.onUnreadCountChanged = (count) {
      if (mounted) setState(() => _count = count);
    };
    _count = _service.unreadCount;
  }

  @override
  void dispose() {
    _service.onUnreadCountChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();

    return Positioned(
      right: -6,
      top: -6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          _count > 99 ? '99+' : '$_count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
