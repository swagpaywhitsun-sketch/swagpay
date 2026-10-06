import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/user_avatar_widget.dart';

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

  void _showAvatarPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);

    Future<void> pickAndSave(ImageSource source) async {
      try {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
        if (image != null) {
          final bytes = await image.readAsBytes();
          final b64 = base64Encode(bytes);
          ref.read(userAvatarProvider.notifier).setAvatar('data:image/jpeg;base64,$b64');
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Color(0xFF229ED9)),
            );
          }
        }
      } catch (_) {
        if (context.mounted) Navigator.pop(context);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final avatar = ref.watch(userAvatarProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Picture',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF303030),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Color(0xFF229ED9), size: 18),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => pickAndSave(ImageSource.gallery),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF229ED9), size: 18),
                  ),
                  title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => pickAndSave(ImageSource.camera),
                ),
                if (avatar != null && avatar.isNotEmpty) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFDC2626))),
                    onTap: () {
                      ref.read(userAvatarProvider.notifier).clearAvatar();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF1E293B),
        elevation: 0,
        toolbarHeight: 56,
        shape: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2E2E32) : const Color(0xFF334155),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            if (isWide)
              IconButton(
                tooltip: _isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                icon: Icon(
                  _isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              ),
            const SizedBox(width: 4),
            // Real Brand Logo
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'logo.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.point_of_sale_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SwagPay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF1570A6),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'ENTERPRISE POS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final repo = ref.watch(paymentRepositoryProvider);
              final isSyncing = repo.isLoading;
              return Tooltip(
                message: isSyncing ? 'Syncing live data from server...' : 'Live Synced • Click to sync now',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    ref.read(paymentRepositoryProvider).refreshFromBackend();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSyncing ? AppColors.primaryLight : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSyncing)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          isSyncing ? 'SYNCING' : 'LIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          const SizedBox(width: 4),
          // User Avatar with Settings Dropdown
          PopupMenuButton<String>(
            tooltip: 'Account Menu & Settings',
            offset: const Offset(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            onSelected: (val) {
              if (val == 'avatar') {
                _showAvatarPicker(context);
              } else if (val == 'settings') {
                context.go('/admin/settings');
              } else if (val == 'reports') {
                context.go('/admin/reports');
              } else if (val == 'theme') {
                ref.read(themeModeProvider.notifier).toggleTheme();
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
                        'SUPER ADMIN',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const Divider(height: 16),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'avatar',
                child: Row(
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Change Profile Picture', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: AppColors.primary),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatarWidget(
                      avatarData: ref.watch(userAvatarProvider),
                      name: user?.fullName ?? 'Admin',
                      radius: 13,
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
          // Persistent Desktop Sidebar (Never flashes on route changes)
          if (isWide)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 70 : 240,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFF1E293B),
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF2E2E32) : const Color(0xFF334155),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        _buildNavItem(Icons.dashboard_rounded, 'Dashboard', '/admin/dashboard'),
                        _buildNavItem(Icons.people_alt_rounded, 'Cashiers & Staff', '/admin/tellers'),
                        _buildNavItem(Icons.point_of_sale_rounded, 'POS Terminals', '/admin/pos'),
                        _buildNavItem(Icons.receipt_long_rounded, 'Transactions', '/admin/transactions'),
                        _buildNavItem(Icons.insights_rounded, 'Reports & Analytics', '/admin/reports'),
                        _buildNavItem(Icons.history_edu_rounded, 'Audit Logs', '/admin/audit-logs'),
                        _buildNavItem(Icons.lock_reset_rounded, 'Settings & Password', '/admin/settings'),
                      ],
                    ),
                  ),
                  Divider(
                    color: isDark ? const Color(0xFF2E2E32) : const Color(0xFF334155),
                    height: 1,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    title: _isSidebarCollapsed
                        ? null
                        : const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                    onTap: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/teller/login');
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          // Main Body Screen (Swapped instantly inside shell with zero layout flash)
          Expanded(
            child: Container(
              color: isDark ? AppColors.darkBackground : AppColors.background,
              child: widget.child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isWide
          ? Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2E2E32) : AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _getMobileNavIndex(widget.currentRoute),
                backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF707579),
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                onTap: (index) {
                  if (index == 0) context.go('/admin/dashboard');
                  if (index == 1) context.go('/admin/tellers');
                  if (index == 2) context.go('/admin/pos');
                  if (index == 3) context.go('/admin/transactions');
                  if (index == 4) context.go('/admin/settings');
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                  BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Cashiers'),
                  BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'POS'),
                  BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Txns'),
                  BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
                ],
              ),
            )
          : null,
    );
  }

  int _getMobileNavIndex(String route) {
    if (route.contains('/admin/tellers') || route.contains('/admin/cashiers')) return 1;
    if (route.contains('/admin/pos')) return 2;
    if (route.contains('/admin/transactions')) return 3;
    if (route.contains('/admin/settings')) return 4;
    return 0;
  }

  Widget _buildNavItem(IconData icon, String label, String route) {
    final isSelected = widget.currentRoute == route ||
        (route == '/admin/tellers' && widget.currentRoute == '/admin/cashiers');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1570A6) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Tooltip(
        message: _isSidebarCollapsed ? label : '',
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
            size: 20,
          ),
          title: _isSidebarCollapsed
              ? null
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                  ),
                ),
          dense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isSidebarCollapsed ? 16 : 14,
            vertical: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: () => context.go(route),
        ),
      ),
    );
  }
}
