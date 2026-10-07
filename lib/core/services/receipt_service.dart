import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart';

class ReceiptService {
  static String generateTextReceipt(PaymentTransaction txn) {
    final dateFormat = DateFormat('dd-MMM-yyyy hh:mm a');
    final formattedDate = dateFormat.format(txn.timestamp);

    String statusStr = 'APPROVED';
    String amountLabel = 'TOTAL PAID';
    if (txn.id.startsWith('tx_off_') || txn.reference.startsWith('OFF-')) {
      statusStr = 'OFFLINE QUEUED (PENDING SYNC)';
      amountLabel = 'QUEUED AMOUNT (PENDING)';
    } else {
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
       POWERED BY WHITSUN
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

  /// Generates a high-quality 58mm/80mm PDF receipt formatted for POS thermal printers and AirPrint
  static Future<Uint8List> generatePdfReceipt(PaymentTransaction txn, PdfPageFormat format) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MMM-yyyy hh:mm a');
    final formattedDate = dateFormat.format(txn.timestamp);

    final isSuccess = txn.status == TransactionStatus.success;
    final isOffline = txn.id.startsWith('tx_off_') || txn.reference.startsWith('OFF-') || txn.status == TransactionStatus.pending;

    String statusText = 'APPROVED / PAID';
    if (isOffline) {
      statusText = 'OFFLINE QUEUED (PENDING SYNC)';
    } else if (txn.status == TransactionStatus.failed) {
      statusText = 'PAYMENT DECLINED';
    } else if (txn.status == TransactionStatus.pending) {
      statusText = 'PAYMENT PENDING';
    }

    // POS Roll standard width (58mm or 80mm roll format)
    final rollFormat = PdfPageFormat(
      72 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: rollFormat,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'SWAGPAY POS',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'OFFICIAL PAYMENT RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Terminal: ${txn.posId} · Cashier: ${txn.tellerName}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.Text(
                        formattedDate,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Transaction Details
                _buildPdfRow('Customer Name', txn.customerName, isBold: true),
                _buildPdfRow('Phone Number', txn.displayPhone),
                _buildPdfRow('Network', txn.networkDisplay),
                _buildPdfRow('Reference', txn.reference),
                if (txn.receiptNumber != null && txn.receiptNumber!.isNotEmpty)
                  _buildPdfRow('Receipt No', txn.receiptNumber!),
                if (txn.branch != null && txn.branch!.isNotEmpty)
                  _buildPdfRow('Branch', txn.branch!),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Amount Section
                _buildPdfRow('Subtotal', '${txn.currency} ${txn.amount.toStringAsFixed(2)}'),
                _buildPdfRow('Fee', '${txn.currency} 0.00'),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL PAID',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${txn.currency} ${txn.amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: isSuccess ? PdfColors.grey200 : PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      statusText,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 6),

                // Simulated Barcode / Ref
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        height: 24,
                        width: 160,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            30,
                            (index) => pw.Container(
                              width: (index % 4 == 0) ? 2.5 : ((index % 2 == 0) ? 1.5 : 0.8),
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        txn.reference,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'THANK YOU FOR TRANSACTING',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'KEEP THIS RECEIPT FOR YOUR RECORDS',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'POWERED BY WHITSUN',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildPdfRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Triggers the native OS print layout / POS thermal printer dialog
  static Future<void> printReceipt(BuildContext context, PaymentTransaction txn) async {
    try {
      await Printing.layoutPdf(
        name: 'SwagPay-Receipt-${txn.reference}',
        onLayout: (PdfPageFormat format) async => generatePdfReceipt(txn, format),
      );
    } catch (e) {
      if (context.mounted) {
        // Fallback to text copy or modal if system printing fails
        showPrintModal(context, txn);
      }
    }
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
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await printReceipt(context, txn);
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
