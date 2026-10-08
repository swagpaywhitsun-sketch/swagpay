import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/transaction.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/services/payment_repository.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/carrier_brand_icon.dart';
import '../../core/widgets/lively_widgets.dart';
import '../../core/widgets/notification_dropdown_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/teller_bottom_nav_bar.dart';
import '../../core/widgets/teller_user_avatar_menu.dart';

class TellerDashboardScreen extends ConsumerStatefulWidget {
  const TellerDashboardScreen({super.key});

  @override
  ConsumerState<TellerDashboardScreen> createState() => _TellerDashboardScreenState();
}

class _TellerDashboardScreenState extends ConsumerState<TellerDashboardScreen> {
  bool _isBalanceVisible = true;
  TransactionStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final avatar = ref.watch(userAvatarProvider);
    final repo = ref.watch(paymentRepositoryProvider);
    final allTxns = repo.getTransactions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final successTxns = allTxns.where((t) => t.status == TransactionStatus.success).toList();
    final now = DateTime.now();
    final todayTxns = successTxns.where((t) =>
        t.timestamp.year == now.year && t.timestamp.month == now.month && t.timestamp.day == now.day).toList();
    final todayTotal = todayTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final displayTxns = _filterStatus == null
        ? allTxns
        : allTxns.where((t) => t.status == _filterStatus).toList();

