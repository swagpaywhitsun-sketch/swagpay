import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/receipt_service.dart';
import '../theme/app_colors.dart';

class ThermalReceiptCard extends StatelessWidget {
  final PaymentTransaction transaction;
  final VoidCallback? onPrint;

  const ThermalReceiptCard({
    super.key,
    required this.transaction,
    this.onPrint,
  });

  Color get _statusColor {
    switch (transaction.status) {
      case TransactionStatus.success:
        return AppColors.success;
      case TransactionStatus.pending:
        return AppColors.gold;
      case TransactionStatus.failed:
        return AppColors.error;
      case TransactionStatus.refunded:
        return AppColors.primaryLight;
    }
  }

  String get _statusLabel {
    switch (transaction.status) {
      case TransactionStatus.success:
        return 'PAYMENT SUCCESSFUL';
      case TransactionStatus.pending:
        return 'PAYMENT PENDING';
      case TransactionStatus.failed:
        return 'PAYMENT DECLINED';
      case TransactionStatus.refunded:
        return 'PAYMENT REFUNDED';
    }
  }

  String get _amountLabel {
    switch (transaction.status) {
      case TransactionStatus.success:
        return 'TOTAL PAID';
      case TransactionStatus.pending:
        return 'AMOUNT PENDING';
      case TransactionStatus.failed:
        return 'AMOUNT (NOT CHARGED)';
      case TransactionStatus.refunded:
        return 'AMOUNT REFUNDED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isPending = transaction.status == TransactionStatus.pending;
    final isFailed = transaction.status == TransactionStatus.failed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Receipt Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'logo.png',
                          width: 26,
                          height: 26,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.receipt_long_rounded, color: Color(0xFF1E293B), size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'SWAG RECEIPT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dateFormat.format(transaction.timestamp),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Status Banner — only shown for non-success transactions
          if (isPending || isFailed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: _statusColor.withValues(alpha: 0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPending ? Icons.hourglass_top_rounded : Icons.cancel_outlined,
                    color: _statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _statusColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

          // Dashed Divider / Cut Line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: List.generate(
                30,
                (i) => Expanded(
                  child: Container(
                    height: 1.5,
                    color: i % 2 == 0 ? Colors.grey.shade300 : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),

          // Body Details
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReceiptRow('Customer Name', transaction.customerName),
                _buildReceiptRow('Customer Number', transaction.customerNumber),
                _buildReceiptRow('Network', transaction.networkDisplay),
                _buildReceiptRow('Reference', transaction.reference),
                if (transaction.receiptNumber != null)
                  _buildReceiptRow('Receipt No', transaction.receiptNumber!),
                _buildReceiptRow('Terminal / POS', transaction.posId),
                _buildReceiptRow('Teller', transaction.tellerName),
                const SizedBox(height: 12),
                const Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                // Amount section — status-aware label and color
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _amountLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                    Text(
                      '${transaction.currency} ${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),

                // Status pill
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _statusColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // Simulated Barcode & Reference Section
                Center(
                  child: Column(
                    children: [
                      Container(
                        height: 38,
                        width: 240,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            36,
                            (index) => Container(
                              width: (index % 4 == 0) ? 3 : ((index % 2 == 0) ? 2 : 1),
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      // Solid crisp black line sitting directly above the reference
                      Container(
                        height: 2,
                        width: 240,
                        color: Colors.black,
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 240,
                        child: Text(
                          transaction.reference,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer message
                const SizedBox(height: 16),
                const Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'Thank You For Your Business',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'System developed by Whitsun',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ReceiptService.copyReceiptToClipboard(transaction);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Receipt copied to clipboard!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPrint ?? () => ReceiptService.showPrintModal(context, transaction),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1570A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
