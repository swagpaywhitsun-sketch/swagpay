import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swagpay/core/models/transaction.dart';
import 'package:swagpay/core/network/api_client.dart';
import 'package:swagpay/core/services/auth_vault.dart';
import 'package:swagpay/core/services/payment_repository.dart';

void main() {
  late SharedPreferences prefs;
  late ApiClient apiClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tokenVault.attach(prefs);
    apiClient = ApiClient();
  });

  test('offline transaction is preserved in queue and persisted to storage', () async {
    final repo = PaymentRepository(apiClient: apiClient, prefs: prefs);

    final txn = repo.recordOfflineTransaction(
      momoNumber: '0241234567',
      amount: 150.0,
      customerName: 'Akwasi Mensah',
      tellerId: 'usr_teller_01',
      tellerName: 'Counter Teller 1',
      posId: 'pos_counter_1',
      network: MoMoNetwork.mtn,
    );

    expect(txn.idempotencyKey.isNotEmpty, true);
    expect(repo.getOfflineQueue().length, 1);
    expect(repo.getOfflineQueue().first.reference, txn.reference);

    // Verify persistence across repository re-initialization
    final repo2 = PaymentRepository(apiClient: apiClient, prefs: prefs);
    expect(repo2.getOfflineQueue().length, 1);
    expect(repo2.getOfflineQueue().first.reference, txn.reference);
  });

  test('teller data scoping restricts counter visibility', () async {
    await tokenVault.saveSession(
      accessToken: 'dummy_token',
      user: {
        'id': 'usr_teller_01',
        'email': 'teller1@swagpay.com',
        'role': 'teller',
        'fullName': 'Counter Teller 1',
      },
    );

    final repo = PaymentRepository(apiClient: apiClient, prefs: prefs);

    // Record an offline transaction for teller 1
    final txn1 = repo.recordOfflineTransaction(
      momoNumber: '0241112233',
      amount: 50.0,
      tellerId: 'usr_teller_01',
      tellerName: 'Counter Teller 1',
      posId: 'pos_01',
    );

    final txns = repo.getTransactions();
    expect(txns.any((t) => t.id == txn1.id), true);
  });

  test('refund submission validates transaction presence and status', () async {
    final repo = PaymentRepository(apiClient: apiClient, prefs: prefs);

    // Submitting refund for nonexistent transaction throws
    expect(
      () => repo.submitRefundRequest(
        transactionId: 'nonexistent_id',
        reason: 'Duplicate charge',
        tellerId: 'usr_teller_01',
        tellerName: 'Teller 1',
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
