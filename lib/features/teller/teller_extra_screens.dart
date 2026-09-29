import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/models/customer.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/app_thin_footer.dart';
import '../../core/widgets/user_avatar_widget.dart';

class TellerNotificationsScreen extends ConsumerWidget {
  const TellerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final notifications = repo.getNotifications();
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: notifications.isEmpty
          ? Center(
              child: Text(
                'No notifications at this time',
                style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF229ED9), size: 18),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text('${item.message}\n${dateFormat.format(item.timestamp)}', style: const TextStyle(fontSize: 11)),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }
}

class TellerProfileScreen extends ConsumerStatefulWidget {
  const TellerProfileScreen({super.key});

  @override
  ConsumerState<TellerProfileScreen> createState() => _TellerProfileScreenState();
}

class _TellerProfileScreenState extends ConsumerState<TellerProfileScreen> {
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
    final avatar = ref.watch(userAvatarProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile Card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarPicker(context),
                    child: Stack(
                      children: [
                        UserAvatarWidget(avatarData: avatar, name: user?.fullName ?? 'Teller', radius: 40),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF229ED9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? 'Teller Cashier',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? 'teller@swagpay.com',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user?.roleDisplay ?? 'Teller Cashier',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF229ED9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Section 1: Account Information ───────────────────────
            _sectionLabel('Account & Terminal', isDark),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  _infoTile(Icons.badge_outlined, 'Teller ID', user?.id ?? 'TEL-001', isDark),
                  Divider(height: 1, indent: 52, color: borderColor),
                  _infoTile(Icons.email_outlined, 'Email Address', user?.email ?? 'teller@swagpay.com', isDark),
                  Divider(height: 1, indent: 52, color: borderColor),
                  _infoTile(Icons.phone_outlined, 'Phone Number', user?.phone.isNotEmpty == true ? user!.phone : 'Not set', isDark),
                  Divider(height: 1, indent: 52, color: borderColor),
                  _infoTile(Icons.storefront_outlined, 'Assigned Branch', user?.branch ?? 'Accra Mall Hub', isDark),
                  Divider(height: 1, indent: 52, color: borderColor),
                  _infoTile(Icons.point_of_sale_outlined, 'Assigned POS Terminal', user?.assignedPos.firstOrNull ?? 'POS-01', isDark),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Section 2: App Preferences ─────────────────────────
            _sectionLabel('App Preferences', isDark),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                    size: 18,
                  ),
                ),
                title: Text(
                  isDark ? 'Light Theme' : 'Dark Theme',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF303030),
                  ),
                ),
                subtitle: Text(
                  isDark ? 'Switch to light color mode' : 'Switch to dark color mode',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                ),
                trailing: Switch(
                  value: isDark,
                  activeThumbColor: const Color(0xFF229ED9),
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Section 3: Logout Action ──────────────────────────────
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/teller/login');
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('LOG OUT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }

  Widget _sectionLabel(String label, bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
    ),
  );

  Widget _infoTile(IconData icon, String title, String value, bool isDark) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563), size: 16),
    ),
    title: Text(title, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
    subtitle: Text(
      value,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF303030),
      ),
    ),
    dense: true,
  );
}

class TellerOfflineQueueScreen extends ConsumerWidget {
  const TellerOfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final queue = repo.getOfflineQueue();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        title: const Text('Offline Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: queue.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_done_outlined, size: 56, color: Color(0xFF229ED9)),
                  const SizedBox(height: 16),
                  Text(
                    'All Transactions Synced',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No pending offline collections in local storage',
                    style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF229ED9),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Return to Dashboard'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  color: const Color(0xFFFFF4E5),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${queue.length} transaction(s) pending sync with central gateway.',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A5300)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: queue.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5)),
                        ),
                        child: ListTile(
                          title: Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text('${item.reference} • GH₵ ${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                          trailing: const Text('QUEUED', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFD97706))),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final count = await ref.read(paymentRepositoryProvider).syncOfflineQueue();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully synced $count transaction(s) to server'),
                            backgroundColor: const Color(0xFF229ED9),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync All Now', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF229ED9)),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }
}

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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        title: const Text('Customer Directory Lookup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Phone, Account Number, or Client ID',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 20),

            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_customer != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFF229ED9),
                          child: Icon(Icons.person_outline_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_customer!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(_customer!.accountNumber, style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Phone Number', style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280), fontSize: 12)),
                        Text(_customer!.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/teller/collection'),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send MoMo Prompt'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF229ED9)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }
}
