// ============================================================================
// CANONICAL USER MODELS — Schema-Aligned Version
// ============================================================================
//
// Aligned with Supabase schema:
//   users: id, email, full_name, phone, user_type, dine_coins_balance,
//          profile_image_url, created_at, updated_at, deleted_at
//
// Establishment model lives in establishment_models.dart — do NOT duplicate.
// ============================================================================

import 'package:flutter/foundation.dart';

/// ============================================================================
/// USER PROFILE
/// ============================================================================
class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? profileImageUrl;
  final String userType; // 'customer', 'operator', 'kitchen', 'supervisor', 'admin'
  final double dineCoinsBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.profileImageUrl,
    this.userType = 'customer',
    this.dineCoinsBalance = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// Display name (full_name or fallback)
  String get displayName => fullName ?? email ?? 'User';

  /// Is staff member?
  bool get isStaff => userType != 'customer';

  /// Is admin or supervisor?
  bool get isAdmin => userType == 'admin' || userType == 'supervisor';

  // ─── JSON Serialization — aligned with schema columns ───
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      userType: json['user_type'] as String? ?? 'customer',
      dineCoinsBalance: (json['dine_coins_balance'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'user_type': userType,
      'dine_coins_balance': dineCoinsBalance,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // ─── copyWith ───
  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? profileImageUrl,
    String? userType,
    double? dineCoinsBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      userType: userType ?? this.userType,
      dineCoinsBalance: dineCoinsBalance ?? this.dineCoinsBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Equality ───
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserProfile(id: $id, name: $displayName, type: $userType)';
}

/// ============================================================================
/// STAFF ASSIGNMENT — Schema: staff_assignments
/// ============================================================================
class StaffAssignment {
  final String id;
  final String userId;
  final String establishmentId;
  final String? name;
  final String? email;
  final String role; // 'waiter', 'manager', 'supervisor', etc.
  final bool isActive;
  final DateTime? createdAt;

  const StaffAssignment({
    required this.id,
    required this.userId,
    required this.establishmentId,
    this.name,
    this.email,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  factory StaffAssignment.fromJson(Map<String, dynamic> json) {
    return StaffAssignment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      establishmentId: json['establishment_id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'establishment_id': establishmentId,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  StaffAssignment copyWith({
    String? id,
    String? userId,
    String? establishmentId,
    String? name,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return StaffAssignment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      establishmentId: establishmentId ?? this.establishmentId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// ============================================================================
/// KITCHEN ASSIGNMENT — Schema: kitchen_assignments
/// ============================================================================
class KitchenAssignment {
  final String id;
  final String userId;
  final String establishmentId;
  final String? assignedStation; // e.g., 'grill', 'fryer', 'salad', 'dessert'
  final bool isActive;
  final DateTime? createdAt;

  const KitchenAssignment({
    required this.id,
    required this.userId,
    required this.establishmentId,
    this.assignedStation,
    this.isActive = true,
    this.createdAt,
  });

  factory KitchenAssignment.fromJson(Map<String, dynamic> json) {
    return KitchenAssignment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      establishmentId: json['establishment_id'] as String,
      assignedStation: json['assigned_station'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'establishment_id': establishmentId,
      'assigned_station': assignedStation,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  KitchenAssignment copyWith({
    String? id,
    String? userId,
    String? establishmentId,
    String? assignedStation,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return KitchenAssignment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      establishmentId: establishmentId ?? this.establishmentId,
      assignedStation: assignedStation ?? this.assignedStation,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}