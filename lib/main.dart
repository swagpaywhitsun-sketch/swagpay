import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/state/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/admin_layout.dart';
import 'features/admin/admin_management_screens.dart';
import 'features/admin/admin_operations_screens.dart';
import 'features/teller/new_collection_flow.dart';
import 'features/teller/teller_auth_screens.dart';
import 'features/teller/teller_dashboard_screen.dart';
import 'features/teller/teller_extra_screens.dart';
import 'features/teller/teller_history_screen.dart';
import 'features/teller/teller_reports_and_shift.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const SwagPayApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/device-unauthorized',
      builder: (context, state) => const DeviceUnauthorizedScreen(),
    ),
    // Teller Routes
    GoRoute(
      path: '/teller/login',
      builder: (context, state) => const TellerLoginScreen(),
    ),
    GoRoute(
      path: '/teller/dashboard',
      builder: (context, state) => const TellerDashboardScreen(),
    ),
    GoRoute(
      path: '/teller/collection',
      builder: (context, state) => const NewCollectionScreen(),
    ),
    GoRoute(
      path: '/teller/history',
      builder: (context, state) => const TellerHistoryScreen(),
    ),
    GoRoute(
      path: '/teller/transaction/:id',
      builder: (context, state) => TransactionDetailScreen(
        transactionId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/teller/reports',
      builder: (context, state) => const TellerReportsScreen(),
    ),
    GoRoute(
      path: '/teller/shift',
      builder: (context, state) => const TellerShiftScreen(),
    ),
    GoRoute(
      path: '/teller/profile',
      builder: (context, state) => const TellerProfileScreen(),
    ),
    GoRoute(
      path: '/teller/notifications',
      builder: (context, state) => const TellerNotificationsScreen(),
    ),
    GoRoute(
      path: '/teller/offline-queue',
      builder: (context, state) => const TellerOfflineQueueScreen(),
    ),
    GoRoute(
      path: '/teller/customer-lookup',
      builder: (context, state) => const CustomerLookupScreen(),
    ),

    // Admin POS Web Routes wrapped in AdminLayout
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/dashboard',
        child: AdminDashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/tellers',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/tellers',
        child: AdminTellersScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/pos',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/pos',
        child: AdminPosScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/transactions',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/transactions',
        child: AdminTransactionsScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/refunds',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/refunds',
        child: AdminRefundsScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/reports',
        child: TellerReportsScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/settlements',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/settlements',
        child: AdminSettlementsScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/audit-logs',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/audit-logs',
        child: AdminAuditLogsScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/settings',
      builder: (context, state) => const AdminLayout(
        currentRoute: '/admin/settings',
        child: AdminSettingsScreen(),
      ),
    ),
  ],
);

class SwagPayApp extends ConsumerWidget {
  const SwagPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SwagPay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
