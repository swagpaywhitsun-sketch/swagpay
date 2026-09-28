import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_records.dart';
import '../models/customer.dart';
import '../models/pos_device.dart';
import '../models/refund_request.dart';
import '../models/settlement.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';

class PaymentRepository {
  final ApiClient apiClient;
  final SharedPreferences prefs;
  final VoidCallback? onChanged;

  List<PaymentTransaction> _transactions = [];
  List<AppUser> _tellers = [];
  List<PosDevice> _posDevices = [];
  List<RefundRequest> _refundRequests = [];
  List<SettlementRecord> _settlements = [];
  List<AuditLog> _auditLogs = [];
  final List<AppNotificationItem> _notifications = [];
  ShiftRecord? _activeShift;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  PaymentRepository({required this.apiClient, required this.prefs, this.onChanged}) {
    final savedBaseUrl = prefs.getString('custom_base_url');
    if (savedBaseUrl != null && savedBaseUrl.isNotEmpty) {
      apiClient.updateBaseUrl(savedBaseUrl);
    }
    // Refresh live data from backend immediately
    refreshFromBackend();
  }

  Future<void> refreshFromBackend() async {
    try {
      // 1. Fetch real transactions
      final txRes = await apiClient.get<List<dynamic>>(ApiConfig.transactions);
      if (txRes.data != null) {
        _transactions = txRes.data!.map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>)).toList();
      }

      // 2. Fetch real tellers
      final telRes = await apiClient.get<List<dynamic>>(ApiConfig.tellers);
      if (telRes.data != null) {
        _tellers = telRes.data!.map((e) {
          final m = e as Map<String, dynamic>;
          return AppUser(
            id: m['id'] as String,
            fullName: m['name'] as String,
            email: m['email'] as String,
            phone: m['phone'] as String? ?? '',
            role: (m['role'] as String? ?? '').contains('ADMIN') ? UserRole.admin : UserRole.teller,
            assignedPos: [m['posId'] as String? ?? 'pos_01'],
            isActive: (m['active'] as num?)?.toInt() == 1,
          );
        }).toList();
      }

      // 3. Fetch real POS terminals
      final posRes = await apiClient.get<List<dynamic>>(ApiConfig.posDevices);
      if (posRes.data != null) {
        _posDevices = posRes.data!.map((e) {
          final m = e as Map<String, dynamic>;
          return PosDevice(
            id: m['id'] as String,
            name: m['name'] as String,
            serialNumber: m['code'] as String,
            deviceFingerprint: m['code'] as String,
            branch: m['location'] as String? ?? 'Main',
            location: m['location'] as String? ?? '',
            status: (m['active'] as num?)?.toInt() == 1 ? PosStatus.online : PosStatus.offline,
            isWhitelisted: true,
            lastSeen: DateTime.now(),
          );
        }).toList();
      }

      // 4. Fetch real refund requests
      final refRes = await apiClient.get<List<dynamic>>(ApiConfig.refunds);
      if (refRes.data != null) {
        _refundRequests = refRes.data!.map((e) => RefundRequest.fromJson(e as Map<String, dynamic>)).toList();
      }

