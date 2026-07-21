// lib/core/models/menu_models.dart

/// Safely parses a dynamic value (num, int, double, or numeric string
/// as sometimes returned by PostgREST for `numeric` columns) into a double.
/// This is the ONE place price parsing happens — never call `.toDouble()`
/// directly on a raw JSON value anywhere else in the app.
double parseMoney(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// A menu category. Global/shared across establishments.
class AppCategory {
  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;

  const AppCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.isActive,
  });

  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'display_order': displayOrder,
    'is_active': isActive,
  };
}

/// A menu item with tags (bestseller, recommended, etc. are tags)
class MenuItem {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final String categoryId;
  final String establishmentId;
  final bool isAvailable;
  final double rating;
  final int? preparationTime;
  final List<String> tags;
  final DateTime? deletedAt; // Per schema: soft delete support

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    required this.categoryId,
    required this.establishmentId,
    this.isAvailable = true,
    this.rating = 4.5,
    this.preparationTime,
    this.tags = const [],
    this.deletedAt,
  });

  bool get isBestseller => tags.contains('bestseller');
  bool get isRecommended => tags.contains('recommended');
  bool get isSpicy => tags.contains('spicy');
  bool get isVegan => tags.contains('vegan');

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      // FIXED: was `(json['price'] as num?)?.toDouble() ?? 0.0`, which
      // silently drops to 0.0 if Supabase ever returns the numeric column
      // as a JSON string instead of a number. parseMoney() handles both.
      price: parseMoney(json['price']),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      categoryId: json['category_id'] as String? ?? '',
      establishmentId: json['establishment_id'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      rating: parseMoney(json['rating']).clamp(0.0, 5.0),
      preparationTime: json['preparation_time'] as int?,
      tags: _parseTags(json),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  static List<String> _parseTags(Map<String, dynamic> json) {
    // If tags are joined via menu_item_tag_links
    final links = json['menu_item_tag_links'] as List?;
    if (links != null) {
      return links
          .map((l) => (l['menu_item_tags']?['name']) as String?)
          .whereType<String>()
          .toList();
    }
    // If tags are directly on the object (from a custom query)
    final tags = json['tags'] as List?;
    if (tags != null) {
      return tags.map((t) => t.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'image_url': imageUrl,
    'category_id': categoryId,
    'establishment_id': establishmentId,
    'is_available': isAvailable,
    'rating': rating,
    'preparation_time': preparationTime,
    'deleted_at': deletedAt?.toIso8601String(),
  };

  String get formattedPrice => 'MWK ${price.toStringAsFixed(0)}';
}

class CartItem {
  final MenuItem menuItem;
  final int quantity;
  final String? specialInstructions;

  const CartItem({
    required this.menuItem,
    required this.quantity,
    this.specialInstructions,
  });

  /// Single source of truth for a cart line's total. menuItem.price is
  /// already safely parsed via parseMoney(), and quantity is always a
  /// non-negative int, so this can never silently produce 0 for a line
  /// that actually has a price.
  double get totalPrice => menuItem.price * quantity;

  CartItem copyWith({
    MenuItem? menuItem,
    int? quantity,
    String? specialInstructions,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  Map<String, dynamic> toJson() => {
    'menu_item': menuItem.toJson(),
    'quantity': quantity,
    'special_instructions': specialInstructions,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      menuItem: MenuItem.fromJson(json['menu_item'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      specialInstructions: json['special_instructions'] as String?,
    );
  }
}

/// Sums the total price across an entire cart map ({itemId: CartItem}).
/// Use this everywhere a cart grand total is needed (customer_home.dart,
/// cart_bottom_sheet.dart, checkout_dialog.dart, etc.) so there is exactly
/// one implementation of "add up all the items" in the app.
double calculateCartTotal(Map<String, CartItem> cart) {
  double total = 0.0;
  for (final item in cart.values) {
    total += item.totalPrice;
  }
  return total;
}

/// Sums the total quantity across an entire cart map.
int calculateCartItemCount(Map<String, CartItem> cart) {
  int count = 0;
  for (final item in cart.values) {
    count += item.quantity;
  }
  return count;
}