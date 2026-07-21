import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/user_models.dart';
import '../../../core/models/menu_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/loyalty_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../pages/login_page.dart';
import 'customer_home.dart';
import 'favorites_screen.dart';
import 'order_history_screen.dart';
import 'dinecoins_screen.dart';
import 'order_tracking_screen.dart';
import 'notification_center_screen.dart';

/// Customer Profile & Settings Screen
/// Profile info, order history, addresses, preferences, app settings
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final AuthService _authService = AuthService();
  final LoyaltyService _loyaltyService = LoyaltyService();
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? _profile;
  LoyaltyAccount? _loyaltyAccount;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _biometricEnabled = false;
  int _currentNavIndex = 3; // Profile tab is index 3

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSettings();
  }

  /// Load user settings from Supabase
  Future<void> _loadSettings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await _supabase
            .from('user_settings')
            .select('notifications_enabled, dark_mode, biometric_login')
            .eq('user_id', userId)
            .maybeSingle();
        if (response != null && mounted) {
          setState(() {
            _notificationsEnabled = response['notifications_enabled'] ?? true;
            _darkModeEnabled = response['dark_mode'] ?? false;
            _biometricEnabled = response['biometric_login'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Save user settings to Supabase
  Future<void> _saveSettings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('user_settings').upsert({
        'user_id': userId,
        'notifications_enabled': _notificationsEnabled,
        'dark_mode': _darkModeEnabled,
        'biometric_login': _biometricEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      _profile = await _authService.getCurrentUserProfile();
      _loyaltyAccount = await _loyaltyService.getAccount();

      // Load recent orders
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final ordersResponse = await _supabase
            .from('orders')
            .select('*, establishment:establishments(name), items:order_items(count)')
            .eq('customer_id', userId)
            .order('created_at', ascending: false)
            .limit(10);
        _recentOrders = (ordersResponse as List<dynamic>).cast<Map<String, dynamic>>();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile({String? fullName, String? phone, DateTime? dateOfBirth}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (dateOfBirth != null) updates['date_of_birth'] = dateOfBirth.toIso8601String();
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('users').update(updates).eq('id', userId);
      await _loadProfile();

      if (mounted) {
        _showSnackBar('Profile updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // FIXED LOGOUT - Uses MaterialPageRoute to LoginPage
  // ═══════════════════════════════════════════════════════════════
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Error during sign out: $e');
        if (mounted) {
          _showSnackBar('Failed to sign out. Please try again.');
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION - Matches customer_home.dart structure
  // ═══════════════════════════════════════════════════════════════
  void _onNavItemTapped(int index) {
    if (index == _currentNavIndex) return;

    switch (index) {
      case 0:
      // Home: Use pushReplacement to avoid stacking
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CustomerHome()),
        );
        break;
      case 1:
      // Favorites: Navigate to CustomerHome (favorites needs cart context)
      // Since FavoritesScreen requires onAddToCart callback which needs
      // establishment/menu context, we go to CustomerHome instead
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CustomerHome()),
        );
        break;
      case 2:
      // Orders: Push OrderHistoryScreen (works standalone)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
        );
        break;
      case 3:
      // Profile: Already here, do nothing
        break;
    }
  }

  void _showEditProfileDialog() {
    final fullNameController = TextEditingController(text: _profile?.fullName ?? '');
    final phoneController = TextEditingController(text: _profile?.phone ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateProfile(
                fullName: fullNameController.text,
                phone: phoneController.text,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          // Profile Header
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF1a1a2e),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667eea),
                                    Color(0xFF764ba2),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _showEditProfileDialog(),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF1a1a2e),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_profile?.fullName ?? ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile?.email ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Loyalty badge
                        if (_loyaltyAccount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _loyaltyAccount!.tierColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _loyaltyAccount!.tierColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _loyaltyAccount!.tierIcon,
                                  color: _loyaltyAccount!.tierColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_loyaltyAccount!.tierName} • ${_loyaltyAccount!.availableCoins} DineCoins',
                                  style: TextStyle(
                                    color: _loyaltyAccount!.tierColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  Row(
                    children: [
                      _buildProfileStat(
                        'Orders',
                        '${_recentOrders.length}',
                        Icons.receipt_long,
                        const Color(0xFF667eea),
                      ),
                      const SizedBox(width: 12),
                      _buildProfileStat(
                        'Coins',
                        '${_loyaltyAccount?.availableCoins ?? 0}',
                        Icons.monetization_on,
                        const Color(0xFFFFD700),
                      ),
                      const SizedBox(width: 12),
                      _buildProfileStat(
                        'Tier',
                        _loyaltyAccount?.tierName ?? 'Bronze',
                        Icons.emoji_events,
                        _loyaltyAccount?.tierColor ??
                            const Color(0xFFCD7F32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Recent Orders
                  _buildSectionTitle('Recent Orders'),
                  const SizedBox(height: 12),
                  if (_recentOrders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No orders yet',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._recentOrders.take(5).map(
                          (order) => _buildOrderHistoryCard(order),
                    ),
                  const SizedBox(height: 24),
                  // Settings
                  _buildSectionTitle('Settings'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(),
                  const SizedBox(height: 24),
                  // Account Actions
                  _buildSectionTitle('Account'),
                  const SizedBox(height: 12),
                  _buildAccountActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      // BOTTOM NAVIGATION BAR - Matches customer_home.dart exactly
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF667eea),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _getInitials() {
    final name = _profile?.fullName ?? '';
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildProfileStat(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Expanded(
      child: Container(
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1a1a2e),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistoryCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'placed';
    final statusColors = {
      'placed': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': const Color(0xFF667eea),
      'ready': Colors.green,
      'served': Colors.teal,
      'completed': const Color(0xFF11998e),
      'cancelled': Colors.red,
    };
    final establishmentName = order['establishment']?['name'] ?? 'Unknown';
    final itemCount = order['items']?[0]?['count'] ?? 0;
    final totalAmount = (order['total_amount'] ?? 0).toDouble();
    final createdAt = DateTime.parse(
      order['created_at'] ?? DateTime.now().toIso8601String(),
    );

    return GestureDetector(
      onTap: () => _navigateToOrderDetail(order['id']),
      child: Container(
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (statusColors[status] ?? Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant,
                  color: statusColors[status] ?? Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    establishmentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '$itemCount items • ${status.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'MWK ${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF667eea),
                  ),
                ),
                Text(
                  '${createdAt.day}/${createdAt.month}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to order detail screen
  void _navigateToOrderDetail(String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
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
          _buildSettingTile(
            icon: Icons.notifications,
            iconColor: const Color(0xFF667eea),
            title: 'Push Notifications',
            subtitle: 'Order updates, promotions & alerts',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                _saveSettings();
                // Notification toggle is persisted to Supabase.
                // If you have a NotificationService with topic subscription methods,
                // add those calls here (e.g., subscribeToTopic('all_users')).
              },
              activeColor: const Color(0xFF667eea),
            ),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.dark_mode,
            iconColor: const Color(0xFF1a1a2e),
            title: 'Dark Mode',
            subtitle: 'Switch to dark theme',
            trailing: Switch(
              value: _darkModeEnabled,
              onChanged: (v) {
                setState(() => _darkModeEnabled = v);
                _saveSettings();
                // TODO: Apply theme change via Provider/Bloc
              },
              activeColor: const Color(0xFF667eea),
            ),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.fingerprint,
            iconColor: const Color(0xFF11998e),
            title: 'Biometric Login',
            subtitle: 'Use fingerprint or face ID',
            trailing: Switch(
              value: _biometricEnabled,
              onChanged: (v) {
                setState(() => _biometricEnabled = v);
                _saveSettings();
              },
              activeColor: const Color(0xFF667eea),
            ),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.language,
            iconColor: Colors.orange,
            title: 'Language',
            subtitle: 'English',
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onTap: _showLanguagePicker,
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.location_on,
            iconColor: Colors.red,
            title: 'Delivery Addresses',
            subtitle: 'Manage saved addresses',
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () => _navigateToAddresses(),
          ),
        ],
      ),
    );
  }

  /// Show language picker dialog
  void _showLanguagePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English', 'en', true),
            _buildLanguageOption('Chichewa', 'ny', false),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String name, String code, bool isSelected) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? const Color(0xFF667eea).withOpacity(0.1)
            : Colors.grey.shade100,
        child: Text(
          code.toUpperCase(),
          style: TextStyle(
            color: isSelected ? const Color(0xFF667eea) : Colors.grey,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(name),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF667eea))
          : null,
      onTap: () {
        Navigator.pop(context);
        _showSnackBar('Language changed to $name');
        // TODO: Implement locale change via Provider/Bloc
      },
    );
  }

  /// Navigate to delivery addresses screen
  void _navigateToAddresses() {
    // TODO: Navigate to Delivery Addresses screen when available
    _showSnackBar('Delivery addresses coming soon');
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildAccountActions() {
    return Container(
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
          _buildActionTile(
            icon: Icons.lock,
            iconColor: const Color(0xFF667eea),
            title: 'Change Password',
            onTap: () => _showChangePasswordDialog(),
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.help_outline,
            iconColor: const Color(0xFF11998e),
            title: 'Help & Support',
            onTap: () => _navigateToHelpSupport(),
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.policy,
            iconColor: Colors.orange,
            title: 'Privacy Policy',
            onTap: () => _navigateToPrivacyPolicy(),
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.notifications_active,
            iconColor: const Color(0xFF667eea),
            title: 'Notification Center',
            onTap: () => _navigateToNotificationCenter(),
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.card_giftcard,
            iconColor: const Color(0xFFFFD700),
            title: 'DineCoins & Rewards',
            onTap: () => _navigateToDineCoins(),
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            title: 'About DineTrack',
            onTap: () => _showAboutDialog(),
          ),
          const Divider(height: 1, indent: 56),
          _buildActionTile(
            icon: Icons.logout,
            iconColor: Colors.red,
            title: 'Sign Out',
            textColor: Colors.red,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  /// Navigate to Notification Center
  void _navigateToNotificationCenter() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationCenterScreen(),
      ),
    );
  }

  /// Navigate to DineCoins screen
  void _navigateToDineCoins() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DineCoinsScreen(),
      ),
    );
  }

  /// Navigate to Help & Support screen
  void _navigateToHelpSupport() {
    // TODO: Create HelpSupportScreen
    _showSnackBar('Help & Support coming soon');
  }

  /// Navigate to Privacy Policy screen
  void _navigateToPrivacyPolicy() {
    // TODO: Create PrivacyPolicyScreen
    _showSnackBar('Privacy Policy coming soon');
  }

  /// Show About DineTrack dialog
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.restaurant, color: Color(0xFF667eea)),
            SizedBox(width: 12),
            Text('About DineTrack'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DineTrack v2.1.0',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The smart restaurant ordering and loyalty platform for Malawi. '
                  'Order seamlessly, earn rewards, and enjoy dining.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              '© 2026 DineTrack. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: textColor,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                _showSnackBar('Passwords do not match');
                return;
              }
              if (newController.text.length < 6) {
                _showSnackBar('Password must be at least 6 characters');
                return;
              }
              try {
                await _supabase.auth.updateUser(
                  UserAttributes(password: newController.text),
                );
                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Password changed successfully');
                }
              } catch (e) {
                _showSnackBar('Failed to change password: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1a1a2e),
      ),
    );
  }
}
