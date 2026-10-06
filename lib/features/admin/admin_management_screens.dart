import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/pos_device.dart';
import '../../core/models/transaction.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';

// ─── TELLERS MANAGEMENT SCREEN ───────────────────────────────────────────────
class AdminTellersScreen extends ConsumerStatefulWidget {
  const AdminTellersScreen({super.key});

  @override
  ConsumerState<AdminTellersScreen> createState() => _AdminTellersScreenState();
}

class _AdminTellersScreenState extends ConsumerState<AdminTellersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
    });
  }

  void _showAddTellerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Swag@1234');
    final singleLimitCtrl = TextEditingController(text: '10000');
    final dailyLimitCtrl = TextEditingController(text: '50000');
    final branchCtrl = TextEditingController();
    final repo = ref.read(paymentRepositoryProvider);
    final posDevices = repo.getPosDevices();
    String selectedPosId = 'ANY_POS';
    bool showPassword = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New Cashier'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 480, maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address (Used for Login) *')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'Initial Login Password *',
                      helperText: 'Default password is Swag@1234. Staff can change this upon login.',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setDialogState(() => showPassword = !showPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number (Used for Login)')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: branchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Branch / Location',
                      hintText: 'Enter branch or location',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // POS Selector (Default to Universal Access)
                  DropdownButtonFormField<String>(
                    initialValue: selectedPosId,
                    decoration: const InputDecoration(labelText: 'Assigned POS Terminal *'),
                    items: [
                      const DropdownMenuItem(
                        value: 'ANY_POS',
                        child: Text(
                          'Universal Access (Any POS Terminal)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1570A6)),
                        ),
                      ),
                      ...posDevices.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.serialNumber})'))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedPosId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: singleLimitCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Single Txn Limit (GH₵)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dailyLimitCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Daily Limit (GH₵)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      final pwd = passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : 'Swag@1234';
                      final newTeller = AppUser(
                        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
                        fullName: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        role: UserRole.teller,
                        branch: branchCtrl.text.trim(),
                        assignedPos: selectedPosId == 'ANY_POS' ? ['ANY_POS'] : [selectedPosId],
                        singleTxnLimit: double.tryParse(singleLimitCtrl.text) ?? 10000.0,
                        dailyLimit: double.tryParse(dailyLimitCtrl.text) ?? 50000.0,
                      );
                      String? secret;
                      Object? failure;
                      try {
                        secret = await repo.addTeller(newTeller, initialPassword: pwd);
                      } catch (e) {
                        failure = e;
                      }
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (failure != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not save cashier: ${failure is ApiException ? failure.message : '$failure'}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } else {
                        _showCredentialsDialog(
                          context,
                          name: newTeller.fullName,
                          phone: newTeller.phone,
                          email: newTeller.email,
                          password: secret ?? pwd,
                          pos: selectedPosId == 'ANY_POS' ? 'Universal Access (Any Terminal)' : selectedPosId,
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Cashier'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCredentialsDialog(
    BuildContext context, {
    required String name,
    required String phone,
    required String email,
    required String password,
    required String pos,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Staff Account Created', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 460, maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Account for "$name" has been provisioned. Share these sign-in credentials with the staff member:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  children: [
                    if (phone.trim().isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.phone_iphone_rounded, size: 16, color: Color(0xFF1570A6)),
                              SizedBox(width: 6),
                              Text('Login Phone:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          SelectableText(
                            phone,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1570A6)),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Login Email:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        SelectableText(email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Password:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1570A6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            password,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1570A6), fontFamily: 'Courier'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Terminal Access:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(pos, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The staff member can easily sign in from any POS terminal using either their Phone Number or Email with this password.',
                      style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              final phoneLine = phone.trim().isNotEmpty ? 'Login Phone: $phone\n' : '';
              Clipboard.setData(ClipboardData(
                text: 'SwagPay Cashier Login Credentials:\n${phoneLine}Login Email: $email\nPassword: $password\nTerminal Access: $pos',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Credentials copied to clipboard!'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Credentials'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showConfigureLimitsDialog(BuildContext context, AppUser teller) {
    final singleCtrl = TextEditingController(text: teller.singleTxnLimit.toStringAsFixed(0));
    final dailyCtrl = TextEditingController(text: teller.dailyLimit.toStringAsFixed(0));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configure Staff Limits', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(
                      '${teller.fullName} • ${teller.roleDisplay}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 480, maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Single limit restricts maximum collection per transaction. Daily limit caps total counter collections per working day.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'SINGLE TRANSACTION LIMIT (GH₵)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: singleCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'GH₵ ',
                      hintText: 'e.g. 10000',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [1000, 5000, 10000, 50000, 100000, 500000].map((amt) {
                      return ActionChip(
                        label: Text('GH₵ ${amt >= 1000 ? "${amt ~/ 1000}k" : amt}', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            singleCtrl.text = amt.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'DAILY AGGREGATE LIMIT (GH₵)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dailyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'GH₵ ',
                      hintText: 'e.g. 50000',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [10000, 50000, 200000, 500000, 1000000, 5000000].map((amt) {
                      return ActionChip(
                        label: Text('GH₵ ${amt >= 1000000 ? "${amt ~/ 1000000}M" : "${amt ~/ 1000}k"}', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            dailyCtrl.text = amt.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final sLimit = double.tryParse(singleCtrl.text.trim());
                final dLimit = double.tryParse(dailyCtrl.text.trim());
                if (sLimit == null || dLimit == null || sLimit <= 0 || dLimit <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid positive numbers for limits'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(paymentRepositoryProvider).updateTellerLimits(
                    teller.id,
                    singleTxnLimit: sLimit,
                    dailyLimit: dLimit,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Limits successfully updated for ${teller.fullName}: Single GH₵ ${sLimit.toStringAsFixed(0)}, Daily GH₵ ${dLimit.toStringAsFixed(0)}'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update limits: ${e is ApiException ? e.message : '$e'}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Limit Settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTeller(BuildContext context, AppUser teller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            const Text('Delete Cashier'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 460, maxWidth: 520),
          child: Text(
            'Are you sure you want to permanently delete "${teller.fullName}" (${teller.email})?\n\nThis will immediately revoke their access and deactivate their terminal assignment.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(paymentRepositoryProvider).deleteTeller(teller.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cashier "${teller.fullName}" was deleted successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete cashier: ${e is ApiException ? e.message : '$e'}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete Cashier'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, AppUser teller) {
    final passwordCtrl = TextEditingController(text: 'Swag@1234');
    bool obscure = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF1570A6), size: 24),
              SizedBox(width: 8),
              Text('Reset Staff Password'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 420, maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set a new password for "${teller.fullName}" (${teller.email}). They will use this password to sign in immediately.',
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Minimum 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Default suggested: Swag@1234',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1570A6),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newPass = passwordCtrl.text.trim();
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(paymentRepositoryProvider).adminResetTellerPassword(teller.id, newPass);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password for "${teller.fullName}" was successfully reset to "$newPass".'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reset password: ${e is ApiException ? e.message : '$e'}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Save New Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allTellers = repo.getTellers();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final q = _searchCtrl.text.trim().toLowerCase();
    final tellers = allTellers.where((t) {
      if (q.isEmpty) return true;
      return t.fullName.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q) ||
          t.phone.toLowerCase().contains(q) ||
          (t.branch ?? '').toLowerCase().contains(q);
    }).toList();

    final activeCount = allTellers.where((t) => t.isActive).length;
    final totalLimit = allTellers.fold<double>(0.0, (acc, t) => acc + t.singleTxnLimit);
    final avgLimit = allTellers.isNotEmpty ? totalLimit / allTellers.length : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cashier & Staff Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Manage cashier accounts, counter POS assignments, and authorization limits',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => repo.refreshFromBackend(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Refresh from Supabase',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTellerDialog(context),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Cashier'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final isNarrow = constraints.maxWidth < 440;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: isWide ? 16 : 10,
                mainAxisSpacing: isWide ? 16 : 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : (isNarrow ? 1.22 : 1.45),
                children: [
                  StatCard(
                    title: 'Total Cashiers',
                    value: '${allTellers.length}',
                    icon: Icons.people_alt_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: 'Registered cashiers',
                  ),
                  StatCard(
                    title: 'Active Counters',
                    value: '$activeCount',
                    icon: Icons.check_circle_rounded,
                    accentColor: AppColors.success,
                    subtitle: '${allTellers.length - activeCount} suspended',
                  ),
                  StatCard(
                    title: 'Avg. Single Limit',
                    value: 'GH₵ ${NumberFormat('#,##0').format(avgLimit)}',
                    icon: Icons.security_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Per transaction cap',
                  ),
                  StatCard(
                    title: 'Assigned POS Nodes',
                    value: '${allTellers.expand((t) => t.assignedPos).toSet().length}',
                    icon: Icons.point_of_sale_rounded,
                    accentColor: AppColors.primary,
                    subtitle: 'Hardware terminals',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search & Filter Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search cashier by name, email, phone, or branch...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Full-width Table Card
          Card(
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (tellers.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(48),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No cashiers found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Try adjusting your search query or add a new cashier.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddTellerDialog(context),
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: const Text('Add Cashier Now'),
                        ),
                      ],
                    ),
                  );
                }

                if (constraints.maxWidth < 768) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tellers.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildMobileCashierCard(context, tellers[index], isDark);
                        },
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${tellers.length} of ${allTellers.length} cashiers',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            TextButton.icon(
                              onPressed: () => repo.refreshFromBackend(),
                              icon: const Icon(Icons.sync_rounded, size: 14),
                              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 28,
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 64,
                          headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('CASHIER ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('CASHIER NAME & EMAIL', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('PHONE NUMBER', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('BRANCH / HUB', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ASSIGNED POS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('TXN LIMIT', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ROLE & STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: tellers.map((t) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(t.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 14),
                                        tooltip: 'Copy Cashier ID',
                                        splashRadius: 14,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: t.id));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Copied Cashier ID "${t.id}"'), duration: const Duration(seconds: 1)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text(t.email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(t.phone.isNotEmpty ? t.phone : '—', style: const TextStyle(fontSize: 12)),
                                      if (t.phone.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 12),
                                          tooltip: 'Copy Phone',
                                          splashRadius: 12,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: t.phone));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Copied phone "${t.phone}"'), duration: const Duration(seconds: 1)),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                DataCell(Text((t.branch != null && t.branch!.trim().isNotEmpty) ? t.branch! : '—', style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (t.assignedPos.contains('ANY_POS') || t.assignedPos.isEmpty)
                                          ? const Color(0xFF1570A6).withValues(alpha: 0.12)
                                          : AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (t.assignedPos.contains('ANY_POS') || t.assignedPos.isEmpty)
                                          ? 'Universal (Any POS)'
                                          : t.assignedPos.join(', '),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: (t.assignedPos.contains('ANY_POS') || t.assignedPos.isEmpty)
                                            ? const Color(0xFF1570A6)
                                            : AppColors.primaryLight,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('GH₵ ${NumberFormat('#,##0').format(t.singleTxnLimit)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                      Text('Daily: GH₵ ${NumberFormat('#,##0').format(t.dailyLimit)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          t.role == UserRole.teller ? 'CASHIER' : (t.role == UserRole.seniorTeller ? 'SENIOR CASHIER' : t.role.name.toUpperCase()),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: t.isActive ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          t.isActive ? 'ACTIVE' : 'OFFLINE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: t.isActive ? AppColors.successDark : AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.tune_rounded, size: 18),
                                        tooltip: 'Configure Limits',
                                        onPressed: () => _showConfigureLimitsDialog(context, t),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFF1570A6)),
                                        tooltip: 'Reset Password',
                                        onPressed: () => _showResetPasswordDialog(context, t),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                        tooltip: 'Delete Cashier',
                                        onPressed: () => _confirmDeleteTeller(context, t),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Table Footer
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${tellers.length} of ${allTellers.length} cashier records • Live synced with Supabase PostgreSQL',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          TextButton.icon(
                            onPressed: () => repo.refreshFromBackend(),
                            icon: const Icon(Icons.sync_rounded, size: 14),
                            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCashierCard(BuildContext context, AppUser t, bool isDark) {
    final branchText = (t.branch != null && t.branch!.trim().isNotEmpty) ? t.branch! : '—';
    final isUniversal = t.assignedPos.contains('ANY_POS') || t.assignedPos.isEmpty;
    final assignedText = isUniversal ? 'Universal (Any POS)' : t.assignedPos.join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: ID badge + Role + Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.id,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: t.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied Cashier ID "${t.id}"'), duration: const Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.role == UserRole.teller ? 'CASHIER' : (t.role == UserRole.seniorTeller ? 'SENIOR CASHIER' : t.role.name.toUpperCase()),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: t.isActive ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.isActive ? 'ACTIVE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: t.isActive ? AppColors.successDark : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Name and Email
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                child: Text(
                  t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : 'C',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      t.email,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Phone & Branch
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        t.phone.isNotEmpty ? t.phone : '—',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (t.phone.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: t.phone));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied phone "${t.phone}"'), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.store_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        branchText,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Details Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Single Txn Limit', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        Text('GH₵ ${NumberFormat('#,##0').format(t.singleTxnLimit)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Daily Limit', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        Text('GH₵ ${NumberFormat('#,##0').format(t.dailyLimit)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('POS: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Expanded(
                      child: Text(
                        assignedText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isUniversal ? const Color(0xFF1570A6) : AppColors.primaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showConfigureLimitsDialog(context, t),
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Limits', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showResetPasswordDialog(context, t),
                icon: const Icon(Icons.lock_reset_rounded, size: 14, color: Color(0xFF1570A6)),
                label: const Text('Reset', style: TextStyle(fontSize: 12, color: Color(0xFF1570A6))),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                onPressed: () => _confirmDeleteTeller(context, t),
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('Delete', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── POS HARDWARE MANAGEMENT SCREEN ──────────────────────────────────────────
class AdminPosScreen extends ConsumerStatefulWidget {
  const AdminPosScreen({super.key});

  @override
  ConsumerState<AdminPosScreen> createState() => _AdminPosScreenState();
}

class _AdminPosScreenState extends ConsumerState<AdminPosScreen> {
  final _searchCtrl = TextEditingController();
  PosDevice? _selectedPos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
    });
  }

  void _showAddPosDialog(BuildContext context) {
    final codeCtrl = TextEditingController(text: 'POS-0${DateTime.now().millisecond}');
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register New POS Hardware Terminal'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 480, maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Terminal Code (e.g. POS-02)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Terminal Name *',
                  hintText: 'e.g. Counter 1, Till 2',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(
                  labelText: 'Physical Location / Branch',
                  hintText: 'Enter branch or physical location',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) return;
              final newPos = PosDevice(
                id: 'pos_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
                serialNumber: codeCtrl.text.trim(),
                deviceFingerprint: codeCtrl.text.trim(),
                branch: locCtrl.text.trim(),
                location: locCtrl.text.trim(),
                status: PosStatus.online,
                isWhitelisted: true,
                lastSeen: DateTime.now(),
              );
              Object? failure;
              try {
                await ref.read(paymentRepositoryProvider).addPosDevice(newPos);
              } catch (e) {
                failure = e;
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(failure == null
                      ? 'Terminal registered successfully.'
                      : 'Could not register terminal: ${failure is ApiException ? failure.message : '$failure'}'),
                  backgroundColor: failure == null ? AppColors.success : AppColors.error,
                ),
              );
            },
            child: const Text('Register Terminal'),
          ),
        ],
      ),
    );
  }

  void _showEditPosDialog(BuildContext context, PosDevice pos) {
    final nameCtrl = TextEditingController(text: pos.name);
    final codeCtrl = TextEditingController(text: pos.serialNumber);
    final locCtrl = TextEditingController(text: pos.location);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Terminal (${pos.serialNumber})'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 480, maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Terminal Code')),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Terminal Name')),
              const SizedBox(height: 12),
              TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location / Counter')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = pos.copyWith(
                name: nameCtrl.text.trim(),
                serialNumber: codeCtrl.text.trim(),
                location: locCtrl.text.trim(),
              );
              await ref.read(paymentRepositoryProvider).updatePosDevice(updated);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Terminal "${updated.name}" updated.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePos(BuildContext context, PosDevice pos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            const Text('Delete POS Terminal'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 460, maxWidth: 520),
          child: Text(
            'Are you sure you want to permanently delete POS terminal "${pos.name}" (${pos.serialNumber})?\n\nCashiers assigned to this terminal will automatically fallback to universal access.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(paymentRepositoryProvider).deletePosDevice(pos.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('POS terminal "${pos.name}" deleted successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete POS terminal: ${e is ApiException ? e.message : '$e'}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete Terminal'),
          ),
        ],
      ),
    );
  }

  void _showPosDetailsDialog(BuildContext context, PosDevice pos) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pos.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Terminal Code: ${pos.serialNumber}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Courier')),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 480, maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailTile('Terminal ID', pos.id),
              const Divider(height: 12),
              _buildDetailTile('Location', pos.location.isNotEmpty ? pos.location : '—'),
              const Divider(height: 12),
              _buildDetailTile('Hardware Fingerprint', pos.deviceFingerprint),
              const Divider(height: 12),
              _buildDetailTile('Last Heartbeat', dateFormat.format(pos.lastSeen)),
              const Divider(height: 12),
              _buildDetailTile('Connection Status', pos.status == PosStatus.online ? 'Online' : 'Offline'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditPosDialog(context, pos);
            },
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allDevices = repo.getPosDevices();
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final q = _searchCtrl.text.trim().toLowerCase();
    final posDevices = allDevices.where((p) {
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.serialNumber.toLowerCase().contains(q) ||
          p.location.toLowerCase().contains(q);
    }).toList();

    final onlineCount = allDevices.where((p) => p.status == PosStatus.online).length;
    final activeCount = allDevices.where((p) => p.isActive).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 768;
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('POS Hardware & Terminals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Hardware POS terminal provision, branch assignment, and device monitoring',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              );

              final actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => repo.refreshFromBackend(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Refresh from Supabase',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPosDialog(context),
                    icon: const Icon(Icons.add_to_queue_rounded, size: 18),
                    label: const Text('Add POS Terminal'),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // KPI Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final isNarrow = constraints.maxWidth < 440;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: isWide ? 16 : 10,
                mainAxisSpacing: isWide ? 16 : 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : (isNarrow ? 1.22 : 1.45),
                children: [
                  StatCard(
                    title: 'Total Terminals',
                    value: '${allDevices.length}',
                    icon: Icons.point_of_sale_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: 'Provisioned devices',
                  ),
                  StatCard(
                    title: 'Terminals Online',
                    value: '$onlineCount',
                    icon: Icons.wifi_rounded,
                    accentColor: AppColors.success,
                    subtitle: '${allDevices.length - onlineCount} disconnected',
                  ),
                  StatCard(
                    title: 'Active Terminals',
                    value: '$activeCount',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Ready for billing',
                  ),
                  StatCard(
                    title: 'Location Hubs',
                    value: '${allDevices.map((p) => p.location).toSet().length}',
                    icon: Icons.store_mall_directory_rounded,
                    accentColor: AppColors.primary,
                    subtitle: 'Store branches',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search POS device by code, name, or location...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Full-width Table Card
          Card(
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (posDevices.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(48),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.devices_other_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No POS terminals found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Register your first counter terminal to enable cashiers to collect payments.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddPosDialog(context),
                          icon: const Icon(Icons.add_to_queue_rounded, size: 16),
                          label: const Text('Register Terminal Now'),
                        ),
                      ],
                    ),
                  );
                }

                if (constraints.maxWidth < 768) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posDevices.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildMobilePosCard(context, posDevices[index], isDark);
                        },
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${posDevices.length} of ${allDevices.length} terminals',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            TextButton.icon(
                              onPressed: () => repo.refreshFromBackend(),
                              icon: const Icon(Icons.sync_rounded, size: 14),
                              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          showCheckboxColumn: true,
                          columnSpacing: 24,
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 64,
                          headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('TERMINAL ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('DEVICE / CODE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('LOCATION / COUNTER', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('LAST HEARTBEAT', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: posDevices.map((p) {
                            final isSelected = _selectedPos?.id == p.id;
                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (_) {
                                setState(() {
                                  _selectedPos = isSelected ? null : p;
                                });
                              },
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _showPosDetailsDialog(context, p),
                                        child: Text(
                                          p.id,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? AppColors.primary : null,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 14),
                                        tooltip: 'Copy Terminal ID',
                                        splashRadius: 14,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: p.id));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Copied POS ID "${p.id}"'), duration: const Duration(seconds: 1)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                          Text(p.serialNumber, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Courier')),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 12),
                                        tooltip: 'Copy Code',
                                        splashRadius: 12,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: p.serialNumber));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Copied code "${p.serialNumber}"'), duration: const Duration(seconds: 1)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(p.location.isNotEmpty ? p.location : 'Main Counter', style: const TextStyle(fontSize: 12))),
                                DataCell(Text(dateFormat.format(p.lastSeen), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: p.status == PosStatus.online ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.status.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: p.status == PosStatus.online ? AppColors.successDark : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                                        tooltip: 'Terminal Details',
                                        onPressed: () => _showPosDetailsDialog(context, p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit Terminal',
                                        onPressed: () => _showEditPosDialog(context, p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                        tooltip: 'Delete Terminal',
                                        onPressed: () => _confirmDeletePos(context, p),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Table Footer
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedPos != null
                                ? 'Selected: ${_selectedPos!.name} (${_selectedPos!.serialNumber}) • ${posDevices.length} total terminals'
                                : 'Showing ${posDevices.length} of ${allDevices.length} hardware terminals • Real-time hardware health check active',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          TextButton.icon(
                            onPressed: () => repo.refreshFromBackend(),
                            icon: const Icon(Icons.sync_rounded, size: 14),
                            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePosCard(BuildContext context, PosDevice p, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final isOnline = p.status == PosStatus.online;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Terminal ID badge + Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _showPosDetailsDialog(context, p),
                      child: Text(
                        p.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: p.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied POS ID "${p.id}"'), duration: const Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? AppColors.successDark : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Device Name & Code
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primaryLight, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Row(
                      children: [
                        Text(
                          p.serialNumber,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Courier'),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: p.serialNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Copied code "${p.serialNumber}"'), duration: const Duration(seconds: 1)),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Location & Heartbeat Info Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Counter / Location', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text(
                      p.location.isNotEmpty ? p.location : 'Main Counter',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Last Heartbeat', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text(
                      dateFormat.format(p.lastSeen),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showPosDetailsDialog(context, p),
                icon: const Icon(Icons.info_outline_rounded, size: 14),
                label: const Text('Details', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showEditPosDialog(context, p),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                onPressed: () => _confirmDeletePos(context, p),
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('Delete', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── TRANSACTIONS MANAGEMENT SCREEN ──────────────────────────────────────────
class AdminTransactionsScreen extends ConsumerStatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  ConsumerState<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends ConsumerState<AdminTransactionsScreen> {
  final _searchCtrl = TextEditingController();
  TransactionStatus? _filterStatus;
  MoMoNetwork? _filterNetwork;
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showTransactionDetails(BuildContext context, PaymentTransaction txn) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm:ss a');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(txn.reference, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Courier')),
                ],
              ),
            ),
            StatusBadge(status: txn.status),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTxnDetailRow('Reference', txn.reference, isCopyable: true, context: context),
                const Divider(height: 16),
                _buildTxnDetailRow('Date & Time', dateFormat.format(txn.timestamp)),
                const Divider(height: 16),
                _buildTxnDetailRow('Customer Name', txn.customerName.isNotEmpty ? txn.customerName : 'Walk-in Customer'),
                const Divider(height: 16),
                _buildTxnDetailRow('Customer Phone', txn.customerNumber, isCopyable: true, context: context),
                const Divider(height: 16),
                _buildTxnDetailRow('Network Provider', txn.networkDisplay),
                const Divider(height: 16),
                _buildTxnDetailRow('Amount Charged', 'GH₵ ${NumberFormat('#,##0.00').format(txn.amount)}'),
                const Divider(height: 16),
                _buildTxnDetailRow('Cashier / Staff', txn.tellerName),
                const Divider(height: 16),
                _buildTxnDetailRow('POS Terminal', txn.posId),
                if (txn.receiptNumber != null) ...[
                  const Divider(height: 16),
                  _buildTxnDetailRow('Receipt Number', txn.receiptNumber!, isCopyable: true, context: context),
                ],
                if (txn.failureReason != null && txn.failureReason!.isNotEmpty) ...[
                  const Divider(height: 16),
                  _buildTxnDetailRow('Failure Reason', txn.failureReason!, color: AppColors.error),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Reference'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: txn.reference));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaction reference copied!'), duration: Duration(seconds: 1)),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnDetailRow(String label, String value, {bool isCopyable = false, BuildContext? context, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (isCopyable && context != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  tooltip: 'Copy $label',
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $label to clipboard'), duration: const Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allTxns = repo.getTransactions();
    final txns = repo.getTransactions(
      searchQuery: _searchCtrl.text.trim(),
      statusFilter: _filterStatus,
      networkFilter: _filterNetwork,
    );
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final successfulTxns = allTxns.where((t) => t.status == TransactionStatus.success).toList();
    final totalCollected = successfulTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final pendingCount = allTxns.where((t) => t.status == TransactionStatus.pending).length;
    final successRate = allTxns.isEmpty ? 100 : ((successfulTxns.length / allTxns.length) * 100).toInt();

    // Pagination calculations
    final totalCount = txns.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 999999);
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalCount);
    final paginatedTxns = totalCount > 0 ? txns.sublist(startIndex, endIndex) : <PaymentTransaction>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 768;
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('All Collections & Transactions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time transaction ledger connected directly to WhitsunPay MoMo gateway & Supabase',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              );

              final actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => repo.refreshFromBackend(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Refresh Ledger',
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transactions exported to CSV successfully!'), backgroundColor: AppColors.success),
                      );
                    },
                    icon: const Icon(Icons.table_view_rounded, size: 18),
                    label: const Text('Export CSV'),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // KPI Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final isNarrow = constraints.maxWidth < 440;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: isWide ? 16 : 10,
                mainAxisSpacing: isWide ? 16 : 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : (isNarrow ? 1.22 : 1.45),
                children: [
                  StatCard(
                    title: 'Total Collections',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(totalCollected)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: AppColors.success,
                    subtitle: '${successfulTxns.length} successful debits',
                  ),
                  StatCard(
                    title: 'Total Volume',
                    value: '${allTxns.length}',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: 'All customer requests',
                  ),
                  StatCard(
                    title: 'Pending MoMo PIN',
                    value: '$pendingCount',
                    icon: Icons.hourglass_top_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Awaiting customer auth',
                  ),
                  StatCard(
                    title: 'Success Rate',
                    value: '$successRate%',
                    icon: Icons.speed_rounded,
                    accentColor: AppColors.primary,
                    subtitle: 'Gateway authorization rate',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() => _currentPage = 1),
                      decoration: const InputDecoration(
                        hintText: 'Search by Ref, customer phone, name, teller...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<TransactionStatus?>(
                    value: _filterStatus,
                    hint: const Text('All Statuses'),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses')),
                      DropdownMenuItem(value: TransactionStatus.success, child: Text('Success')),
                      DropdownMenuItem(value: TransactionStatus.pending, child: Text('Pending')),
                      DropdownMenuItem(value: TransactionStatus.failed, child: Text('Failed')),
                      DropdownMenuItem(value: TransactionStatus.refunded, child: Text('Refunded')),
                    ],
                    onChanged: (val) => setState(() {
                      _filterStatus = val;
                      _currentPage = 1;
                    }),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<MoMoNetwork?>(
                    value: _filterNetwork,
                    hint: const Text('All Networks'),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Networks')),
                      DropdownMenuItem(value: MoMoNetwork.mtn, child: Text('MTN MoMo')),
                      DropdownMenuItem(value: MoMoNetwork.vodafone, child: Text('Telecel Cash')),
                      DropdownMenuItem(value: MoMoNetwork.airtel, child: Text('AT Money')),
                    ],
                    onChanged: (val) => setState(() {
                      _filterNetwork = val;
                      _currentPage = 1;
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Full-width Table Card with Pagination Controls
          Card(
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (txns.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(48),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No transactions found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('No records matched your search filters or no collections have been made yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchCtrl.clear();
                              _filterStatus = null;
                              _filterNetwork = null;
                              _currentPage = 1;
                            });
                          },
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text('Reset All Filters'),
                        ),
                      ],
                    ),
                  );
                }

                if (constraints.maxWidth < 768) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paginatedTxns.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildMobileTransactionCard(context, paginatedTxns[index], isDark);
                        },
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${totalCount == 0 ? 0 : startIndex + 1}–$endIndex of $totalCount',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                                  tooltip: 'Previous Page',
                                  onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                                ),
                                Text(
                                  '$_currentPage / $totalPages',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                                  tooltip: 'Next Page',
                                  onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 64,
                          headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('REFERENCE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('DATE & TIME', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('CUSTOMER & PHONE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('AMOUNT (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('NETWORK', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('CASHIER / POS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('RECEIPT', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: paginatedTxns.map((t) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _showTransactionDetails(context, t),
                                        child: Text(
                                          t.reference,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.primary,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 14),
                                        tooltip: 'Copy Reference',
                                        splashRadius: 14,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: t.reference));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Copied reference "${t.reference}"'), duration: const Duration(seconds: 1)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(dateFormat.format(t.timestamp), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(t.customerNumber, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 12),
                                            tooltip: 'Copy Phone',
                                            splashRadius: 12,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: t.customerNumber));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Copied phone "${t.customerNumber}"'), duration: const Duration(seconds: 1)),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(t.amount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                                DataCell(Text(t.networkDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t.tellerName, style: const TextStyle(fontSize: 12)),
                                      Text(t.posId, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'Courier')),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(t.receiptNumber ?? '—', style: const TextStyle(fontSize: 11, fontFamily: 'Courier')),
                                      if (t.receiptNumber != null) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 12),
                                          tooltip: 'Copy Receipt',
                                          splashRadius: 12,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: t.receiptNumber!));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Copied receipt "${t.receiptNumber}"'), duration: const Duration(seconds: 1)),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                DataCell(StatusBadge(status: t.status)),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, size: 18),
                                    tooltip: 'Inspect Transaction',
                                    onPressed: () => _showTransactionDetails(context, t),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Table Footer with Full Pagination Controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          // Left: Page size dropdown & Total range indicator
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Rows per page: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              DropdownButton<int>(
                                value: _pageSize,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                  DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                  DropdownMenuItem(value: 100, child: Text('100', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _pageSize = val;
                                      _currentPage = 1;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Showing ${totalCount == 0 ? 0 : startIndex + 1}–$endIndex of $totalCount transactions',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),

                          // Right: Page Navigator buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.first_page_rounded, size: 20),
                                tooltip: 'First Page',
                                onPressed: _currentPage > 1 ? () => setState(() => _currentPage = 1) : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                tooltip: 'Previous Page',
                                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Page $_currentPage of $totalPages',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                tooltip: 'Next Page',
                                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.last_page_rounded, size: 20),
                                tooltip: 'Last Page',
                                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionCard(BuildContext context, PaymentTransaction t, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    Color netColor;
    switch (t.network) {
      case MoMoNetwork.mtn:
        netColor = const Color(0xFFEAB308);
        break;
      case MoMoNetwork.vodafone:
        netColor = const Color(0xFFEF4444);
        break;
      case MoMoNetwork.airtel:
        netColor = const Color(0xFF3B82F6);
        break;
    }

    return InkWell(
      onTap: () => _showTransactionDetails(context, t),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Ref & Copy + Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.reference,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: t.reference));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied reference "${t.reference}"'), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 13),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                StatusBadge(status: t.status),
              ],
            ),
            const SizedBox(height: 10),

            // Customer info & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            t.customerNumber,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: t.customerNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied phone "${t.customerNumber}"'), duration: const Duration(seconds: 1)),
                              );
                            },
                            child: const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'GH₵ ${NumberFormat('#,##0.00').format(t.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryLight),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: netColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.networkDisplay,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: netColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Metadata Box: Cashier/POS, Date, Receipt
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${t.tellerName} (${t.posId})', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      Text(dateFormat.format(t.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  if (t.receiptNumber != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.receipt_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('Receipt: ${t.receiptNumber}', style: const TextStyle(fontSize: 11, fontFamily: 'Courier')),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: t.receiptNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Copied receipt "${t.receiptNumber}"'), duration: const Duration(seconds: 1)),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // View Details button
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showTransactionDetails(context, t),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('Inspect Details', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
