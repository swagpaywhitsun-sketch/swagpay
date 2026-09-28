import 'package:flutter/material.dart';

class AppColors {
  // Telegram Brand Palette (#229ED9, #303030, #FFFFFF)
  static const Color primary = Color(0xFF229ED9); // Telegram Sky Blue
  static const Color primaryLight = Color(0xFF54B9EC);
  static const Color primaryDark = Color(0xFF1B82B3);

  // Telegram Dark / Charcoal (#303030)
  static const Color darkGraphite = Color(0xFF303030);
  static const Color darkGraphiteLight = Color(0xFF3E3E3E);

  // Accent & Semantic
  static const Color success = Color(0xFF2EBD85);
  static const Color successDark = Color(0xFF229A6B);
  static const Color gold = Color(0xFFF5A623);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF229ED9);
  static const Color warning = Color(0xFFF5A623);
  static const Color pending = Color(0xFFF5A623);

  // Neutral (Light Mode)
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E9EF);
  static const Color textPrimary = Color(0xFF303030); // Charcoal Text
  static const Color textSecondary = Color(0xFF707579); // Telegram Neutral
  static const Color textDisabled = Color(0xFFA2AAB3);
  static const Color divider = Color(0xFFEAEFF5);

  // Neutral (Dark Mode)
  static const Color darkBackground = Color(0xFF212121);
  static const Color darkSurface = Color(0xFF303030); // Telegram Charcoal Surface
  static const Color darkSurfaceElevated = Color(0xFF3E3E3E);
  static const Color darkBorder = Color(0xFF424242);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAAAAAA);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF303030), Color(0xFF229ED9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF2EBD85), Color(0xFF229A6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
