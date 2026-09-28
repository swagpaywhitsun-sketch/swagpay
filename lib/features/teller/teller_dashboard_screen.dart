import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/user_avatar_widget.dart';

class TellerDashboardScreen extends ConsumerStatefulWidget {
  const TellerDashboardScreen({super.key});

  @override
  ConsumerState<TellerDashboardScreen> createState() => _TellerDashboardScreenState();
}

class _TellerDashboardScreenState extends ConsumerState<TellerDashboardScreen> {
  int _bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final avatar = ref.watch(userAvatarProvider);
    final repo = ref.watch(paymentRepositoryProvider);
    final txns = repo.getTransactions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final successfulTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final todayTotal = successfulTxns.fold<double>(0.0, (acc, t) => acc + t.amount);

    return Scaffold(
      appBar: AppBar(
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
          // User Avatar with Settings and Logout Dropdown
          PopupMenuButton<String>(
            tooltip: 'Settings & Profile',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            onSelected: (val) {
              if (val == 'settings' || val == 'profile') {
                context.push('/teller/profile');
              } else if (val == 'shift') {
                context.push('/teller/shift');
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
                child: Row(
                  children: [
                    UserAvatarWidget(
                      avatarData: avatar,
                      name: user?.fullName ?? 'Teller',
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Teller Cashier',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            user?.email ?? 'teller@swagpay.com',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Settings & Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Performance Reports'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: UserAvatarWidget(
                avatarData: avatar,
                name: user?.fullName ?? 'Teller',
                radius: 17,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [


              // KPI Card: Full-width Today's Collections (supporting 6-10+ figures comfortably)
              StatCard(
                title: "Today's Total Collections",
                value: 'GH₵ ${NumberFormat('#,##0.00').format(todayTotal)}',
                icon: Icons.payments_rounded,
                accentColor: AppColors.success,
                subtitle: '${successfulTxns.length} successful payment transaction(s) today',
              ),
              const SizedBox(height: 20),

              // Big Primary Action: NEW COLLECTION
              InkWell(
                onTap: () => context.push('/teller/collection'),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.success, AppColors.successDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEW PAYMENT COLLECTION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Tap to enter customer number & collect',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Actions Grid (Simplified without Lookup Customer)
              Row(
                children: [
                  _buildQuickActionTile(
                    context,
                    title: 'History',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    onTap: () => context.push('/teller/history'),
                  ),
                  const SizedBox(width: 10),
                  _buildQuickActionTile(
                    context,
                    title: 'Offline Queue',
                    icon: Icons.cloud_off_rounded,
                    color: AppColors.gold,
                    onTap: () => context.push('/teller/offline-queue'),
                  ),
                  const SizedBox(width: 10),
                  _buildQuickActionTile(
                    context,
                    title: 'My Reports',
                    icon: Icons.bar_chart_rounded,
                    color: AppColors.primaryLight,
                    onTap: () => context.push('/teller/reports'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Collections',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  TextButton(
                    onPressed: () => context.push('/teller/history'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recent Transactions List (Last 5)
              if (txns.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  alignment: Alignment.center,
                  child: const Text('No transactions recorded yet'),
                )
              else
                ...txns.take(5).map((txn) => _buildTransactionCard(context, txn, isDark)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF3E3E3E) : AppColors.border,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomNavIndex,
          backgroundColor: isDark ? const Color(0xFF262626) : Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF707579),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) {
            setState(() => _bottomNavIndex = index);
            if (index == 1) context.push('/teller/history');
            if (index == 2) context.push('/teller/reports');
            if (index == 3) context.push('/teller/profile');
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, PaymentTransaction txn, bool isDark) {
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/teller/transaction/${txn.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: txn.status == TransactionStatus.success
                      ? AppColors.success.withValues(alpha: 0.12)
                      : (txn.status == TransactionStatus.failed
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.gold.withValues(alpha: 0.12)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  txn.status == TransactionStatus.success
                      ? Icons.check_rounded
                      : (txn.status == TransactionStatus.failed ? Icons.close_rounded : Icons.replay_rounded),
                  color: txn.status == TransactionStatus.success
                      ? AppColors.successDark
                      : (txn.status == TransactionStatus.failed ? AppColors.error : AppColors.gold),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${txn.customerNumber} • ${txn.networkDisplay} • ${timeFormat.format(txn.timestamp)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${txn.currency} ${txn.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
}
