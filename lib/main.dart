import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/auth_vault.dart';
import 'core/state/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/admin_layout.dart';
import 'features/admin/admin_management_screens.dart';
import 'features/admin/admin_operations_screens.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/teller/new_collection_flow.dart';
import 'features/teller/teller_auth_screens.dart';
import 'features/teller/teller_dashboard_screen.dart';
import 'features/teller/teller_extra_screens.dart';
import 'features/teller/teller_history_screen.dart';
import 'features/teller/teller_reports_and_shift.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  tokenVault.attach(sharedPreferences);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const SwagPayApp(),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/teller/login' ||
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/device-unauthorized' ||
          state.matchedLocation == '/forgot-password';

      final hasStoredSession = tokenVault.readAccessToken() != null && tokenVault.readUserSnapshot() != null;

      // Restrict access to login page for unauthenticated users
      if (!auth.isAuthenticated) {
        if (hasStoredSession) {
          // Stored session in vault being resumed on page reload; do not kick to login
          return null;
        }
        return isAuthRoute ? null : '/teller/login';
      }

      // Authenticated users on login or splash redirect to their respective portals
      if (state.matchedLocation == '/teller/login' || state.matchedLocation == '/splash') {
        return auth.isAdmin ? '/admin/dashboard' : '/teller/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/device-unauthorized',
        builder: (context, state) => const DeviceUnauthorizedScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
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

      // Admin POS Web Routes wrapped in persistent ShellRoute
      // Keeps the sidebar and header completely static with zero flashing during navigation
      ShellRoute(
        builder: (context, state, child) => AdminLayout(
          currentRoute: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/tellers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminTellersScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/pos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminPosScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/transactions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminTransactionsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/refunds',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminRefundsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/reports',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/audit-logs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminAuditLogsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminSettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

class SwagPayApp extends ConsumerStatefulWidget {
  const SwagPayApp({super.key});

  @override
  ConsumerState<SwagPayApp> createState() => _SwagPayAppState();
}

class _SwagPayAppState extends ConsumerState<SwagPayApp> {
  @override
  void initState() {
    super.initState();
    // Restore session on app boot so browser refresh maintains login state
    ref.read(authProvider.notifier).resumeSession();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SwagPay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}
