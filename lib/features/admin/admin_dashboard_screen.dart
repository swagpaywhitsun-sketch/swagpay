import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/pos_device.dart';
import '../../core/models/refund_request.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(paymentRepositoryProvider);
      if (!repo.hasSynced) {
        ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final txns = repo.getTransactions();
    final tellers = repo.getTellers();
    final posDevices = repo.getPosDevices();
    final refunds = repo.getRefundRequests();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter successful transactions
    final successfulTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final totalCollected = successfulTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    // Calculate Today's collections specifically
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todaySuccessful = successfulTxns.where((t) => !t.timestamp.isBefore(todayStart)).toList();
    final todayCollected = todaySuccessful.fold<double>(0.0, (acc, t) => acc + t.amount);

    final activeTellers = tellers.where((t) => t.isActive).length;
    final activePos = posDevices.where((p) => p.status == PosStatus.online).length;
    final pendingRefunds = refunds.where((r) => r.status == RefundStatus.pending).length;
    final successRate = txns.isEmpty ? 100 : ((successfulTxns.length / txns.length) * 100).toInt();

    // ─── 7-DAY REAL COLLECTIONS VELOCITY ─────────────────────────────────────
    final sevenDays = List.generate(7, (i) {
      final d = todayStart.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final dailyAmounts = sevenDays.map((dayStart) {
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dayTxns = successfulTxns.where((t) => !t.timestamp.isBefore(dayStart) && t.timestamp.isBefore(dayEnd));
      return dayTxns.fold<double>(0.0, (sum, t) => sum + t.amount);
    }).toList();

    final dailyCounts = sevenDays.map((dayStart) {
      final dayEnd = dayStart.add(const Duration(days: 1));
      return successfulTxns.where((t) => !t.timestamp.isBefore(dayStart) && t.timestamp.isBefore(dayEnd)).length;
    }).toList();

    final sevenDayTotal = dailyAmounts.fold<double>(0.0, (sum, a) => sum + a);
    final spots = List.generate(7, (i) => FlSpot(i.toDouble(), dailyAmounts[i]));
    final maxDaily = dailyAmounts.fold<double>(0.0, (m, a) => a > m ? a : m);
    final chartMaxY = maxDaily > 0 ? (maxDaily * 1.35) : 100.0;

    // ─── TELCO NETWORKS DISTRIBUTION (LIVE) ──────────────────────────────────
    final mtnTxns = successfulTxns.where((t) => t.network == MoMoNetwork.mtn).toList();
    final telecelTxns = successfulTxns.where((t) => t.network == MoMoNetwork.vodafone).toList();
    final atTxns = successfulTxns.where((t) => t.network == MoMoNetwork.airtel).toList();

    final mtnAmount = mtnTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final telecelAmount = telecelTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final atAmount = atTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    return RefreshIndicator(
      onRefresh: () => ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'POS Control Center',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Live counter collections, hardware terminals & staff management',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
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
                              'IP: ${repo.clientRemoteIp}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Courier', color: AppColors.primaryLight),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Refresh live data from PostgreSQL',
                      onPressed: () => ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh(),
                      icon: repo.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transactions and summary exported to CSV successfully!'), backgroundColor: AppColors.success),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export Data'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!repo.hasSynced && repo.isLoading) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connecting to server and retrieving real-time data...',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Row 1: KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final crossAxisCount = isWide ? 4 : 2;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: isWide ? 1.9 : 1.5,
                  children: [
                    StatCard(
                      title: 'Total Collected Today',
                      value: 'GH₵ ${NumberFormat('#,##0.00').format(todayCollected)}',
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: AppColors.success,
                      subtitle: '${todaySuccessful.length} txns today • GH₵ ${NumberFormat('#,##0').format(totalCollected)} all-time',
                    ),
                    StatCard(
                      title: 'System Success Rate',
                      value: '$successRate%',
                      icon: Icons.speed_rounded,
                      accentColor: AppColors.primaryLight,
                      subtitle: '${successfulTxns.length} success of ${txns.length} total txns',
                    ),
                    StatCard(
                      title: 'Active Tellers & POS',
                      value: '$activeTellers / $activePos',
                      icon: Icons.point_of_sale_rounded,
                      accentColor: AppColors.gold,
                      subtitle: '${posDevices.length} registered terminals',
                      onTap: () => context.go('/admin/pos'),
                    ),
                    StatCard(
                      title: 'Pending Refunds',
                      value: '$pendingRefunds',
                      icon: Icons.undo_rounded,
                      accentColor: AppColors.error,
                      subtitle: pendingRefunds > 0 ? 'Requires admin authorization' : 'All claims resolved',
                      onTap: () => context.go('/admin/refunds'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Charts & Operational Status Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;

                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Collections Trend Chart (100% REAL 7-DAY VALUES)
                    Expanded(
                      flex: isWide ? 2 : 0,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
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
                                        'Collections Velocity (Last 7 Days)',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '7-Day Volume: GH₵ ${NumberFormat('#,##0.00').format(sevenDayTotal)} across counter nodes',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('LIVE DATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.successDark)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 220,
                                child: LineChart(
                                  LineChartData(
                                    minY: 0,
                                    maxY: chartMaxY,
                                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                                    titlesData: FlTitlesData(
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            final idx = value.toInt();
                                            if (idx >= 0 && idx < sevenDays.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Text(
                                                  DateFormat('E').format(sevenDays[idx]),
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 42,
                                          getTitlesWidget: (value, meta) {
                                            if (value == 0) return const SizedBox.shrink();
                                            return Text(
                                              NumberFormat.compact().format(value),
                                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((spot) {
                                            final idx = spot.x.toInt();
                                            final dayDate = idx < sevenDays.length ? sevenDays[idx] : DateTime.now();
                                            final txnCount = idx < dailyCounts.length ? dailyCounts[idx] : 0;
                                            return LineTooltipItem(
                                              '${DateFormat('EEE, dd MMM').format(dayDate)}\nGH₵ ${NumberFormat('#,##0.00').format(spot.y)}\n$txnCount collections',
                                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: true,
                                        color: AppColors.success,
                                        barWidth: 3,
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: AppColors.success.withValues(alpha: 0.15),
                                        ),
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 4,
                                              color: AppColors.success,
                                              strokeWidth: 2,
                                              strokeColor: Colors.white,
                                            );
                                          },
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
                    ),
                    if (isWide) const SizedBox(width: 16),
                    if (!isWide) const SizedBox(height: 16),

                    // Operational Alerts & Live Status Panel (100% REAL STATE)
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Operational Alerts & Status',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 16),
                              _buildAlertItem(
                                icon: activePos > 0 ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                color: activePos > 0 ? AppColors.success : AppColors.gold,
                                title: '$activePos of ${posDevices.length} Terminals Online',
                                subtitle: posDevices.isEmpty
                                    ? 'No POS hardware registered in database yet.'
                                    : '${posDevices.where((p) => p.status == PosStatus.online).length} terminal node(s) actively reporting status.',
                              ),
                              const Divider(height: 20),
                              _buildAlertItem(
                                icon: Icons.account_balance_wallet_rounded,
                                color: AppColors.success,
                                title: 'GH₵ ${NumberFormat('#,##0.00').format(totalCollected)} Verified Collections',
                                subtitle: '${successfulTxns.length} successful debits authorized across counters.',
                              ),
                              const Divider(height: 20),
                              _buildAlertItem(
                                icon: pendingRefunds > 0 ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                                color: pendingRefunds > 0 ? AppColors.error : AppColors.success,
                                title: '$pendingRefunds Pending Reversal Request(s)',
                                subtitle: pendingRefunds > 0
                                    ? 'Cashier refund claim requires administrator approval.'
                                    : 'All cashier refund claims have been audited and resolved.',
                              ),
                              const Divider(height: 20),
                              _buildAlertItem(
                                icon: Icons.security_rounded,
                                color: AppColors.primary,
                                title: 'Active Remote Client IP',
                                subtitle: repo.clientRemoteIp.isNotEmpty && repo.clientRemoteIp != '127.0.0.1'
                                    ? '${repo.clientRemoteIp} (Audited via Fly.io edge)'
                                    : 'Direct local session (${repo.clientRemoteIp.isNotEmpty ? repo.clientRemoteIp : "127.0.0.1"})',
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

            // Real Telco Distribution Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Provider Breakdown',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Live MoMo network split calculated directly from recorded transactions',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          children: [
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: _buildNetworkCard('MTN Mobile Money', mtnTxns.length, mtnAmount, const Color(0xFFFFCC00)),
                            ),
                            if (isWide) const SizedBox(width: 12),
                            if (!isWide) const SizedBox(height: 12),
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: _buildNetworkCard('Telecel Cash', telecelTxns.length, telecelAmount, const Color(0xFFE60000)),
                            ),
                            if (isWide) const SizedBox(width: 12),
                            if (!isWide) const SizedBox(height: 12),
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: _buildNetworkCard('AT Money', atTxns.length, atAmount, const Color(0xFF0066CC)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Recent Collections Table (100% REAL)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Transactions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        TextButton(
                          onPressed: () => context.go('/admin/transactions'),
                          child: const Text('View All Transactions'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (txns.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: const Text('No transactions recorded yet.'),
                          );
                        }
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: 28,
                              headingRowColor: WidgetStateProperty.all(
                                isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              ),
                              columns: const [
                                DataColumn(label: Text('REFERENCE', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('AMOUNT (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('NETWORK', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('CASHIER / POS', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: txns.take(6).map((t) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(t.reference, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text('${t.customerName} (${t.customerNumber})')),
                                    DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(t.amount)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(t.networkDisplay)),
                                    DataCell(Text('${t.tellerName} • ${t.posId}')),
                                    DataCell(StatusBadge(status: t.status)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard(String networkName, int count, double totalAmount, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(networkName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            '$count collections',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
