import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/widgets/carrier_brand_icon.dart';
import '../../core/widgets/lively_widgets.dart';
import '../../core/widgets/notification_dropdown_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/teller_bottom_nav_bar.dart';
import '../../core/widgets/teller_user_avatar_menu.dart';
import '../../core/widgets/thermal_receipt_card.dart';

class TellerHistoryScreen extends ConsumerStatefulWidget {
  const TellerHistoryScreen({super.key});

  @override
  ConsumerState<TellerHistoryScreen> createState() => _TellerHistoryScreenState();
}

class _TellerHistoryScreenState extends ConsumerState<TellerHistoryScreen> {
  final _searchController = TextEditingController();
  TransactionStatus? _selectedStatus;
  bool _filterOnlyMine = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allTxns = repo.getTransactions();
    final myTxns = repo.getTransactions(onlyMine: true);
    final txns = repo.getTransactions(
      searchQuery: _searchController.text.trim(),
      statusFilter: _selectedStatus,
      onlyMine: _filterOnlyMine,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);

    // Summary stats
    final successCount = allTxns.where((t) => t.status == TransactionStatus.success).length;
    final pendingCount = allTxns.where((t) => t.status == TransactionStatus.pending).length;
    final failedCount = allTxns.where((t) => t.status == TransactionStatus.failed).length;
    final totalAmount = allTxns
        .where((t) => t.status == TransactionStatus.success)
        .fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/teller/dashboard'),
        ),
        title: const Text(
          'Collection History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Collections',
            onPressed: () => ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh(),
          ),
          NotificationDropdownButton(isDark: isDark),
          const SizedBox(width: 8),
          TellerUserAvatarMenu(isDark: isDark),
        ],
      ),
      body: Column(
        children: [

          // ── Dribbble Glassmorphic Summary Banner ────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF1E2128), Color(0xFF181A20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Colors.white, Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL COLLECTED REVENUE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedCountUp(
                          value: totalAmount,
                          prefix: 'GH₵ ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        '${allTxns.length} recorded',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF229ED9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryBadge('$successCount Success', const Color(0xFF10B981), isDark),
                    const SizedBox(width: 8),
                    _summaryBadge('$pendingCount Pending', const Color(0xFFF59E0B), isDark),
                    const SizedBox(width: 8),
                    _summaryBadge('$failedCount Failed', const Color(0xFFEF4444), isDark),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),

          // ── Search & Filter Section ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, reference...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () { _searchController.clear(); setState(() {}); },
                          )
                        : null,
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF229ED9), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _scopeChip('All Collections (${allTxns.length})', false, isDark, cardBg, borderColor),
                      _scopeChip('My Counter (${myTxns.length})', true, isDark, cardBg, borderColor),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 16, color: borderColor),
                      const SizedBox(width: 8),
                      _filterChip('All Status', null, isDark, cardBg, borderColor),
                      _filterChip('Success', TransactionStatus.success, isDark, cardBg, borderColor),
                      _filterChip('Pending', TransactionStatus.pending, isDark, cardBg, borderColor),
                      _filterChip('Failed', TransactionStatus.failed, isDark, cardBg, borderColor),
                      _filterChip('Refunded', TransactionStatus.refunded, isDark, cardBg, borderColor),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Transaction List ────────────────────────────────────
          Expanded(
            child: txns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF)),
                        const SizedBox(height: 12),
                        Text(
                          'No collections match filter',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF303030),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try clearing your search or status filter',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: txns.length,
                    itemBuilder: (context, index) {
                      final txn = txns[index];
                      final prevTxn = index > 0 ? txns[index - 1] : null;
                      final showDateHeader = prevTxn == null ||
                          !_sameDay(txn.timestamp, prevTxn.timestamp);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader) _buildDateHeader(txn.timestamp, isDark),
                          _buildTxnCard(context, txn, isDark, cardBg, borderColor)
                              .animate()
                              .fadeIn(duration: 220.ms, delay: (index * 20).clamp(0, 240).ms)
                              .slideY(begin: 0.04, end: 0),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/history'),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateHeader(DateTime date, bool isDark) {
    final now = DateTime.now();
    final isToday = _sameDay(date, now);
    final isYesterday = _sameDay(date, now.subtract(const Duration(days: 1)));
    final label = isToday ? 'Today' : isYesterday ? 'Yesterday' : DateFormat('EEEE, dd MMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BouncyTap(
        onTap: () => context.push('/teller/transaction/${txn.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Carrier brand crisp badge
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CarrierBrandIcon(network: txn.network, size: 36),
              ),
              const SizedBox(width: 12),
              // Customer & reference info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${txn.displayPhone} · ${txn.networkDisplay}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      txn.reference,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        letterSpacing: 0.3,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Amount + status badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GH₵ ${NumberFormat('#,##0.00').format(txn.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeFormat.format(txn.timestamp),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

  // ── Clean Filter Chip Without Emoji ─────────────────────────────────────
  Widget _scopeChip(
    String label,
    bool onlyMine,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    final isSelected = _filterOnlyMine == onlyMine;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: BouncyTap(
        onTap: () => setState(() => _filterOnlyMine = onlyMine),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0E7490)
                : (isDark ? const Color(0xFF1E2128) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0E7490)
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
      ),
    );
  }

  Widget _filterChip(
    String label,
    TransactionStatus? status,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    final isSelected = _selectedStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: BouncyTap(
        onTap: () => setState(() => _selectedStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
      ),
    );
  }

  Widget _summaryBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final txn = repo.getTransactionById(transactionId);

    if (txn == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/teller/dashboard'),
          ),
          title: const Text('Transaction Detail'),
        ),
        body: const Center(child: Text('Transaction record not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(txn.reference),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ThermalReceiptCard(transaction: txn)
                .animate()
                .fadeIn(duration: 350.ms)
                .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/teller/dashboard'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to Dashboard'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/history'),
    );
  }
}
