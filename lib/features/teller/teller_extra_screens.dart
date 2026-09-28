import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/models/customer.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_thin_footer.dart';
import '../../core/widgets/user_avatar_widget.dart';

class TellerNotificationsScreen extends ConsumerWidget {
  const TellerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final notifications = repo.getNotifications();
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications at this time'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${item.message}\n${dateFormat.format(item.timestamp)}'),
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
              const SnackBar(content: Text('Profile picture updated!'), backgroundColor: AppColors.success),
            );
          }
        }
      } catch (_) {
        if (context.mounted) Navigator.pop(context);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final avatar = ref.watch(userAvatarProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Profile Picture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => pickAndSave(ImageSource.gallery),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.success),
                  ),
                  title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => pickAndSave(ImageSource.camera),
                ),
                if (avatar != null && avatar.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showAvatarPicker(context),
                      child: Stack(
                        children: [
                          UserAvatarWidget(avatarData: avatar, name: user?.fullName ?? 'Teller', radius: 48),
                          Positioned(
                            bottom: 2, right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(user?.fullName ?? 'Teller Cashier', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      user?.email ?? 'teller@swagpay.com',
                      style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user?.roleDisplay ?? 'Teller',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _showAvatarPicker(context),
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: const Text('Change Profile Photo'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Account Information
            _sectionLabel('Account Information'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _infoTile(Icons.badge_outlined, AppColors.primary, 'Teller ID', user?.id ?? 'TEL-001'),
                  const Divider(height: 1, indent: 56),
                  _infoTile(Icons.email_outlined, AppColors.primaryLight, 'Email', user?.email ?? 'teller@swagpay.com'),
                  const Divider(height: 1, indent: 56),
                  _infoTile(Icons.phone_outlined, AppColors.success, 'Phone', user?.phone.isNotEmpty == true ? user!.phone : 'Not set'),
                  const Divider(height: 1, indent: 56),
                  _infoTile(Icons.store_outlined, AppColors.gold, 'Branch', user?.branch ?? 'Accra Mall Hub'),
                  const Divider(height: 1, indent: 56),
                  _infoTile(Icons.point_of_sale_outlined, AppColors.primaryDark, 'Assigned POS', user?.assignedPos.firstOrNull ?? 'POS-01'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App Preferences
            _sectionLabel('App Preferences'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: AppColors.gold, size: 20),
                ),
                title: Text(isDark ? 'Light Mode' : 'Dark Mode', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(isDark ? 'Switch to light theme' : 'Switch to dark theme', style: const TextStyle(fontSize: 12)),
                trailing: Switch(
                  value: isDark,
                  activeThumbColor: AppColors.primary,
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Logout
            ElevatedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/teller/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textSecondary),
    ),
  );

  Widget _infoTile(IconData icon, Color color, String title, String value) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 18),
    ),
    title: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    dense: true,
  );
}

class TellerOfflineQueueScreen extends ConsumerWidget {
  const TellerOfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final queue = repo.getOfflineQueue();

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Transaction Queue')),
      body: queue.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 64, color: AppColors.success),
                  const SizedBox(height: 16),
                  const Text(
                    'All Transactions Synced',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No pending offline collections in local cache.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Return to Dashboard'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.gold.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${queue.length} transaction(s) pending sync with central payment gateway.',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                      return Card(
                        child: ListTile(
                          title: Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${item.reference} • ₦${item.amount.toStringAsFixed(2)}'),
                          trailing: const Text('QUEUED', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
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
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync All Now'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Directory Lookup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 24),

            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_customer != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_customer!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(_customer!.accountNumber, style: const TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Phone Number', style: TextStyle(color: AppColors.textSecondary)),
                          Text(_customer!.phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/teller/collection'),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Send MoMo Prompt'),
                      ),
                    ],
                  ),
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
