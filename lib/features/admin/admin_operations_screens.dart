import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/settlement.dart';
import '../../core/models/transaction.dart';
import '../../core/network/api_client.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';

// ─── DAILY SETTLEMENTS SCREEN ───────────────────────────────────────────────
class AdminSettlementsScreen extends ConsumerStatefulWidget {
  const AdminSettlementsScreen({super.key});

  @override
  ConsumerState<AdminSettlementsScreen> createState() => _AdminSettlementsScreenState();
}

class _AdminSettlementsScreenState extends ConsumerState<AdminSettlementsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allSettlements = repo.getSettlements();
    final dateFormat = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final q = _searchCtrl.text.trim().toLowerCase();
    final settlements = allSettlements.where((s) {
      if (q.isEmpty) return true;
      return s.id.toLowerCase().contains(q) || dateFormat.format(s.date).toLowerCase().contains(q);
    }).toList();

    final totalSettled = allSettlements.fold<double>(0.0, (acc, s) => acc + s.totalSettled);
    final totalCollected = allSettlements.fold<double>(0.0, (acc, s) => acc + s.totalCollected);
    final totalTxns = allSettlements.fold<int>(0, (acc, s) => acc + s.transactionCount);
    final variance = totalCollected - totalSettled;

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
                  const Text('Daily Settlements & Reconciliation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Reconcile counter collections with clearing bank pool and POS terminal batches',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () => repo.refreshFromBackend(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Settlements',
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
                    title: 'Total Settled',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(totalSettled)}',
                    icon: Icons.account_balance_rounded,
                    accentColor: AppColors.success,
                    subtitle: 'Net cleared funds',
                  ),
                  StatCard(
                    title: 'Gross Collections',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(totalCollected)}',
                    icon: Icons.payments_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: '$totalTxns total debits',
                  ),
                  StatCard(
                    title: 'Reconciliation Variance',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(variance)}',
                    icon: Icons.balance_rounded,
                    accentColor: variance == 0 ? AppColors.success : AppColors.gold,
                    subtitle: variance == 0 ? 'Zero discrepancy' : 'Fees deducted',
                  ),
                  StatCard(
                    title: 'Batch Reports',
                    value: '${allSettlements.length}',
                    icon: Icons.checklist_rounded,
                    accentColor: AppColors.primary,
                    subtitle: 'Daily clearing cycles',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search Bar
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
                        hintText: 'Search settlements by Batch ID or Date...',
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
                            DataColumn(label: Text('BATCH ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('SETTLEMENT DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('COLLECTED (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('SETTLED (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('VARIANCE (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('TXN COUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: settlements.map((s) {
                            return DataRow(
                              cells: [
                                DataCell(Text(s.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataCell(Text(dateFormat.format(s.date), style: const TextStyle(fontSize: 12))),
                                DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(s.totalCollected)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(s.totalSettled)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                DataCell(
                                  Text(
                                    'GH₵ ${NumberFormat('#,##0.00').format(s.variance)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: s.variance == 0 ? AppColors.successDark : AppColors.error,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${s.transactionCount}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: s.status == SettlementStatus.settled ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      s.status.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: s.status == SettlementStatus.settled ? AppColors.successDark : AppColors.error,
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
                            'Showing ${settlements.length} clearing batches • Supabase ledger automatically aggregated daily',
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

// ─── AUDIT TRAIL SCREEN ─────────────────────────────────────────────────────
class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allLogs = repo.getAuditLogs();
    final dateFormat = DateFormat('dd MMM, hh:mm:ss a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final q = _searchCtrl.text.trim().toLowerCase();
    final logs = allLogs.where((l) {
      if (q.isEmpty) return true;
      return l.user.toLowerCase().contains(q) ||
          l.action.toLowerCase().contains(q) ||
          l.entity.toLowerCase().contains(q) ||
          l.ip.toLowerCase().contains(q) ||
          l.details.toLowerCase().contains(q);
    }).toList();

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
                  const Text('System Audit Trail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Immutable operational and security log of all transactions and system events',
                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                      ),
                      if (repo.clientRemoteIp.isNotEmpty && repo.clientRemoteIp != '127.0.0.1') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Client IP: ${repo.clientRemoteIp}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Courier', color: AppColors.primaryLight),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () => repo.refreshFromBackend(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Logs',
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
                    title: 'Logged Events',
                    value: '${allLogs.length}',
                    icon: Icons.history_edu_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: 'Recorded security operations',
                  ),
                  StatCard(
                    title: 'Cashier Logins',
                    value: '${allLogs.where((l) => l.action.contains('LOGIN')).length}',
                    icon: Icons.vpn_key_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Authenticated sessions',
                  ),
                  StatCard(
                    title: 'Reconciliations',
                    value: '${allLogs.where((l) => l.action.contains('RECONCILIATION')).length}',
                    icon: Icons.sync_lock_rounded,
                    accentColor: AppColors.success,
                    subtitle: 'Automated verification runs',
                  ),
                  StatCard(
                    title: 'Distinct Actors',
                    value: '${allLogs.map((l) => l.user).toSet().length}',
                    icon: Icons.fingerprint_rounded,
                    accentColor: AppColors.primary,
                    subtitle: 'Identified actors',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search Bar
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
                        hintText: 'Search audit logs by actor, action, target entity, or IP...',
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
                if (logs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(48),
                    alignment: Alignment.center,
                    child: const Text('No audit events found matching query.'),
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
                            DataColumn(label: Text('TIMESTAMP', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ACTOR & ROLE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ACTION TYPE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('TARGET ENTITY', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('EVENT METADATA', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('NODE / IP', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: logs.map((l) {
                            return DataRow(
                              cells: [
                                DataCell(Text(dateFormat.format(l.timestamp), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(l.user, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text(l.role, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(l.action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(l.entity, style: const TextStyle(fontSize: 12)),
                                      if (l.entity.isNotEmpty && l.entity != '—') ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 12),
                                          tooltip: 'Copy Entity',
                                          splashRadius: 12,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: l.entity));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Copied "${l.entity}"'), duration: const Duration(seconds: 1)),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 320),
                                    child: Text(
                                      (l.details.isNotEmpty && l.details != 'null' && l.details != 'NULL') ? l.details : '—',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.devices_rounded, size: 12, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            l.device.isNotEmpty ? l.device : 'Web Portal',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            l.ip.isNotEmpty ? l.ip : '127.0.0.1',
                                            style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                          if (l.ip.isNotEmpty && l.ip != '—') ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.copy_rounded, size: 12),
                                              tooltip: 'Copy IP',
                                              splashRadius: 12,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: l.ip));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Copied IP "${l.ip}"'), duration: const Duration(seconds: 1)),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
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
                            'Showing ${logs.length} of ${allLogs.length} audit records • Immutable Supabase PostgreSQL trail',
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

// ─── ADMIN REPORTS & ANALYTICS SCREEN (FULL DESKTOP / WEB) ───────────────────
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  int _selectedDays = 30;

  String _formatCompactCount(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allTxns = repo.getTransactions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final cutoff = _selectedDays >= 90 ? null : now.subtract(Duration(days: _selectedDays));
    final txns = cutoff == null ? allTxns : allTxns.where((t) => t.timestamp.isAfter(cutoff)).toList();

    final successTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final failedTxns = txns.where((t) => t.status == TransactionStatus.failed).toList();
    final totalAmount = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    // LIVE Collections by Network Provider calculation (ZERO MOCK FIGURES)
    final mtnTxns = successTxns.where((t) => t.network == MoMoNetwork.mtn).toList();
    final telecelTxns = successTxns.where((t) => t.network == MoMoNetwork.vodafone).toList();
    final atTxns = successTxns.where((t) => t.network == MoMoNetwork.airtel).toList();

    final mtnAmount = mtnTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final telecelAmount = telecelTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final atAmount = atTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final mtnFraction = totalAmount > 0 ? (mtnAmount / totalAmount) : 0.0;
    final telecelFraction = totalAmount > 0 ? (telecelAmount / totalAmount) : 0.0;
    final atFraction = totalAmount > 0 ? (atAmount / totalAmount) : 0.0;

    // Grouping transactions by Teller
    final tellerTotals = <String, Map<String, dynamic>>{};
    for (final t in successTxns) {
      final key = t.tellerName.isNotEmpty ? t.tellerName : 'Cashier Counter';
      if (!tellerTotals.containsKey(key)) {
        tellerTotals[key] = {'count': 0, 'amount': 0.0, 'pos': t.posId};
      }
      tellerTotals[key]!['count'] = (tellerTotals[key]!['count'] as int) + 1;
      tellerTotals[key]!['amount'] = (tellerTotals[key]!['amount'] as double) + t.amount;
    }

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
                  const Text('Reports & Collection Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time collection reports, telco breakdown, and counter performance insights',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7D')),
                      ButtonSegment(value: 30, label: Text('30D')),
                      ButtonSegment(value: 90, label: Text('All')),
                    ],
                    selected: {_selectedDays},
                    onSelectionChanged: (set) => setState(() => _selectedDays = set.first),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Downloading detailed CSV analytics report...'), backgroundColor: AppColors.success),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export Report'),
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
                    title: 'Total Gross Collected',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: AppColors.success,
                    subtitle: '${successTxns.length} successful collections',
                  ),
                  StatCard(
                    title: 'Total Transactions',
                    value: '${txns.length}',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: '${failedTxns.length} declined / failed',
                  ),
                  StatCard(
                    title: 'Avg. Ticket Size',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(successTxns.isNotEmpty ? totalAmount / successTxns.length : 0.0)}',
                    icon: Icons.trending_up_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Per collection average',
                  ),
                  StatCard(
                    title: 'Authorization Rate',
                    value: '${txns.isEmpty ? 100 : ((successTxns.length / txns.length) * 100).toStringAsFixed(1)}%',
                    icon: Icons.speed_rounded,
                    accentColor: AppColors.primary,
                    subtitle: 'Customer PIN completion',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Row: Collections by Network Provider & Outcome Distribution
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collections by Network Provider (LIVE DATA)
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Collections by Network Provider',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('LIVE WHITSUNPAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.successDark)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Calculated dynamically from real customer MoMo ledger',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 24),
                            _buildNetworkProgressItem(
                              title: 'MTN Mobile Money',
                              count: mtnTxns.length,
                              amount: mtnAmount,
                              fraction: mtnFraction,
                              color: const Color(0xFFFFCC00),
                            ),
                            const SizedBox(height: 18),
                            _buildNetworkProgressItem(
                              title: 'Telecel Cash',
                              count: telecelTxns.length,
                              amount: telecelAmount,
                              fraction: telecelFraction,
                              color: const Color(0xFFE60000),
                            ),
                            const SizedBox(height: 18),
                            _buildNetworkProgressItem(
                              title: 'AT Money (AirtelTigo)',
                              count: atTxns.length,
                              amount: atAmount,
                              fraction: atFraction,
                              color: const Color(0xFF0066CC),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isWide) const SizedBox(width: 16),
                  if (!isWide) const SizedBox(height: 16),

                  // Outcome Distribution Chart
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collection Status Distribution',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ratio of successful collections to customer declined prompts',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 24),
                            Builder(
                              builder: (context) {
                                final totalStatusCount = successTxns.length + failedTxns.length;
                                final successPct = totalStatusCount > 0 ? (successTxns.length / totalStatusCount) * 100 : 100.0;
                                final failedPct = totalStatusCount > 0 ? (failedTxns.length / totalStatusCount) * 100 : 0.0;
                                final countFormat = NumberFormat('#,###');

                                return SizedBox(
                                  height: 160,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            PieChart(
                                              PieChartData(
                                                sectionsSpace: 3,
                                                centerSpaceRadius: 40,
                                                sections: [
                                                  PieChartSectionData(
                                                    color: AppColors.success,
                                                    value: successTxns.isNotEmpty ? successTxns.length.toDouble() : 1.0,
                                                    title: (totalStatusCount > 0 && successPct >= 8) ? '${successPct.toStringAsFixed(1)}%' : '',
                                                    radius: 44,
                                                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                                  ),
                                                  PieChartSectionData(
                                                    color: AppColors.error,
                                                    value: failedTxns.isNotEmpty ? failedTxns.length.toDouble() : (successTxns.isEmpty ? 1.0 : 0.001),
                                                    title: (totalStatusCount > 0 && failedPct >= 8) ? '${failedPct.toStringAsFixed(1)}%' : '',
                                                    radius: 44,
                                                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _formatCompactCount(totalStatusCount),
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                                                ),
                                                const Text(
                                                  'Total',
                                                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildLegendDot(AppColors.success, 'Successful: ${countFormat.format(successTxns.length)} (${successPct.toStringAsFixed(1)}%)'),
                                          const SizedBox(height: 12),
                                          _buildLegendDot(AppColors.error, 'Failed: ${countFormat.format(failedTxns.length)} (${failedPct.toStringAsFixed(1)}%)'),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Cashier Performance Table Card
          Card(
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cashier / Counter Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              SizedBox(height: 2),
                              Text('Volume collected broken down by active counter staff', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${tellerTotals.length} Active Tellers', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 28,
                          headingRowHeight: 44,
                          headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('CASHIER / STAFF', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('POS TERMINAL', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('SUCCESSFUL TXNS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('TOTAL COLLECTED', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('SHARE OF REVENUE', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: tellerTotals.entries.map((entry) {
                            final count = entry.value['count'] as int;
                            final amount = entry.value['amount'] as double;
                            final share = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                DataCell(Text(entry.value['pos']?.toString() ?? 'pos_01', style: const TextStyle(fontFamily: 'Courier', fontSize: 12))),
                                DataCell(Text('$count', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(amount)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: LinearProgressIndicator(
                                          value: share / 100,
                                          backgroundColor: AppColors.border,
                                          color: AppColors.success,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${share.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
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

  Widget _buildNetworkProgressItem({
    required String title,
    required int count,
    required double amount,
    required double fraction,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  '$title ($count txns)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              'GH₵ ${NumberFormat('#,##0.00').format(amount)} (${(fraction * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: fraction,
          backgroundColor: AppColors.border,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── SYSTEM CONFIGURATION & API SCREEN ──────────────────────────────────────
// ─── ADMIN SETTINGS / PASSWORD CHANGE SCREEN ────────────────────────────────
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final repo = ref.read(paymentRepositoryProvider);
      await repo.changePassword(
        currentPassword: _currentPassCtrl.text.trim(),
        newPassword: _newPassCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSuccess = true;
        _statusMessage = 'Password updated successfully! Next sign in will require your new credentials.';
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSuccess = false;
        _statusMessage = e is ApiException ? e.message : '$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusMessage ?? 'Failed to change password'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'Account Security & Password',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your administrator password and account credentials',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              // Active Account Summary Card
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Administrator',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? 'admin@swagpay.com',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ROLE: SUPER ADMIN',
                          style: TextStyle(
                            color: AppColors.successDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Password Change Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 10),
                            const Text(
                              'Change Password',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ensure your new password contains at least 6 characters for enterprise security compliance.',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Current Password
                        TextFormField(
                          controller: _currentPassCtrl,
                          obscureText: _obscureCurrent,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            hintText: 'Enter your existing password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                              onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter your current password';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // New Password
                        TextFormField(
                          controller: _newPassCtrl,
                          obscureText: _obscureNew,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            hintText: 'Enter a strong new password (min. 6 chars)',
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                              onPressed: () => setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter a new password';
                            if (val.trim().length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Confirm New Password
                        TextFormField(
                          controller: _confirmPassCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            hintText: 'Re-enter your new password',
                            prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please confirm your new password';
                            if (val.trim() != _newPassCtrl.text.trim()) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Status Alert
                        if (_statusMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _isSuccess ? AppColors.success.withValues(alpha: 0.12) : AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isSuccess ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                  color: _isSuccess ? AppColors.successDark : AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: TextStyle(
                                      color: _isSuccess ? AppColors.successDark : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _handleChangePassword,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.security_update_good_rounded, size: 18),
                            label: Text(
                              _isSaving ? 'Updating Password...' : 'Update Password',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
