// lib/core/models/order_models.dart

import 'menu_models.dart';

class Order {
  final String id;
  final int? orderNumber;
  final String establishmentId;
  final String? tableId;
  final String? customerId;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final String? specialInstructions;
  final String? groupSessionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    this.orderNumber,
    required this.establishmentId,
    this.tableId,
    this.customerId,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    this.specialInstructions,
    this.groupSessionId,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber: json['order_number'] as int?,
      establishmentId: json['establishment_id'] as String,
      tableId: json['table_id'] as String?,
      customerId: json['customer_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      specialInstructions: json['special_instructions'] as String?,
      groupSessionId: json['group_session_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: (json['order_items'] as List?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_number': orderNumber,
    'establishment_id': establishmentId,
    'table_id': tableId,
    'customer_id': customerId,
    'status': status,
    'payment_status': paymentStatus,
    'total_amount': totalAmount,
    'special_instructions': specialInstructions,
    'group_session_id': groupSessionId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  bool get isPending => status == 'pending' || status == 'confirmed';
  bool get isCompleted => status == 'completed' || status == 'served';
  bool get isCancelled => status == 'cancelled';
  bool get isPaid => paymentStatus == 'paid';
}

class OrderItem {
  final String id;
  final String orderId;
  final String menuItemId;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? specialInstructions;
  final MenuItem? menuItem;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.specialInstructions,
    this.menuItem,
    required this.createdAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      menuItemId: json['menu_item_id'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
      specialInstructions: json['special_instructions'] as String?,
      menuItem: json['menu_items'] != null
          ? MenuItem.fromJson(json['menu_items'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'menu_item_id': menuItemId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'line_total': lineTotal,
    'special_instructions': specialInstructions,
    'created_at': createdAt.toIso8601String(),
  };
}