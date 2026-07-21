import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/models/user_models.dart';
import 'core/services/auth_service.dart';
import 'flavors/customer/screens/browse_restaurants_screen.dart';
import 'flavors/customer/screens/notification_center_screen.dart';
import 'flavors/customer/screens/order_tracking_screen.dart';
import 'flavors/customer/screens/dinecoins_screen.dart';
import 'flavors/kitchen/screens/kitchen_order_management_screen.dart';
import 'flavors/operator/screens/operator_home_page.dart';
import 'flavors/operator/screens/operator_table_management_screen.dart';
import 'flavors/supervisor/screens/supervisor_analytics_dashboard.dart';
import 'flavors/supervisor/screens/admin_dashboard.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/registration_page.dart';
import 'pages/restaurant_registration_page.dart';
import 'shared/widgets/notification_overlay.dart';

// Pre-computed colors to avoid const evaluation issues
final Color _subtitleColor = Colors.white.withValues(alpha: 0.5);
final Color _hintColor = Colors.white.withValues(alpha: 0.3);
final Color _fillColor = Colors.white.withValues(alpha: 0.05);
final Color _borderColor = Colors.white.withValues(alpha: 0.1);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: 'assets/env/.env.production');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DineTrack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      debugShowCheckedModeBanner: false,
      home: const RoleResolver(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GUEST USER PROFILE — Used when browsing without logging in
// ═══════════════════════════════════════════════════════════════

/// A static guest profile for unauthenticated users.
/// All guest sessions share this identity until they sign up.
const UserProfile kGuestProfile = UserProfile(
  id: 'guest-user',
  email: null,
  fullName: 'Guest',
  phone: null,
  profileImageUrl: null,
  userType: 'customer',
  dineCoinsBalance: 0.0,
);

bool get isGuestMode => Supabase.instance.client.auth.currentUser == null;

// ═══════════════════════════════════════════════════════════════
// ROLE RESOLVER — Entry point with guest support
// ═══════════════════════════════════════════════════════════════

class RoleResolver extends StatefulWidget {
  const RoleResolver({super.key});

  @override
  State<RoleResolver> createState() => _RoleResolverState();
}

class _RoleResolverState extends State<RoleResolver> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _resolveRoute();
  }

  Future<void> _resolveRoute() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = _authService.currentUser;
    if (user == null) {
      // No auth — show landing page (not login directly)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LandingPage()),
        );
      }
      return;
    }

    final profile = await _authService.getCurrentUserProfile();
    if (profile == null) {
      // Auth exists but no profile — force registration
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RegistrationPage()),
        );
      }
      return;
    }

    // Operator gate: must have establishment
    if (profile.userType == 'operator') {
      final hasEstablishment = await _checkOperatorHasEstablishment(profile.id);
      if (!hasEstablishment) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RestaurantRegistrationPage()),
          );
        }
        return;
      }
    }

    if (mounted) {
      _navigateByRole(profile);
    }
  }

  /// Check if operator already has an establishment registered
  Future<bool> _checkOperatorHasEstablishment(String userId) async {
    try {
      final result = await Supabase.instance.client
          .from('establishments')
          .select('id')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  void _navigateByRole(UserProfile profile) {
    Widget destination;

    switch (profile.userType) {
      case 'customer':
        destination = const CustomerHomeRouter();
        break;
      case 'kitchen':
        destination = const KitchenOrderManagementScreen();
        break;
      case 'operator':
        destination = const OperatorHomeRouter();
        break;
      case 'supervisor':
        destination = const SupervisorAnalyticsDashboard();
        break;
      case 'admin':
        destination = const AdminDashboard();
        break;
      default:
        destination = const LoginPage();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.restaurant, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'DineTrack',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Smart Restaurant Management',
              style: TextStyle(color: _subtitleColor, fontSize: 14),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CUSTOMER FLOW
// ═══════════════════════════════════════════════════════════════

class CustomerHomeRouter extends StatefulWidget {
  const CustomerHomeRouter({super.key});

  @override
  State<CustomerHomeRouter> createState() => _CustomerHomeRouterState();
}

class _CustomerHomeRouterState extends State<CustomerHomeRouter> {
  final AuthService _authService = AuthService();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    _profile = await _authService.getCurrentUserProfile();

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    // Only check group sessions for authenticated users
    if (userId != null && !isGuestMode) {
      // Use 'group_sessions' (not 'table_sessions')
      // Check if user is either the creator OR a participant of an active session
      final createdSession = await supabase
          .from('group_sessions')
          .select('id, establishment_id')
          .eq('created_by', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (createdSession != null) {
        _hasActiveSession = true;
      } else {
        // Also check if user is a participant in someone else's session
        final participantSession = await supabase
            .from('group_session_participants')
            .select('session_id, group_sessions!inner(status, establishment_id)')
            .eq('user_id', userId)
            .eq('group_sessions.status', 'active')
            .maybeSingle();

        _hasActiveSession = participantSession != null;
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _hasActiveSession
        ? CustomerSessionHome(profile: _profile)
        : BrowseRestaurantsScreen(userProfile: _profile ?? kGuestProfile);
  }
}

class CustomerSessionHome extends StatefulWidget {
  final UserProfile? profile;
  const CustomerSessionHome({super.key, this.profile});

  @override
  State<CustomerSessionHome> createState() => _CustomerSessionHomeState();
}

class _CustomerSessionHomeState extends State<CustomerSessionHome> {
  int _currentIndex = 0;

  void _onNotificationTap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _SessionMenuPlaceholder(),
      const NotificationCenterScreen(),
      const DineCoinsScreen(),
    ];

    return NotificationOverlay(
      child: Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF667eea),
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Menu'),
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
            BottomNavigationBarItem(
              icon: NotificationBadgeIcon(
                icon: Icons.notifications,
                onTap: _onNotificationTap,
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Coins'),
          ],
        ),
      ),
    );
  }
}

class _SessionMenuPlaceholder extends StatelessWidget {
  const _SessionMenuPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Menu'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Table Session Active', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Menu items will appear here'),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OPERATOR FLOW — With establishment gate
// ═══════════════════════════════════════════════════════════════

class OperatorHomeRouter extends StatefulWidget {
  const OperatorHomeRouter({super.key});

  @override
  State<OperatorHomeRouter> createState() => _OperatorHomeRouterState();
}

class _OperatorHomeRouterState extends State<OperatorHomeRouter> {
  bool _isLoading = true;
  bool _hasEstablishment = false;

  @override
  void initState() {
    super.initState();
    _checkEstablishment();
  }

  Future<void> _checkEstablishment() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final result = await Supabase.instance.client
          .from('establishments')
          .select('id')
          .eq('owner_id', user.id)
          .limit(1)
          .maybeSingle();
      _hasEstablishment = result != null;
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasEstablishment) {
      // No establishment — redirect to registration
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RestaurantRegistrationPage()),
        );
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return const _OperatorHomePageWithNav(); // Normal operator dashboard with bottom nav
  }
}

