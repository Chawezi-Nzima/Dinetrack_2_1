import 'package:flutter/material.dart';
import '../../../core/models/menu_models.dart';

class CategoryGrid extends StatelessWidget {
  final List<AppCategory> categories;
  final Function(AppCategory) onCategoryTap;
  final VoidCallback onSeeAll;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              GestureDetector(
                onTap: onSeeAll,
                child: const Text(
                  'See All',
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              return GestureDetector(
                onTap: () => onCategoryTap(category),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4F46E5).withOpacity(0.1),
                            const Color(0xFF4F46E5).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4F46E5).withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        _getCategoryIcon(category.name),
                        color: const Color(0xFF4F46E5),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 60,
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('appetizer')) return Icons.restaurant;
    if (lower.contains('main')) return Icons.dinner_dining;
    if (lower.contains('beverage') || lower.contains('drink')) return Icons.local_drink;
    if (lower.contains('dessert')) return Icons.cake;
    if (lower.contains('snack')) return Icons.fastfood;
    if (lower.contains('soup')) return Icons.soup_kitchen;
    if (lower.contains('salad')) return Icons.eco;
    return Icons.restaurant_menu;
  }
}