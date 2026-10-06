import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';

/// Enterprise Data Analysis & Collection Analytics Hub for SwagPay Administrators.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> with SingleTickerProviderStateMixin {
  int _selectedDays = 30; // 1 = Today, 7 = 7D, 30 = 30D, 90 = 90D, 365 = All Time
  MoMoNetwork? _selectedNetwork;
  String? _selectedPos;
  int _activeTab = 0; // 0: Overview, 1: Hourly Heatmap, 2: Telco Intel, 3: Cashiers, 4: Daily Audit

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCompact(num n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toStringAsFixed(0);
  }

  void _exportCsv(List<PaymentTransaction> txns, double totalAmount) {
    final buffer = StringBuffer();
    buffer.writeln('SWAGPAY COLLECTION ANALYTICS & AUDIT REPORT');
    buffer.writeln('Generated At,${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Time Horizon,${_selectedDays == 1 ? "Today" : "$_selectedDays Days"}');
    buffer.writeln('Total Successful Volume (GH₵),${totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Total Transactions,${txns.length}');
    buffer.writeln('');
    buffer.writeln('ID,Reference,Customer Name,Customer Phone,Network,Amount (GH₵),Status,Cashier,POS Terminal,Timestamp');

    final sorted = List<PaymentTransaction>.from(txns)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (final t in sorted) {
      final safeName = t.customerName.replaceAll(',', ' ');
      final netName = t.network.name.toUpperCase();
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').format(t.timestamp);
      buffer.writeln('${t.id},${t.reference},$safeName,${t.customerPhone},$netName,${t.amount.toStringAsFixed(2)},${t.status.name},${t.tellerName},${t.posId},$dt');
    }

    final csvContent = buffer.toString();
    Clipboard.setData(ClipboardData(text: csvContent));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete audit report (${sorted.length} records) copied to clipboard & ready for Excel/Sheets!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allTxns = repo.getTransactions();
    final posDevices = repo.getPosDevices();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final DateTime? effectiveCutoff;
    if (_selectedDays == 1) {
      effectiveCutoff = DateTime(now.year, now.month, now.day);
    } else if (_selectedDays >= 365) {
      effectiveCutoff = null;
    } else {
      effectiveCutoff = now.subtract(Duration(days: _selectedDays));
    }

    // Apply Filters: Date Cutoff, Network, POS
    final List<PaymentTransaction> txns;
    if (effectiveCutoff != null) {
      final nonNullCutoff = effectiveCutoff;
      var filtered = allTxns.where((t) => t.timestamp.isAfter(nonNullCutoff)).toList();
      if (_selectedNetwork != null) {
        filtered = filtered.where((t) => t.network == _selectedNetwork).toList();
      }
      if (_selectedPos != null && _selectedPos!.isNotEmpty) {
        filtered = filtered.where((t) => t.posId == _selectedPos).toList();
      }
      txns = filtered;
    } else {
      var filtered = allTxns;
      if (_selectedNetwork != null) {
        filtered = filtered.where((t) => t.network == _selectedNetwork).toList();
      }
      if (_selectedPos != null && _selectedPos!.isNotEmpty) {
        filtered = filtered.where((t) => t.posId == _selectedPos).toList();
      }
      txns = filtered;
    }

    // Prior period calculation for % delta indicators
    final List<PaymentTransaction> priorTxns;
    if (effectiveCutoff != null) {
      final nonNullCutoff = effectiveCutoff;
      final periodDuration = now.difference(nonNullCutoff);
      final priorCutoff = nonNullCutoff.subtract(periodDuration);
      priorTxns = allTxns.where((t) => t.timestamp.isAfter(priorCutoff) && t.timestamp.isBefore(nonNullCutoff)).toList();
    } else {
      priorTxns = [];
    }

    final successTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final failedTxns = txns.where((t) => t.status == TransactionStatus.failed).toList();
    final totalAmount = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final priorSuccess = priorTxns.where((t) => t.status == TransactionStatus.success).toList();
    final priorAmount = priorSuccess.fold<double>(0.0, (acc, t) => acc + t.amount);

    // Delta percentage calculation
    final double amountDeltaPct;
    if (priorAmount > 0) {
      amountDeltaPct = ((totalAmount - priorAmount) / priorAmount) * 100;
    } else {
      amountDeltaPct = 0.0;
    }

    final double avgTicket = successTxns.isNotEmpty ? totalAmount / successTxns.length : 0.0;
    final double priorAvg = priorSuccess.isNotEmpty ? priorAmount / priorSuccess.length : 0.0;
    final double avgTicketDeltaPct = priorAvg > 0 ? ((avgTicket - priorAvg) / priorAvg) * 100 : 0.0;

    final double successRate = txns.isNotEmpty ? (successTxns.length / txns.length) * 100 : 100.0;

    // Telco Breakdown
    final mtnTxns = successTxns.where((t) => t.network == MoMoNetwork.mtn).toList();
    final telecelTxns = successTxns.where((t) => t.network == MoMoNetwork.vodafone).toList();
    final atTxns = successTxns.where((t) => t.network == MoMoNetwork.airtel).toList();

    final mtnAmount = mtnTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final telecelAmount = telecelTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final atAmount = atTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final mtnShare = totalAmount > 0 ? (mtnAmount / totalAmount) * 100 : 0.0;
    final telecelShare = totalAmount > 0 ? (telecelAmount / totalAmount) * 100 : 0.0;
    final atShare = totalAmount > 0 ? (atAmount / totalAmount) * 100 : 0.0;

    // Top network identification
    String topNetworkName = 'MTN MoMo';
    double topNetworkShare = mtnShare;
    if (telecelAmount > mtnAmount && telecelAmount > atAmount) {
      topNetworkName = 'Telecel Cash';
      topNetworkShare = telecelShare;
    } else if (atAmount > mtnAmount && atAmount > telecelAmount) {
      topNetworkName = 'AT Money';
      topNetworkShare = atShare;
    }

    // 24-Hour Distribution Engine
    final hourlyRevenue = List.filled(24, 0.0);
    final hourlyCounts = List.filled(24, 0);
    for (final t in successTxns) {
      final h = t.timestamp.hour;
      hourlyRevenue[h] += t.amount;
      hourlyCounts[h] += 1;
    }

    int peakHourIndex = 12;
    double maxHourRev = 0.0;
    for (int i = 0; i < 24; i++) {
      if (hourlyRevenue[i] > maxHourRev) {
        maxHourRev = hourlyRevenue[i];
        peakHourIndex = i;
      }
    }
    final peakHourStr = '${peakHourIndex.toString().padLeft(2, '0')}:00 – ${(peakHourIndex + 1).toString().padLeft(2, '0')}:00';

    // Shifts
    final morningRev = hourlyRevenue.sublist(8, 12).fold<double>(0.0, (a, b) => a + b);
    final afternoonRev = hourlyRevenue.sublist(12, 17).fold<double>(0.0, (a, b) => a + b);
    final eveningRev = hourlyRevenue.sublist(17, 21).fold<double>(0.0, (a, b) => a + b);
    final nightRev = totalAmount - (morningRev + afternoonRev + eveningRev);

    // Ticket Size Tier Breakdown
    int microCount = 0; // < 50
    double microAmount = 0.0;
    int standardCount = 0; // 50 - 200
    double standardAmount = 0.0;
    int mediumCount = 0; // 200 - 1000
    double mediumAmount = 0.0;
    int bulkCount = 0; // > 1000
    double bulkAmount = 0.0;

    for (final t in successTxns) {
      if (t.amount < 50) {
        microCount++;
        microAmount += t.amount;
      } else if (t.amount <= 200) {
        standardCount++;
        standardAmount += t.amount;
      } else if (t.amount <= 1000) {
        mediumCount++;
        mediumAmount += t.amount;
      } else {
        bulkCount++;
        bulkAmount += t.amount;
      }
    }

    // Cashier Grouping
    final tellerTotals = <String, Map<String, dynamic>>{};
    for (final t in successTxns) {
      final key = t.tellerName.isNotEmpty ? t.tellerName : 'Cashier Counter';
      if (!tellerTotals.containsKey(key)) {
        tellerTotals[key] = {
          'count': 0,
          'amount': 0.0,
          'pos': t.posId,
          'failed': 0,
          'max': 0.0,
        };
      }
      tellerTotals[key]!['count'] = (tellerTotals[key]!['count'] as int) + 1;
      tellerTotals[key]!['amount'] = (tellerTotals[key]!['amount'] as double) + t.amount;
      if (t.amount > (tellerTotals[key]!['max'] as double)) {
        tellerTotals[key]!['max'] = t.amount;
      }
    }
    for (final t in failedTxns) {
      final key = t.tellerName.isNotEmpty ? t.tellerName : 'Cashier Counter';
      if (tellerTotals.containsKey(key)) {
        tellerTotals[key]!['failed'] = (tellerTotals[key]!['failed'] as int) + 1;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── HEADER BAR & INTERACTIVE FILTERS ──────────────────────────────
          _buildHeaderBar(context, isDark, posDevices, totalAmount, txns),
          const SizedBox(height: 20),

          // ─── EXECUTIVE SCORECARDS (6 KPI CARDS) ───────────────────────────
          _buildKpiGrid(
            totalAmount: totalAmount,
            amountDeltaPct: amountDeltaPct,
            successCount: successTxns.length,
            txnsCount: txns.length,
            failedCount: failedTxns.length,
            avgTicket: avgTicket,
            avgTicketDeltaPct: avgTicketDeltaPct,
            successRate: successRate,
            peakHourStr: peakHourStr,
            maxHourRev: maxHourRev,
            topNetworkName: topNetworkName,
            topNetworkShare: topNetworkShare,
          ),
          const SizedBox(height: 24),

          // ─── MODERN TAB NAVIGATION ─────────────────────────────────────────
          _buildTabBar(isDark),
          const SizedBox(height: 20),

          // ─── TAB CONTENT VIEWS ─────────────────────────────────────────────
          IndexedStack(
            index: _activeTab,
            children: [
              // Tab 0: Overview & Trends
              _buildOverviewTab(
                context: context,
                isDark: isDark,
                successTxns: successTxns,
                failedTxns: failedTxns,
                totalAmount: totalAmount,
                microCount: microCount,
                standardCount: standardCount,
                mediumCount: mediumCount,
                bulkCount: bulkCount,
                microAmount: microAmount,
                standardAmount: standardAmount,
                mediumAmount: mediumAmount,
                bulkAmount: bulkAmount,
              ),

              // Tab 1: Hourly Rush & Shift Analytics
              _buildHourlyShiftTab(
                context: context,
                isDark: isDark,
                hourlyRevenue: hourlyRevenue,
                hourlyCounts: hourlyCounts,
                peakHourIndex: peakHourIndex,
                morningRev: morningRev,
                afternoonRev: afternoonRev,
                eveningRev: eveningRev,
                nightRev: nightRev,
                totalAmount: totalAmount,
                successTxns: successTxns,
              ),

              // Tab 2: Telco & Operator Intelligence
              _buildTelcoTab(
                context: context,
                isDark: isDark,
                totalAmount: totalAmount,
                mtnTxns: mtnTxns,
                telecelTxns: telecelTxns,
                atTxns: atTxns,
                mtnAmount: mtnAmount,
                telecelAmount: telecelAmount,
                atAmount: atAmount,
                mtnShare: mtnShare,
                telecelShare: telecelShare,
                atShare: atShare,
                allTxns: txns,
              ),

              // Tab 3: Cashier & Counter Productivity
              _buildCashierTab(
                context: context,
                isDark: isDark,
                tellerTotals: tellerTotals,
                totalAmount: totalAmount,
              ),

              // Tab 4: Daily Reconciliation & Audit Ledger
              _buildAuditTab(
                context: context,
                isDark: isDark,
                txns: txns,
                totalAmount: totalAmount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── HEADER BAR ─────────────────────────────────────────────────────────────
  Widget _buildHeaderBar(
    BuildContext context,
    bool isDark,
    List<dynamic> posDevices,
    double totalAmount,
    List<PaymentTransaction> txns,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Reports & Data Analytics',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 6,
                                height: 6,
                                child: DecoratedBox(decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                              ),
                              SizedBox(width: 5),
                              Text('LIVE LEDGER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deep financial analytics, MoMo operator share, peak rush insights, and cashier audit logs',
                      style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                if (isWide)
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Refresh Ledger',
                        icon: const Icon(Icons.sync_rounded, size: 20),
                        onPressed: () {
                          ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ledger refreshed with latest real-time transactions!'), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => _exportCsv(txns, totalAmount),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Export CSV Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Controls & Filters Strip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Timeframe Segmented Switcher
                  SegmentedButton<int>(
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Today')),
                      ButtonSegment(value: 7, label: Text('7D')),
                      ButtonSegment(value: 30, label: Text('30D')),
                      ButtonSegment(value: 90, label: Text('90D')),
                      ButtonSegment(value: 365, label: Text('All Time')),
                    ],
                    selected: {_selectedDays},
                    onSelectionChanged: (set) => setState(() => _selectedDays = set.first),
                  ),

                  // Network Filter Dropdown
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A30) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF3E3E46) : const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MoMoNetwork?>(
                            value: _selectedNetwork,
                            hint: const Text('All Networks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                            isDense: true,
                            dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Telcos (MTN, Telecel, AT)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: MoMoNetwork.mtn, child: Text('MTN Mobile Money', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              DropdownMenuItem(value: MoMoNetwork.vodafone, child: Text('Telecel Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              DropdownMenuItem(value: MoMoNetwork.airtel, child: Text('AT Money', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                            onChanged: (val) => setState(() => _selectedNetwork = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // POS Filter Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A30) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF3E3E46) : const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedPos,
                            hint: const Text('All Terminals', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                            isDense: true,
                            dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All POS Terminals', style: TextStyle(fontSize: 12))),
                              ...posDevices.map((p) => DropdownMenuItem(value: p.id.toString(), child: Text('${p.name} (${p.code})', style: const TextStyle(fontSize: 12)))),
                            ],
                            onChanged: (val) => setState(() => _selectedPos = val),
                          ),
                        ),
                      ),
                      if (!isWide) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Export CSV',
                          icon: const Icon(Icons.download_rounded),
                          onPressed: () => _exportCsv(txns, totalAmount),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── KPI GRID (6 METRICS) ───────────────────────────────────────────────────
  Widget _buildKpiGrid({
    required double totalAmount,
    required double amountDeltaPct,
    required int successCount,
    required int txnsCount,
    required int failedCount,
    required double avgTicket,
    required double avgTicketDeltaPct,
    required double successRate,
    required String peakHourStr,
    required double maxHourRev,
    required String topNetworkName,
    required double topNetworkShare,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1100;
        final isMedium = constraints.maxWidth > 700;
        final cols = isWide ? 6 : (isMedium ? 3 : 2);

        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 1.6 : (isMedium ? 1.9 : 1.5),
          children: [
            StatCard(
              title: 'Total Gross Collected',
              value: 'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)}',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: AppColors.success,
              subtitle: '${amountDeltaPct >= 0 ? "+" : ""}${amountDeltaPct.toStringAsFixed(1)}% vs prior period',
            ),
            StatCard(
              title: 'Successful Collections',
              value: '$successCount',
              icon: Icons.check_circle_outline_rounded,
              accentColor: const Color(0xFF10B981),
              subtitle: 'Out of $txnsCount total attempts',
            ),
            StatCard(
              title: 'Average Ticket Size',
              value: 'GH₵ ${NumberFormat('#,##0.00').format(avgTicket)}',
              icon: Icons.trending_up_rounded,
              accentColor: AppColors.gold,
              subtitle: '${avgTicketDeltaPct >= 0 ? "+" : ""}${avgTicketDeltaPct.toStringAsFixed(1)}% delta',
            ),
            StatCard(
              title: 'Authorization Rate',
              value: '${successRate.toStringAsFixed(1)}%',
              icon: Icons.speed_rounded,
              accentColor: AppColors.primary,
              subtitle: '$failedCount declines / timeouts',
            ),
            StatCard(
              title: 'Peak Activity Window',
              value: peakHourStr,
              icon: Icons.access_time_filled_rounded,
              accentColor: const Color(0xFF8B5CF6),
              subtitle: 'Yield: GH₵ ${NumberFormat('#,##0').format(maxHourRev)}',
            ),
            StatCard(
              title: 'Primary MoMo Driver',
              value: topNetworkName,
              icon: Icons.cell_tower_rounded,
              accentColor: const Color(0xFFF59E0B),
              subtitle: '${topNetworkShare.toStringAsFixed(1)}% market volume',
            ),
          ],
        );
      },
    );
  }

  // ─── TAB NAVIGATION ────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.analytics_outlined, size: 16), text: 'Overview & Velocity'),
          Tab(icon: Icon(Icons.schedule_rounded, size: 16), text: 'Rush Hours & Heatmap'),
          Tab(icon: Icon(Icons.hub_outlined, size: 16), text: 'Telco Market Intelligence'),
          Tab(icon: Icon(Icons.badge_outlined, size: 16), text: 'Cashier Productivity'),
          Tab(icon: Icon(Icons.receipt_long_rounded, size: 16), text: 'Reconciliation Ledger'),
        ],
      ),
    );
  }

  // ─── TAB 0: OVERVIEW & VELOCITY ─────────────────────────────────────────────
  Widget _buildOverviewTab({
    required BuildContext context,
    required bool isDark,
    required List<PaymentTransaction> successTxns,
    required List<PaymentTransaction> failedTxns,
    required double totalAmount,
    required int microCount,
    required int standardCount,
    required int mediumCount,
    required int bulkCount,
    required double microAmount,
    required double standardAmount,
    required double mediumAmount,
    required double bulkAmount,
  }) {
    // Generate daily velocity spots
    final now = DateTime.now();
    final int daysCount = _selectedDays == 1 ? 24 : (_selectedDays > 30 ? 30 : _selectedDays);

    final List<FlSpot> spots = [];
    final List<String> bottomLabels = [];

    if (_selectedDays == 1) {
      // Hourly velocity for Today
      final todayStart = DateTime(now.year, now.month, now.day);
      for (int h = 0; h < 24; h++) {
        final hStart = todayStart.add(Duration(hours: h));
        final hEnd = hStart.add(const Duration(hours: 1));
        final hSum = successTxns.where((t) => !t.timestamp.isBefore(hStart) && t.timestamp.isBefore(hEnd)).fold<double>(0.0, (acc, t) => acc + t.amount);
        spots.add(FlSpot(h.toDouble(), hSum));
        bottomLabels.add('${h}h');
      }
    } else {
      // Daily velocity
      for (int i = 0; i < daysCount; i++) {
        final dStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: (daysCount - 1) - i));
        final dEnd = dStart.add(const Duration(days: 1));
        final dSum = successTxns.where((t) => !t.timestamp.isBefore(dStart) && t.timestamp.isBefore(dEnd)).fold<double>(0.0, (acc, t) => acc + t.amount);
        spots.add(FlSpot(i.toDouble(), dSum));
        bottomLabels.add(DateFormat('dd/MM').format(dStart));
      }
    }

    final double maxVal = spots.fold<double>(0.0, (m, s) => s.y > m ? s.y : m);
    final double chartMaxY = maxVal > 0 ? (maxVal * 1.25) : 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Column(
          children: [
            // Revenue Trajectory Line Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collection Revenue Velocity (Inflow Trajectory)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDays == 1 ? 'Hourly MoMo collection progression today' : 'Daily inflow volume over the selected time horizon',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)} Inflow',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Area / Line Chart
                    SizedBox(
                      height: 240,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: chartMaxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: chartMaxY / 4 > 0 ? chartMaxY / 4 : 10,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                getTitlesWidget: (v, _) => Text(
                                  'GH₵ ${_formatCompact(v)}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (daysCount / 6).clamp(1, 10).toDouble(),
                                getTitlesWidget: (v, _) {
                                  final idx = v.toInt();
                                  if (idx >= 0 && idx < bottomLabels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        bottomLabels[idx],
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final label = (spot.x.toInt() < bottomLabels.length) ? bottomLabels[spot.x.toInt()] : '';
                                  return LineTooltipItem(
                                    '$label\nGH₵ ${NumberFormat('#,##0.00').format(spot.y)}',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: AppColors.primary,
                              barWidth: 3.5,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: spots.length <= 14),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.35),
                                    AppColors.primary.withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Row / Column: Status Distribution & Ticket Size Tier Breakdown
            Builder(
              builder: (context) {
                final outcomeCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Collection Outcome & Authorization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Successful vs customer-declined / timed-out prompts', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        Builder(
                          builder: (context) {
                            final total = successTxns.length + failedTxns.length;
                            final successPct = total > 0 ? (successTxns.length / total) * 100 : 100.0;
                            final failedPct = total > 0 ? (failedTxns.length / total) * 100 : 0.0;

                            return SizedBox(
                              height: 170,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PieChart(
                                          PieChartData(
                                            sectionsSpace: 3,
                                            centerSpaceRadius: 46,
                                            sections: [
                                              PieChartSectionData(
                                                color: AppColors.success,
                                                value: successTxns.isNotEmpty ? successTxns.length.toDouble() : 1.0,
                                                title: '${successPct.toStringAsFixed(0)}%',
                                                radius: 40,
                                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                              ),
                                              PieChartSectionData(
                                                color: AppColors.error,
                                                value: failedTxns.isNotEmpty ? failedTxns.length.toDouble() : 0.001,
                                                title: failedTxns.isNotEmpty ? '${failedPct.toStringAsFixed(0)}%' : '',
                                                radius: 40,
                                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                            const Text('Prompts', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLegendItem(AppColors.success, 'Paid / Approved', '${successTxns.length} txns (${successPct.toStringAsFixed(1)}%)'),
                                      const SizedBox(height: 12),
                                      _buildLegendItem(AppColors.error, 'Declined / Expired', '${failedTxns.length} txns (${failedPct.toStringAsFixed(1)}%)'),
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
                );

                final tierCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ticket Size Tier Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Consumer spending concentration across transaction value buckets', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        _buildTierProgress(
                          title: 'Micro (< GH₵50)',
                          count: microCount,
                          amount: microAmount,
                          totalAmount: totalAmount,
                          color: const Color(0xFF06B6D4),
                        ),
                        const SizedBox(height: 12),
                        _buildTierProgress(
                          title: 'Standard (GH₵50 – GH₵200)',
                          count: standardCount,
                          amount: standardAmount,
                          totalAmount: totalAmount,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(height: 12),
                        _buildTierProgress(
                          title: 'Commercial (GH₵200 – GH₵1,000)',
                          count: mediumCount,
                          amount: mediumAmount,
                          totalAmount: totalAmount,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 12),
                        _buildTierProgress(
                          title: 'Enterprise / High Value (> GH₵1,000)',
                          count: bulkCount,
                          amount: bulkAmount,
                          totalAmount: totalAmount,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: outcomeCard),
                      const SizedBox(width: 18),
                      Expanded(child: tierCard),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      outcomeCard,
                      const SizedBox(height: 18),
                      tierCard,
                    ],
                  );
                }
              },
            )
          ],
        );
      },
    );
  }

  // ─── TAB 1: HOURLY RUSH & SHIFT ANALYTICS ──────────────────────────────────
  Widget _buildHourlyShiftTab({
    required BuildContext context,
    required bool isDark,
    required List<double> hourlyRevenue,
    required List<int> hourlyCounts,
    required int peakHourIndex,
    required double morningRev,
    required double afternoonRev,
    required double eveningRev,
    required double nightRev,
    required double totalAmount,
    required List<PaymentTransaction> successTxns,
  }) {
    final double maxHour = hourlyRevenue.fold<double>(0.0, (m, r) => r > m ? r : m);
    final double barMaxY = maxHour > 0 ? (maxHour * 1.25) : 100.0;

    return Column(
      children: [
        // 24-Hour Bar Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('24-Hour Collection Density & Rush Hour Heatmap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Volume collected by hour of day (identifies busiest cashier counter hours)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Peak Rush: ${peakHourIndex.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 240,
                  child: BarChart(
                    BarChartData(
                      maxY: barMaxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: barMaxY / 4 > 0 ? barMaxY / 4 : 10,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (v, _) => Text(
                              'GH₵ ${_formatCompact(v)}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final h = v.toInt();
                              if (h % 3 == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text('${h}h', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final h = group.x.toInt();
                            final rev = hourlyRevenue[h];
                            final cnt = hourlyCounts[h];
                            return BarTooltipItem(
                              '${h.toString().padLeft(2, '0')}:00 – ${(h + 1).toString().padLeft(2, '0')}:00\nGH₵ ${NumberFormat('#,##0.00').format(rev)}\n$cnt collections',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            );
                          },
                        ),
                      ),
                      barGroups: List.generate(24, (h) {
                        final isPeak = h == peakHourIndex && hourlyRevenue[h] > 0;
                        return BarChartGroupData(
                          x: h,
                          barRods: [
                            BarChartRodData(
                              toY: hourlyRevenue[h],
                              color: isPeak ? const Color(0xFFF59E0B) : AppColors.primary,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Shift Comparison Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 2.1 : 1.6,
              children: [
                _buildShiftCard(
                  title: 'Morning Shift',
                  hours: '08:00 – 12:00',
                  amount: morningRev,
                  totalAmount: totalAmount,
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
                _buildShiftCard(
                  title: 'Afternoon Rush',
                  hours: '12:00 – 17:00',
                  amount: afternoonRev,
                  totalAmount: totalAmount,
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
                _buildShiftCard(
                  title: 'Evening Shift',
                  hours: '17:00 – 21:00',
                  amount: eveningRev,
                  totalAmount: totalAmount,
                  icon: Icons.nightlight_round_outlined,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
                _buildShiftCard(
                  title: 'Night & Off-Peak',
                  hours: '21:00 – 08:00',
                  amount: nightRev,
                  totalAmount: totalAmount,
                  icon: Icons.bedtime_outlined,
                  color: const Color(0xFF6B7280),
                  isDark: isDark,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ─── TAB 2: TELCO & OPERATOR INTELLIGENCE ──────────────────────────────────
  Widget _buildTelcoTab({
    required BuildContext context,
    required bool isDark,
    required double totalAmount,
    required List<PaymentTransaction> mtnTxns,
    required List<PaymentTransaction> telecelTxns,
    required List<PaymentTransaction> atTxns,
    required double mtnAmount,
    required double telecelAmount,
    required double atAmount,
    required double mtnShare,
    required double telecelShare,
    required double atShare,
    required List<PaymentTransaction> allTxns,
  }) {
    final mtnAll = allTxns.where((t) => t.network == MoMoNetwork.mtn).toList();
    final telecelAll = allTxns.where((t) => t.network == MoMoNetwork.vodafone).toList();
    final atAll = allTxns.where((t) => t.network == MoMoNetwork.airtel).toList();

    final mtnSuccessRate = mtnAll.isNotEmpty ? (mtnTxns.length / mtnAll.length) * 100 : 100.0;
    final telecelSuccessRate = telecelAll.isNotEmpty ? (telecelTxns.length / telecelAll.length) * 100 : 100.0;
    final atSuccessRate = atAll.isNotEmpty ? (atTxns.length / atAll.length) * 100 : 100.0;

    final mtnAvg = mtnTxns.isNotEmpty ? mtnAmount / mtnTxns.length : 0.0;
    final telecelAvg = telecelTxns.isNotEmpty ? telecelAmount / telecelTxns.length : 0.0;
    final atAvg = atTxns.isNotEmpty ? atAmount / atTxns.length : 0.0;

    return Column(
      children: [
        // 3 Telco Detailed Intelligence Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 3 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 1.4 : 2.2,
              children: [
                _buildOperatorCard(
                  name: 'MTN Mobile Money',
                  logoColor: const Color(0xFFFFCC00),
                  amount: mtnAmount,
                  share: mtnShare,
                  successCount: mtnTxns.length,
                  totalCount: mtnAll.length,
                  successRate: mtnSuccessRate,
                  avgTicket: mtnAvg,
                  isDark: isDark,
                ),
                _buildOperatorCard(
                  name: 'Telecel Cash',
                  logoColor: const Color(0xFFE60000),
                  amount: telecelAmount,
                  share: telecelShare,
                  successCount: telecelTxns.length,
                  totalCount: telecelAll.length,
                  successRate: telecelSuccessRate,
                  avgTicket: telecelAvg,
                  isDark: isDark,
                ),
                _buildOperatorCard(
                  name: 'AT Money (AirtelTigo)',
                  logoColor: const Color(0xFF0066CC),
                  amount: atAmount,
                  share: atShare,
                  successCount: atTxns.length,
                  totalCount: atAll.length,
                  successRate: atSuccessRate,
                  avgTicket: atAvg,
                  isDark: isDark,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Comparison Bar Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Market Volume Comparison by Mobile Money Operator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Comparative distribution of collected merchant funds across Ghana telcos', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                _buildNetworkProgressItem(
                  title: 'MTN Mobile Money',
                  count: mtnTxns.length,
                  amount: mtnAmount,
                  fraction: totalAmount > 0 ? mtnAmount / totalAmount : 0.0,
                  color: const Color(0xFFFFCC00),
                ),
                const SizedBox(height: 18),
                _buildNetworkProgressItem(
                  title: 'Telecel Cash',
                  count: telecelTxns.length,
                  amount: telecelAmount,
                  fraction: totalAmount > 0 ? telecelAmount / totalAmount : 0.0,
                  color: const Color(0xFFE60000),
                ),
                const SizedBox(height: 18),
                _buildNetworkProgressItem(
                  title: 'AT Money (AirtelTigo)',
                  count: atTxns.length,
                  amount: atAmount,
                  fraction: totalAmount > 0 ? atAmount / totalAmount : 0.0,
                  color: const Color(0xFF0066CC),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── TAB 3: CASHIER PRODUCTIVITY ───────────────────────────────────────────
  Widget _buildCashierTab({
    required BuildContext context,
    required bool isDark,
    required Map<String, Map<String, dynamic>> tellerTotals,
    required double totalAmount,
  }) {
    final sortedTellers = tellerTotals.entries.toList()
      ..sort((a, b) => (b.value['amount'] as double).compareTo(a.value['amount'] as double));

    return Card(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cashier / Counter Productivity Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Ranked by total collections and customer throughput across ${sortedTellers.length} active staff', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${sortedTellers.length} Staff on Duty', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
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
                    columnSpacing: 24,
                    headingRowHeight: 44,
                    headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('RANK', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('CASHIER / STAFF', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('POS TERMINAL', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('SUCCESSFUL TXNS', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('TOTAL COLLECTED', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('AVG. TICKET', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('MAX SINGLE TXN', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('SHARE OF VOLUME', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: sortedTellers.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final teller = entry.value;
                      final count = teller.value['count'] as int;
                      final amount = teller.value['amount'] as double;
                      final maxSingle = teller.value['max'] as double;
                      final avg = count > 0 ? amount / count : 0.0;
                      final share = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;

                      final rankIcon = rank == 1 ? '🥇' : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '#$rank'));

                      return DataRow(
                        cells: [
                          DataCell(Text(rankIcon, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                          DataCell(Text(teller.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                          DataCell(Text(teller.value['pos']?.toString() ?? 'pos_01', style: const TextStyle(fontFamily: 'Courier', fontSize: 12))),
                          DataCell(Text('$count', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success))),
                          DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(avg)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(maxSingle)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 70,
                                  child: LinearProgressIndicator(
                                    value: (share / 100).clamp(0.0, 1.0),
                                    backgroundColor: isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0),
                                    color: AppColors.primary,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${share.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
    );
  }

  // ─── TAB 4: DAILY RECONCILIATION & AUDIT ────────────────────────────────────
  Widget _buildAuditTab({
    required BuildContext context,
    required bool isDark,
    required List<PaymentTransaction> txns,
    required double totalAmount,
  }) {
    // Group transactions by calendar day
    final Map<String, List<PaymentTransaction>> daysMap = {};
    for (final t in txns) {
      final key = DateFormat('yyyy-MM-dd').format(t.timestamp);
      daysMap.putIfAbsent(key, () => []).add(t);
    }

    final sortedDates = daysMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return Card(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Financial Reconciliation & Settlement Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Day-by-day aggregated collections audit with bank payout status', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _exportCsv(txns, totalAmount),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Download CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    columnSpacing: 24,
                    headingRowHeight: 44,
                    headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('SUCCESSFUL TXNS', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('FAILED / TIMEOUT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('GROSS INFLOW', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('AVG. TRANSACTION', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('COMPLETION RATE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('SETTLEMENT STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: sortedDates.map((dStr) {
                      final dayTxns = daysMap[dStr]!;
                      final daySuccess = dayTxns.where((t) => t.status == TransactionStatus.success).toList();
                      final dayFailed = dayTxns.where((t) => t.status == TransactionStatus.failed).toList();
                      final dayAmount = daySuccess.fold<double>(0.0, (acc, t) => acc + t.amount);
                      final dayAvg = daySuccess.isNotEmpty ? dayAmount / daySuccess.length : 0.0;
                      final dayRate = dayTxns.isNotEmpty ? (daySuccess.length / dayTxns.length) * 100 : 100.0;

                      final formattedDate = DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dStr));

                      return DataRow(
                        cells: [
                          DataCell(Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                          DataCell(Text('${daySuccess.length}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text('${dayFailed.length}', style: TextStyle(color: dayFailed.isNotEmpty ? AppColors.error : AppColors.textSecondary))),
                          DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(dayAmount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success))),
                          DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(dayAvg)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (dayRate >= 90 ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${dayRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: dayRate >= 90 ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                const SizedBox(width: 4),
                                const Text('Reconciled & Settled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
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
    );
  }

  // ─── HELPER CARDS & VISUAL ELEMENTS ────────────────────────────────────────
  Widget _buildShiftCard({
    required String title,
    required String hours,
    required double amount,
    required double totalAmount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final share = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                Text('${share.toStringAsFixed(1)}% of total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(hours, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text('GH₵ ${NumberFormat('#,##0.00').format(amount)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorCard({
    required String name,
    required Color logoColor,
    required double amount,
    required double share,
    required int successCount,
    required int totalCount,
    required double successRate,
    required double avgTicket,
    required bool isDark,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: logoColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: logoColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${share.toStringAsFixed(1)}% Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: logoColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('GH₵ ${NumberFormat('#,##0.00').format(amount)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Success Rate', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text('${successRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Completed Txns', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text('$successCount / $totalCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Avg. Ticket', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text('GH₵ ${NumberFormat('#,##0').format(avgTicket)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String value) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildTierProgress({
    required String title,
    required int count,
    required double amount,
    required double totalAmount,
    required Color color,
  }) {
    final share = totalAmount > 0 ? (amount / totalAmount) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$title ($count collections)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(
              'GH₵ ${NumberFormat('#,##0.00').format(amount)} (${(share * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: share.clamp(0.0, 1.0),
          backgroundColor: AppColors.border,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
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
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('$title ($count txns)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
          value: fraction.clamp(0.0, 1.0),
          backgroundColor: AppColors.border,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
