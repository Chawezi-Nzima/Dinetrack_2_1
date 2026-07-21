// lib/core/routing/role_based_router.dart

import 'package:flutter/material.dart';

import '../../flavors/customer/screens/customer_home.dart';
import '../../flavors/kitchen/screens/home_kitchen.dart';
import '../../flavors/operator/screens/operator_home_page.dart';
import '../../flavors/supervisor/screens/supervisor_dashboard.dart';
import '../../pages/login_page.dart';
import '../services/auth_service.dart';

/// Decides which home screen to show based on the authenticated user's role.
///
/// Can be used either:
///   1. As a widget: `home: const RoleBasedRouter()` in MaterialApp
///   2. As a navigation helper: `RoleBasedRouter.navigateToHome(context)` after login
class RoleBasedRouter extends StatelessWidget {
  const RoleBasedRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    // If not authenticated, send to login.
    if (!auth.isAuthenticated) {
      return const LoginPage();
    }

    // If still resolving the role, show loading.
    if (!auth.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Route by resolved role.
    return _routeByRole(auth.userType);
  }

  /// Static helper for post-login navigation.
  /// Call this after a successful sign-in to push-replace to the correct home.
  static Future<void> navigateToHome(BuildContext context) async {
    final auth = AuthService();

    // Ensure role is resolved before routing.
    if (!auth.isReady) {
      await auth.initialize();
    }

    if (!context.mounted) return;

    final target = _routeByRole(auth.userType);

    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => target),
          (route) => false, // Clear the entire navigation stack.
    );
  }

  /// Returns the correct home widget for a given role string.
  static Widget _routeByRole(String? userType) {
    switch (userType) {
      case 'customer':
        return const CustomerHome();
      case 'operator':
        return const OperatorHomePage();
      case 'kitchen':
        return const HomeKitchen();
      case 'supervisor':
        return const SupervisorDashboard();
      case 'admin':
        return const SupervisorDashboard();
      default:
      // Unknown or missing role — safe fallback to customer.
        return const CustomerHome();
    }
  }
}