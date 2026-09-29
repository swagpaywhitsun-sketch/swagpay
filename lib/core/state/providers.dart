import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../services/auth_vault.dart';
import '../services/payment_repository.dart';

// SharedPreferences provider (overridden in main)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// ApiClient provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Notifier to track UI rebuild version (separate from repository lifecycle)
class PaymentVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final paymentVersionProvider = NotifierProvider<PaymentVersionNotifier, int>(PaymentVersionNotifier.new);

// PaymentRepository Notifier — keeps repository alive across data refreshes.
// Using a Notifier ensures the PaymentRepository instance is created ONCE and
// never destroyed/recreated when onChanged fires (which was causing data loss).
class PaymentRepositoryNotifier extends Notifier<int> {
  late PaymentRepository _repo;
  Timer? _refreshTimer;
  bool _live = false;

  @override
  int build() {
    final client = ref.read(apiClientProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    _live = false;
    _repo = PaymentRepository(
      apiClient: client,
      prefs: prefs,
      // A sync can land after this notifier is disposed; state is then gone.
      onChanged: () {
        if (_live) state++;
      },
    );
    // Auto-refresh every 12 seconds to keep data live
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _repo.refreshFromBackend();
    });
    ref.onDispose(() {
      _live = false;
      _refreshTimer?.cancel();
    });
    // build() must not touch state through the repository, so the first sync
    // runs once this notifier exists.
    Future.microtask(() {
      if (_live) _repo.refreshFromBackend();
    });
    _live = true;
    return 0;
  }

  PaymentRepository get repo => _repo;

  Future<void> manualRefresh() => _repo.refreshFromBackend();
}

final paymentRepositoryNotifierProvider =
    NotifierProvider<PaymentRepositoryNotifier, int>(PaymentRepositoryNotifier.new);

// Public provider — consumers watch this and get the stable repository instance.
// Reading paymentRepositoryNotifierProvider ensures consumers rebuild when data changes.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  ref.watch(paymentRepositoryNotifierProvider); // react to data changes
  return ref.read(paymentRepositoryNotifierProvider.notifier).repo;
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

// User Avatar Provider for custom profile picture
class UserAvatarNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('user_profile_avatar');
  }

  void setAvatar(String avatarUrlOrAsset) {
    state = avatarUrlOrAsset;
    ref.read(sharedPreferencesProvider).setString('user_profile_avatar', avatarUrlOrAsset);
  }

  void clearAvatar() {
    state = null;
    ref.read(sharedPreferencesProvider).remove('user_profile_avatar');
  }
}

final userAvatarProvider = NotifierProvider<UserAvatarNotifier, String?>(UserAvatarNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  ApiClient get _client => ref.read(apiClientProvider);

  @override
  AuthState build() {
    // Nothing is trusted locally: a session only exists after resumeSession()
    // validates stored server tokens, or after a successful login.
    return const AuthState(currentUser: null, isDeviceAuthorized: true);
  }

  /// Lets the network layer recover an expired access token without the
  /// provider graph leaking into ApiClient.
  void _wireRefresh() => ApiClient.refreshHandler = refreshNow;

  /// Restores a previous session from the secure vault. Called from the splash
  /// screen before routing decisions are made.
  Future<bool> resumeSession() async {
    _wireRefresh();
    final access = tokenVault.readAccessToken();
    if (access == null || access.isEmpty) return false;
    _client.updateToken(access);
    final user = userFromSession(tokenVault.readUserSnapshot());
    if (user == null) {
      await tokenVault.clearSession();
      return false;
    }
    state = AuthState(currentUser: user);
    unawaited(ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh());
    return true;
  }

  /// Single authentication path. There is no offline fallback identity and no
  /// locally accepted PIN — the server decides who you are.
  Future<bool> _authenticate(String identifier, String password, String role) async {
    _wireRefresh();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await tokenVault.ensureDeviceId();
      final deviceId = tokenVault.readDeviceId() ?? 'unknown-device';
      final deviceName = await DeviceIdentity.describe();

      final res = await _client.post<Map<String, dynamic>>(
        ApiConfig.login,
        data: {
          'identifier': identifier,
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceName,
          if (role.isNotEmpty) 'role': role,
        },
      );

      final data = res.data;
      if (data == null || data['success'] != true || data['token'] == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: data?['message'] as String? ?? 'Sign in failed',
        );
        return false;
      }

      final user = userFromSession(data['user'] as Map<String, dynamic>?);
      if (user == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Server returned an incomplete session');
        return false;
      }

      await tokenVault.saveSession(
        accessToken: data['token'] as String,
        refreshToken: data['refreshToken'] as String?,
        user: data['user'] as Map<String, dynamic>,
      );
      _client.updateToken(data['token'] as String);
      state = AuthState(currentUser: user);
      unawaited(ref.read(paymentRepositoryNotifierProvider.notifier).manualRefresh());
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.statusCode == 403
            ? e.message
            : e.statusCode == 401
                ? 'Invalid credentials'
                : e.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Cannot reach the SwagPay server');
      return false;
    }
  }

  /// Single sign-in entry point. The server returns the caller's real role,
  /// so the client never guesses or asserts one.
  Future<bool> signIn(String identifier, String password) => _authenticate(identifier, password, '');

  void logout() {
    final refresh = tokenVault.readRefreshToken();
    final access = tokenVault.readAccessToken();
    tokenVault.clearSession();
    _client.updateToken(null);
    state = const AuthState(currentUser: null);
    // Best-effort server-side revocation; the local session is already gone.
    if (refresh != null && refresh.isNotEmpty && access != null && access.isNotEmpty) {
      _client
          .post<Map<String, dynamic>>(
        ApiConfig.logout,
        data: {'refreshToken': refresh},
        headers: {'Authorization': 'Bearer $access'},
      )
          .then((_) {})
          .catchError((Object _) {});
    }
  }

  /// Called by ApiClient after a 401: exchanges the refresh token for a new
  /// access token. Returns false when the session is gone for good.
  Future<bool> refreshNow() async {
    final refresh = tokenVault.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiConfig.refresh,
        data: {'refreshToken': refresh},
      );
      final token = res.data?['token'] as String?;
      if (token == null) return false;
      await tokenVault.saveAccessToken(token);
      _client.updateToken(token);
      return true;
    } catch (_) {
      await tokenVault.clearSession();
      _client.updateToken(null);
      state = const AuthState(currentUser: null, errorMessage: 'Session expired, sign in again');
      return false;
    }
  }

  /// Requests a password reset OTP / token for the given identifier (email or phone).
  Future<Map<String, dynamic>?> requestPasswordReset(String identifier) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiConfig.forgotPassword,
        data: {'identifier': identifier},
      );
      state = state.copyWith(isLoading: false);
      return res.data;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Cannot reach the SwagPay server');
      return null;
    }
  }

  /// Submits the reset token / OTP and sets a new password.
  Future<bool> resetPassword({
    required String identifier,
    String? token,
    String? otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiConfig.resetPassword,
        data: {
          'identifier': identifier,
          if (token != null && token.isNotEmpty) 'token': token,
          if (otp != null && otp.isNotEmpty) 'otp': otp,
          'newPassword': newPassword,
        },
      );
      state = state.copyWith(isLoading: false);
      return res.data?['success'] == true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Cannot reach the SwagPay server');
      return false;
    }
  }

  void setDeviceAuthorization(bool isAuthorized) {
    state = state.copyWith(isDeviceAuthorized: isAuthorized);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
