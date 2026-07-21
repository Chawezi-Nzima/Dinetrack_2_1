// lib/pages/landing_page.dart

import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import 'login_page.dart';

// ═══════════════════════════════════════════════════════════════
// RESPONSIVE BREAKPOINTS
// ═══════════════════════════════════════════════════════════════

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double wideDesktop = 1600;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= wideDesktop;

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobile) return ScreenType.mobile;
    if (width < tablet) return ScreenType.tablet;
    if (width < desktop) return ScreenType.desktop;
    return ScreenType.wideDesktop;
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobile) return 2;
    if (width < tablet) return 3;
    if (width < desktop) return 4;
    if (width < wideDesktop) return 5;
    return 6;
  }
}

enum ScreenType { mobile, tablet, desktop, wideDesktop }

// ═══════════════════════════════════════════════════════════════
// RESPONSIVE SPACING & SIZING
// ═══════════════════════════════════════════════════════════════

class ResponsiveSpacing {
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return 20;
    if (width < Breakpoints.tablet) return 40;
    if (width < Breakpoints.desktop) return 80;
    if (width < Breakpoints.wideDesktop) return 120;
    return 160;
  }

  static double getSectionPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return 40;
    if (width < Breakpoints.tablet) return 60;
    if (width < Breakpoints.desktop) return 80;
    return 100;
  }

  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.desktop) return width;
    if (width < Breakpoints.wideDesktop) return 1100;
    return 1400;
  }
}

