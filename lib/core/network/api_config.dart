import 'package:flutter/foundation.dart';

class ApiConfig {
  static String _resolveBaseUrl() {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb && Uri.base.origin.contains('swagpay.fly.dev')) {
      return Uri.base.origin;
    }
    // Production Fly.io gateway for APK, iOS and Web testing
    return 'https://swagpay.fly.dev';
  }

  static String baseUrl = _resolveBaseUrl();
  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 20;

  // Endpoints
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String changePassword = '/api/auth/change-password';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String accountLookup = '/api/account/lookup';
  static const String initiatePayment = '/api/payments/initiate';
  static const String paymentStatus = '/api/payments/status';
  static const String transactions = '/api/transactions';
  static const String tellers = '/api/tellers';
  static const String posDevices = '/api/pos';
  static const String refunds = '/api/refunds';
  static const String settlements = '/api/settlements';
  static const String auditLogs = '/api/audit-logs';
}
