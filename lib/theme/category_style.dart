import 'package:flutter/material.dart';

import '../utils/constants.dart';

class CategoryStyle {
  static List<Color> gradientFor(String category) {
    switch (category) {
      case 'café':
        return const [Color(0xFF6F4E37), Color(0xFFD4A574)];
      case 'restaurante':
        return const [Color(0xFFE65100), Color(0xFFFF8A65)];
      case 'gimnasio':
        return const [Color(0xFF1565C0), Color(0xFF4DD0E1)];
      case 'retail':
        return const [Color(0xFF7B1FA2), Color(0xFFF48FB1)];
      case 'salud':
        return const [Color(0xFF2E7D32), Color(0xFF4DB6AC)];
      case 'lifestyle':
        return const [Color(0xFF5D4037), Color(0xFFBCAAA4)];
      case 'servicios':
        return const [Color(0xFF37474F), Color(0xFF78909C)];
      default:
        return AppConstants.brandGradientAccentColors;
    }
  }

  static IconData iconFor(String category) {
    switch (category) {
      case 'café':
        return Icons.coffee_rounded;
      case 'restaurante':
        return Icons.restaurant_rounded;
      case 'gimnasio':
        return Icons.fitness_center_rounded;
      case 'retail':
        return Icons.shopping_bag_rounded;
      case 'salud':
        return Icons.health_and_safety_rounded;
      case 'lifestyle':
        return Icons.spa_rounded;
      case 'servicios':
        return Icons.handyman_rounded;
      default:
        return Icons.store_rounded;
    }
  }

  static LinearGradient gradient(String category) {
    final colors = gradientFor(category);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  static Color badgeColor(String category) => gradientFor(category).first;
}
