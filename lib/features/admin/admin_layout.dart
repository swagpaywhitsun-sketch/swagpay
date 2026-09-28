import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/user.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';

class AdminLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const AdminLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Row(
          children: [
            if (isWide)
              IconButton(
                icon: Icon(_isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded, color: Colors.white70),
                onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SwagPay POS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        actions: [
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          const SizedBox(width: 4),
          // User Avatar with Settings Dropdown
          PopupMenuButton<String>(
            tooltip: 'Account Menu & Settings',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            onSelected: (val) {
              if (val == 'settings') {
                context.go('/admin/settings');
              } else if (val == 'reports') {
                context.go('/admin/reports');
              } else if (val == 'theme') {
                ref.read(themeModeProvider.notifier).toggleTheme();
              } else if (val == 'teller_mode') {
                ref.read(authProvider.notifier).switchRoleForDemo(UserRole.teller);
                context.go('/teller/dashboard');
              } else if (val == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/teller/login');
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Administrator',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      user?.email ?? 'admin@swagpay.com',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SUPER ADMIN POS',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                    ),
                    const Divider(height: 16),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: AppColors.primaryLight),
                    SizedBox(width: 10),
                    Text('System Settings & API', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 18, color: AppColors.success),
                    SizedBox(width: 10),
                    Text('Reports & Analytics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.brightness_6_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Toggle Dark / Light Mode', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'teller_mode',
                child: Row(
                  children: [
                    Icon(Icons.phone_android_rounded, size: 18, color: AppColors.gold),
                    SizedBox(width: 10),
                    Text('Switch to Teller Mobile App', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error)),
                  ],
                ),
              ),
            ],
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        user?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user?.fullName ?? 'Admin',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Persistent Desktop Sidebar
          if (isWide)
            Container(
              width: _isSidebarCollapsed ? 70 : 240,
              color: isDark ? AppColors.darkSurface : const Color(0xFF061829),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        _buildNavItem(Icons.dashboard_rounded, 'Dashboard', '/admin/dashboard'),
                        _buildNavItem(Icons.people_alt_rounded, 'Tellers & Staff', '/admin/tellers'),
                        _buildNavItem(Icons.point_of_sale_rounded, 'POS Terminals', '/admin/pos'),
                        _buildNavItem(Icons.receipt_long_rounded, 'Transactions', '/admin/transactions'),
                        _buildNavItem(Icons.undo_rounded, 'Refund Approvals', '/admin/refunds'),
                        _buildNavItem(Icons.insights_rounded, 'Reports & Analytics', '/admin/reports'),
                        _buildNavItem(Icons.account_balance_rounded, 'Settlement Pool', '/admin/settlements'),
                        _buildNavItem(Icons.history_edu_rounded, 'Audit Logs', '/admin/audit-logs'),
                        _buildNavItem(Icons.settings_applications_rounded, 'System Settings', '/admin/settings'),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: _isSidebarCollapsed
                        ? null
                        : const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    onTap: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/teller/login');
                    },
                  ),
                ],
              ),
            ),
          // Main Body Screen
          Expanded(
            child: Container(
              color: isDark ? AppColors.darkBackground : AppColors.background,
              child: widget.child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isWide
          ? BottomNavigationBar(
              currentIndex: _getMobileNavIndex(widget.currentRoute),
              onTap: (index) {
                if (index == 0) context.go('/admin/dashboard');
                if (index == 1) context.go('/admin/tellers');
                if (index == 2) context.go('/admin/pos');
                if (index == 3) context.go('/admin/transactions');
                if (index == 4) context.go('/admin/settings');
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Tellers'),
                BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'POS'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Txns'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            )
          : null,
    );
  }

  int _getMobileNavIndex(String route) {
    if (route.contains('/admin/tellers')) return 1;
    if (route.contains('/admin/pos')) return 2;
    if (route.contains('/admin/transactions')) return 3;
    if (route.contains('/admin/settings')) return 4;
    return 0;
  }

  Widget _buildNavItem(IconData icon, String label, String route) {
    final isSelected = widget.currentRoute == route;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.success : Colors.white70,
          size: 20,
        ),
        title: _isSidebarCollapsed
            ? null
            : Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
        dense: true,
        onTap: () => context.go(route),
      ),
    );
  }
}
