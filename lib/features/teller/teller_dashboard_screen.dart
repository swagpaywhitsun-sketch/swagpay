import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
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
    final pendingTxns = txns.where((t) => t.status == TransactionStatus.pending).toList();
    final failedTxns = txns.where((t) => t.status == TransactionStatus.failed).toList();
    final todayTotal = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final pendingTotal = pendingTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF4F6FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SwagPay',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            elevation: 8,
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
              PopupMenuItem<String>(
                enabled: false,
                height: 72,
                child: Row(
                  children: [
                    UserAvatarWidget(avatarData: avatar, name: user?.fullName ?? 'Teller', radius: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(user?.fullName ?? 'Teller Cashier',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(user?.email ?? 'teller@swagpay.com',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                            child: Text(user?.roleDisplay ?? 'Teller',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              _menuItem('settings', Icons.settings_outlined, 'Settings', AppColors.primary),
              _menuItem('reports', Icons.analytics_outlined, 'Reports', AppColors.success),
              PopupMenuItem<String>(
                value: 'theme',
                height: 46,
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                      child: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 17, color: AppColors.gold)),
                  const SizedBox(width: 12),
                  Text(isDark ? 'Light Mode' : 'Dark Mode', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
              ),
              const PopupMenuDivider(),
              _menuItem('logout', Icons.logout_rounded, 'Logout', AppColors.error, isDestructive: true),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: UserAvatarWidget(avatarData: avatar, name: user?.fullName ?? 'Teller', radius: 17),
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

                    // ── Hero Collection Card ─────────────────────────────
                    _buildHeroCard(todayTotal, successTxns.length, isDark),
                    const SizedBox(height: 12),

                    // ── Stats Row ────────────────────────────────────────
                    Row(
                      children: [
                        _buildMiniStat('Pending', pendingTxns.length, pendingTotal, AppColors.gold, Icons.hourglass_top_rounded, isDark),
                        const SizedBox(width: 10),
                        _buildMiniStat('Failed', failedTxns.length, 0, AppColors.error, Icons.cancel_outlined, isDark),
                        const SizedBox(width: 10),
                        _buildMiniStat('Total Txns', txns.length, 0, AppColors.primaryLight, Icons.receipt_long_rounded, isDark),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── PAYMENT Button ───────────────────────────────────
                    _buildPaymentButton(context),
                    const SizedBox(height: 14),

                    // ── Quick Actions ────────────────────────────────────
                    Row(
                      children: [
                        _buildQuickAction(context, 'History', Icons.receipt_long_rounded, AppColors.primary, () => context.push('/teller/history')),
                        const SizedBox(width: 10),
                        _buildQuickAction(context, 'Offline Queue', Icons.cloud_off_rounded, AppColors.gold, () => context.push('/teller/offline-queue')),
                        const SizedBox(width: 10),
                        _buildQuickAction(context, 'My Reports', Icons.bar_chart_rounded, AppColors.primaryLight, () => context.push('/teller/reports')),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Recent Collections Header ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Collections', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        TextButton.icon(
                          onPressed: () => context.push('/teller/history'),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Transaction list ─────────────────────────────────────────
            if (txns.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No transactions yet', style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTxnCard(context, txns[index], isDark),
                    childCount: txns.take(8).length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ── Bottom Nav — always stays on Dashboard (index 0) ──────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF3E3E3E) : AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: 0, // always 0 — sub-pages are pushed, not tab-switched
          backgroundColor: isDark ? const Color(0xFF262626) : Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF707579),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) {
            // Never mutate local index — sub-pages are full push routes
            if (index == 1) context.push('/teller/history');
            if (index == 2) context.push('/teller/reports');
            if (index == 3) context.push('/teller/profile');
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  // ── Hero collection card ─────────────────────────────────────────────────
  Widget _buildHeroCard(double total, int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Collections", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: Text('$count txns', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'GH₵ ${NumberFormat('#,##0.00').format(total)}',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Successful MoMo collections', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Mini stat cards ──────────────────────────────────────────────────────
  Widget _buildMiniStat(String label, int count, double amount, Color color, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── PAYMENT action button ────────────────────────────────────────────────
  Widget _buildPaymentButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/teller/collection'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.success, AppColors.successDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PAYMENT', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                Text('Collect MoMo payment', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick action tiles ───────────────────────────────────────────────────
  Widget _buildQuickAction(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Transaction card ─────────────────────────────────────────────────────
  Widget _buildTxnCard(BuildContext context, PaymentTransaction txn, bool isDark) {
    final timeFormat = DateFormat('hh:mm a');

    final statusColor = txn.status == TransactionStatus.success
        ? AppColors.success
        : txn.status == TransactionStatus.failed
            ? AppColors.error
            : AppColors.gold;

    final statusIcon = txn.status == TransactionStatus.success
        ? Icons.check_rounded
        : txn.status == TransactionStatus.failed
            ? Icons.close_rounded
            : Icons.hourglass_top_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/teller/transaction/${txn.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(txn.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${txn.customerNumber} · ${txn.networkDisplay} · ${timeFormat.format(txn.timestamp)}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${txn.currency} ${NumberFormat('#,##0.00').format(txn.amount)}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: statusColor)),
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

  // ── Helper: menu item ────────────────────────────────────────────────────
  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, Color color, {bool isDestructive = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 46,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600, fontSize: 14, color: isDestructive ? color : null)),
      ]),
    );
  }
}
