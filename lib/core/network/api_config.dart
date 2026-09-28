class ApiConfig {
  static String baseUrl = 'http://localhost:5050';
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
