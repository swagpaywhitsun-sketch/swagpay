import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/app_thin_footer.dart';

class TellerReportsScreen extends ConsumerWidget {
  const TellerReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final txns = repo.getTransactions();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final headingColor = isDark ? Colors.white : const Color(0xFF303030);
    final mutedColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF707579);

    final successTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final pendingTxns = txns.where((t) => t.status == TransactionStatus.pending).toList();
    final failedTxns = txns.where((t) => t.status == TransactionStatus.failed).toList();
    final totalAmount = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final successRate = txns.isEmpty ? 0.0 : successTxns.length / txns.length;

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
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Cashier Performance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Total Collections hero card ────────────────────────────
            _card(
              cardBg: cardBg,
              borderColor: borderColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL COLLECTIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: headingColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${successTxns.length} settled of ${txns.length} transaction(s)',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF229ED9).withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(successRate * 100).toStringAsFixed(0)}% success',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF229ED9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Outcome counters ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _miniStat('Successful', successTxns.length, Icons.check_circle_outline, const Color(0xFF2EBD85), cardBg, borderColor, headingColor, mutedColor, isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat('Pending', pendingTxns.length, Icons.hourglass_empty_rounded, const Color(0xFFF5A623), cardBg, borderColor, headingColor, mutedColor, isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat('Failed', failedTxns.length, Icons.cancel_outlined, const Color(0xFFE53935), cardBg, borderColor, headingColor, mutedColor, isDark),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Outcome distribution ───────────────────────────────────
            _card(
              cardBg: cardBg,
              borderColor: borderColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collection Outcome Distribution',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: headingColor),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 170,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 38,
                              sections: [
                                PieChartSectionData(
                                  color: const Color(0xFF2EBD85),
                                  value: successTxns.length.toDouble().clamp(1.0, 999.0),
                                  title: '${successTxns.length}',
                                  radius: 42,
                                  titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                PieChartSectionData(
                                  color: const Color(0xFFF5A623),
                                  value: pendingTxns.length.toDouble().clamp(0.1, 999.0),
                                  title: '${pendingTxns.length}',
                                  radius: 42,
                                  titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                PieChartSectionData(
                                  color: const Color(0xFFE53935),
                                  value: failedTxns.length.toDouble().clamp(0.1, 999.0),
                                  title: '${failedTxns.length}',
                                  radius: 42,
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
                            _legend(const Color(0xFF2EBD85), 'Successful (${successTxns.length})', mutedColor),
                            const SizedBox(height: 8),
                            _legend(const Color(0xFFF5A623), 'Pending (${pendingTxns.length})', mutedColor),
                            const SizedBox(height: 8),
                            _legend(const Color(0xFFE53935), 'Failed (${failedTxns.length})', mutedColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Network breakdown ──────────────────────────────────────
            _card(
              cardBg: cardBg,
              borderColor: borderColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collections by Network',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: headingColor),
                  ),
                  const SizedBox(height: 16),
                  _progress(
                    'MTN MoMo (${mtnTxns.length})',
                    mtnFraction,
                    'GH₵ ${NumberFormat('#,##0.00').format(mtnAmount)} · ${(mtnFraction * 100).toStringAsFixed(1)}%',
                    const Color(0xFFF5A623),
                    cardBg, borderColor, headingColor, mutedColor,
                  ),
                  const SizedBox(height: 14),
                  _progress(
                    'Telecel Cash (${telecelTxns.length})',
                    telecelFraction,
                    'GH₵ ${NumberFormat('#,##0.00').format(telecelAmount)} · ${(telecelFraction * 100).toStringAsFixed(1)}%',
                    const Color(0xFF229ED9),
                    cardBg, borderColor, headingColor, mutedColor,
                  ),
                  const SizedBox(height: 14),
                  _progress(
                    'AT Money (${atTxns.length})',
                    atFraction,
                    'GH₵ ${NumberFormat('#,##0.00').format(atAmount)} · ${(atFraction * 100).toStringAsFixed(1)}%',
                    const Color(0xFFE53935),
                    cardBg, borderColor, headingColor, mutedColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }

  Widget _card({
    required Color cardBg,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }

  Widget _miniStat(
    String label,
    int value,
    IconData icon,
    Color color,
    Color cardBg,
    Color borderColor,
    Color headingColor,
    Color mutedColor,
    bool isDark,
  ) {
    return _card(
      cardBg: cardBg,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: headingColor),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String text, Color mutedColor) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
      ],
    );
  }

  Widget _progress(
    String title,
    double fraction,
    String amount,
    Color color,
    Color cardBg,
    Color borderColor,
    Color headingColor,
    Color mutedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: headingColor)),
            Text(amount, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: mutedColor)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: fraction,
          backgroundColor: isDarkTrack(cardBg) ? const Color(0xFF27272A) : const Color(0xFFF1F3F5),
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  bool isDarkTrack(Color cardBg) => cardBg.computeLuminance() < 0.5;
}
