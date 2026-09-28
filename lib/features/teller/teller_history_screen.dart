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

  Color _statusColor(TransactionStatus? s) {
    if (s == TransactionStatus.success) return AppColors.success;
    if (s == TransactionStatus.failed) return AppColors.error;
    if (s == TransactionStatus.refunded) return AppColors.primaryLight;
    return AppColors.gold;
  }

  IconData _statusIcon(TransactionStatus s) {
    if (s == TransactionStatus.success) return Icons.check_circle_rounded;
    if (s == TransactionStatus.failed) return Icons.cancel_rounded;
    if (s == TransactionStatus.refunded) return Icons.undo_rounded;
    return Icons.hourglass_top_rounded;
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
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF4F6FA);

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
        // Back button goes to dashboard, not the previous page
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/teller/dashboard'),
        ),
        title: const Text('Collection History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh(),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Summary Header ─────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('All Collections', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${allTxns.length} total', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'GH₵ ${NumberFormat('#,##0.00').format(totalAmount)}',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryPill('$successCount Success', AppColors.success),
                    const SizedBox(width: 8),
                    _summaryPill('$pendingCount Pending', AppColors.gold),
                    const SizedBox(width: 8),
                    _summaryPill('$failedCount Failed', AppColors.error),
                  ],
                ),
              ],
            ),
          ),

          // ── Search & Filter ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, reference...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () { _searchController.clear(); setState(() {}); },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', null, isDark),
                      _filterChip('✓ Success', TransactionStatus.success, isDark),
                      _filterChip('⏳ Pending', TransactionStatus.pending, isDark),
                      _filterChip('✖ Failed', TransactionStatus.failed, isDark),
                      _filterChip('↩ Refunded', TransactionStatus.refunded, isDark),
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
                        Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No transactions found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        Text('Try adjusting your search or filter', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: txns.length,
                    itemBuilder: (context, index) {
                      // Group by date
                      final txn = txns[index];
                      final prevTxn = index > 0 ? txns[index - 1] : null;
                      final showDateHeader = prevTxn == null ||
                          !_sameDay(txn.timestamp, prevTxn.timestamp);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader) _buildDateHeader(txn.timestamp, isDark),
                          _buildTxnCard(context, txn, isDark),
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
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      ),
    );
  }

  Widget _buildTxnCard(BuildContext context, PaymentTransaction txn, bool isDark) {
    final timeFormat = DateFormat('hh:mm a');
    final statusColor = _statusColor(txn.status);
    final statusIco = _statusIcon(txn.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: () => context.push('/teller/transaction/${txn.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Status icon circle
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(statusIco, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              // Middle info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(txn.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${txn.customerNumber} · ${txn.networkDisplay}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      txn.reference,
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Right — amount + time + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GH₵ ${NumberFormat('#,##0.00').format(txn.amount)}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: statusColor),
                  ),
                  const SizedBox(height: 3),
                  Text(timeFormat.format(txn.timestamp),
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
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

  Widget _filterChip(String label, TransactionStatus? status, bool isDark) {
    final isSelected = _selectedStatus == status;
    final color = _statusColor(status);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : (isDark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.border)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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
      builder: (ctx) => Padding(
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
