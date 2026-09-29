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

    final successfulTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final totalCollected = successfulTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final activeTellers = tellers.where((t) => t.isActive).length;
    final activePos = posDevices.where((p) => p.status == PosStatus.online).length;
    final pendingRefunds = refunds.where((r) => r.status == RefundStatus.pending).length;
    final successRate = txns.isEmpty ? 100 : ((successfulTxns.length / txns.length) * 100).toInt();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                    Text(
                      'Real-time overview of collections, tellers, and hardware nodes',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Refresh live data',
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
                          const SnackBar(content: Text('Exporting Executive Summary PDF...')),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export Summary PDF'),
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
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(totalCollected)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: AppColors.success,
                    subtitle: '${successfulTxns.length} successful txns',
                  ),
                  StatCard(
                    title: 'System Success Rate',
                    value: '$successRate%',
                    icon: Icons.speed_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: '${txns.length} total processed',
                  ),
                  StatCard(
                    title: 'Active Tellers & POS',
                    value: '$activeTellers / $activePos',
                    icon: Icons.point_of_sale_rounded,
                    accentColor: AppColors.gold,
                    subtitle: 'Terminals online',
                    onTap: () => context.go('/admin/pos'),
                  ),
                  StatCard(
                    title: 'Pending Refunds',
                    value: '$pendingRefunds',
                    icon: Icons.undo_rounded,
                    accentColor: AppColors.error,
                    subtitle: 'Require admin review',
                    onTap: () => context.go('/admin/refunds'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Charts Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;

              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collections Trend Chart
                  Expanded(
                    flex: isWide ? 2 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collections Velocity (Last 7 Days)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Volume in GH₵ across all active counter nodes',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 220,
                              child: LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                                  titlesData: const FlTitlesData(
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: const [
                                        FlSpot(0, 80),
                                        FlSpot(1, 140),
                                        FlSpot(2, 110),
                                        FlSpot(3, 220),
                                        FlSpot(4, 180),
                                        FlSpot(5, 310),
                                        FlSpot(6, 272),
                                      ],
                                      isCurved: true,
                                      color: AppColors.success,
                                      barWidth: 3,
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppColors.success.withValues(alpha: 0.15),
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

                  // Alerts & Terminal Status Panel
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Operational Alerts',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 16),
                            _buildAlertItem(
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                              title: 'Reconciliation Clean',
                              subtitle: 'All counter collections match settlement pool.',
                            ),
                            const Divider(height: 20),
                            _buildAlertItem(
                              icon: Icons.wifi_rounded,
                              color: AppColors.success,
                              title: 'POS-01 Connected',
                              subtitle: 'Accra Mall Food Court active on MoMo gateway.',
                            ),
                            const Divider(height: 20),
                            _buildAlertItem(
                              icon: Icons.verified_user_rounded,
                              color: AppColors.success,
                              title: 'Security Whitelist Active',
                              subtitle: '3 terminals verified on POS subnet.',
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

          // Recent Collections Table
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
                            rows: txns.take(5).map((t) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(t.reference, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text('${t.customerName} (${t.customerNumber})')),
                                  DataCell(Text('GH₵ ${t.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
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
