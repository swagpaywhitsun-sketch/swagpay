import 'package:flutter/foundation.dart';

class ApiConfig {
  static String _resolveBaseUrl() {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'http://localhost:8080';
  }

  static String baseUrl = _resolveBaseUrl();
  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 20;

  // Endpoints
  static const String login = '/api/auth/login';
  static const String accountLookup = '/api/account/lookup';
  static const String initiatePayment = '/api/payments/initiate';
  static const String paymentStatus = '/api/payments/status';
  static const String transactions = '/api/transactions';
  static const String tellers = '/api/tellers';
  static const String posDevices = '/api/pos';
  static const String refunds = '/api/refunds';
  static const String auditLogs = '/api/audit-logs';
}