// ═══════════════════════════════════════════════════════════════
// LANDING PAGE
// ═══════════════════════════════════════════════════════════════

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.qr_code_scanner,
      'title': 'QR Table Ordering',
      'description': 'Guests scan QR codes at their table to browse menus, place orders, and pay — no app download needed.',
      'color': const Color(0xFF4F46E5),
    },
    {
      'icon': Icons.kitchen,
      'title': 'Kitchen Display System',
      'description': 'Real-time order tickets with color-coded priorities, preparation timers, and status updates.',
      'color': const Color(0xFFF59E0B),
    },
    {
      'icon': Icons.analytics,
      'title': 'Operator Dashboard',
      'description': 'Manage tables, staff, menu items, track revenue, and monitor orders from one central hub.',
      'color': const Color(0xFF10B981),
    },
    {
      'icon': Icons.payments,
      'title': 'PayChangu Integration',
      'description': 'Accept mobile money and card payments seamlessly with automated receipt generation.',
      'color': const Color(0xFF8B5CF6),
    },
    {
      'icon': Icons.loyalty,
      'title': 'DineCoins Rewards',
      'description': 'Earn loyalty points on every order. Redeem for discounts, free items, or priority service.',
      'color': const Color(0xFFEC4899),
    },
    {
      'icon': Icons.notifications_active,
      'title': 'Smart Notifications',
      'description': 'Push alerts for order status, table assistance requests, and promotional offers.',
      'color': const Color(0xFF06B6D4),
    },
  ];

  final List<Map<String, dynamic>> _roles = [
    {
      'icon': Icons.person_outline,
      'title': 'Customer',
      'subtitle': 'Dine & Order',
      'description': 'Browse restaurants, scan table QR codes, order food, track orders, earn DineCoins, and pay seamlessly.',
      'color': const Color(0xFF4F46E5),
      'gradient': [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
      'action': 'Browse as Guest',
    },
    {
      'icon': Icons.storefront,
      'title': 'Restaurant Operator',
      'subtitle': 'Manage Your Venue',
      'description': 'Register your restaurant, manage tables & QR codes, handle menu items, track orders, and view analytics.',
      'color': const Color(0xFF10B981),
      'gradient': [const Color(0xFF10B981), const Color(0xFF34D399)],
      'action': 'Register Restaurant',
    },
    {
      'icon': Icons.supervisor_account,
      'title': 'Supervisor',
      'subtitle': 'Oversee Operations',
      'description': 'Approve restaurant registrations, monitor platform analytics, manage staff roles, and ensure quality.',
      'color': const Color(0xFFF59E0B),
      'gradient': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      'action': 'Apply as Supervisor',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
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
    _navigateToLogin('customer');
  }

  void _scrollToRoles() {
    // Find the roles section offset and scroll to it
    // Using a key would be more precise in production
    final screenHeight = MediaQuery.of(context).size.height;
    _scrollController.animateTo(
      screenHeight * 2.5, // Approximate position
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        controller: _scrollController,
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
  // HERO SECTION — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final isTablet = screenType == ScreenType.tablet;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isDesktop ? 100 : (isTablet ? 80 : 60),
            horizontalPadding,
            isDesktop ? 80 : (isTablet ? 60 : 40),
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: isDesktop
                  ? _buildDesktopHeroLayout()
                  : _buildMobileTabletHeroLayout(),
            ),
          ),
        );
      },
    );
  }

  // Desktop: Two-column layout with content left, visual right
  Widget _buildDesktopHeroLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Content
        Expanded(
          flex: 5,
          child: _buildHeroContent(),
        ),
        const SizedBox(width: 80),
        // Right: Visual / Illustration area
        Expanded(
          flex: 4,
          child: _buildHeroVisual(),
        ),
      ],
    );
  }

  // Mobile/Tablet: Stacked layout
  Widget _buildMobileTabletHeroLayout() {
    return Column(
      children: [
        _buildHeroContent(),
        const SizedBox(height: 40),
        _buildHeroVisual(),
      ],
    );
  }

  Widget _buildHeroContent() {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
    final isTablet = screenType == ScreenType.tablet;

    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: isDesktop ? 100 : (isTablet ? 90 : 80),
          height: isDesktop ? 100 : (isTablet ? 90 : 80),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(isDesktop ? 28 : 24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.restaurant,
            color: Colors.white,
            size: isDesktop ? 48 : (isTablet ? 44 : 40),
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'DineTrack',
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 56 : (isTablet ? 48 : 40),
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),

        // Tagline
        Text(
          'Smart Restaurant Management, Simplified',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
            fontWeight: FontWeight.w400,
          ),
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Subtitle badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            'QR Ordering • Kitchen Display • Payments • Loyalty',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: isDesktop ? 14 : 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // CTA Buttons — responsive layout
        _buildHeroCTAButtons(),
      ],
    );
  }

  Widget _buildHeroCTAButtons() {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;

    if (isDesktop) {
      // Desktop: Horizontal buttons, not full width
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 200,
            child: _buildPrimaryButton(
              label: 'Get Started',
              icon: Icons.arrow_forward,
              onTap: _scrollToRoles,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 200,
            child: _buildSecondaryButton(
              label: 'Browse as Guest',
              icon: Icons.person_outline,
              onTap: _continueAsGuest,
            ),
          ),
        ],
      );
    }

    // Mobile/Tablet: Full width stacked or side by side
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 400) {
          // Side by side on wider mobile/tablet
          return Row(
            children: [
              Expanded(
                child: _buildPrimaryButton(
                  label: 'Get Started',
                  icon: Icons.arrow_forward,
                  onTap: _scrollToRoles,
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
          );
        }
        // Stacked on narrow mobile
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: _buildPrimaryButton(
                label: 'Get Started',
                icon: Icons.arrow_forward,
                onTap: _scrollToRoles,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildSecondaryButton(
                label: 'Browse as Guest',
                icon: Icons.person_outline,
                onTap: _continueAsGuest,
              ),
            ),
          ],
        );
      },
    );
  }

  // Decorative visual for desktop hero
  Widget _buildHeroVisual() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withValues(alpha: 0.2),
            const Color(0xFF764ba2).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Restaurant\n Digitized',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HOW IT WORKS — RESPONSIVE
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final isTablet = screenType == ScreenType.tablet;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  _buildSectionHeader(
                    title: 'How It Works',
                    subtitle: 'Four simple steps to transform your dining experience',
                  ),
                  const SizedBox(height: 32),

                  // Steps grid — responsive
                  isDesktop
                      ? _buildDesktopStepsGrid(steps)
                      : isTablet
                      ? _buildTabletStepsGrid(steps)
                      : _buildMobileStepsList(steps),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopStepsGrid(List<Map<String, String>> steps) {
    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < steps.length - 1 ? 20 : 0,
            ),
            child: _buildStepCardDesktop(step),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabletStepsGrid(List<Map<String, String>> steps) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: steps.length,
      itemBuilder: (context, index) => _buildStepCardDesktop(steps[index]),
    );
  }

  Widget _buildMobileStepsList(List<Map<String, String>> steps) {
    return Column(
      children: steps.map((step) => _buildStepCard(step)).toList(),
    );
  }

  // Desktop step card (vertical layout)
  Widget _buildStepCardDesktop(Map<String, String> step) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                step['number']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            step['title']!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step['description']!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // Mobile step card (horizontal layout)
  Widget _buildStepCard(Map<String, String> step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    color: Colors.white.withValues(alpha: 0.5),
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
  // FEATURES SECTION — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFeaturesSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);
        final crossAxisCount = Breakpoints.getGridCrossAxisCount(context);

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    title: 'Features',
                    subtitle: 'Everything you need to run a modern restaurant',
                  ),
                  const SizedBox(height: 24),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: isDesktop ? 1.0 : 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _features.length,
                    itemBuilder: (context, index) {
                      final feature = _features[index];
                      return _buildFeatureCard(feature);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isDesktop ? 56 : 44,
            height: isDesktop ? 56 : 44,
            decoration: BoxDecoration(
              color: (feature['color'] as Color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
            ),
            child: Icon(
              feature['icon'] as IconData,
              color: feature['color'] as Color,
              size: isDesktop ? 28 : 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            feature['title'] as String,
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              feature['description'] as String,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: isDesktop ? 13 : 12,
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ROLE SELECTION — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRoleSelectionSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final isTablet = screenType == ScreenType.tablet;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final sectionPadding = ResponsiveSpacing.getSectionPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: sectionPadding,
            horizontal: horizontalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    title: 'Choose Your Role',
                    subtitle: 'Select how you want to use DineTrack',
                  ),
                  const SizedBox(height: 24),

                  // Role cards — responsive layout
                  isDesktop
                      ? _buildDesktopRoleGrid()
                      : isTablet
                      ? _buildTabletRoleGrid()
                      : Column(
                    children: _roles.map((role) => _buildRoleCard(role)).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopRoleGrid() {
    return Row(
      children: _roles.asMap().entries.map((entry) {
        final index = entry.key;
        final role = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < _roles.length - 1 ? 20 : 0,
            ),
            child: _buildRoleCardDesktop(role),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabletRoleGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildRoleCard(_roles[0])),
            const SizedBox(width: 16),
            Expanded(child: _buildRoleCard(_roles[1])),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _buildRoleCard(_roles[2]),
        ),
      ],
    );
  }

  // Desktop role card (taller, more spacious)
  Widget _buildRoleCardDesktop(Map<String, dynamic> role) {
    final gradient = role['gradient'] as List<Color>;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient[0].withValues(alpha: 0.15),
            gradient[1].withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: gradient[0].withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleRoleTap(role['title'] as String),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    role['icon'] as IconData,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  role['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  role['subtitle'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  role['description'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        role['action'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
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

  void _handleRoleTap(String title) {
    if (title == 'Customer') {
      _continueAsGuest();
    } else if (title == 'Restaurant Operator') {
      _navigateToLogin('operator');
    } else if (title == 'Supervisor') {
      _navigateToLogin('supervisor');
    }
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final gradient = role['gradient'] as List<Color>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient[0].withValues(alpha: 0.15),
            gradient[1].withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradient[0].withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleRoleTap(role['title'] as String),
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
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  role['description'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
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
  // FOOTER — RESPONSIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Breakpoints.getScreenType(context);
        final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;
        final horizontalPadding = ResponsiveSpacing.getHorizontalPadding(context);
        final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            32,
            horizontalPadding,
            48,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: isDesktop
                  ? _buildDesktopFooter()
                  : _buildMobileFooter(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo & brand
        Row(
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

        // Center: Links (placeholder)
        Row(
          children: [
            _buildFooterLink('Privacy'),
            const SizedBox(width: 24),
            _buildFooterLink('Terms'),
            const SizedBox(width: 24),
            _buildFooterLink('Contact'),
          ],
        ),

        // Right: Copyright
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '© 2026 DineTrack. All rights reserved.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
            Text(
              'Powered by Supabase & PayChangu',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFooter() {
    return Column(
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
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Powered by Supabase & PayChangu',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLink(String label) {
    return TextButton(
      onPressed: () {},
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 13,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    final screenType = Breakpoints.getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop || screenType == ScreenType.wideDesktop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 32 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: isDesktop ? 16 : 14,
          ),
        ),
      ],
    );
  }

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
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
}