      // 5. Fetch real settlements
      try {
        final setRes = await apiClient.get<List<dynamic>>(ApiConfig.settlements);
        if (setRes.data != null) {
          _settlements = setRes.data!.map((e) => SettlementRecord.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      // 6. Fetch real audit logs
      final audRes = await apiClient.get<List<dynamic>>(ApiConfig.auditLogs);
      if (audRes.data != null) {
        _auditLogs = audRes.data!.map((e) {
          final m = e as Map<String, dynamic>;
          return AuditLog(
            id: m['id'] as String,
            timestamp: m['createdAt'] != null ? DateTime.tryParse(m['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
            user: m['actorId'] as String? ?? 'System',
            role: 'User',
            action: m['action'] as String? ?? 'LOG',
            entity: '${m['targetType'] ?? ''} ${m['targetId'] ?? ''}',
            details: m['metadata'] as String? ?? '',
            ip: m['ipAddress'] as String? ?? '127.0.0.1',
            device: 'POS-01',
          );
        }).toList();
      }
    } catch (_) {
      // Non-fatal if offline
    } finally {
      _isLoading = false;
      onChanged?.call();
    }
  }

  // --- REAL CUSTOMER LOOKUP (WHITSUNPAY) ---
  Future<Customer?> lookupCustomer(String phone) async {
    final clean = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.length < 9) return null;

    try {
      final res = await apiClient.get<Map<String, dynamic>>('${ApiConfig.accountLookup}/$clean');
      if (res.data != null && res.data!['name'] != null) {
        return Customer(
          id: clean,
          accountNumber: clean,
          name: res.data!['name'] as String,
          phone: clean,
          email: '',
          outstandingBalance: 0.0,
        );
      }
    } catch (_) {}

    return Customer(
      id: clean,
      accountNumber: clean,
      name: 'Subscriber ($clean)',
      phone: clean,
      email: '',
      outstandingBalance: 0.0,
    );
  }

  // --- REAL MOMO PAYMENT INITIATION ---
  Future<Map<String, dynamic>> initiateMoMoPayment({
    required String momoNumber,
    required double amount,
    String? customerName,
    required String tellerId,
    required String posId,
  }) async {
    final res = await apiClient.post<Map<String, dynamic>>(
      ApiConfig.initiatePayment,
      data: {
        'momoNumber': momoNumber,
        'amount': amount,
        'customerName': customerName ?? 'Subscriber',
        'tellerId': tellerId,
        'posId': posId,
      },
    );

    if (res.data != null && res.data!['success'] == true) {
      return res.data!;
    }
    throw ApiException(message: res.data?['message']?.toString() ?? 'Failed to initiate MoMo prompt');
  }

  // --- REAL PAYMENT STATUS CHECK ---
  Future<PaymentTransaction> checkPaymentStatus(String reference) async {
    final res = await apiClient.get<Map<String, dynamic>>('${ApiConfig.paymentStatus}/$reference');
    if (res.data != null) {
      final txn = PaymentTransaction.fromJson(res.data!);
      // Update in local cache list
      final idx = _transactions.indexWhere((t) => t.reference == reference);
      if (idx != -1) {
        _transactions[idx] = txn;
      } else {
        _transactions.insert(0, txn);
      }
      return txn;
    }
    throw ApiException(message: 'Could not fetch transaction status');
  }

  // --- TRANSACTIONS ---
  List<PaymentTransaction> getTransactions({
    String? searchQuery,
    TransactionStatus? statusFilter,
    MoMoNetwork? networkFilter,
  }) {
    return _transactions.where((t) {
      if (statusFilter != null && t.status != statusFilter) return false;
      if (networkFilter != null && t.network != networkFilter) return false;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final match = t.reference.toLowerCase().contains(q) ||
            t.customerNumber.toLowerCase().contains(q) ||
            t.customerName.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  PaymentTransaction? getTransactionById(String id) {
    try {
      return _transactions.firstWhere((t) => t.id == id || t.reference == id);
    } catch (_) {
      return null;
    }
  }

  // --- REFUNDS ---
  List<RefundRequest> getRefundRequests() => List.unmodifiable(_refundRequests);

  Future<void> submitRefundRequest({
    required String transactionId,
    required String reason,
    String? notes,
    required String tellerId,
    required String tellerName,
  }) async {
    final txn = getTransactionById(transactionId);
    if (txn == null) throw ApiException(message: 'Transaction not found');

    await apiClient.post(
      ApiConfig.refunds,
      data: {
        'transactionId': txn.id,
        'reference': txn.reference,
        'amount': txn.amount,
        'tellerId': tellerId,
        'tellerName': tellerName,
        'reason': reason,
        'notes': notes,
      },
    );
    await refreshFromBackend();
  }

  Future<void> reviewRefund(String requestId, bool approve, {String? adminName, String? reason}) async {
    await apiClient.post(
      '${ApiConfig.refunds}/$requestId/review',
      data: {
        'approve': approve,
        'reviewerName': adminName ?? 'Admin',
        'rejectionReason': reason,
      },
    );
    await refreshFromBackend();
  }

  // --- GETTERS ---
  List<AppUser> getTellers() => List.unmodifiable(_tellers);
  List<PosDevice> getPosDevices() => List.unmodifiable(_posDevices);
  List<SettlementRecord> getSettlements() => List.unmodifiable(_settlements);
  List<AuditLog> getAuditLogs() => List.unmodifiable(_auditLogs);
  List<AppNotificationItem> getNotifications() => List.unmodifiable(_notifications);

  Future<void> addTeller(AppUser teller) async {
    try {
      await apiClient.post(
        ApiConfig.tellers,
        data: {
          'id': teller.id,
          'name': teller.fullName,
          'email': teller.email,
          'phone': teller.phone,
          'role': teller.role == UserRole.admin ? 'ADMIN' : 'TELLER',
          'posId': teller.assignedPos.isNotEmpty ? teller.assignedPos.first : 'pos_01',
        },
      );
      await refreshFromBackend();
    } catch (_) {
      _tellers.add(teller);
      onChanged?.call();
    }
  }

  Future<void> addPosDevice(PosDevice pos) async {
    try {
      await apiClient.post(
        ApiConfig.posDevices,
        data: {
          'id': pos.id,
          'code': pos.serialNumber,
          'name': pos.name,
          'location': pos.location,
        },
      );
      await refreshFromBackend();
    } catch (_) {
      _posDevices.add(pos);
      onChanged?.call();
    }
  }

  Future<void> updatePosDevice(PosDevice pos) async {
    final idx = _posDevices.indexWhere((p) => p.id == pos.id);
    if (idx != -1) {
      _posDevices[idx] = pos;
      onChanged?.call();
    }
  }

  // --- OFFLINE QUEUE ---
  List<PaymentTransaction> getOfflineQueue() => const [];
  Future<int> syncOfflineQueue() async => 0;

  // --- SHIFTS ---
  ShiftRecord? get activeShift {
    if (_activeShift != null) {
      final successTxns = _transactions.where((t) => t.status == TransactionStatus.success).toList();
      final totalCollected = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
      return _activeShift!.copyWith(
        totalCollected: totalCollected,
        totalCount: _transactions.length,
        successCount: successTxns.length,
        failedCount: _transactions.length - successTxns.length,
        cashExpected: totalCollected,
      );
    }
    return null;
  }

  ShiftRecord getOrCreateActiveShift({String? tellerId, String? tellerName}) {
    if (_activeShift != null && !_activeShift!.isClosed) {
      return activeShift!;
    }
    final successTxns = _transactions.where((t) => t.status == TransactionStatus.success).toList();
    final totalCollected = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    _activeShift = ShiftRecord(
      id: 'shift_${DateTime.now().millisecondsSinceEpoch}',
      tellerId: tellerId ?? 'usr_teller',
      tellerName: tellerName ?? 'Teller Cashier',
      startTime: DateTime.now().subtract(const Duration(hours: 3)),
      totalCollected: totalCollected,
      totalCount: _transactions.length,
      successCount: successTxns.length,
      failedCount: _transactions.length - successTxns.length,
      cashExpected: totalCollected,
      isClosed: false,
    );
    return _activeShift!;
  }

  Future<ShiftRecord> startShift({required String tellerId, required String tellerName}) async {
    final successTxns = _transactions.where((t) => t.status == TransactionStatus.success).toList();
    final totalCollected = successTxns.fold<double>(0.0, (acc, t) => acc + t.amount);
    _activeShift = ShiftRecord(
      id: 'shift_${DateTime.now().millisecondsSinceEpoch}',
      tellerId: tellerId,
      tellerName: tellerName,
      startTime: DateTime.now(),
      totalCollected: totalCollected,
      totalCount: _transactions.length,
      successCount: successTxns.length,
      failedCount: _transactions.length - successTxns.length,
      cashExpected: totalCollected,
      isClosed: false,
    );
    onChanged?.call();
    return _activeShift!;
  }

  Future<ShiftRecord> closeShift({required double cashActual, String? notes}) async {
    final current = getOrCreateActiveShift();
    _activeShift = current.copyWith(
      endTime: DateTime.now(),
      cashActual: cashActual,
      variance: cashActual - current.cashExpected,
      isClosed: true,
      notes: notes,
    );
    onChanged?.call();
    return _activeShift!;
  }
}
