import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'lively_widgets.dart';

class TellerBottomNavBar extends StatelessWidget {
  final String currentRoute;

  const TellerBottomNavBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);

    final navItems = [
      _NavItem(
        route: '/teller/dashboard',
        icon: Icons.grid_view_rounded,
        tooltip: 'Dashboard',
      ),
      _NavItem(
        route: '/teller/history',
        icon: Icons.receipt_long_rounded,
        tooltip: 'History',
      ),
      _NavItem(
        route: '/teller/collection',
        icon: Icons.point_of_sale_rounded,
        tooltip: 'Enter Amount',
        isCenterAction: true,
      ),
      _NavItem(
        route: '/teller/reports',
        icon: Icons.bar_chart_rounded,
        tooltip: 'Reports',
      ),
      _NavItem(
        route: '/teller/profile',
        icon: Icons.person_rounded,
        tooltip: 'Settings',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: navItems.map((item) {
                  final isSelected = currentRoute == item.route;

                  if (item.isCenterAction) {
                    return BouncyTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (!isSelected) {
                          context.go(item.route);
                        }
                      },
                      child: Tooltip(
                        message: item.tooltip,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF229ED9), Color(0xFF0E7490)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF229ED9).withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white30,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }

                  return BouncyTap(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (!isSelected) {
                        context.go(item.route);
                      }
                    },
                    child: Tooltip(
                      message: item.tooltip,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF229ED9).withValues(alpha: isDark ? 0.2 : 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF229ED9).withValues(alpha: 0.35)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color: isSelected
                                  ? const Color(0xFF229ED9)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 3),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 5 : 0,
                              height: isSelected ? 5 : 0,
                              decoration: const BoxDecoration(
                                color: Color(0xFF229ED9),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String tooltip;
  final bool isCenterAction;

  const _NavItem({
    required this.route,
    required this.icon,
    required this.tooltip,
    this.isCenterAction = false,
  });
}
