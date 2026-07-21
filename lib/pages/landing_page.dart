// lib/pages/landing_page.dart
/*
import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import 'login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.qr_code_scanner,
      'title': 'QR Table Ordering',
      'description': 'Guests scan QR codes at their table to browse menus, place orders, and pay — no app download needed.',
      'color': Color(0xFF4F46E5),
    },
    {
      'icon': Icons.kitchen,
      'title': 'Kitchen Display System',
      'description': 'Real-time order tickets with color-coded priorities, preparation timers, and status updates.',
      'color': Color(0xFFF59E0B),
    },
    {
      'icon': Icons.analytics,
      'title': 'Operator Dashboard',
      'description': 'Manage tables, staff, menu items, track revenue, and monitor orders from one central hub.',
      'color': Color(0xFF10B981),
    },
    {
      'icon': Icons.payments,
      'title': 'PayChangu Integration',
      'description': 'Accept mobile money and card payments seamlessly with automated receipt generation.',
      'color': Color(0xFF8B5CF6),
    },
    {
      'icon': Icons.loyalty,
      'title': 'DineCoins Rewards',
      'description': 'Earn loyalty points on every order. Redeem for discounts, free items, or priority service.',
      'color': Color(0xFFEC4899),
    },
    {
      'icon': Icons.notifications_active,
      'title': 'Smart Notifications',
      'description': 'Push alerts for order status, table assistance requests, and promotional offers.',
      'color': Color(0xFF06B6D4),
    },
  ];

  final List<Map<String, dynamic>> _roles = [
    {
      'icon': Icons.person_outline,
      'title': 'Customer',
      'subtitle': 'Dine & Order',
      'description': 'Browse restaurants, scan table QR codes, order food, track orders, earn DineCoins, and pay seamlessly.',
      'color': Color(0xFF4F46E5),
      'gradient': [Color(0xFF4F46E5), Color(0xFF6366F1)],
      'action': 'Browse as Guest',
    },
    {
      'icon': Icons.storefront,
      'title': 'Restaurant Operator',
      'subtitle': 'Manage Your Venue',
      'description': 'Register your restaurant, manage tables & QR codes, handle menu items, track orders, and view analytics.',
      'color': Color(0xFF10B981),
      'gradient': [Color(0xFF10B981), Color(0xFF34D399)],
      'action': 'Register Restaurant',
    },
    {
      'icon': Icons.supervisor_account,
      'title': 'Supervisor',
      'subtitle': 'Oversee Operations',
      'description': 'Approve restaurant registrations, monitor platform analytics, manage staff roles, and ensure quality.',
      'color': Color(0xFFF59E0B),
      'gradient': [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      'action': 'Apply as Supervisor',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToLogin(String? userType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(preselectedRole: userType),
      ),
    );
  }

  void _continueAsGuest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const BrowseRestaurantsScreen(userProfile: kGuestProfile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          // ── HERO SECTION ──
          SliverToBoxAdapter(
            child: _buildHeroSection(),
          ),

          // ── HOW IT WORKS ──
          SliverToBoxAdapter(
            child: _buildHowItWorksSection(),
          ),

          // ── FEATURES GRID ──
          SliverToBoxAdapter(
            child: _buildFeaturesSection(),
          ),

          // ── ROLE SELECTION ──
          SliverToBoxAdapter(
            child: _buildRoleSelectionSection(),
          ),

          // ── FOOTER ──
          SliverToBoxAdapter(
            child: _buildFooter(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'DineTrack',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),

          // Tagline
          Text(
            'Smart Restaurant Management, Simplified',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Subtitle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              'QR Ordering • Kitchen Display • Payments • Loyalty',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // CTA Buttons
          Row(
            children: [
              Expanded(
                child: _buildPrimaryButton(
                  label: 'Get Started',
                  icon: Icons.arrow_forward,
                  onTap: () => _scrollToRoles(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSecondaryButton(
                  label: 'Browse as Guest',
                  icon: Icons.person_outline,
                  onTap: _continueAsGuest,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HOW IT WORKS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHowItWorksSection() {
    final steps = [
      {
        'number': '01',
        'title': 'Scan QR Code',
        'description': 'Guests scan the QR code at their table to instantly access the digital menu.',
      },
      {
        'number': '02',
        'title': 'Browse & Order',
        'description': 'Browse categories, view item details, customize orders, and add to cart.',
      },
      {
        'number': '03',
        'title': 'Kitchen Receives',
        'description': 'Orders appear instantly on the kitchen display with priority and timing.',
      },
      {
        'number': '04',
        'title': 'Pay & Enjoy',
        'description': 'Pay via mobile money, card, or DineCoins. Track order status in real-time.',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How It Works',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Four simple steps to transform your dining experience',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Steps
          ...steps.map((step) => _buildStepCard(step)),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, String> step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                step['number']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['title']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step['description']!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FEATURES SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything you need to run a modern restaurant',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _features.length,
            itemBuilder: (context, index) {
              final feature = _features[index];
              return _buildFeatureCard(feature);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (feature['color'] as Color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature['icon'] as IconData,
              color: feature['color'] as Color,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            feature['title'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            feature['description'] as String,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ROLE SELECTION SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRoleSelectionSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Role',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select how you want to use DineTrack',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          ..._roles.map((role) => _buildRoleCard(role)),
        ],
      ),
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final gradient = role['gradient'] as List<Color>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient[0].withOpacity(0.15),
            gradient[1].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradient[0].withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (role['title'] == 'Customer') {
              _continueAsGuest();
            } else {
              _navigateToLogin(role['title'].toString().toLowerCase());
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        role['icon'] as IconData,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            role['subtitle'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.3),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  role['description'] as String,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        role['action'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'DineTrack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '© 2026 DineTrack. All rights reserved.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by Supabase & PayChangu',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(width: 8),
          Icon(icon, size: 18),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(width: 8),
          Icon(icon, size: 18),
        ],
      ),
    );
  }

  void _scrollToRoles() {
    // In a real app, you'd scroll to the roles section
    // For now, we just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scroll down to choose your role'),
        backgroundColor: Color(0xFF667eea),
      ),
    );
  }
}*/