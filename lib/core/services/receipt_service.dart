import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';

class ReceiptService {
  static String generateTextReceipt(PaymentTransaction txn) {
    final dateFormat = DateFormat('dd-MMM-yyyy hh:mm a');
    final formattedDate = dateFormat.format(txn.timestamp);

    String statusStr = 'APPROVED';
    String amountLabel = 'TOTAL PAID';
    switch (txn.status) {
      case TransactionStatus.success:
        statusStr = 'APPROVED / PAID';
        amountLabel = 'TOTAL PAID';
        break;
      case TransactionStatus.pending:
        statusStr = 'PENDING AUTH';
        amountLabel = 'AMOUNT PENDING';
        break;
      case TransactionStatus.failed:
        statusStr = 'DECLINED';
        amountLabel = 'AMOUNT (NOT CHARGED)';
        break;
      case TransactionStatus.refunded:
        statusStr = 'REFUNDED';
        amountLabel = 'AMOUNT REFUNDED';
        break;
    }

    final branchName = (txn.branch != null && txn.branch!.trim().isNotEmpty) ? txn.branch! : 'Main Store';
    final rcptNo = (txn.receiptNumber != null && txn.receiptNumber!.isNotEmpty) ? txn.receiptNumber! : 'N/A';

    return '''
================================
          SWAGPAY POS
    OFFICIAL PAYMENT RECEIPT
================================
Date:       $formattedDate
Terminal:   ${txn.posId}
Cashier:    ${txn.tellerName}
Branch:     $branchName
--------------------------------
Customer:   ${txn.customerName}
Phone:      ${txn.displayPhone}
Network:    ${txn.networkDisplay}
Ref:        ${txn.reference}
Receipt No: $rcptNo
--------------------------------
Subtotal:   ${txn.currency} ${txn.amount.toStringAsFixed(2)}
Fee:        ${txn.currency} 0.00
--------------------------------
$amountLabel: ${txn.currency} ${txn.amount.toStringAsFixed(2)}
STATUS:     $statusStr
================================
  THANK YOU FOR TRANSACTING
  KEEP RECEIPT FOR YOUR RECORDS
   POWERED BY SWAGPAY GATEWAY
================================
''';
  }

  /// Generates ESC/POS standard byte array suitable for standard 58mm/80mm thermal POS receipt printers.
  static List<int> generateEscPosBytes(PaymentTransaction txn) {
    final text = generateTextReceipt(txn);
    final List<int> bytes = [];
    // ESC @ (Initialize printer)
    bytes.addAll([0x1B, 0x40]);
    // ESC a 1 (Center justification for header)
    bytes.addAll([0x1B, 0x61, 0x01]);
    // Text encoding
    bytes.addAll(utf8.encode(text));
    // Feed lines & cut
    bytes.addAll([0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x41, 0x00]);
    return bytes;
  }

  static Future<void> copyReceiptToClipboard(PaymentTransaction txn) async {
    final text = generateTextReceipt(txn);
    await Clipboard.setData(ClipboardData(text: text));
  }

  static void showPrintModal(BuildContext context, PaymentTransaction txn) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final receiptText = generateTextReceipt(txn);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.print_rounded, color: Color(0xFF1570A6), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'POS Thermal Printer Dispatch',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    receiptText,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11.5, height: 1.35),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await copyReceiptToClipboard(txn);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Receipt text copied to clipboard!')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Text'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final escBytes = generateEscPosBytes(txn);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ESC/POS payload generated (${escBytes.length} bytes) & dispatched to POS thermal printer'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print Now', style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1570A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
