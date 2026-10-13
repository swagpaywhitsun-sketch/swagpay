import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart';

class ReceiptService {
  static String _centerText(String text, int width) {
    if (text.length >= width) return text;
    final leftPadding = (width - text.length) ~/ 2;
    return ' ' * leftPadding + text;
  }

  static String generateTextReceipt(PaymentTransaction txn) {
    final dateFormat = DateFormat('dd-MMM-yyyy hh:mm a');
    final formattedDate = dateFormat.format(txn.timestamp);

    String statusStr = 'Approved by PIN';
    if (txn.id.startsWith('tx_off_') || txn.reference.startsWith('OFF-')) {
      statusStr = 'OFFLINE QUEUED (PENDING SYNC)';
    } else {
      switch (txn.status) {
        case TransactionStatus.success:
          statusStr = 'Approved by PIN';
          break;
        case TransactionStatus.pending:
          statusStr = 'PENDING AUTH';
          break;
        case TransactionStatus.failed:
          statusStr = 'DECLINED';
          break;
        case TransactionStatus.refunded:
          statusStr = 'REFUNDED';
          break;
      }
    }

    final isUniversal = txn.posId.isEmpty ||
        txn.posId == 'ANY_POS' ||
        txn.posId.startsWith('pos_') ||
        txn.posId.toLowerCase().contains('universal');
    final displayPos = isUniversal ? 'Universal POS' : txn.posId;
    final rcptNo = (txn.receiptNumber != null && txn.receiptNumber!.isNotEmpty) ? txn.receiptNumber! : 'N/A';

    return '''
================================
${_centerText(txn.effectiveMerchantName.toUpperCase(), 32)}
${_centerText(txn.effectiveMerchantAddress, 32)}
${_centerText('Location: ${txn.effectiveShopLocation}', 32)}
================================
${_centerText('OFFICIAL PAYMENT RECEIPT', 32)}
--------------------------------
Date:       $formattedDate
Terminal:   $displayPos
Cashier:    ${txn.tellerName}
--------------------------------
Customer:   ${txn.customerName}
Network:    ${txn.networkDisplay}
Receipt No: $rcptNo
--------------------------------
Amount:     GHS ${txn.totalAmount.toStringAsFixed(2)}
STATUS:     $statusStr
================================
${_centerText('THANK YOU FOR TRANSACTING', 32)}
${_centerText('KEEP RECEIPT FOR YOUR RECORDS', 32)}
${_centerText(txn.operatorReference, 32)}
${_centerText('*CUSTOMER COPY*', 32)}
${_centerText('SwagPay', 32)}
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

    final isUniversal = txn.posId.isEmpty ||
        txn.posId == 'ANY_POS' ||
        txn.posId.startsWith('pos_') ||
        txn.posId.toLowerCase().contains('universal');
    final displayPos = isUniversal ? 'Universal POS' : txn.posId;

    String statusText = 'Approved by PIN';
    if (isOffline) {
      statusText = 'OFFLINE QUEUED (PENDING SYNC)';
    } else if (txn.status == TransactionStatus.failed) {
      statusText = 'PAYMENT DECLINED';
    } else if (txn.status == TransactionStatus.pending) {
      statusText = 'PAYMENT PENDING';
    } else if (txn.status == TransactionStatus.refunded) {
      statusText = 'PAYMENT REFUNDED';
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
                // Header with Merchant Name, Address, and Shop Location (no phone)
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        txn.effectiveMerchantName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        txn.effectiveMerchantAddress,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Location: ${txn.effectiveShopLocation}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'OFFICIAL PAYMENT RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Terminal, Cashier & Audit Meta
                _buildPdfRow('Date / Time', formattedDate),
                _buildPdfRow('Terminal', displayPos),
                _buildPdfRow('Cashier', txn.tellerName),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Transaction Details (Phone Number Removed, Only 1 Reference placed under barcode)
                _buildPdfRow('Customer Name', txn.customerName, isBold: true),
                _buildPdfRow('Network', txn.networkDisplay),
                if (txn.receiptNumber != null && txn.receiptNumber!.isNotEmpty)
                  _buildPdfRow('Receipt No', txn.receiptNumber!),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                // Amount Section (Processing fee included in amount, not separated)
                _buildPdfRow('Amount', 'GHS ${txn.totalAmount.toStringAsFixed(2)}', isBold: true),
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
                        'TOTAL AMOUNT',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'GHS ${txn.totalAmount.toStringAsFixed(2)}',
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

                // Simulated Barcode & Single Reference directly underneath
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
                      pw.SizedBox(height: 4),
                      // Single Reference on the receipt, directly under the barcode
                      pw.Text(
                        txn.operatorReference,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '*CUSTOMER COPY*',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 6),
                // Footer
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
                        'SwagPay',
                        style: pw.TextStyle(
                          fontSize: 7.5,
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

  /// Triggers real POS thermal printer / AirPrint dialog for Shift Reconciliation
  static Future<void> printShiftReport({
    required BuildContext context,
    required String tellerName,
    required String branch,
    required int totalCount,
    required int successCount,
    required double mtnAmount,
    required double telecelAmount,
    required double atAmount,
    required double totalAmount,
    required DateTime timestamp,
  }) async {
    try {
      await Printing.layoutPdf(
        name: 'SwagPay-Shift-Reconciliation-${DateFormat('yyyyMMdd-HHmm').format(timestamp)}',
        onLayout: (PdfPageFormat format) async => generateShiftReportPdf(
          format: format,
          tellerName: tellerName,
          branch: branch,
          totalCount: totalCount,
          successCount: successCount,
          mtnAmount: mtnAmount,
          telecelAmount: telecelAmount,
          atAmount: atAmount,
          totalAmount: totalAmount,
          timestamp: timestamp,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  static Future<Uint8List> generateShiftReportPdf({
    required PdfPageFormat format,
    required String tellerName,
    required String branch,
    required int totalCount,
    required int successCount,
    required double mtnAmount,
    required double telecelAmount,
    required double atAmount,
    required double totalAmount,
    required DateTime timestamp,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd-MMM-yyyy hh:mm a');
    final formattedDate = dateFormat.format(timestamp);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'SWAGPAY POS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'SHIFT RECONCILIATION REPORT',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'OFFICIAL AUDIT COPY',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                _buildPdfRow('Generated:', formattedDate),
                _buildPdfRow('Cashier / Teller:', tellerName),
                _buildPdfRow('Branch:', branch.isEmpty ? 'Main Hub' : branch),
                _buildPdfRow('Settled Txns:', '$successCount of $totalCount txns', isBold: true),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),

                _buildPdfRow('MTN MoMo Total:', 'GHS ${mtnAmount.toStringAsFixed(2)}'),
                _buildPdfRow('Telecel Cash Total:', 'GHS ${telecelAmount.toStringAsFixed(2)}'),
                _buildPdfRow('AT Money Total:', 'GHS ${atAmount.toStringAsFixed(2)}'),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 3),

                _buildPdfRow('TOTAL REVENUE:', 'GHS ${totalAmount.toStringAsFixed(2)}', isBold: true),

                pw.SizedBox(height: 10),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 6),

                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'SHIFT RECONCILED & CLOSED',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'SwagPay',
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
}
