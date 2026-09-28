import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ReceiptService {
  static String generateTextReceipt(PaymentTransaction txn) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(txn.timestamp);

    String amountLabel;
    switch (txn.status) {
      case TransactionStatus.success:
        amountLabel = 'TOTAL PAID';
        break;
      case TransactionStatus.pending:
        amountLabel = 'AMOUNT PENDING';
        break;
      case TransactionStatus.failed:
        amountLabel = 'AMOUNT (NOT CHARGED)';
        break;
      case TransactionStatus.refunded:
        amountLabel = 'AMOUNT REFUNDED';
        break;
    }

    return '''
================================
          SWAGPAY
   OFFICIAL PAYMENT RECEIPT
================================
Date:       $formattedDate
Ref:        ${txn.reference}
Txn ID:     ${txn.id}
Terminal:   ${txn.posId}
Teller:     ${txn.tellerName}
Branch:     ${txn.branch ?? 'Main Counter'}
--------------------------------
Customer:   ${txn.customerName}
Number:     ${txn.customerNumber}
Network:    ${txn.networkDisplay}
--------------------------------
STATUS:     ${txn.status.name.toUpperCase()}
$amountLabel: ${txn.currency} ${txn.amount.toStringAsFixed(2)}
--------------------------------
Idempotency: ${txn.idempotencyKey.substring(0, 8)}...
================================
  Thank You For Your Business
  System developed by Whitsun
================================
''';
  }

  static Future<void> copyReceiptToClipboard(PaymentTransaction txn) async {
    final text = generateTextReceipt(txn);
    await Clipboard.setData(ClipboardData(text: text));
  }
}
