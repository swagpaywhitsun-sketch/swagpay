import 'package:flutter/material.dart';

class AppColors {
  // Telegram Brand Palette (#229ED9, #303030, #FFFFFF)
  static const Color primary = Color(0xFF1570A6); // WCAG AA Compliant Sky-Blue (4.8:1 on white)
  static const Color primaryLight = Color(0xFF229ED9);
  static const Color primaryDark = Color(0xFF0E4C72);

  // Telegram Dark / Charcoal (#303030)
  static const Color darkGraphite = Color(0xFF303030);
  static const Color darkGraphiteLight = Color(0xFF3E3E3E);

  // Accent & Semantic
  static const Color success = Color(0xFF15803D); // High contrast emerald
  static const Color successDark = Color(0xFF166534);
  static const Color gold = Color(0xFFB45309);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF1570A6);
  static const Color warning = Color(0xFFB45309);
  static const Color pending = Color(0xFFB45309);

  // Shopify Polaris Palette
  static const Color shopifyGreen = Color(0xFF008060); // Polaris Emerald
  static const Color shopifyGreenDark = Color(0xFF006E52);
  static const Color shopifyGreenLight = Color(0xFFAEE9D1);

  // Neutral (Light Mode) — Shopify canvas
  static const Color background = Color(0xFFF6F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD1D5DB); // Enhanced contrast border
  static const Color textPrimary = Color(0xFF1F2937); // Charcoal Text (WCAG AAA)
  static const Color textSecondary = Color(0xFF4B5563); // WCAG AA compliant (7:1 contrast on white)
  static const Color textDisabled = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // Neutral (Dark Mode) — Telegram Charcoal
  static const Color darkBackground = Color(0xFF18181B);
  static const Color darkSurface = Color(0xFF27272A);
  static const Color darkSurfaceElevated = Color(0xFF3F3F46);
  static const Color darkBorder = Color(0xFF3F3F46);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFFD1D5DB);

  // Shopify Polaris dark canvas (teller suite)
  static const Color shopifyDarkBackground = Color(0xFF121214);
  static const Color shopifyDarkSurface = Color(0xFF1E1E22);
  static const Color shopifyDarkSurfaceElevated = Color(0xFF27272A);
  static const Color shopifyDarkBorder = Color(0xFF3F3F46);
  static const Color shopifyDarkTextSecondary = Color(0xFFD1D5DB);

  // Polaris badge tints (light mode)
  static const Color badgeSuccessBg = Color(0xFFDCFCE7);
  static const Color badgeSuccessFg = Color(0xFF14532D);
  static const Color badgePendingBg = Color(0xFFFEF3C7);
  static const Color badgePendingFg = Color(0xFF78350F);
  static const Color badgeFailedBg = Color(0xFFFEE2E2);
  static const Color badgeFailedFg = Color(0xFF7F1D1D);
  static const Color badgeRefundedBg = Color(0xFFE0F2FE);
  static const Color badgeRefundedFg = Color(0xFF0369A1);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF15803D), Color(0xFF166534)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
