import 'package:flutter_test/flutter_test.dart';
import 'package:swagpay/core/models/transaction.dart';
import 'package:swagpay/core/services/receipt_service.dart';

void main() {
  group('Receipt Specification Tests', () {
    final testTxn = PaymentTransaction(
      id: 'tx_123456789',
      reference: 'SWAG-20261013-ABCD',
      gatewayReference: 'MTN-FIN-9876543210',
      customerNumber: '0241234567',
      customerName: 'Kofi Mensah',
      customerPhone: '0241234567',
      amount: 150.00,
      fee: 2.50,
      totalCharged: 152.50,
      status: TransactionStatus.success,
      network: MoMoNetwork.mtn,
      timestamp: DateTime(2026, 10, 13, 14, 30),
      tellerId: 'usr_teller_1',
      tellerName: 'Ama Serwaa',
      posId: 'POS-01',
      branch: 'Accra Mall Store',
      receiptNumber: 'RCPT-0042',
      idempotencyKey: 'idemp_123',
      merchantName: 'Kofi & Sons Electronics',
      merchantAddress: 'Plot 48 Spintex Road, Accra',
      shopLocation: 'Accra Mall Branch #12',
    );

    test('1. Receipt header includes Merchant name, address, and shop location, but ignores phone number', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      // Must contain merchant name, address, and shop location
      expect(textReceipt, contains('KOFI & SONS ELECTRONICS'));
      expect(textReceipt, contains('Plot 48 Spintex Road, Accra'));
      expect(textReceipt, contains('Location: Accra Mall Branch #12'));

      // Header must NOT contain any merchant phone
      final headerSection = textReceipt.split('PURCHASE')[0];
      expect(headerSection, isNot(contains('0241234567')));
      expect(headerSection, isNot(contains('Phone')));
    });

    test('2 & 5. Only 1 reference is shown on the receipt, located in the footnote with *CUSTOMER COPY*', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      // Must NOT have a Reference line in the upper transaction details
      final upperSection = textReceipt.split('================================')[2];
      expect(upperSection, isNot(contains('Reference:')));
      expect(upperSection, isNot(contains('Ref:')));

      // Footnote contains the single reference (operator reference)
      final footnoteSection = textReceipt.split('THANK YOU FOR TRANSACTING')[1];
      expect(footnoteSection, contains('MTN-FIN-9876543210'));

      // Reference in footnote is unlabeled
      expect(footnoteSection, isNot(contains('Ref: MTN-FIN-9876543210')));
      expect(footnoteSection, isNot(contains('Reference: MTN-FIN-9876543210')));

      // Then followed by *CUSTOMER COPY*
      expect(footnoteSection, contains('*CUSTOMER COPY*'));

      // Exactly 1 reference appears across the whole receipt text
      final occurrences = 'MTN-FIN-9876543210'.allMatches(textReceipt).length;
      expect(occurrences, equals(1));
    });

    test('3. No Fee appears on the receipt and Amount includes processing fee without separation', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      // Total amount should be 152.50 (150.00 + 2.50)
      expect(textReceipt, contains('Amount:     GHS 152.50'));

      // MUST NOT CONTAIN ANY FEE ON THE RECEIPT
      expect(textReceipt.toLowerCase(), isNot(contains('fee')));
      expect(textReceipt, isNot(contains('Subtotal:')));
      expect(textReceipt, isNot(contains('Processing Fee')));
    });

    test('4. Does not just say APPROVED, says Approved by PIN', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      expect(textReceipt, contains('STATUS:     Approved by PIN'));
      expect(textReceipt, isNot(contains('APPROVED / PAID')));
    });

    test('6. Removes customer phone number completely from receipt', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      expect(textReceipt, contains('Customer:   Kofi Mensah'));
      // Phone number should be absent
      expect(textReceipt, isNot(contains('0241234567')));
      expect(textReceipt, isNot(contains('Phone:')));
    });

    test('7. Receipt branding SwagPay is in header, not in footer', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      final header = textReceipt.split('PURCHASE')[0];
      final footer = textReceipt.split('*CUSTOMER COPY*')[1];

      expect(header, contains('SwagPay'));
      expect(footer, isNot(contains('SwagPay')));
      expect(textReceipt, isNot(contains('POWERED BY WHITSUN')));
    });

    test('8. Fallback merchant profile defaults to KOFI & SONS ELECTRONICS', () {
      final minimalTxn = PaymentTransaction(
        id: 'tx_min',
        reference: 'SWAG-MIN',
        customerNumber: '0240000000',
        customerName: 'Kwame Mensah',
        customerPhone: '0240000000',
        amount: 50.0,
        status: TransactionStatus.success,
        network: MoMoNetwork.mtn,
        timestamp: DateTime(2026, 10, 13),
        tellerId: 'usr_teller',
        tellerName: 'Cashier 1',
        posId: 'POS-01',
        idempotencyKey: 'idemp_min',
      );

      final textReceipt = ReceiptService.generateTextReceipt(minimalTxn);
      expect(textReceipt, contains('KOFI & SONS ELECTRONICS'));
      expect(textReceipt, contains('Plot 48 Spintex Road, Accra'));
      expect(textReceipt, contains('Location: Accra Mall Branch #12'));
    });

    test('9. Cashier name uses first name only, not full name', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      expect(textReceipt, contains('Cashier:    Ama'));
      expect(textReceipt, isNot(contains('Cashier:    Ama Serwaa')));
    });

    test('10. Label says PURCHASE (terminal payment receipt, not POS Official Receipt)', () {
      final textReceipt = ReceiptService.generateTextReceipt(testTxn);

      expect(textReceipt, contains('PURCHASE'));
      expect(textReceipt, isNot(contains('OFFICIAL PAYMENT RECEIPT')));
    });

    test('11. Generates two copies: one for Attendant and one for Customer', () {
      final twoCopiesText = ReceiptService.generateTwoCopiesTextReceipt(testTxn);

      expect(twoCopiesText, contains('*ATTENDANT COPY*'));
      expect(twoCopiesText, contains('*CUSTOMER COPY*'));
      expect(twoCopiesText.indexOf('*ATTENDANT COPY*'), lessThan(twoCopiesText.indexOf('*CUSTOMER COPY*')));
    });
  });
}