class _OperatorHomePageWithNav extends StatefulWidget {
  const _OperatorHomePageWithNav();

  @override
  State<_OperatorHomePageWithNav> createState() => _OperatorHomePageWithNavState();
}

class _OperatorHomePageWithNavState extends State<_OperatorHomePageWithNav> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const OperatorHomePage(),
      const OperatorTableManagementScreen(establishmentId: ''),
      const Placeholder(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF667eea),
        unselectedItemColor: Colors.grey.shade400,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.table_restaurant), label: 'Tables'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR Codes'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOGIN PAGE — With Guest Access (embedded for fallback)
// ═══════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  /// Navigate to customer browse screen as a guest
  void _continueAsGuest() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BrowseRestaurantsScreen(userProfile: kGuestProfile),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final result = await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (result.user != null && mounted) {
        final profile = await authService.getCurrentUserProfile();
        if (profile != null) {
          _navigateByRole(profile);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final result = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userType: 'customer',
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (result.user != null && mounted) {
        final profile = await authService.getCurrentUserProfile();
        if (profile != null) {
          _navigateByRole(profile);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateByRole(UserProfile profile) {
    Widget destination;
    switch (profile.userType) {
      case 'customer':
        destination = const CustomerHomeRouter();
        break;
      case 'kitchen':
        destination = const KitchenOrderManagementScreen();
        break;
      case 'operator':
        destination = const OperatorHomeRouter();
        break;
      case 'supervisor':
        destination = const SupervisorAnalyticsDashboard();
        break;
      case 'admin':
        destination = const AdminDashboard();
        break;
      default:
        destination = const CustomerHomeRouter();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                _isSignUp ? 'Create Account' : 'Welcome Back',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? 'Sign up to get started' : 'Sign in to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: _subtitleColor, fontSize: 14),
              ),
              const SizedBox(height: 40),

              if (_isSignUp) ...[
                _buildTextField(_fullNameController, 'Full Name', Icons.person),
                const SizedBox(height: 16),
                _buildTextField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
              ],

              _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, 'Password', Icons.lock, obscureText: true),
              const SizedBox(height: 24),

              // Primary action button
              ElevatedButton(
                onPressed: _isLoading ? null : (_isSignUp ? _signUp : _login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),

              const SizedBox(height: 16),

              // Toggle sign in / sign up
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'Already have an account? Sign In' : 'Don\'t have an account? Sign Up',
                  style: const TextStyle(color: Color(0xFF667eea)),
                ),
              ),

              const SizedBox(height: 24),

              // ── GUEST ACCESS DIVIDER ──
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or', style: TextStyle(color: _subtitleColor, fontSize: 14)),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                ],
              ),

              const SizedBox(height: 24),

              // ── CONTINUE AS GUEST BUTTON ──
              OutlinedButton.icon(
                onPressed: _continueAsGuest,
                icon: const Icon(Icons.person_outline, color: Colors.white70),
                label: const Text(
                  'Continue as Guest',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 12),

              // Guest hint text
              Text(
                'Browse restaurants and menus without signing in',
                textAlign: TextAlign.center,
                style: TextStyle(color: _hintColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscureText = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _hintColor),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: _fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea))),
      ),
    );
  }
}