import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/settlement.dart';
import '../../core/network/api_client.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';
export 'admin_reports_screen.dart';

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
  int _currentPage = 1;
  int _pageSize = 25;
  String? _selectedCategory;

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
    final filteredLogs = allLogs.where((l) {
      if (_selectedCategory != null && !l.action.toUpperCase().contains(_selectedCategory!)) {
        return false;
      }
      if (q.isEmpty) return true;
      return l.user.toLowerCase().contains(q) ||
          l.action.toLowerCase().contains(q) ||
          l.entity.toLowerCase().contains(q) ||
          l.ip.toLowerCase().contains(q) ||
          l.details.toLowerCase().contains(q);
    }).toList();

    final totalCount = filteredLogs.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 999999);
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalCount);
    final pageLogs = totalCount == 0 ? <dynamic>[] : filteredLogs.sublist(startIndex, endIndex);

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

          // Search Bar & Category Filter Strip
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() => _currentPage = 1),
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
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _currentPage = 1;
                          }),
                        ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All Events', style: TextStyle(fontSize: 12)),
                          selected: _selectedCategory == null,
                          onSelected: (_) => setState(() {
                            _selectedCategory = null;
                            _currentPage = 1;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Logins & Sessions', style: TextStyle(fontSize: 12)),
                          selected: _selectedCategory == 'LOGIN',
                          onSelected: (_) => setState(() {
                            _selectedCategory = 'LOGIN';
                            _currentPage = 1;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Collections & Payments', style: TextStyle(fontSize: 12)),
                          selected: _selectedCategory == 'PAYMENT',
                          onSelected: (_) => setState(() {
                            _selectedCategory = 'PAYMENT';
                            _currentPage = 1;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Cashiers & Hardware', style: TextStyle(fontSize: 12)),
                          selected: _selectedCategory == 'TELLER',
                          onSelected: (_) => setState(() {
                            _selectedCategory = 'TELLER';
                            _currentPage = 1;
                          }),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Security & Passwords', style: TextStyle(fontSize: 12)),
                          selected: _selectedCategory == 'PASSWORD',
                          onSelected: (_) => setState(() {
                            _selectedCategory = 'PASSWORD';
                            _currentPage = 1;
                          }),
                        ),
                      ],
                    ),
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
                if (filteredLogs.isEmpty) {
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
                          rows: pageLogs.map<DataRow>((l) {
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
                    // Table Footer with Interactive Pagination Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 10,
                        children: [
                          // Left: Rows per page & showing range
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Rows per page:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _pageSize,
                                isDense: true,
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                  DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                  DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
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
                                'Showing ${totalCount == 0 ? 0 : startIndex + 1}–$endIndex of $totalCount audit events',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),

                          // Right: Page navigation buttons
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
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Refresh Records',
                                icon: const Icon(Icons.sync_rounded, size: 18),
                                onPressed: () => repo.refreshFromBackend(),
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
}

// ─── ADMIN REPORTS & ANALYTICS SCREEN DELEGATED TO admin_reports_screen.dart ──

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
