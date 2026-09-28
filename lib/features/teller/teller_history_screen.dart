import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
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
    final txns = repo.getTransactions(
      searchQuery: _searchController.text.trim(),
      statusFilter: _selectedStatus,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by Ref, Customer phone, name...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Statuses', null),
                      _buildFilterChip('Success', TransactionStatus.success),
                      _buildFilterChip('Pending', TransactionStatus.pending),
                      _buildFilterChip('Failed', TransactionStatus.failed),
                      _buildFilterChip('Refunded', TransactionStatus.refunded),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transaction list
          Expanded(
            child: txns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No collections match your filter',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: txns.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final txn = txns[index];
                      return _buildHistoryItem(context, txn, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, TransactionStatus? status) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => setState(() => _selectedStatus = status),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, PaymentTransaction txn, bool isDark) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Card(
      child: ListTile(
        onTap: () => context.push('/teller/transaction/${txn.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
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
                ? Icons.check_circle_outline_rounded
                : (txn.status == TransactionStatus.failed ? Icons.highlight_off_rounded : Icons.history_rounded),
            color: txn.status == TransactionStatus.success
                ? AppColors.successDark
                : (txn.status == TransactionStatus.failed ? AppColors.error : AppColors.gold),
          ),
        ),
        title: Text(
          txn.customerName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${txn.reference} • ${dateFormat.format(txn.timestamp)}\n${txn.networkDisplay}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }
}

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  void _showRefundDialog(BuildContext context, WidgetRef ref, PaymentTransaction txn) {
    final reasonController = TextEditingController(text: 'Customer requested cancellation');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Refund / Void'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submitting refund request for ${txn.reference} (${txn.currency}${txn.amount.toStringAsFixed(2)}). Admin approval is required.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason for Void / Refund *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Additional Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = ref.read(authProvider);
              await ref.read(paymentRepositoryProvider).submitRefundRequest(
                    transactionId: txn.id,
                    reason: reasonController.text.trim(),
                    notes: notesController.text.trim(),
                    tellerId: auth.currentUser?.id ?? 'TEL-001',
                    tellerName: auth.currentUser?.fullName ?? 'John Doe',
                  );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refund request submitted to Admin for approval'),
                    backgroundColor: AppColors.gold,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final txn = repo.getTransactionById(transactionId);

    if (txn == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Detail')),
        body: const Center(child: Text('Transaction record not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(txn.reference),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ThermalReceiptCard(transaction: txn),
            const SizedBox(height: 24),

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
    );
  }
}
