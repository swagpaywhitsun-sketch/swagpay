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

  // Shopify Polaris Palette
  static const Color shopifyGreen = Color(0xFF008060); // Polaris Emerald
  static const Color shopifyGreenDark = Color(0xFF006E52);
  static const Color shopifyGreenLight = Color(0xFFAEE9D1);

  // Neutral (Light Mode) — Shopify canvas
  static const Color background = Color(0xFFF6F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE1E3E5); // Polaris slate border
  static const Color textPrimary = Color(0xFF303030); // Charcoal Text
  static const Color textSecondary = Color(0xFF6B7280); // Polaris subdued
  static const Color textDisabled = Color(0xFFA2AAB3);
  static const Color divider = Color(0xFFEAEFF5);

  // Neutral (Dark Mode) — Telegram Charcoal
  static const Color darkBackground = Color(0xFF212121);
  static const Color darkSurface = Color(0xFF303030);
  static const Color darkSurfaceElevated = Color(0xFF3E3E3E);
  static const Color darkBorder = Color(0xFF424242);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAAAAAA);

  // Shopify Polaris dark canvas (teller suite)
  static const Color shopifyDarkBackground = Color(0xFF121214);
  static const Color shopifyDarkSurface = Color(0xFF1E1E22);
  static const Color shopifyDarkSurfaceElevated = Color(0xFF27272A);
  static const Color shopifyDarkBorder = Color(0xFF2E2E32);
  static const Color shopifyDarkTextSecondary = Color(0xFF9CA3AF);

  // Polaris badge tints (light mode)
  static const Color badgeSuccessBg = Color(0xFFAEE9D1);
  static const Color badgeSuccessFg = Color(0xFF0C5132);
  static const Color badgePendingBg = Color(0xFFFFEA8A);
  static const Color badgePendingFg = Color(0xFF916A00);
  static const Color badgeFailedBg = Color(0xFFFED3D1);
  static const Color badgeFailedFg = Color(0xFF921515);
  static const Color badgeRefundedBg = Color(0xFFA4E8F2);
  static const Color badgeRefundedFg = Color(0xFF005273);

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
