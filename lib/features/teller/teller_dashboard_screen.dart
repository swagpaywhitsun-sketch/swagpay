import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/services/payment_repository.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/user_avatar_widget.dart';

class TellerDashboardScreen extends ConsumerStatefulWidget {
  const TellerDashboardScreen({super.key});

  @override
  ConsumerState<TellerDashboardScreen> createState() => _TellerDashboardScreenState();
}

class _TellerDashboardScreenState extends ConsumerState<TellerDashboardScreen> {

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
    final txns = repo.getTransactions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final successTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final now = DateTime.now();
    final todayTxns = successTxns.where((t) =>
        t.timestamp.year == now.year && t.timestamp.month == now.month && t.timestamp.day == now.day).toList();
    final todayTotal = todayTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'logo.png',
                height: 28,
                width: 28,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.point_of_sale_outlined, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SwagPay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // ── Account Dropdown ────────────────────────────────────
          PopupMenuButton<String>(
            tooltip: 'Account Menu',
            offset: const Offset(0, 52),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor),
            ),
            color: cardBg,
            elevation: 10,
            onSelected: (val) {
              if (val == 'settings') {
                context.push('/teller/profile');
              } else if (val == 'reports') {
                context.push('/teller/reports');
              } else if (val == 'theme') {
                ref.read(themeModeProvider.notifier).toggleTheme();
              } else if (val == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/teller/login');
              }
            },
            itemBuilder: (ctx) => [
              // Branded profile header
              PopupMenuItem<String>(
                enabled: false,
                height: 92,
                child: SizedBox(
                  width: 254,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF229ED9), Color(0xFF1B82B3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                        ),
                        child: UserAvatarWidget(
                          avatarData: avatar,
                          name: user?.fullName ?? 'Cashier',
                          radius: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.fullName ?? 'Cashier',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? 'cashier@swagpay.com',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user?.roleDisplay ?? 'Cashier',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
              const PopupMenuDivider(height: 1),
              _buildMenuItem('settings', Icons.settings_outlined, 'Account Settings', isDark),
              _buildMenuItem('reports', Icons.analytics_outlined, 'Shift Reports', isDark),
              PopupMenuItem<String>(
                value: 'theme',
                height: 42,
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 18,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isDark ? 'Light Theme' : 'Dark Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF303030),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              _buildMenuItem('logout', Icons.logout_rounded, 'Log Out', isDark, isDestructive: true),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: UserAvatarWidget(
                avatarData: avatar,
                name: user?.fullName ?? 'Cashier',
                radius: 16,
              ),
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (repo.lastSyncError != null) ...[
                      _buildSyncBanner(repo, isDark, cardBg),
                      const SizedBox(height: 14),
                    ],

                    // ── Compact Shopify KPI Card (Size Reduced) ─────────────
                    _buildCompactKpiCard(todayTotal, todayTxns.length, isDark, cardBg, borderColor),
                    const SizedBox(height: 14),

                    // ── Main Payment Button (Shopify Action Bar) ────────────
                    _buildPaymentButton(context),
                    const SizedBox(height: 14),

                    // ── Quick Navigation Actions ───────────────────────────
                    Row(
                      children: [
                        _buildQuickAction(
                          context,
                          'History',
                          Icons.receipt_long_outlined,
                          () => context.push('/teller/history'),
                          isDark, cardBg, borderColor,
                        ),
                        const SizedBox(width: 10),
                        _buildQuickAction(
                          context,
                          'Offline Queue',
                          Icons.cloud_off_outlined,
                          () => context.push('/teller/offline-queue'),
                          isDark, cardBg, borderColor,
                        ),
                        const SizedBox(width: 10),
                        _buildQuickAction(
                          context,
                          'Reports',
                          Icons.bar_chart_outlined,
                          () => context.push('/teller/reports'),
                          isDark, cardBg, borderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Recent Collections Header ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Collections',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF303030),
                            letterSpacing: -0.2,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push('/teller/history'),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                          label: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Recent Transaction list ──────────────────────────────────
            if (txns.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF)),
                      const SizedBox(height: 12),
                      Text(
                        'No transactions recorded',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTxnCard(context, txns[index], isDark, cardBg, borderColor),
                    childCount: txns.take(8).length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ── Bottom Nav ───────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          backgroundColor: cardBg,
          selectedItemColor: const Color(0xFF229ED9),
          unselectedItemColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) {
            if (index == 1) context.push('/teller/history');
            if (index == 2) context.push('/teller/reports');
            if (index == 3) context.push('/teller/profile');
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_outlined), activeIcon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics_rounded), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }



  // ── Reduced Compact KPI Card (Shopify Polaris style) ─────────────────────
  Widget _buildSyncBanner(PaymentRepository repo, bool isDark, Color cardBg) {
    final err = repo.lastSyncError;
    final isApiError = err is ApiException;
    final hasError = err != null;
    final title = !hasError
        ? 'Connected — no collections yet'
        : isApiError && err.statusCode != null
            ? 'Server error (HTTP ${err.statusCode})'
            : 'Cannot reach the server';
    final detail = !hasError
        ? 'Terminal is online. New MoMo collections will appear here.'
        : '${isApiError ? err.message : '$err'}\n${ApiConfig.baseUrl}';
    final accent = hasError ? const Color(0xFFE53935) : const Color(0xFF229ED9);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(hasError ? Icons.wifi_tethering_error_rounded : Icons.cloud_done_outlined,
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
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
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

  Widget _buildCompactKpiCard(double total, int count, bool isDark, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    "Today's Collections",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'GH₵ ${NumberFormat('#,##0.00').format(total)}',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF303030),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 14,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count txns',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF303030),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PAYMENT Primary Action Button ─────────────────────────────────────────
  Widget _buildPaymentButton(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () => context.push('/teller/collection'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF229ED9), // Shopify Dark Emerald
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 20),
            SizedBox(width: 10),
            Text(
              'COLLECT PAYMENT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick action navigation tile ─────────────────────────────────────────
  Widget _buildQuickAction(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF303030),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Transaction Card Item ────────────────────────────────────────────────
  Widget _buildTxnCard(
    BuildContext context,
    PaymentTransaction txn,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () => context.push('/teller/transaction/${txn.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Clean line icon container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                  size: 18,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF303030),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${txn.displayPhone} · ${txn.networkDisplay} · ${timeFormat.format(txn.timestamp)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${txn.currency} ${NumberFormat('#,##0.00').format(txn.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: txn.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: Popup Menu Item ──────────────────────────────────────────────
  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String label,
    bool isDark, {
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? const Color(0xFFDC2626)
        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563));

    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
              color: isDestructive
                  ? const Color(0xFFDC2626)
                  : (isDark ? Colors.white : const Color(0xFF303030)),
            ),
          ),
        ],
      ),
    );
  }
}
