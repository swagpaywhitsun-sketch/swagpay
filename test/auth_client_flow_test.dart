// End-to-end client auth chain: sign in, store the session, attach it to every
// request, and survive an expired access token via one silent refresh.
// Runs against an in-process HTTP stub — no SwagPay server or database needed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swagpay/core/models/user.dart';
import 'package:swagpay/core/network/api_client.dart';
import 'package:swagpay/core/network/api_config.dart';
import 'package:swagpay/core/services/auth_vault.dart';
import 'package:swagpay/core/state/providers.dart';

const _userJson = {
  'id': 'usr_1',
  'fullName': 'Akosua',
  'email': 'akosua@swagpay.test',
  'phone': '0550000001',
  'role': 'teller',
  'dbRole': 'TELLER',
  'posId': 'pos_01',
  'active': true,
};

const _txnJson = {
  'id': 'tx_1',
  'reference': 'WP-1',
  'momoNumber': '0550000001',
  'customerName': 'Yaw',
  'amount': 45,
  'status': 'SUCCESS',
  'tellerId': 'usr_1',
  'tellerName': 'Akosua',
  'posId': 'pos_01',
  'network': 'MTN',
  'createdAt': '2026-09-29T09:00:00.000Z',
  'receiptNumber': 'RCPT-1',
};

class StubServer {
  late final HttpServer server;
  final List<String> requests = [];
  String? lastAuthHeader;
  int generation = 0;
  bool staleOnce = false;

  String get accessToken => 'access-gen-$generation';
  String get baseUrl => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handle);
  }

  Future<void> stop() => server.close(force: true);

  Future<void> handle(HttpRequest req) async {
    final body = req.method == 'POST' ? await utf8.decoder.bind(req).join() : '';
    requests.add('${req.method} ${req.uri.path}');
    req.response.headers.contentType = ContentType.json;

    void reply(int code, Object payload) {
      req.response.statusCode = code;
      req.response.write(jsonEncode(payload));
      req.response.close();
    }

    switch ('${req.method} ${req.uri.path}') {
      case 'POST /api/auth/login':
        final sent = jsonDecode(body) as Map<String, dynamic>;
        if (sent['password'] != 'correct horse') {
          reply(401, {'success': false, 'message': 'Invalid credentials'});
          return;
        }
        reply(200, {
          'success': true,
          'user': _userJson,
          'token': accessToken,
          'refreshToken': 'refresh-1',
          'expiresIn': 43200,
        });
        return;

      case 'POST /api/auth/refresh':
        generation++;
        reply(200, {'success': true, 'token': accessToken, 'expiresIn': 43200});
        return;

      case 'GET /api/transactions':
        lastAuthHeader = req.headers.value('authorization');
        if (staleOnce) {
          // Exactly one ledger read is answered with 401 so the refresh path must fire.
          staleOnce = false;
          reply(401, {'error': 'authentication_required'});
          return;
        }
        reply(200, [_txnJson]);
        return;

      default:
        reply(404, {'error': 'not_found'});
    }
  }
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  late StubServer stub;

  setUp(() async {
    // flutter_test blocks outbound sockets unless the override is cleared; the
    // auth chain has to be exercised against a real HTTP stack.
    HttpOverrides.global = null;
    stub = StubServer();
    await stub.start();
    ApiConfig.baseUrl = stub.baseUrl;
    ApiClient.refreshHandler = null;
  });

  tearDown(() async {
    await stub.stop();
    ApiClient.refreshHandler = null;
  });

  Future<SharedPreferences> useVault(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    tokenVault.attach(prefs);
    return prefs;
  }

  ProviderContainer newContainer(SharedPreferences prefs) {
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    return c;
  }

  Future<AppUser?> signIn(ProviderContainer c) async {
    final ok = await c.read(authProvider.notifier).signIn('akosua@swagpay.test', 'correct horse');
    return ok ? c.read(authProvider).currentUser : null;
  }

  test('sign in is decided by the server, never by a local fallback', () async {
    final prefs = await useVault({});
    final c = newContainer(prefs);

    expect(c.read(authProvider).isAuthenticated, isFalse, reason: 'cold start carries no identity');

    expect(await c.read(authProvider.notifier).signIn('akosua@swagpay.test', 'guess'), isFalse);
    expect(c.read(authProvider).errorMessage, 'Invalid credentials');
    expect(c.read(authProvider).isAuthenticated, isFalse);

    final user = await signIn(c);
    expect(user, isNotNull);
    expect(user!.id, 'usr_1');
    expect(user.isTeller, isTrue, reason: 'role comes from the server payload');
    expect(tokenVault.readAccessToken(), stub.accessToken);
    expect(tokenVault.readRefreshToken(), 'refresh-1');
    expect(tokenVault.readDeviceId(), isNotNull, reason: 'terminal identity is created at sign-in');
    expect(stub.requests, contains('POST /api/auth/login'));
  });

  test('every request carries the bearer token and a 401 refreshes exactly once', () async {
    final prefs = await useVault({});
    final c = newContainer(prefs);

    await signIn(c);
    // Coalesced by the repository's single-flight sync, so no ledger read is
    // still in flight when the token below goes stale.
    await c.read(paymentRepositoryNotifierProvider.notifier).manualRefresh();

    // The access token the app holds is now the one the server considers stale.
    stub.generation = 7;
    stub.staleOnce = true;
    c.read(apiClientProvider).updateToken('access-gen-6');

    final repo = c.read(paymentRepositoryProvider);
    await repo.refreshFromBackend();

    expect(stub.requests, contains('POST /api/auth/refresh'), reason: 'a 401 must trigger a silent refresh');
    expect(stub.lastAuthHeader, 'Bearer ${stub.accessToken}',
        reason: 'the retry is authenticated with the refreshed token');
    expect(repo.getTransactions().map((t) => t.reference), contains('WP-1'));
    expect(repo.lastSyncError, isNull);
    expect(tokenVault.readAccessToken(), stub.accessToken);
  });

  test('a stored session is restored on relaunch without signing in again', () async {
    final hotPrefs = await useVault({});
    final hot = newContainer(hotPrefs);
    final user = await signIn(hot);
    final deviceId = tokenVault.readDeviceId();
    final accessToken = tokenVault.readAccessToken();

    hot.read(authProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);
    expect(hot.read(authProvider).isAuthenticated, isFalse);

    // Same device, persisted vault — as after killing the app.
    final coldPrefs = await useVault(<String, Object>{
      'swag_device_id': deviceId!,
      'swag_auth_access_token': accessToken!,
      'swag_auth_user': jsonEncode(_userJson),
    });
    final cold = newContainer(coldPrefs);

    expect(cold.read(authProvider).isAuthenticated, isFalse, reason: 'nothing is trusted before resume');
    expect(await cold.read(authProvider.notifier).resumeSession(), isTrue);
    expect(cold.read(authProvider).currentUser?.email, 'akosua@swagpay.test');
    expect(user, isNotNull);
  });

  test('a corrupt stored session cannot mint an identity', () async {
    final corruptPrefs = await useVault(<String, Object>{
      'swag_auth_access_token': 'leftover-token',
      'swag_auth_user': '{"email":"nobody@swagpay.test"}', // no id
    });
    final c = newContainer(corruptPrefs);

    expect(await c.read(authProvider.notifier).resumeSession(), isFalse);
    expect(c.read(authProvider).isAuthenticated, isFalse);
    expect(tokenVault.readAccessToken(), isNull, reason: 'the unusable session is discarded');
  });
}
