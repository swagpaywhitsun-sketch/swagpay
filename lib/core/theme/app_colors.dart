import 'package:flutter/material.dart';

class AppColors {
  // Primary (Deep Navy Banking Blue)
  static const Color primary = Color(0xFF0A2540);
  static const Color primaryLight = Color(0xFF1E4E8C);
  static const Color primaryDark = Color(0xFF061829);

  // Accent & Semantic
  static const Color success = Color(0xFF00B37E);
  static const Color successDark = Color(0xFF00875A);
  static const Color gold = Color(0xFFF5A623);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2F80ED);
  static const Color warning = Color(0xFFF5A623);
  static const Color pending = Color(0xFFF5A623);

  // Neutral (Light)
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE1E6ED);
  static const Color textPrimary = Color(0xFF0A2540);
  static const Color textSecondary = Color(0xFF5A6B7B);
  static const Color textDisabled = Color(0xFFA0AAB5);
  static const Color divider = Color(0xFFEDF2F7);

  // Neutral (Dark Mode)
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceElevated = Color(0xFF21262D);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkTextPrimary = Color(0xFFF0F6FC);
  static const Color darkTextSecondary = Color(0xFF8B949E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF061829), Color(0xFF0A2540), Color(0xFF133E68)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00B37E), Color(0xFF00875A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
