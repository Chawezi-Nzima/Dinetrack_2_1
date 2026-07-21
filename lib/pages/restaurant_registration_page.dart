// lib/pages/restaurant_registration_page.dart
// Restaurant Registration + Subscription Flow for Operators
// Entry: LandingPage → LoginPage → (operator user) → RestaurantRegistrationPage
// Or: LandingPage → RegistrationPage (operator) → RestaurantRegistrationPage
/*
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/auth_service.dart';
import 'login_page.dart';

// ═══════════════════════════════════════════════════════════════
// RESTAURANT REGISTRATION PAGE
// Multi-step wizard: Info → Plan → Payment → Confirmation
// ═══════════════════════════════════════════════════════════════

class RestaurantRegistrationPage extends StatefulWidget {
  const RestaurantRegistrationPage({super.key});

  @override
  State<RestaurantRegistrationPage> createState() => _RestaurantRegistrationPageState();
}

class _RestaurantRegistrationPageState extends State<RestaurantRegistrationPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // ── Step 1: Restaurant Info ──
  final _restaurantNameController = TextEditingController();
  final _restaurantTypeController = TextEditingController();
  final _addressController = TextEditingController();
  final _restaurantPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ── Step 2: Subscription Plan ──
  String _selectedPlan = 'monthly';

  // ── Step 3: Payment ──
  final _paymentPhoneController = TextEditingController();
  String _selectedPaymentMethod = 'mobile_money';

  // ── State ──
  bool _isLoading = false;
  String? _errorMessage;
  String? _checkoutUrl;
  String? _paymentReference;

  final _auth = AuthService();
  final _supabase = Supabase.instance.client;

  // Schema-consistent establishment types
  final List<Map<String, dynamic>> _establishmentTypes = [
    {'value': 'restaurant', 'label': 'Restaurant', 'icon': Icons.restaurant},
    {'value': 'cafe', 'label': 'Café', 'icon': Icons.coffee},
    {'value': 'bar', 'label': 'Bar & Lounge', 'icon': Icons.local_bar},
    {'value': 'food_truck', 'label': 'Food Truck', 'icon': Icons.local_shipping},
    {'value': 'bakery', 'label': 'Bakery', 'icon': Icons.bakery_dining},
  ];

  // Subscription plans (schema-consistent with subscriptions table)
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'monthly',
      'label': 'Monthly',
      'price': 15000.00,
      'currency': 'MWK',
      'period': 'month',
      'description': 'Perfect for getting started',
      'features': [
        'Unlimited menu items',
        'Up to 20 tables',
        'QR code ordering',
        'Kitchen display system',
        'Basic analytics',
        'Email support',
      ],
      'gradient': [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
    },
    {
      'id': 'yearly',
      'label': 'Yearly',
      'price': 150000.00,
      'currency': 'MWK',
      'period': 'year',
      'description': 'Save 2 months — best value',
      'features': [
        'Everything in Monthly',
        'Unlimited tables',
        'Priority support',
        'Advanced analytics',
        'Staff management',
        'Custom branding',
      ],
      'gradient': [const Color(0xFF10B981), const Color(0xFF34D399)],
      'badge': 'SAVE 17%',
    },
  ];

  // Payment methods (schema-consistent with payments.payment_method enum)
  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'mobile_money', 'label': 'Mobile Money', 'icon': Icons.phone_android},
    {'value': 'card', 'label': 'Card Payment', 'icon': Icons.credit_card},
    {'value': 'bank_transfer', 'label': 'Bank Transfer', 'icon': Icons.account_balance},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _restaurantNameController.dispose();
    _restaurantTypeController.dispose();
    _addressController.dispose();
    _restaurantPhoneController.dispose();
    _descriptionController.dispose();
    _paymentPhoneController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────

  void _nextStep() {
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep == 1 && !_validateStep2()) return;
    if (_currentStep == 2 && !_validateStep3()) return;

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _validateStep1() {
    if (_restaurantNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your restaurant name');
      return false;
    }
    if (_restaurantTypeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select a restaurant type');
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  bool _validateStep2() {
    setState(() => _errorMessage = null);
    return true;
  }

  bool _validateStep3() {
    if (_selectedPaymentMethod == 'mobile_money' &&
        _paymentPhoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your mobile money number');
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // SUBMIT — Create establishment + subscription + payment
  // ─────────────────────────────────────────────────────────────

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to register a restaurant');
      }

      // 1. Verify user_type is 'operator' (schema-consistent)
      final profile = await _auth.getCurrentUserProfile();
      if (profile?.userType != 'operator') {
        throw Exception('Only restaurant operators can register establishments');
      }

      // 2. Insert establishment (matches DB schema: establishments table)
      final establishmentData = {
        'owner_id': user.id,
        'name': _restaurantNameController.text.trim(),
        'type': _restaurantTypeController.text.trim(),
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        'phone': _restaurantPhoneController.text.trim().isNotEmpty
            ? _restaurantPhoneController.text.trim()
            : null,
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'is_active': false,           // Requires supervisor approval
        'supervisor_approved': false, // Pending approval
      };

      final establishmentResponse = await _supabase
          .from('establishments')
          .insert(establishmentData)
          .select()
          .single();

      final establishmentId = establishmentResponse['id'] as String;
      final selectedPlan = _plans.firstWhere((p) => p['id'] == _selectedPlan);
      final amount = selectedPlan['price'] as double;

      // 3. Initiate PayChangu payment (creates payment record with checkout_url)
      // This calls your backend edge function or direct PayChangu API
      final paymentResult = await _initiatePayChanguPayment(
        establishmentId: establishmentId,
        amount: amount,
        planType: _selectedPlan,
        phone: _paymentPhoneController.text.trim(),
      );

      setState(() {
        _checkoutUrl = paymentResult['checkout_url'] as String?;
        _paymentReference = paymentResult['reference'] as String?;
      });

      // 4. Create subscription record (pending until payment confirmed)
      await _supabase.from('subscriptions').insert({
        'establishment_id': establishmentId,
        'plan_type': _selectedPlan,
        'status': 'pending', // schema: subscription_status enum
        'amount': amount,
        'start_date': DateTime.now().toUtc().toIso8601String(),
      });

      // 5. Advance to confirmation step
      _nextStep();
    } on PostgrestException catch (e) {
      setState(() => _errorMessage = 'Database error: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'Registration failed: \$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Initiates PayChangu payment via edge function or direct API
  Future<Map<String, dynamic>> _initiatePayChanguPayment({
    required String establishmentId,
    required double amount,
    required String planType,
    required String phone,
  }) async {
    // TODO: Replace with your actual PayChangu integration
    // This should call a Supabase Edge Function or your backend API
    // that returns: { checkout_url: string, reference: string }

    // Placeholder for PayChangu integration:
    // final response = await _supabase.functions.invoke(
    //   'paychangu-initiate',
    //   body: {
    //     'amount': amount,
    //     'currency': 'MWK',
    //     'email': _auth.currentUser?.email,
    //     'phone': phone,
    //     'callback_url': 'https://yourapp.com/payment/callback',
    //     'return_url': 'https://yourapp.com/payment/success',
    //     'metadata': {
    //       'establishment_id': establishmentId,
    //       'plan_type': planType,
    //     },
    //   },
    // );

    // For now, return mock data to allow UI flow completion
    // In production, this MUST be replaced with actual PayChangu API call
    await Future.delayed(const Duration(seconds: 2)); // Simulate network

    return {
      'checkout_url': 'https://paychangu.com/checkout/mock-\$establishmentId',
      'reference': 'DINETRACK-\${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side — Progress & Branding
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Register Restaurant',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Set up your venue in minutes',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 48),
                _buildStepIndicatorDesktop(),
              ],
            ),
          ),
        ),
        // Right side — Form Wizard
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildDesktopHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1RestaurantInfo(),
                    _buildStep2SubscriptionPlan(),
                    _buildStep3Payment(),
                    _buildStep4Confirmation(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _isLoading ? null : _previousStep,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorDesktop() {
    final steps = [
      {'label': 'Restaurant Info', 'icon': Icons.store},
      {'label': 'Choose Plan', 'icon': Icons.card_membership},
      {'label': 'Payment', 'icon': Icons.payment},
      {'label': 'Confirmation', 'icon': Icons.check_circle},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.white.withValues(alpha: 0.3)
                        : isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: isActive
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Icon(
                      step['icon'] as IconData,
                      color: isActive ? const Color(0xFF4F46E5) : Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  step['label'] as String,
                  style: TextStyle(
                    color: isActive || isCompleted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile header with progress
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (_currentStep > 0)
                  IconButton(
                    onPressed: _isLoading ? null : _previousStep,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: const Color(0xFF6B7280),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: _buildMobileStepIndicator(),
                ),
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  icon: const Icon(Icons.close, size: 20),
                  color: const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
        // Progress bar
        LinearProgressIndicator(
          value: (_currentStep + 1) / 4,
          backgroundColor: Colors.grey.shade100,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
          minHeight: 3,
        ),
        // Form content
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1RestaurantInfo(),
              _buildStep2SubscriptionPlan(),
              _buildStep3Payment(),
              _buildStep4Confirmation(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStepIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _getStepTitle(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Step \${_currentStep + 1} of 4',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Restaurant Information';
      case 1:
        return 'Choose Your Plan';
      case 2:
        return 'Payment';
      case 3:
        return 'All Set!';
      default:
        return '';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 1: RESTAURANT INFORMATION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStep1RestaurantInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            title: 'Tell us about your restaurant',
            subtitle: 'This information will be visible to your customers',
          ),
          const SizedBox(height: 32),

          // Restaurant Name
          _buildTextField(
            controller: _restaurantNameController,
            label: 'Restaurant Name *',
            hint: 'e.g. Mamas Kitchen',
            icon: Icons.store,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (value.length < 2) return 'Too short';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Restaurant Type (Dropdown)
          _buildTypeSelector(),
          const SizedBox(height: 20),

          // Address
          _buildTextField(
            controller: _addressController,
            label: 'Address',
            hint: 'e.g. 123 Main Street, Lilongwe',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),

          // Phone
          _buildTextField(
            controller: _restaurantPhoneController,
            label: 'Restaurant Phone',
            hint: 'e.g. +265 99 123 4567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),

          // Description
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Briefly describe your restaurant, cuisine, and atmosphere...',
            icon: Icons.description_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 32),

          _buildErrorBox(),
          const SizedBox(height: 16),

          _buildPrimaryButton(
            label: 'Continue to Plans',
            icon: Icons.arrow_forward,
            onTap: _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Restaurant Type *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _establishmentTypes.map((type) {
              final isSelected = _restaurantTypeController.text == type['value'];
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(type['label'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _restaurantTypeController.text = selected ? type['value'] as String : '';
                    _errorMessage = null;
                  });
                },
                selectedColor: const Color(0xFF4F46E5),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 2: SUBSCRIPTION PLAN
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStep2SubscriptionPlan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            title: 'Choose your subscription',
            subtitle: 'Select a plan that fits your business needs',
          ),
          const SizedBox(height: 32),

          ..._plans.map((plan) => _buildPlanCard(plan)),

          const SizedBox(height: 24),

          // Plan details info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your subscription starts immediately after payment. You can upgrade or cancel anytime from your operator dashboard.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildErrorBox(),
          const SizedBox(height: 16),

          _buildPrimaryButton(
            label: 'Continue to Payment',
            icon: Icons.arrow_forward,
            onTap: _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan['id'];
    final gradient = plan['gradient'] as List<Color>;
    final price = plan['price'] as double;
    final currency = plan['currency'] as String;
    final period = plan['period'] as String;
    final features = plan['features'] as List<String>;
    final badge = plan['badge'] as String?;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPlan = plan['id'] as String;
        _errorMessage = null;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [
              gradient[0].withValues(alpha: 0.08),
              gradient[1].withValues(alpha: 0.02),
            ],
          )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? gradient[0] : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ]
              : null,
        ),
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
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan['label'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: gradient),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['description'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? gradient[0] : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? gradient[0] : Colors.grey.shade300,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$currency \${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/\$period',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: gradient[0],
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    feature,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 3: PAYMENT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStep3Payment() {
    final selectedPlan = _plans.firstWhere((p) => p['id'] == _selectedPlan);
    final price = selectedPlan['price'] as double;
    final currency = selectedPlan['currency'] as String;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            title: 'Complete your payment',
            subtitle: 'Secure checkout powered by PayChangu',
          ),
          const SizedBox(height: 32),

          // Order summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedPlan['label'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '\$currency \${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '\$currency \${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Payment method selector
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ..._paymentMethods.map((method) => _buildPaymentMethodTile(method)),

          const SizedBox(height: 24),

          // Mobile money phone field (conditional)
          if (_selectedPaymentMethod == 'mobile_money') ...[
            _buildTextField(
              controller: _paymentPhoneController,
              label: 'Mobile Money Number *',
              hint: 'e.g. 0991234567',
              icon: Icons.phone_android,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
          ],

          // PayChangu trust badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Secure Payment by PayChangu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B21A8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your payment is encrypted and processed securely. You will receive a receipt via email.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildErrorBox(),
          const SizedBox(height: 16),

          _buildPrimaryButton(
            label: 'Pay \$currency \${price.toStringAsFixed(0)}',
            icon: Icons.lock_outline,
            onTap: _submitRegistration,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'You will be redirected to PayChangu to complete payment',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['value'];

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPaymentMethod = method['value'] as String;
        _errorMessage = null;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE9FE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                method['icon'] as IconData,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                method['label'] as String,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 4: CONFIRMATION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStep4Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF34D399)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.3, 1.0],
                tileMode: TileMode.clamp,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Registration Submitted!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your restaurant has been registered and is pending supervisor approval.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          // Status cards
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pending_actions,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Approval',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A supervisor will review your restaurant within 24 hours. You will be notified once approved.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Receipt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reference: \${_paymentReference ?? 'N/A'}\nA receipt has been sent to your email.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_checkoutUrl != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC4B5FD)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.open_in_new,
                      color: Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click below to finalize your payment via PayChangu.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 40),

          if (_checkoutUrl != null)
            _buildPrimaryButton(
              label: 'Open PayChangu Checkout',
              icon: Icons.open_in_new,
              onTap: () {
                // TODO: Launch URL via url_launcher package
                // await launchUrl(Uri.parse(_checkoutUrl!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening checkout: \$_checkoutUrl'),
                    backgroundColor: const Color(0xFF4F46E5),
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          _buildSecondaryButton(
            label: 'Go to Dashboard',
            icon: Icons.dashboard_outlined,
            onTap: () {
              // Navigate to operator home — will show pending state
              Navigator.pushReplacementNamed(context, '/operator/home');
            },
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text(
              'Return to Login',
              style: TextStyle(
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED UI COMPONENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStepHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade500,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF9CA3AF).withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.6),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF4F46E5),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildErrorBox() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4F46E5),
          side: const BorderSide(color: Color(0xFF4F46E5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18),
          ],
        ),
      ),
    );
  }
}
*/