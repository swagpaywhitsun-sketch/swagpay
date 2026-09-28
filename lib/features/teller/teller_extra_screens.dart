import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/customer.dart';
import '../../core/models/user.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';

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
    );
  }
}

class TellerProfileScreen extends ConsumerWidget {
  const TellerProfileScreen({super.key});

  void _showAvatarPicker(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urlController = TextEditingController();

    final presetAvatars = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
      'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200',
      'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Set Profile Picture',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose a profile avatar preset or provide a custom image URL:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: presetAvatars.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final pUrl = presetAvatars[idx];
                    return InkWell(
                      onTap: () {
                        ref.read(userAvatarProvider.notifier).setAvatar(pUrl);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile photo updated!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(36),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundImage: NetworkImage(pUrl),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Custom Photo URL (https://...)',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final text = urlController.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(userAvatarProvider.notifier).setAvatar(text);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile picture updated!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: const Text('Save Custom Photo URL'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(userAvatarProvider.notifier).clearAvatar();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile photo reset to default initial')),
                  );
                },
                child: const Text('Reset to Default Initial', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final avatar = ref.watch(userAvatarProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Teller Profile & Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & Name Card
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primary,
                        backgroundImage: avatar != null && avatar.startsWith('http')
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar == null || !avatar.startsWith('http')
                            ? Text(
                                user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'T',
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _showAvatarPicker(context, ref),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryDark,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAvatarPicker(context, ref),
                    icon: const Icon(Icons.photo_camera_rounded, size: 16),
                    label: const Text('Change Profile Picture', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullName ?? 'Teller Cashier',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${user?.roleDisplay} • ${user?.branch ?? 'Accra Mall Hub'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile info cards
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Teller Identifier'),
                    subtitle: Text(user?.id ?? 'TEL-001'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email Address'),
                    subtitle: Text(user?.email ?? 'teller@swagpay.com'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.point_of_sale_outlined),
                    title: const Text('Assigned POS Terminal'),
                    subtitle: Text(user?.assignedPos.firstOrNull ?? 'POS-01'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('Single Transaction Limit'),
                    subtitle: Text('GH₵ ${user?.singleTxnLimit.toStringAsFixed(0) ?? '10,000'}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hardware & Settings (Biometrics removed per instructions)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.print_rounded, color: AppColors.primary),
                    title: const Text('Bluetooth Thermal Printer'),
                    subtitle: const Text('Connected: ESC/POS Thermal 80mm'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bluetooth printer paired and ready')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                    title: const Text('Profile Picture'),
                    subtitle: const Text('Tap to change or upload avatar'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showAvatarPicker(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined, color: AppColors.gold),
                    title: const Text('Dark Mode Display'),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Switch to Admin POS
            OutlinedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).switchRoleForDemo(UserRole.admin);
                context.go('/admin/dashboard');
              },
              icon: const Icon(Icons.admin_panel_settings_rounded),
              label: const Text('Open Admin Web / POS Terminal View'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),

            // Logout
            ElevatedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/teller/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout of Counter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    );
  }
}
