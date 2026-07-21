// lib/core/models/establishment_models.dart

/// Establishment model — Schema: establishments
class Establishment {
  final String id;
  final String ownerId;
  final String name;
  final String type; // 'restaurant', 'pub', 'cafe', 'bar', etc.
  final String? address;
  final String? phone;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final bool supervisorApproved;
  final double dineCoinsBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Establishment({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    this.address,
    this.phone,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.supervisorApproved,
    required this.dineCoinsBalance,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'restaurant',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      supervisorApproved: json['supervisor_approved'] as bool? ?? false,
      dineCoinsBalance: (json['dine_coins_balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'type': type,
    'address': address,
    'phone': phone,
    'description': description,
    'image_url': imageUrl,
    'is_active': isActive,
    'supervisor_approved': supervisorApproved,
    'dine_coins_balance': dineCoinsBalance,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  bool get isVisibleToPublic => isActive && supervisorApproved;

  String get displayType {
    switch (type) {
      case 'restaurant':
        return 'Restaurant';
      case 'pub':
        return 'Pub';
      case 'cafe':
        return 'Café';
      case 'bar':
        return 'Bar';
      default:
        return type;
    }
  }
}

/// Table model — Schema: tables
/// Renamed from `Table` to `TableModel` to avoid conflict with Flutter's Table widget.
class TableModel {
  final String id;
  final String establishmentId;
  final int tableNumber;
  final String? label;
  final String? qrCode;
  final String? qrCodeData;
  final int? capacity;
  final bool isAvailable;
  final DateTime? occupiedAt;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;

  TableModel({
    required this.id,
    required this.establishmentId,
    required this.tableNumber,
    this.label,
    this.qrCode,
    this.qrCodeData,
    this.capacity,
    this.isAvailable = true,
    this.occupiedAt,
    this.lastActivityAt,
    this.createdAt,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] as String,
      establishmentId: json['establishment_id'] as String,
      tableNumber: json['table_number'] as int,
      label: json['label'] as String?,
      qrCode: json['qr_code'] as String?,
      qrCodeData: json['qr_code_data'] as String?,
      capacity: json['capacity'] as int?,
      isAvailable: json['is_available'] as bool? ?? true,
      occupiedAt: json['occupied_at'] != null
          ? DateTime.parse(json['occupied_at'] as String)
          : null,
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.parse(json['last_activity_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'establishment_id': establishmentId,
      'table_number': tableNumber,
      'label': label,
      'qr_code': qrCode,
      'qr_code_data': qrCodeData,
      'capacity': capacity,
      'is_available': isAvailable,
      'occupied_at': occupiedAt?.toIso8601String(),
      'last_activity_at': lastActivityAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}