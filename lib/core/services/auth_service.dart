// lib/core/services/auth_service.dart

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_models.dart';
import 'supabase_service.dart';

/// Handles authentication, role detection, and post-login routing.
/// Keeps auth logic separate from the "fat" SupabaseService so
/// responsibilities stay clear.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = SupabaseService();
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// The user's type from the `public.users` table (not auth metadata).
  /// Updated after every sign-in so routing decisions are accurate.
  String? _userType;
  String? get userType => _userType;

  /// Cached profile for quick access without re-querying.
  UserProfile? _cachedProfile;
  UserProfile? get cachedProfile => _cachedProfile;

  /// Whether the auth service has finished its initial role resolution.
  bool _isReady = false;
  bool get isReady => _isReady;

  /// Call this once at app startup (e.g. in main.dart after Supabase init).
  /// It resolves the current user's type so the router can land them
  /// on the correct screen immediately.
  Future<void> initialize() async {
    if (!isAuthenticated) {
      _isReady = true;
      notifyListeners();
      return;
    }

    await _resolveUserType();
    _isReady = true;
    notifyListeners();
  }

  /// Sign in and immediately resolve the user's type.
  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _supabase.signIn(email, password);

    // Only resolve user type if sign-in was successful
    if (response.user != null) {
      await _resolveUserType();
    }
    notifyListeners();
    return response;
  }

  /// Sign up a new user. The DB trigger creates the `public.users` row.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String userType,
    String? fullName,
    String? phone,
  }) async {
    final response = await _supabase.signUp(
      email: email,
      password: password,
      userType: userType,
      fullName: fullName,
      phone: phone,
    );

    if (response.user != null) {
      // Type is already in metadata; the trigger will write it to public.users.
      _userType = userType;
    }
    notifyListeners();
    return response;
  }

  /// Returns the current user's full profile from Supabase.
  Future<UserProfile?> getCurrentUserProfile() async {
    return await _supabase.getCurrentUserProfile();
  }

  /// Sign out and clear all cached state.
  Future<void> signOut() async {
    await _supabase.signOut();
    _userType = null;
    _cachedProfile = null;
    _isReady = true;
    notifyListeners();
  }

  /// Refresh the cached profile and user type from the DB.
  Future<void> refreshProfile() async {
    await _resolveUserType();
    notifyListeners();
  }

  /// Internal: fetch `public.users` row and cache type + profile.
  /// NEVER throws — always completes with safe defaults.
  Future<void> _resolveUserType() async {
    final userId = currentUserId;
    if (userId == null) {
      _userType = null;
      _cachedProfile = null;
      return;
    }

    try {
      final profile = await _supabase.getCurrentUserProfile();
      _cachedProfile = profile;

      // Use profile userType if available, fallback to auth metadata
      if (profile != null) {
        _userType = profile.userType;
      } else {
        // Fallback to auth metadata when DB row is missing
        final metaType = currentUser?.userMetadata?['user_type'];
        _userType = metaType?.toString() ?? 'customer';
        developer.log('AuthService: using fallback user_type from metadata: $_userType',
            name: 'AuthService');
      }
    } catch (e, stackTrace) {
      developer.log('AuthService: failed to resolve user type: $e\n$stackTrace',
          name: 'AuthService');
      // Safe fallback — never crash the login flow
      final metaType = currentUser?.userMetadata?['user_type'];
      _userType = metaType?.toString() ?? 'customer';
      _cachedProfile = null;
    }
  }

  /// True if the current user is a customer.
  bool get isCustomer => _userType == 'customer';

  bool get isOperator => _userType == 'operator';
  bool get isKitchen => _userType == 'kitchen';
  bool get isSupervisor => _userType == 'supervisor';
  bool get isAdmin => _userType == 'admin';

  /// True for anyone who can manage an establishment (operator or staff).
  bool get isStaffAny => isOperator || isKitchen;

  /// Returns the establishmentId the current staff user is linked to,
  /// or null if they're a customer/unlinked.
  Future<String?> getLinkedEstablishmentId() async {
    if (!isStaffAny) return null;
    return await _supabase.getOperatorEstablishmentId();
  }
}