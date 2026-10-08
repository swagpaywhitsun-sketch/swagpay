import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/models/customer.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/carrier_brand_icon.dart';
import '../../core/widgets/lively_widgets.dart';
import '../../core/widgets/notification_dropdown_button.dart';
import '../../core/widgets/teller_bottom_nav_bar.dart';
import '../../core/widgets/teller_user_avatar_menu.dart';
import '../../core/widgets/user_avatar_widget.dart';

// ── NOTIFICATIONS SCREEN ─────────────────────────────────────────────────────
class TellerNotificationsScreen extends ConsumerWidget {
  const TellerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final notifications = repo.getNotifications();
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(paymentRepositoryProvider).markAllNotificationsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read'), backgroundColor: Color(0xFF10B981)),
              );
            },
          ),
          TellerUserAvatarMenu(isDark: isDark),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF229ED9).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_none_rounded, size: 48, color: Color(0xFF229ED9)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No new alerts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are fully up to date with counter activities.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return BouncyTap(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF229ED9), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const PulsingBeacon(color: Color(0xFF229ED9), size: 6, showRipple: false),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateFormat.format(item.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (index * 40).ms).slideY(begin: 0.05, end: 0);
              },
            ),
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/notifications'),
    );
  }
}

// ── SETTINGS & PROFILE SCREEN ────────────────────────────────────────────────
class TellerProfileScreen extends ConsumerStatefulWidget {
  const TellerProfileScreen({super.key});

  @override
  ConsumerState<TellerProfileScreen> createState() => _TellerProfileScreenState();
}