    final bgColor = isDark ? const Color(0xFF0F1115) : const Color(0xFFF4F6F9);
    final cardBg = isDark ? const Color(0xFF181A20) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262933) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildDribbbleAppBar(context, user, avatar, isDark, cardBg, borderColor),
      body: RefreshIndicator(
        color: const Color(0xFF229ED9),
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (repo.lastSyncError != null) ...[
                      _buildSyncBanner(repo, isDark, cardBg),
                      const SizedBox(height: 14),
                    ],

                    // ── Hero Dribbble Glassmorphic Wallet Card ──────────
                    _buildHeroFintechCard(
                      todayTotal,
                      todayTxns.length,
                      successTxns.length,
                      allTxns.length,
                      isDark,
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 18),

                    // ── Lively Primary Payment CTA Button ───────────────
                    _buildLivelyCollectButton(context)
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), curve: Curves.easeOutBack),

                    const SizedBox(height: 18),

                    // ── Quick Actions Grid / Hub ─────────────────────────
                    _buildQuickActionsHub(context, isDark, cardBg, borderColor)
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 22),

                    // ── Recent Activity Section Header & Filter Pills ───
                    _buildActivityHeader(displayTxns.length, isDark),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Recent Transaction List ──────────────────────────────────
            if (displayTxns.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF20232B) : const Color(0xFFEDF2F7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _filterStatus != null ? 'No matching ${_filterStatus!.name} records' : 'No collections recorded today',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap "COLLECT PAYMENT" to initiate your first MoMo transaction',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final txn = displayTxns[index];
                      return _buildLivelyTxnCard(context, txn, isDark, cardBg, borderColor)
                          .animate()
                          .fadeIn(delay: (60 * (index < 6 ? index : 6)).ms, duration: 350.ms)
                          .slideX(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
                    },
                    childCount: displayTxns.take(12).length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ── Icon-Only Footer Menu Toggle ─────────────────────────────────
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/dashboard'),
    );
  }

  // ── Dribbble Top Bar with Live Terminal Beacon ───────────────────────────
  PreferredSizeWidget _buildDribbbleAppBar(
    BuildContext context,
    dynamic user,
    String? avatar,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: isDark ? const Color(0xFF14161B) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF229ED9), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF229ED9).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'logo.png',
                height: 20,
                width: 20,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const Icon(
                  Icons.point_of_sale_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SwagPay',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const PulsingBeacon(
                    size: 6,
                    color: Color(0xFF10B981),
                    showRipple: false,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Notifications Dropdown with live badge (capped at 99+)
        NotificationDropdownButton(isDark: isDark),
        const SizedBox(width: 8),

        // Account Dropdown Avatar (Uber Eats Style)
        TellerUserAvatarMenu(isDark: isDark),
      ],
    );
  }

  // ── Dribbble Glassmorphic Hero Fintech Card ──────────────────────────────
  Widget _buildHeroFintechCard(
    double total,
    int todayCount,
    int totalSuccess,
    int allTxnsCount,
    bool isDark,
  ) {
    final successRate = allTxnsCount > 0
        ? ((totalSuccess / allTxnsCount) * 100).toStringAsFixed(1)
        : '100.0';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0C4A6E), // Deep Cyan Navy
            Color(0xFF0369A1), // Electric Sky
            Color(0xFF0284C7), // Vivid Cyan
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient decorative glowing orbs (Dribbble signature)
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Header, Live Beacon, and Eye toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PulsingBeacon(size: 6, color: Color(0xFF4ADE80)),
                              SizedBox(width: 6),
                              Text(
                                "TODAY'S COLLECTIONS",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    BouncyTap(
                      onTap: () {
                        setState(() => _isBalanceVisible = !_isBalanceVisible);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Amount Display with Animated Count Up
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (_isBalanceVisible) ...[
                      AnimatedCountUp(
                        value: total,
                        prefix: 'GH₵ ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'GH₵ ••••••',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Mini Sparkline Graph showing transaction pace
                SizedBox(
                  height: 38,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: 6,
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 1.5),
                            FlSpot(1, 2.8),
                            FlSpot(2, 2.1),
                            FlSpot(3, 4.2),
                            FlSpot(4, 3.8),
                            FlSpot(5, 5.2),
                            FlSpot(6, 4.9),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: Colors.white.withValues(alpha: 0.9),
                          barWidth: 2.4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0.0),
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

                const SizedBox(height: 14),

                // Bottom Metrics Pill Row inside Hero Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFFDE047)),
                          const SizedBox(width: 5),
                          Text(
                            '$todayCount transactions',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 12, color: Colors.white.withValues(alpha: 0.2)),
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF4ADE80)),
                          const SizedBox(width: 5),
                          Text(
                            '$successRate% success',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 12, color: Colors.white.withValues(alpha: 0.2)),
                      Row(
                        children: [
                          const Icon(Icons.wifi_tethering_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 5),
                          const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lively Primary Payment CTA Button ────────────────────────────────────
  Widget _buildLivelyCollectButton(BuildContext context) {
    return BouncyTap(
      onTap: () => context.push('/teller/collection'),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF229ED9), // Telegram Azure
              Color(0xFF0284C7), // Deep Cyan
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF229ED9).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'COLLECT PAYMENT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'MOMO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions Grid / Hub ─────────────────────────────────────────────
  Widget _buildQuickActionsHub(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return Row(
      children: [
        _buildActionCard(
          context,
          title: 'History',
          subtitle: 'All txns',
          icon: Icons.receipt_long_rounded,
          gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          onTap: () => context.push('/teller/history'),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
        ),
        const SizedBox(width: 10),
        _buildActionCard(
          context,
          title: 'Offline',
          subtitle: 'Queue',
          icon: Icons.cloud_off_rounded,
          gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          onTap: () => context.push('/teller/offline-queue'),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
        ),
        const SizedBox(width: 10),
        _buildActionCard(
          context,
          title: 'Shift',
          subtitle: 'Summary',
          icon: Icons.analytics_rounded,
          gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
          onTap: () => context.push('/teller/reports'),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Expanded(
      child: BouncyTap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent Activity Section Header & Filter Pills ─────────────────────────
  Widget _buildActivityHeader(int count, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Recent Collections',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262933) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            BouncyTap(
              onTap: () => context.push('/teller/history'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF229ED9),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF229ED9)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterPill('All', null, isDark),
              const SizedBox(width: 8),
              _buildFilterPill('Success', TransactionStatus.success, isDark),
              const SizedBox(width: 8),
              _buildFilterPill('Pending', TransactionStatus.pending, isDark),
              const SizedBox(width: 8),
              _buildFilterPill('Failed', TransactionStatus.failed, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, TransactionStatus? status, bool isDark) {
    final isSelected = _filterStatus == status;
    return BouncyTap(
      onTap: () {
        setState(() => _filterStatus = status);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF229ED9)
              : (isDark ? const Color(0xFF1E2128) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF229ED9)
                : (isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ── Lively Transaction Card Item ─────────────────────────────────────────
  Widget _buildLivelyTxnCard(
    BuildContext context,
    PaymentTransaction txn,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: BouncyTap(
        onTap: () => context.push('/teller/transaction/${txn.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // Carrier Icon with subtle brand glow
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CarrierBrandIcon(
                  network: txn.network,
                  size: 38,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          txn.displayPhone,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeFormat.format(txn.timestamp),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${txn.currency} ${NumberFormat('#,##0.00').format(txn.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  StatusBadge(status: txn.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sync Banner Helper ───────────────────────────────────────────────────
  Widget _buildSyncBanner(PaymentRepository repo, bool isDark, Color cardBg) {
    final err = repo.lastSyncError;
    final isApiError = err is ApiException;
    final hasError = err != null;
    final title = !hasError
        ? 'Connected — terminal online'
        : isApiError && err.statusCode != null
            ? 'Server sync notice (HTTP ${err.statusCode})'
            : 'Terminal operating in local offline mode';
    final detail = !hasError
        ? 'Terminal is online. New MoMo collections will appear here.'
        : '${isApiError ? err.message : '$err'}\n${ApiConfig.baseUrl}';
    final accent = hasError ? const Color(0xFFEF4444) : const Color(0xFF229ED9);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(hasError ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent)),
                const SizedBox(height: 3),
                Text(detail,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retry sync',
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh(),
            icon: Icon(Icons.refresh_rounded, color: accent, size: 20),
          ),
        ],
      ),
    );
  }




}
