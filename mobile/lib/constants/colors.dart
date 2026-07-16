import 'package:flutter/material.dart';

/// High-contrast colours used across the app.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0D47A1);
  static const Color accent = Color(0xFFFFA000);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
  static const Color background = Color(0xFFF5F5F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF212121);
  static const Color muted = Color(0xFF757575);

  // Zone banners
  static const Color zoneA = Color(0xFFD32F2F); // Red
  static const Color zoneB = Color(0xFF1976D2); // Blue
  static const Color zoneC = Color(0xFF388E3C); // Green

  static Color zoneColor(String zone) {
    switch (zone.toUpperCase()) {
      case 'ZONE A':
      case 'A':
        return zoneA;
      case 'ZONE B':
      case 'B':
        return zoneB;
      case 'ZONE C':
      case 'C':
        return zoneC;
      default:
        return primary;
    }
  }
}
