import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/providers.dart';
import 'user_avatar_widget.dart';

class TellerUserAvatarMenu extends ConsumerWidget {
  final bool isDark;

  const TellerUserAvatarMenu({
    super.key,
    required this.isDark,
  });

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String label,
    bool isDark, {
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final chevronColor = isDestructive
        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));

    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDestructive
                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                  : (isDark ? const Color(0xFF282F3E) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
                color: isDestructive
                    ? const Color(0xFFEF4444)
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: chevronColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final avatar = ref.watch(userAvatarProvider);
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);

    return PopupMenuButton<String>(
      tooltip: 'Account Menu',
      offset: const Offset(0, 50),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      color: cardBg,
      elevation: 16,
      onSelected: (val) {
        if (val == 'settings') {
          context.push('/teller/profile');
        } else if (val == 'reports') {
          context.push('/teller/reports');
        } else if (val == 'theme') {
          ref.read(themeModeProvider.notifier).toggleTheme();
        } else if (val == 'logout') {
          ref.read(authProvider.notifier).logout();
          context.go('/teller/login');
        }
      },
      itemBuilder: (ctx) => [
        // Uber Eats Compact Profile Header
        PopupMenuItem<String>(
          enabled: false,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: SizedBox(
            width: 245,
            child: Row(
              children: [
                UserAvatarWidget(
                  avatarData: avatar,
                  name: user?.fullName ?? 'Cashier',
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user?.fullName ?? 'Cashier',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user?.roleDisplay.toUpperCase() ?? 'VERIFIED CASHIER',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        _buildMenuItem('settings', Icons.tune_rounded, 'Settings', isDark),
        _buildMenuItem('reports', Icons.analytics_outlined, 'Performance & Shift', isDark),
        PopupMenuItem<String>(
          value: 'theme',
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282F3E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        _buildMenuItem('logout', Icons.logout_rounded, 'Sign Out', isDark, isDestructive: true),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF229ED9).withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: UserAvatarWidget(
              avatarData: avatar,
              name: user?.fullName ?? 'Cashier',
              radius: 16,
            ),
          ),
        ),
      ),
    );
  }
}
