import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_thin_footer.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/thermal_receipt_card.dart';

class TellerHistoryScreen extends ConsumerStatefulWidget {
  const TellerHistoryScreen({super.key});

  @override
  ConsumerState<TellerHistoryScreen> createState() => _TellerHistoryScreenState();
}

class _TellerHistoryScreenState extends ConsumerState<TellerHistoryScreen> {
  final _searchController = TextEditingController();
  TransactionStatus? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allTxns = repo.getTransactions();
    final txns = repo.getTransactions(
      searchQuery: _searchController.text.trim(),
      statusFilter: _selectedStatus,
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
            onPressed: () => ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh(),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Compact Summary KPI Banner (Reduced Size) ────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
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
                          'All Collections',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF303030),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${allTxns.length} total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF303030),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _summaryBadge('$successCount Success', const Color(0xFF229ED9), isDark),
                    const SizedBox(width: 8),
                    _summaryBadge('$pendingCount Pending', const Color(0xFFD97706), isDark),
                    const SizedBox(width: 8),
                    _summaryBadge('$failedCount Failed', const Color(0xFFDC2626), isDark),
                  ],
                ),
              ],
            ),
          ),

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
                      _filterChip('All', null, isDark, cardBg, borderColor),
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
                          _buildTxnCard(context, txn, isDark, cardBg, borderColor),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const AppThinFooter(),
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
              // Clean icon box
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_outlined,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                  size: 18,
                ),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF303030),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${txn.displayPhone} · ${txn.networkDisplay}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      txn.reference,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF),
                        letterSpacing: 0.3,
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
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeFormat.format(txn.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF229ED9)
                : cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF229ED9) : borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151)),
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

  void _showRefundDialog(BuildContext context, WidgetRef ref, PaymentTransaction txn) {
    final reasonController = TextEditingController(text: 'Customer requested cancellation');
    final notesController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.undo_rounded, color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request Refund / Void', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Requires Admin approval', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(txn.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(txn.reference, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                  Text('${txn.currency} ${txn.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.error)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason for Void / Refund *', prefixIcon: Icon(Icons.edit_note_rounded), alignLabelWithHint: true),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Additional Notes (optional)', prefixIcon: Icon(Icons.notes_rounded), alignLabelWithHint: true),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final auth = ref.read(authProvider);
                      await ref.read(paymentRepositoryProvider).submitRefundRequest(
                        transactionId: txn.id,
                        reason: reasonController.text.trim(),
                        notes: notesController.text.trim(),
                        tellerId: auth.currentUser?.id ?? 'TEL-001',
                        tellerName: auth.currentUser?.fullName ?? 'Teller',
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Refund request submitted to Admin for approval'),
                            backgroundColor: AppColors.gold));
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Submit Refund Request', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
}

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
            ThermalReceiptCard(transaction: txn),
            const SizedBox(height: 20),

            if (txn.status == TransactionStatus.success) ...[
              OutlinedButton.icon(
                onPressed: () => _showRefundDialog(context, ref, txn),
                icon: const Icon(Icons.undo_rounded, color: AppColors.error),
                label: const Text('Request Void / Refund Reversal', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
            ],

            ElevatedButton.icon(
              onPressed: () => context.go('/teller/dashboard'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }
}
