import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ReceiptService {
  static String generateTextReceipt(PaymentTransaction txn) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(txn.timestamp);

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
AMOUNT PAID: ${txn.currency} ${txn.amount.toStringAsFixed(2)}
STATUS:     ${txn.status.name.toUpperCase()}
--------------------------------
Idempotency: ${txn.idempotencyKey.substring(0, 8)}...
================================
   THANK YOU FOR YOUR PAYMENT
      Powered by SwagPay
================================
''';
  }

  static Future<void> copyReceiptToClipboard(PaymentTransaction txn) async {
    final text = generateTextReceipt(txn);
    await Clipboard.setData(ClipboardData(text: text));
  }
}
