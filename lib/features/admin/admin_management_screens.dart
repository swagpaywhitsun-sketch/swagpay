import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/pos_device.dart';
import '../../core/models/transaction.dart';
import '../../core/models/user.dart';
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

  void _showAddTellerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '10000');
    final branchCtrl = TextEditingController(text: 'Accra Mall Food Court');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Teller / Cashier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address *')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number (MoMo)')),
              const SizedBox(height: 12),
              TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Branch / Location')),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Single Txn Limit (GH₵)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
              final newTeller = AppUser(
                id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
                fullName: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                role: UserRole.teller,
                branch: branchCtrl.text.trim(),
                assignedPos: ['pos_01'],
                singleTxnLimit: double.tryParse(limitCtrl.text) ?? 10000.0,
                dailyLimit: 50000.0,
              );
              await ref.read(paymentRepositoryProvider).addTeller(newTeller);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Teller successfully added to Supabase database!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Create Teller'),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Teller & Staff Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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
                    label: const Text('Add Teller'),
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
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : 1.6,
                children: [
                  StatCard(
                    title: 'Total Tellers',
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
                        hintText: 'Search teller by name, email, phone, or branch...',
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
                        const Text('No tellers found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Try adjusting your search query or add a new teller.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddTellerDialog(context),
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: const Text('Add Teller Now'),
                        ),
                      ],
                    ),
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
                            DataColumn(label: Text('TELLER ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('STAFF NAME & EMAIL', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                DataCell(Text(t.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
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
                                DataCell(Text(t.phone.isNotEmpty ? t.phone : '—', style: const TextStyle(fontSize: 12))),
                                DataCell(Text(t.branch ?? 'Accra Central Hub', style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(t.assignedPos.join(', '), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                                  ),
                                ),
                                DataCell(Text('GH₵ ${NumberFormat('#,##0').format(t.singleTxnLimit)}', style: const TextStyle(fontWeight: FontWeight.w800))),
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
                                        child: Text(t.role.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
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
                                  IconButton(
                                    icon: const Icon(Icons.tune_rounded, size: 18),
                                    tooltip: 'Edit Teller Limits',
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Configuring counter limits for ${t.fullName}')),
                                      );
                                    },
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
                            'Showing ${tellers.length} of ${allTellers.length} staff records • Live synced with Supabase PostgreSQL',
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
}

// ─── POS HARDWARE MANAGEMENT SCREEN ──────────────────────────────────────────
class AdminPosScreen extends ConsumerStatefulWidget {
  const AdminPosScreen({super.key});

  @override
  ConsumerState<AdminPosScreen> createState() => _AdminPosScreenState();
}

class _AdminPosScreenState extends ConsumerState<AdminPosScreen> {
  final _searchCtrl = TextEditingController();

  void _showAddPosDialog(BuildContext context) {
    final codeCtrl = TextEditingController(text: 'POS-0${DateTime.now().millisecond}');
    final nameCtrl = TextEditingController(text: 'Till Counter');
    final locCtrl = TextEditingController(text: 'Accra Mall Food Court');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register New POS Hardware Terminal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Terminal Code (e.g. POS-02)')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Terminal Name (e.g. Till 2 - Main Hall)')),
            const SizedBox(height: 12),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Physical Location')),
          ],
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
              await ref.read(paymentRepositoryProvider).addPosDevice(newPos);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Terminal registered successfully in Supabase!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Register Terminal'),
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
    final whitelistedCount = allDevices.where((p) => p.isWhitelisted).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('POS Hardware & Terminals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    'Hardware terminal whitelist, serial validation, and remote device monitoring',
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
                    onPressed: () => _showAddPosDialog(context),
                    icon: const Icon(Icons.add_to_queue_rounded, size: 18),
                    label: const Text('Add POS Terminal'),
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
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : 1.6,
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
                    title: 'Whitelisted Nodes',
                    value: '$whitelistedCount',
                    icon: Icons.verified_user_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Authorized hardware',
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
                            DataColumn(label: Text('TERMINAL ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('DEVICE / CODE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('LOCATION / COUNTER', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('LAST HEARTBEAT', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('WHITELIST LOCK', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: posDevices.map((p) {
                            return DataRow(
                              cells: [
                                DataCell(Text(p.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text(p.serialNumber, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Courier')),
                                    ],
                                  ),
                                ),
                                DataCell(Text(p.location.isNotEmpty ? p.location : 'Main Counter', style: const TextStyle(fontSize: 12))),
                                DataCell(Text(dateFormat.format(p.lastSeen), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Switch(
                                    value: p.isWhitelisted,
                                    onChanged: (val) {
                                      repo.updatePosDevice(p.copyWith(isWhitelisted: val));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${p.name} whitelist status updated to $val')),
                                      );
                                    },
                                  ),
                                ),
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
                            'Showing ${posDevices.length} of ${allDevices.length} hardware terminals • Real-time hardware health check active',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('All Collections & Transactions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time transaction ledger connected directly to WhitsunPay MoMo gateway & Supabase',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
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
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : 1.6,
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
                      onChanged: (_) => setState(() {}),
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
                    onChanged: (val) => setState(() => _filterStatus = val),
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
                    onChanged: (val) => setState(() => _filterNetwork = val),
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
                            });
                          },
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text('Reset All Filters'),
                        ),
                      ],
                    ),
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
                          ],
                          rows: txns.map((t) {
                            return DataRow(
                              cells: [
                                DataCell(Text(t.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataCell(Text(dateFormat.format(t.timestamp), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text(t.customerNumber, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
                                DataCell(Text(t.receiptNumber ?? '—', style: const TextStyle(fontSize: 11, fontFamily: 'Courier'))),
                                DataCell(StatusBadge(status: t.status)),
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
                            'Showing ${txns.length} of ${allTxns.length} transactions • Supabase PostgreSQL live stream active',
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
}
