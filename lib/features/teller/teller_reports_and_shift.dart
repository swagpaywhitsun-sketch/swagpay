import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';

class TellerReportsScreen extends ConsumerWidget {
  const TellerReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final txns = repo.getTransactions();

    final successTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final failedTxns = txns.where((t) => t.status == TransactionStatus.failed).toList();
    final totalAmount = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final mtnTxns = successTxns.where((t) => t.network == MoMoNetwork.mtn).toList();
    final telecelTxns = successTxns.where((t) => t.network == MoMoNetwork.vodafone).toList();
    final atTxns = successTxns.where((t) => t.network == MoMoNetwork.airtel).toList();

    final mtnAmount = mtnTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final telecelAmount = telecelTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final atAmount = atTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final mtnFraction = totalAmount > 0 ? (mtnAmount / totalAmount) : 0.0;
    final telecelFraction = totalAmount > 0 ? (telecelAmount / totalAmount) : 0.0;
    final atFraction = totalAmount > 0 ? (atAmount / totalAmount) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Teller Performance Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Summary Row
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Collections',
                    value: 'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: AppColors.success,
                    subtitle: '${successTxns.length} settled',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Transactions',
                    value: '${txns.length}',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.primaryLight,
                    subtitle: '${failedTxns.length} failed/void',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Performance Pie Chart (Success vs Failed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collection Outcome Distribution',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
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
                                    value: (successTxns.length).toDouble().clamp(1.0, 999.0),
                                    title: '${successTxns.length}',
                                    radius: 44,
                                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  PieChartSectionData(
                                    color: AppColors.error,
                                    value: (failedTxns.length).toDouble().clamp(0.1, 999.0),
                                    title: '${failedTxns.length}',
                                    radius: 44,
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
                              _buildChartLegend(AppColors.success, 'Successful (${successTxns.length})'),
                              const SizedBox(height: 8),
                              _buildChartLegend(AppColors.error, 'Declined / Failed (${failedTxns.length})'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Methods Breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collections by Network Provider',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    _buildChannelProgress('MTN MoMo (${mtnTxns.length})', mtnFraction, 'GH₵ ${NumberFormat('#,##0.00').format(mtnAmount)} (${(mtnFraction * 100).toStringAsFixed(1)}%)', AppColors.gold),
                    const SizedBox(height: 12),
                    _buildChannelProgress('Telecel Cash (${telecelTxns.length})', telecelFraction, 'GH₵ ${NumberFormat('#,##0.00').format(telecelAmount)} (${(telecelFraction * 100).toStringAsFixed(1)}%)', AppColors.error),
                    const SizedBox(height: 12),
                    _buildChannelProgress('AT Money (${atTxns.length})', atFraction, 'GH₵ ${NumberFormat('#,##0.00').format(atAmount)} (${(atFraction * 100).toStringAsFixed(1)}%)', AppColors.primaryLight),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildChannelProgress(String title, double fraction, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
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
}

class TellerShiftScreen extends ConsumerStatefulWidget {
  const TellerShiftScreen({super.key});

  @override
  ConsumerState<TellerShiftScreen> createState() => _TellerShiftScreenState();
}

class _TellerShiftScreenState extends ConsumerState<TellerShiftScreen> {
  final _cashActualController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _cashActualController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final shift = repo.activeShift;
    final timeFormat = DateFormat('hh:mm a');

    if (shift == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shift Status')),
        body: const Center(child: Text('No active shift currently open')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Active Shift Reconciliation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'COUNTER SHIFT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: shift.isClosed ? Colors.grey : AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            shift.isClosed ? 'CLOSED' : 'OPEN & ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: shift.isClosed ? Colors.grey : AppColors.successDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildShiftRow('Teller', shift.tellerName),
                    _buildShiftRow('Shift Start Time', timeFormat.format(shift.startTime)),
                    _buildShiftRow('Total Collections', 'GH₵ ${shift.totalCollected.toStringAsFixed(2)}'),
                    _buildShiftRow('Total Transactions', '${shift.totalCount}'),
                    _buildShiftRow('Expected Settlement Amount', 'GH₵ ${shift.cashExpected.toStringAsFixed(2)}'),
                    if (shift.isClosed && shift.cashActual != null) ...[
                      const Divider(height: 24),
                      _buildShiftRow('Actual Reconciled Amount', 'GH₵ ${shift.cashActual!.toStringAsFixed(2)}'),
                      _buildShiftRow(
                        'Variance',
                        'GH₵ ${shift.variance.toStringAsFixed(2)}',
                        isNegative: shift.variance < 0,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (!shift.isClosed) ...[
              const Text(
                'End of Shift MoMo Reconciliation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verify all digital Mobile Money collections at your counter window before closing shift.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cashActualController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Reconciled Volume in Register (GH₵) *',
                  prefixText: 'GH₵ ',
                  prefixIcon: Icon(Icons.money_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Closing Notes / Handover remarks',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final val = double.tryParse(_cashActualController.text.trim());
                  if (val == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid cash amount counted')),
                    );
                    return;
                  }
                  await ref.read(paymentRepositoryProvider).closeShift(
                        cashActual: val,
                        notes: _notesController.text.trim(),
                      );
                  setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Shift closed successfully. Reconciliation report logged.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.lock_clock_rounded),
                label: const Text('Reconcile & Close Shift'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShiftRow(String label, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isNegative ? AppColors.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
