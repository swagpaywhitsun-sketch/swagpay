import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../services/payment_repository.dart';

// SharedPreferences provider (overridden in main)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// ApiClient provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Notifier to trigger UI rebuilds when payment repository data changes
class PaymentVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final paymentVersionProvider = NotifierProvider<PaymentVersionNotifier, int>(PaymentVersionNotifier.new);

// PaymentRepository provider (reacts to paymentVersionProvider)
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  ref.watch(paymentVersionProvider);
  final client = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return PaymentRepository(
    apiClient: client,
    prefs: prefs,
    onChanged: () => ref.read(paymentVersionProvider.notifier).bump(),
  );
});

// Theme Mode Provider using modern Riverpod Notifier
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final mode = prefs.getString('theme_mode');
    if (mode == 'dark') return ThemeMode.dark;
    if (mode == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
  }

  void toggleTheme() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Auth State
class AuthState {
  final AppUser? currentUser;
  final bool isLoading;
  final String? errorMessage;
  final bool is2faRequired;
  final String? pending2faEmail;
  final bool isDeviceAuthorized;

  const AuthState({
    this.currentUser,
    this.isLoading = false,
    this.errorMessage,
    this.is2faRequired = false,
    this.pending2faEmail,
    this.isDeviceAuthorized = true,
  });

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;
  bool get isTeller => currentUser?.isTeller ?? false;

  AuthState copyWith({
    AppUser? currentUser,
    bool? isLoading,
    String? errorMessage,
    bool? is2faRequired,
    String? pending2faEmail,
    bool? isDeviceAuthorized,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      is2faRequired: is2faRequired ?? this.is2faRequired,
      pending2faEmail: pending2faEmail ?? this.pending2faEmail,
      isDeviceAuthorized: isDeviceAuthorized ?? this.isDeviceAuthorized,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedEmail = prefs.getString('auth_user_email');
    if (savedEmail != null && savedEmail.contains('admin')) {
      return const AuthState(
        currentUser: AppUser(
          id: 'usr_admin',
          fullName: 'Administrator',
          email: 'admin@swagpay.com',
          phone: '0240000001',
          role: UserRole.admin,
          branch: 'Accra Central Hub',
          assignedPos: ['pos_01'],
          singleTxnLimit: 50000.0,
          dailyLimit: 200000.0,
        ),
        isDeviceAuthorized: true,
      );
    }
    // Default session: Real active teller from Supabase
    return const AuthState(
      currentUser: AppUser(
        id: 'usr_teller1',
        fullName: 'Kofi Mensah',
        email: 'teller@swagpay.com',
        phone: '0550402859',
        role: UserRole.teller,
        branch: 'Accra Mall Food Court',
        assignedPos: ['pos_01'],
        singleTxnLimit: 10000.0,
        dailyLimit: 50000.0,
      ),
      isDeviceAuthorized: true,
    );
  }

  Future<bool> loginTeller(String identifier, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.post<Map<String, dynamic>>(
        ApiConfig.login,
        data: {
          'identifier': identifier,
          'password': password,
          'role': 'TELLER',
        },
      );

      if (res.data != null && res.data!['success'] == true) {
        final userData = res.data!['user'] as Map<String, dynamic>;
        final user = AppUser(
          id: userData['id'] as String,
          fullName: userData['fullName'] as String,
          email: userData['email'] as String,
          phone: userData['phone'] as String? ?? '',
          role: UserRole.teller,
          branch: 'Accra Mall Food Court',
          assignedPos: [userData['posId'] as String? ?? 'pos_01'],
        );

        state = state.copyWith(currentUser: user, isLoading: false);
        ref.read(sharedPreferencesProvider).setString('auth_user_email', user.email);
        return true;
      }
    } catch (_) {}

    // Fallback if local server not yet up: match pin '1234'
    if (password == '1234') {
      const user = AppUser(
        id: 'usr_teller1',
        fullName: 'Kofi Mensah',
        email: 'teller@swagpay.com',
        phone: '0550402859',
        role: UserRole.teller,
        branch: 'Accra Mall Food Court',
        assignedPos: ['pos_01'],
      );
      state = state.copyWith(currentUser: user, isLoading: false);
      ref.read(sharedPreferencesProvider).setString('auth_user_email', user.email);
      return true;
    }

    state = state.copyWith(isLoading: false, errorMessage: 'Invalid Teller PIN (Enter 1234)');
    return false;
  }

  Future<bool> loginAdmin(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (password == 'admin123') {
      const user = AppUser(
        id: 'usr_admin',
        fullName: 'Administrator',
        email: 'admin@swagpay.com',
        phone: '0240000001',
        role: UserRole.admin,
        branch: 'Accra Central Hub',
        assignedPos: ['pos_01'],
      );
      state = state.copyWith(currentUser: user, isLoading: false);
      ref.read(sharedPreferencesProvider).setString('auth_user_email', user.email);
      return true;
    }

    state = state.copyWith(isLoading: false, errorMessage: 'Invalid Admin Password (Enter admin123)');
    return false;
  }

  void switchRoleForDemo(UserRole role) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (role == UserRole.admin || role == UserRole.superAdmin) {
      state = state.copyWith(
        currentUser: const AppUser(
          id: 'usr_admin',
          fullName: 'Administrator',
          email: 'admin@swagpay.com',
          phone: '0240000001',
          role: UserRole.admin,
          branch: 'Accra Central Hub',
          assignedPos: ['pos_01'],
          singleTxnLimit: 50000.0,
          dailyLimit: 200000.0,
        ),
      );
      prefs.setString('auth_user_email', 'admin@swagpay.com');
    } else {
      state = state.copyWith(
        currentUser: const AppUser(
          id: 'usr_teller1',
          fullName: 'Kofi Mensah',
          email: 'teller@swagpay.com',
          phone: '0550402859',
          role: UserRole.teller,
          branch: 'Accra Mall Food Court',
          assignedPos: ['pos_01'],
          singleTxnLimit: 10000.0,
          dailyLimit: 50000.0,
        ),
      );
      prefs.setString('auth_user_email', 'teller@swagpay.com');
    }
  }

  void logout() {
    ref.read(sharedPreferencesProvider).remove('auth_user_email');
    state = const AuthState(currentUser: null);
  }

  void setDeviceAuthorization(bool isAuthorized) {
    state = state.copyWith(isDeviceAuthorized: isAuthorized);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
