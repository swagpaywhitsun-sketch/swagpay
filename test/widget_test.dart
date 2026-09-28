import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swagpay/core/state/providers.dart';
import 'package:swagpay/main.dart';

void main() {
  testWidgets('SwagPay basic app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const SwagPayApp(),
      ),
    );

    // Allow splash timer to complete
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(SwagPayApp), findsOneWidget);
  });
}