class _TellerProfileScreenState extends ConsumerState<TellerProfileScreen> {
  void _showAvatarPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);

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
              const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Color(0xFF10B981)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    child: const Icon(Icons.photo_library_outlined, color: Color(0xFF229ED9), size: 20),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
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
                    child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF229ED9), size: 20),
                  ),
                  title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => pickAndSave(ImageSource.camera),
                ),
                if (avatar != null && avatar.isNotEmpty) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFFEF4444))),
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
    final avatar = ref.watch(userAvatarProvider);
    final repo = ref.watch(paymentRepositoryProvider);
    final matchedPos = repo.getPosDevices().where((p) => user?.assignedPos.contains(p.id) == true || user?.assignedPos.contains(p.serialNumber) == true).firstOrNull;
    final matchedTeller = repo.getTellers().where((t) => t.id == user?.id || t.email == user?.email).firstOrNull;
    final resolvedBranch = (user?.branch != null && user!.branch!.trim().isNotEmpty)
        ? user.branch!
        : (matchedTeller?.branch != null && matchedTeller!.branch!.trim().isNotEmpty)
            ? matchedTeller.branch!
            : (matchedPos?.branch != null && matchedPos!.branch.trim().isNotEmpty)
                ? matchedPos.branch
                : 'Accra Central Hub - Counter 1';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8);
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/teller/dashboard'),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          NotificationDropdownButton(isDark: isDark),
          const SizedBox(width: 8),
          TellerUserAvatarMenu(isDark: isDark),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dribbble Profile Hero Card ───────────────────────────
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E2430), Color(0xFF161A22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Colors.white, Color(0xFFF8FAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  BouncyTap(
                    onTap: () => _showAvatarPicker(context),
                    child: Stack(
                      children: [
                        GlowHalo(
                          glowColor: const Color(0xFF229ED9),
                          blurRadius: 18,
                          child: UserAvatarWidget(
                            avatarData: avatar,
                            name: user?.fullName ?? 'Cashier',
                            radius: 44,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Color(0xFF229ED9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.fullName ?? 'Cashier',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PulsingBeacon(color: Color(0xFF10B981), size: 6),
                            const SizedBox(width: 6),
                            Text(
                              user?.roleDisplay.toUpperCase() ?? 'VERIFIED CASHIER',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 20),

            // ── Live Terminal & Hardware Diagnostics ─────────────────
            _sectionLabel('Assigned POS Terminal', isDark),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  _infoTile(
                    Icons.point_of_sale_rounded,
                    'POS Hardware Assigned',
                    (user?.assignedPos.contains('ANY_POS') == true || user?.assignedPos.isEmpty == true)
                        ? 'Universal Access'
                        : (user?.assignedPos.firstOrNull ?? 'Universal Access'),
                    isDark,
                  ),
                  Divider(height: 1, indent: 52, color: borderColor),
                  _infoTile(
                    Icons.storefront_outlined,
                    'Branch Location',
                    resolvedBranch,
                    isDark,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
            const SizedBox(height: 20),

            // ── App Preferences & Tactile Toggles ────────────────────
            _sectionLabel('Tactile App Preferences', isDark),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: const Color(0xFF229ED9),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      isDark ? 'Dark Theme' : 'Light Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      isDark ? 'Active sleek dark mode' : 'Active daylight theme',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    trailing: Switch(
                      value: isDark,
                      activeThumbColor: const Color(0xFF229ED9),
                      onChanged: (_) {
                        HapticFeedback.selectionClick();
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                    ),
                  ),
                  Divider(height: 1, indent: 52, color: borderColor),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.vibration_rounded, color: Color(0xFF10B981), size: 18),
                    ),
                    title: Text(
                      'Haptic Numpad & Touch Feedback',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      'Tactile spring vibration on every keypress',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    trailing: Switch(
                      value: ref.watch(hapticFeedbackProvider),
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        ref.read(hapticFeedbackProvider.notifier).toggle(val);
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
            const SizedBox(height: 24),

            // ── Logout Button ─────────────────────────────────────────
            BouncyTap(
              onTap: () {
                HapticFeedback.heavyImpact();
                ref.read(authProvider.notifier).logout();
                context.go('/teller/login');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'SIGN OUT FROM TERMINAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/profile'),
    );
  }

  Widget _sectionLabel(String label, bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    ),
  );

  Widget _infoTile(IconData icon, String title, String value, bool isDark) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF229ED9).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: const Color(0xFF229ED9), size: 18),
    ),
    title: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
    subtitle: Text(
      value,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
    ),
    dense: true,
  );
}

// ── OFFLINE QUEUE SCREEN ─────────────────────────────────────────────────────
class TellerOfflineQueueScreen extends ConsumerWidget {
  const TellerOfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final queue = repo.getOfflineQueue();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Offline Sync Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          TellerUserAvatarMenu(isDark: isDark),
        ],
      ),
      body: queue.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_done_rounded, size: 56, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'All Collections Synced',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No pending offline collections in local hardware storage.',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  BouncyTap(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF229ED9), Color(0xFF1570A6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Return to Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const PulsingBeacon(color: Color(0xFFF59E0B), size: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${queue.length} transaction(s) pending sync with central server.',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: queue.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            CarrierBrandIcon(network: item.network, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('${item.reference} • ${item.displayPhone}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('GH₵ ${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('QUEUED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFFF59E0B))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: BouncyTap(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      final count = await ref.read(paymentRepositoryProvider).syncOfflineQueue();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully synced $count transaction(s) to server'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF229ED9), Color(0xFF1570A6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF229ED9).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('SYNC ALL TRANSACTIONS NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/offline-queue'),
    );
  }
}

// ── CUSTOMER DIRECTORY LOOKUP ────────────────────────────────────────────────
class CustomerLookupScreen extends ConsumerStatefulWidget {
  const CustomerLookupScreen({super.key});

  @override
  ConsumerState<CustomerLookupScreen> createState() => _CustomerLookupScreenState();
}

class _CustomerLookupScreenState extends ConsumerState<CustomerLookupScreen> {
  final _controller = TextEditingController();
  Customer? _customer;
  bool _isLoading = false;

  void _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    final res = await ref.read(paymentRepositoryProvider).lookupCustomer(query);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _customer = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Customer Directory Lookup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          TellerUserAvatarMenu(isDark: isDark),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Phone, Account Number, or Client ID',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF229ED9)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF229ED9)),
                    onPressed: _search,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator(color: Color(0xFF229ED9))),
            ] else if (_customer != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GlowHalo(
                          glowColor: const Color(0xFF229ED9),
                          blurRadius: 12,
                          child: const CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0xFF229ED9),
                            child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _customer!.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Account: ${_customer!.accountNumber}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Phone Number', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                        Text(_customer!.phone, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    BouncyTap(
                      onTap: () => context.push('/teller/collection'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF229ED9), Color(0xFF1570A6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF229ED9).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('INITIATE MOMO COLLECTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/profile'),
    );
  }
}
