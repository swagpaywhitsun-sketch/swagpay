import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/services/receipt_service.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/carrier_brand_icon.dart';
import '../../core/widgets/lively_widgets.dart';
import '../../core/widgets/notification_dropdown_button.dart';
import '../../core/widgets/teller_bottom_nav_bar.dart';
import '../../core/widgets/teller_user_avatar_menu.dart';

class TellerReportsScreen extends ConsumerWidget {
  const TellerReportsScreen({super.key});

  void _showShiftReconciliationSheet(
    BuildContext context,
    double totalAmount,
    int successCount,
    int totalCount,
    double mtnAmount,
    double telecelAmount,
    double atAmount,
    String tellerName, [
    String branch = '',
  ]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cashier Shift Reconciliation',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Shift Reconciliation • ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16181D) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _reconcileRow('Cashier / Teller', tellerName, isDark),
                    Divider(height: 16, color: borderColor),
                    _reconcileRow('Settled Collections', '$successCount of $totalCount txns', isDark),
                    Divider(height: 16, color: borderColor),
                    _reconcileRow('MTN MoMo Total', 'GHS ${NumberFormat('#,##0.00').format(mtnAmount)}', isDark),
                    Divider(height: 16, color: borderColor),
                    _reconcileRow('Telecel Cash Total', 'GHS ${NumberFormat('#,##0.00').format(telecelAmount)}', isDark),
                    Divider(height: 16, color: borderColor),
                    _reconcileRow('AT Money Total', 'GHS ${NumberFormat('#,##0.00').format(atAmount)}', isDark),
                    Divider(height: 16, color: borderColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'GRAND TOTAL REVENUE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                        Text(
                          'GHS ${NumberFormat('#,##0.00').format(totalAmount)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BouncyTap(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  await ReceiptService.printShiftReport(
                    context: context,
                    tellerName: tellerName,
                    branch: branch,
                    totalCount: totalCount,
                    successCount: successCount,
                    mtnAmount: mtnAmount,
                    telecelAmount: telecelAmount,
                    atAmount: atAmount,
                    totalAmount: totalAmount,
                    timestamp: now,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF229ED9), Color(0xFF1570A6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF229ED9).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PRINT SHIFT RECONCILIATION REPORT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _reconcileRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final txns = repo.getTransactions();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8);
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);
    final headingColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final successTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final pendingTxns = txns.where((t) => t.status == TransactionStatus.pending).toList();
    final failedTxns = txns.where((t) => t.status == TransactionStatus.failed).toList();
    final totalAmount = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final successRate = txns.isEmpty ? 0.0 : successTxns.length / txns.length;
    final avgTicket = successTxns.isNotEmpty ? totalAmount / successTxns.length : 0.0;

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
        actions: [
          IconButton(
            tooltip: 'Print Shift Report',
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            onPressed: () => _showShiftReconciliationSheet(
              context,
              totalAmount,
              successTxns.length,
              txns.length,
              mtnAmount,
              telecelAmount,
              atAmount,
              user?.fullName ?? 'Cashier',
              user?.branch ?? 'Main Hub',
            ),
          ),
          NotificationDropdownButton(isDark: isDark),
          const SizedBox(width: 8),
          TellerUserAvatarMenu(isDark: isDark),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dribbble Fintech Hero Card ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E2430), Color(0xFF141720)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFF334155),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF229ED9).withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cashier Status Header with Pulsing Beacon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const PulsingBeacon(color: Color(0xFF10B981), size: 8),
                          const SizedBox(width: 8),
                          Text(
                            '${user?.fullName ?? "CASHIER"} • SHIFT ACTIVE'.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '${(successRate * 100).toStringAsFixed(0)}% SUCCESS',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TOTAL SETTLED COLLECTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedCountUp(
                    value: totalAmount,
                    prefix: 'GH₵ ',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SETTLED TRANSACTIONS',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${successTxns.length} / ${txns.length}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AVERAGE TICKET',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GH₵ ${NumberFormat('#,##0.00').format(avgTicket)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 14),

            // ── Outcome Counters (Bouncy Micro-cards) ────────────────────
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    label: 'Successful',
                    value: successTxns.length,
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    cardBg: cardBg,
                    borderColor: borderColor,
                    headingColor: headingColor,
                    mutedColor: mutedColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat(
                    label: 'Pending',
                    value: pendingTxns.length,
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFFF59E0B),
                    cardBg: cardBg,
                    borderColor: borderColor,
                    headingColor: headingColor,
                    mutedColor: mutedColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat(
                    label: 'Failed',
                    value: failedTxns.length,
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFEF4444),
                    cardBg: cardBg,
                    borderColor: borderColor,
                    headingColor: headingColor,
                    mutedColor: mutedColor,
                    isDark: isDark,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 16),

            // ── Donut Chart Distribution ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Outcome Distribution',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: headingColor),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${txns.length} Total',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF229ED9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 175,
                    child: Row(
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 42,
                                  sections: [
                                    PieChartSectionData(
                                      color: const Color(0xFF10B981),
                                      value: successTxns.length.toDouble().clamp(0.1, 999.0),
                                      title: '',
                                      radius: 28,
                                    ),
                                    PieChartSectionData(
                                      color: const Color(0xFFF59E0B),
                                      value: pendingTxns.length.toDouble().clamp(0.1, 999.0),
                                      title: '',
                                      radius: 28,
                                    ),
                                    PieChartSectionData(
                                      color: const Color(0xFFEF4444),
                                      value: failedTxns.length.toDouble().clamp(0.1, 999.0),
                                      title: '',
                                      radius: 28,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${txns.length}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: headingColor,
                                    ),
                                  ),
                                  Text(
                                    'TRX',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legendItem(const Color(0xFF10B981), 'Successful', successTxns.length, mutedColor, headingColor),
                            const SizedBox(height: 10),
                            _legendItem(const Color(0xFFF59E0B), 'Pending', pendingTxns.length, mutedColor, headingColor),
                            const SizedBox(height: 10),
                            _legendItem(const Color(0xFFEF4444), 'Failed', failedTxns.length, mutedColor, headingColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 16),

            // ── Collections by Carrier (Real Branded Icons) ─────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Collections by Carrier Network',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: headingColor),
                      ),
                      const Icon(Icons.signal_cellular_alt_rounded, size: 18, color: Color(0xFF229ED9)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _brandedNetworkRow(
                    network: MoMoNetwork.mtn,
                    title: 'MTN Mobile Money',
                    txnCount: mtnTxns.length,
                    amount: mtnAmount,
                    fraction: mtnFraction,
                    color: const Color(0xFFF59E0B),
                    headingColor: headingColor,
                    mutedColor: mutedColor,
                    cardBg: cardBg,
                  ),
                  const SizedBox(height: 14),
                  _brandedNetworkRow(
                    network: MoMoNetwork.vodafone,
                    title: 'Telecel Cash',
                    txnCount: telecelTxns.length,
                    amount: telecelAmount,
                    fraction: telecelFraction,
                    color: const Color(0xFFEF4444),
                    headingColor: headingColor,
                    mutedColor: mutedColor,
                    cardBg: cardBg,
                  ),
                  const SizedBox(height: 14),
                  _brandedNetworkRow(
                    network: MoMoNetwork.airtel,
                    title: 'AT Money',
                    txnCount: atTxns.length,
                    amount: atAmount,
                    fraction: atFraction,
                    color: const Color(0xFF3B82F6),
                    headingColor: headingColor,
                    mutedColor: mutedColor,
                    cardBg: cardBg,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 20),

            // ── End Shift CTA Button ─────────────────────────────────────
            BouncyTap(
              onTap: () => _showShiftReconciliationSheet(
                context,
                totalAmount,
                successTxns.length,
                txns.length,
                mtnAmount,
                telecelAmount,
                atAmount,
                user?.fullName ?? 'Cashier',
                user?.branch ?? 'Main Hub',
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'GENERATE SHIFT RECONCILIATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/reports'),
    );
  }

  Widget _miniStat({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color headingColor,
    required Color mutedColor,
    required bool isDark,
  }) {
    return BouncyTap(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: headingColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String text, int count, Color mutedColor, Color headingColor) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }

  Widget _brandedNetworkRow({
    required MoMoNetwork network,
    required String title,
    required int txnCount,
    required double amount,
    required double fraction,
    required Color color,
    required Color headingColor,
    required Color mutedColor,
    required Color cardBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CarrierBrandIcon(network: network, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: headingColor),
                  ),
                  Text(
                    '$txnCount transaction(s)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'GH₵ ${NumberFormat('#,##0.00').format(amount)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: headingColor),
                ),
                Text(
                  '${(fraction * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
