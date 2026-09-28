import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/models/user.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';

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
    final repo = ref.watch(paymentRepositoryProvider);
    final txns = repo.getTransactions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final successfulTxns = txns.where((t) => t.status == TransactionStatus.success).toList();
    final todayTotal = successfulTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    final successRate = txns.isEmpty ? 100 : ((successfulTxns.length / txns.length) * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${user?.fullName ?? 'Teller'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${user?.assignedPos.firstOrNull ?? 'POS-01'} • Online',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Role switcher button (for quick preview of Admin POS Web vs Mobile Teller)
          TextButton.icon(
            onPressed: () {
              ref.read(authProvider.notifier).switchRoleForDemo(UserRole.admin);
              context.go('/admin/dashboard');
            },
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.amber, size: 18),
            label: const Text(
              'Admin Web',
              style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push('/teller/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
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
              // Shift Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE SHIFT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Counter: ${user?.branch ?? 'Victoria Island'}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/teller/shift'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Shift Status', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KPI Cards
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: "Today's Collections",
                      value: 'GH₵ ${NumberFormat('#,##0.00').format(todayTotal)}',
                      icon: Icons.payments_rounded,
                      accentColor: AppColors.success,
                      subtitle: '${successfulTxns.length} successful',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Success Rate',
                      value: '$successRate%',
                      icon: Icons.speed_rounded,
                      accentColor: AppColors.gold,
                      subtitle: '${txns.length} total txns',
                    ),
                  ),
                ],
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

              // Quick Actions Grid
              Row(
                children: [
                  _buildQuickActionTile(
                    context,
                    title: 'Lookup Customer',
                    icon: Icons.person_search_rounded,
                    color: AppColors.info,
                    onTap: () => context.push('/teller/customer-lookup'),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() => _bottomNavIndex = index);
          if (index == 1) context.push('/teller/history');
          if (index == 2) context.push('/teller/reports');
          if (index == 3) context.push('/teller/shift');
          if (index == 4) context.push('/teller/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Shift'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Profile'),
        ],
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
