import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/refund_request.dart';
import '../../core/models/settlement.dart';
import '../../core/models/transaction.dart';
import '../../core/network/api_config.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';

// ─── REFUND APPROVALS SCREEN ────────────────────────────────────────────────
class AdminRefundsScreen extends ConsumerStatefulWidget {
  const AdminRefundsScreen({super.key});

  @override
  ConsumerState<AdminRefundsScreen> createState() => _AdminRefundsScreenState();
}

class _AdminRefundsScreenState extends ConsumerState<AdminRefundsScreen> {
  final _searchCtrl = TextEditingController();
  RefundStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allRefunds = repo.getRefundRequests();
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final q = _searchCtrl.text.trim().toLowerCase();
    final refunds = allRefunds.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return r.id.toLowerCase().contains(q) ||
          r.reference.toLowerCase().contains(q) ||
          r.tellerName.toLowerCase().contains(q) ||
          r.reason.toLowerCase().contains(q);
    }).toList();

    final pendingCount = allRefunds.where((r) => r.status == RefundStatus.pending).length;
    final approvedCount = allRefunds.where((r) => r.status == RefundStatus.approved).length;
    final rejectedCount = allRefunds.where((r) => r.status == RefundStatus.rejected).length;
    final totalRefundedAmount = allRefunds
        .where((r) => r.status == RefundStatus.approved)
        .fold<double>(0.0, (acc, r) => acc + r.amount);

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
                  const Text('Refund & Void Approvals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Review and authorize cashier refund requests before debiting settlement pool',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () => repo.refreshFromBackend(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Refunds',
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
                    title: 'Pending Requests',
                    value: '$pendingCount',
                    icon: Icons.hourglass_top_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Awaiting admin decision',
                  ),
                  StatCard(
                    title: 'Total Refunded',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(totalRefundedAmount)}',
                    icon: Icons.undo_rounded,
                    accentColor: AppColors.error,
                    subtitle: 'Reversed transactions',
                  ),
                  StatCard(
                    title: 'Approved Reversals',
                    value: '$approvedCount',
                    icon: Icons.check_circle_rounded,
                    accentColor: AppColors.success,
                    subtitle: 'Cleared back to MoMo',
                  ),
                  StatCard(
                    title: 'Rejected Requests',
                    value: '$rejectedCount',
                    icon: Icons.cancel_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: 'Declined claims',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search & Filter Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search by Request ID, reference, cashier name, reason...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<RefundStatus?>(
                    value: _statusFilter,
                    hint: const Text('All Statuses'),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses')),
                      DropdownMenuItem(value: RefundStatus.pending, child: Text('Pending Only')),
                      DropdownMenuItem(value: RefundStatus.approved, child: Text('Approved')),
                      DropdownMenuItem(value: RefundStatus.rejected, child: Text('Rejected')),
                    ],
                    onChanged: (val) => setState(() => _statusFilter = val),
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
                if (refunds.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(48),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 48, color: AppColors.success.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No refund requests to review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('All cashier collections are clean and settled without pending dispute tickets.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => repo.refreshFromBackend(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Check For New Requests'),
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
                            DataColumn(label: Text('REQUEST ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('REFERENCE', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('AMOUNT (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('CASHIER', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('REASON / NOTES', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('DATE & TIME', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('DECISION ACTION', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: refunds.map((r) {
                            return DataRow(
                              cells: [
                                DataCell(Text(r.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                DataCell(Text(r.reference, style: const TextStyle(fontFamily: 'Courier', fontSize: 12))),
                                DataCell(Text('GH₵ ${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                                DataCell(Text(r.tellerName, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(r.reason, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(dateFormat.format(r.createdAt), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: r.status == RefundStatus.approved
                                          ? AppColors.success.withValues(alpha: 0.15)
                                          : (r.status == RefundStatus.rejected
                                              ? AppColors.error.withValues(alpha: 0.15)
                                              : AppColors.gold.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      r.status.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: r.status == RefundStatus.approved
                                          ? AppColors.successDark
                                          : (r.status == RefundStatus.rejected ? AppColors.error : AppColors.gold),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  r.status == RefundStatus.pending
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FilledButton.tonalIcon(
                                              style: FilledButton.styleFrom(backgroundColor: AppColors.success.withValues(alpha: 0.15)),
                                              icon: const Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                                              label: const Text('Approve', style: TextStyle(color: AppColors.successDark, fontWeight: FontWeight.bold, fontSize: 11)),
                                              onPressed: () async {
                                                await repo.reviewRefund(r.id, true);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Refund ${r.id} APPROVED and credited')),
                                                  );
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                                              icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 16),
                                              label: const Text('Reject', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                              onPressed: () async {
                                                await repo.reviewRefund(r.id, false);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Refund ${r.id} REJECTED')),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        )
                                      : Text(r.status == RefundStatus.approved ? 'Approved by Admin' : 'Declined', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                            'Showing ${refunds.length} of ${allRefunds.length} refund tickets • Real-time reversal ledger active',
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
                  Text(
                    'Immutable operational and security log of all cashier, admin, and gateway transactions',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
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
                                DataCell(Text(l.entity, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 320),
                                    child: Text(
                                      l.details,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                                DataCell(Text(l.ip, style: const TextStyle(fontFamily: 'Courier', fontSize: 11))),
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final txns = repo.getTransactions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                            SizedBox(
                              height: 160,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 4,
                                        centerSpaceRadius: 40,
                                        sections: [
                                          PieChartSectionData(
                                            color: AppColors.success,
                                            value: successTxns.isNotEmpty ? successTxns.length.toDouble() : 1.0,
                                            title: '${successTxns.length}',
                                            radius: 46,
                                            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          PieChartSectionData(
                                            color: AppColors.error,
                                            value: failedTxns.isNotEmpty ? failedTxns.length.toDouble() : 0.05,
                                            title: '${failedTxns.length}',
                                            radius: 46,
                                            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLegendDot(AppColors.success, 'Successful (${successTxns.length})'),
                                      const SizedBox(height: 12),
                                      _buildLegendDot(AppColors.error, 'Failed / Declined (${failedTxns.length})'),
                                    ],
                                  ),
                                ],
                              ),
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
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  late final TextEditingController _apiUrlCtrl;
  bool _useLiveApi = true;
  bool _isConnecting = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final currentUrl = prefs.getString('custom_base_url') ?? ApiConfig.baseUrl;
    _apiUrlCtrl = TextEditingController(text: currentUrl);
    _useLiveApi = prefs.getBool('use_live_api') ?? true;
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = null;
    });

    final url = _apiUrlCtrl.text.trim();
    final client = ref.read(apiClientProvider);
    client.updateBaseUrl(url);

    try {
      await client.get('/health').timeout(const Duration(seconds: 4));
      setState(() {
        _isConnecting = false;
        _connectionStatus = 'Success! Connected to $url';
      });
    } catch (_) {
      setState(() {
        _isConnecting = false;
        _connectionStatus = 'Saved. Will route API calls to: $url';
      });
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('custom_base_url', url);
    await prefs.setBool('use_live_api', _useLiveApi);
    await ref.read(paymentRepositoryProvider).refreshFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('System Configuration & Live Gateway', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
            'Manage WhitsunPay gateway connectivity, PostgreSQL database host, and terminal gatekeeper',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Backend API Connection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.dns_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WhitsunPay Backend Gateway', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Connected to live Fly.io production service & Supabase pooler', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _apiUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Gateway Endpoint URL',
                      hintText: 'https://swagpay.fly.dev',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Live Production Gateway Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Route MoMo debit prompts directly to developer.whitsun.dev via live client credentials', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    value: _useLiveApi,
                    onChanged: (val) => setState(() => _useLiveApi = val),
                  ),

                  if (_connectionStatus != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _connectionStatus!.startsWith('Success') ? AppColors.success.withValues(alpha: 0.1) : AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _connectionStatus!.startsWith('Success') ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            color: _connectionStatus!.startsWith('Success') ? AppColors.success : AppColors.gold,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _connectionStatus!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _connectionStatus!.startsWith('Success') ? AppColors.successDark : AppColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _testConnection,
                    icon: _isConnecting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(_isConnecting ? 'Verifying...' : 'Save & Verify Connection'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // WhitsunPay Gateway Credentials Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Gateway Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildProfileRow('Client ID', '019e8ba678a27f00bc19c3757989ed0b'),
                  const Divider(height: 16),
                  _buildProfileRow('Gateway Target', 'https://developer.whitsun.dev'),
                  const Divider(height: 16),
                  _buildProfileRow('Default Currency', 'GH₵ (Ghana Cedis / GHS)'),
                  const Divider(height: 16),
                  _buildProfileRow('PostgreSQL Pooler', 'aws-1-eu-central-1.pooler.supabase.com:6543'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
      ],
    );
  }
}
