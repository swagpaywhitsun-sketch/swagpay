import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swagpay/core/services/auth_vault.dart';
import 'package:swagpay/core/state/providers.dart';
import 'package:swagpay/features/auth/forgot_password_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tokenVault.attach(prefs);
  });

  testWidgets('ForgotPasswordScreen renders input fields and action buttons', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      ),
    );

    // Header checks
    expect(find.text('SwagPay'), findsOneWidget);
    expect(find.text('Forgot Your Password?'), findsOneWidget);
    expect(find.text('Send Reset Code'), findsOneWidget);
    expect(find.text('Back to Sign In'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Empty submission triggers local error
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your registered email or phone number'), findsOneWidget);
  });
}
