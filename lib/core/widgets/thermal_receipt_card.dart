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
    if (transaction.id.startsWith('tx_off_') || transaction.reference.startsWith('OFF-')) {
      return AppColors.pending;
    }
    switch (transaction.status) {
      case TransactionStatus.success:
        return AppColors.success;
      case TransactionStatus.pending:
        return AppColors.pending;
      case TransactionStatus.failed:
        return AppColors.error;
      case TransactionStatus.refunded:
        return AppColors.primaryLight;
    }
  }

  String get _statusLabel {
    if (transaction.id.startsWith('tx_off_') || transaction.reference.startsWith('OFF-')) {
      return 'OFFLINE QUEUED (PENDING SYNC)';
    }
    switch (transaction.status) {
      case TransactionStatus.success:
        return 'APPROVED / PAID';
      case TransactionStatus.pending:
        return 'PAYMENT PENDING';
      case TransactionStatus.failed:
        return 'PAYMENT DECLINED';
      case TransactionStatus.refunded:
        return 'PAYMENT REFUNDED';
    }
  }

  String get _amountLabel {
    if (transaction.id.startsWith('tx_off_') || transaction.reference.startsWith('OFF-')) {
      return 'QUEUED AMOUNT (PENDING)';
    }
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
    final isSuccess = transaction.status == TransactionStatus.success;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Jagged Tear Edge
          CustomPaint(
            size: const Size(double.infinity, 10),
            painter: _SerratedEdgePainter(isTop: true, color: Colors.white),
          ),

          // Main Thermal Receipt Body
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Branding
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(
                                'logo.png',
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'SWAGPAY POS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'OFFICIAL PAYMENT RECEIPT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (transaction.posId.isEmpty ||
                                      transaction.posId == 'ANY_POS' ||
                                      transaction.posId.startsWith('pos_') ||
                                      transaction.posId.toLowerCase().contains('universal'))
                                  ? 'Terminal: Universal POS'
                                  : 'Terminal: ${transaction.posId}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                          Text(
                            'Cashier: ${transaction.tellerName}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dateFormat.format(transaction.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                _buildDottedDivider(),
                const SizedBox(height: 12),

                // Customer & Transaction Details
                _buildReceiptRow('Customer Name', transaction.customerName, isBold: true),
                _buildReceiptRow('Phone Number', transaction.displayPhone),
                _buildReceiptRow('Network', transaction.networkDisplay),
                _buildReceiptRow('Reference', transaction.reference, isMono: true),
                if (transaction.receiptNumber != null && transaction.receiptNumber!.isNotEmpty)
                  _buildReceiptRow('Receipt No', transaction.receiptNumber!, isMono: true),
                if (transaction.branch != null && transaction.branch!.isNotEmpty)
                  _buildReceiptRow('Branch / Location', transaction.branch!),

                const SizedBox(height: 12),
                _buildDottedDivider(),
                const SizedBox(height: 12),

                // Amount Breakdown
                _buildReceiptRow('Payment Subtotal', 'GHS ${transaction.amount.toStringAsFixed(2)}'),
                _buildReceiptRow('Processing Fee', 'GHS 0.00'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSuccess ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _amountLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'GHS ${transaction.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _statusColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _buildDottedDivider(),
                const SizedBox(height: 14),

                // Thermal Barcode Simulation
                Center(
                  child: Column(
                    children: [
                      Container(
                        height: 36,
                        width: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            38,
                            (index) => Container(
                              width: (index % 5 == 0) ? 3 : ((index % 2 == 0) ? 2 : 1),
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.reference,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                // Footer
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'THANK YOU FOR TRANSACTING',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'KEEP THIS RECEIPT FOR YOUR RECORDS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'POWERED BY WHITSUN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1570A6),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Jagged Tear Edge
          CustomPaint(
            size: const Size(double.infinity, 10),
            painter: _SerratedEdgePainter(isTop: false, color: Colors.white),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
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
                          const SnackBar(
                            content: Text('Receipt text copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Text'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPrint ?? () => ReceiptService.printReceipt(context, transaction),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1570A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildDottedDivider() {
    return Row(
      children: List.generate(
        32,
        (i) => Expanded(
          child: Container(
            height: 1.5,
            color: i % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF0F172A),
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                fontFamily: isMono ? 'Courier' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates the realistic serrated / zigzag tear edge of POS thermal paper
class _SerratedEdgePainter extends CustomPainter {
  final bool isTop;
  final Color color;

  _SerratedEdgePainter({required this.isTop, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const toothWidth = 8.0;
    final toothHeight = size.height;
    final count = (size.width / toothWidth).ceil();

    if (isTop) {
      // Sawtooth teeth pointing downwards from the top edge
      path.moveTo(0, toothHeight);
      for (int i = 0; i < count; i++) {
        final x = i * toothWidth;
        path.lineTo(x + toothWidth / 2, 0);
        path.lineTo(x + toothWidth, toothHeight);
      }
      path.lineTo(size.width, toothHeight);
      path.close();
    } else {
      // Sawtooth teeth pointing downwards at the bottom edge
      path.moveTo(0, 0);
      for (int i = 0; i < count; i++) {
        final x = i * toothWidth;
        path.lineTo(x + toothWidth / 2, toothHeight);
        path.lineTo(x + toothWidth, 0);
      }
      path.lineTo(size.width, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SerratedEdgePainter oldDelegate) =>
      oldDelegate.isTop != isTop || oldDelegate.color != color;
}
