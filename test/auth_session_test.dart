// Session-boundary tests for the client: identity only ever comes from the
// server payload, never from a local default.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swagpay/core/models/user.dart';
import 'package:swagpay/core/services/auth_vault.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tokenVault.attach(prefs);
  });

  test('a session snapshot with no server identity yields no user', () {
    expect(userFromSession(null), isNull);
    expect(userFromSession({'email': 'someone@swagpay.com'}), isNull, reason: 'no id = no identity');
    expect(userFromSession({'id': 'usr_1'}), isNull, reason: 'no email = no identity');
  });

  test('role comes from the server payload', () {
    final admin = userFromSession({'id': 'usr_1', 'email': 'a@b.c', 'role': 'admin', 'fullName': 'A'});
    final teller = userFromSession({'id': 'usr_2', 'email': 't@b.c', 'role': 'teller', 'fullName': 'T'});
    expect(admin!.role, UserRole.admin);
    expect(teller!.role, UserRole.teller);
    expect(teller.fullName, 'T');
  });

  test('device id is generated once and survives a session clear', () async {
    await tokenVault.ensureDeviceId();
    final first = tokenVault.readDeviceId();
    expect(first, isNotNull);
    await tokenVault.saveSession(accessToken: 'a', refreshToken: 'r', user: {'id': 'x', 'email': 'y'});
    await tokenVault.clearSession();
    expect(tokenVault.readAccessToken(), isNull);
    expect(tokenVault.readDeviceId(), first, reason: 'the terminal keeps its identity across sign-outs');
  });
}
