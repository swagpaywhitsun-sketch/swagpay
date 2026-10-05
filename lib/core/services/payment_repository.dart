import 'dart:async';
import 'dart:convert';
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
import '../services/auth_vault.dart';
import '../network/api_config.dart';

class PaymentRepository {
  static const _offlineQueueStorageKey = 'swag_offline_queue_data';

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
  final List<PaymentTransaction> _offlineQueue = [];
  ShiftRecord? _activeShift;
  String _clientRemoteIp = '127.0.0.1';
  bool _isLoading = false;
  Object? _lastSyncError;
  bool _hasSynced = false;
  int _dataVersion = 0;

  bool get isLoading => _isLoading;
  String get clientRemoteIp => _clientRemoteIp;
  int get dataVersion => _dataVersion;

  /// Null once the latest backend sync completed successfully.
  Object? get lastSyncError => _lastSyncError;

  /// True after the first backend sync attempt has finished (success or failure).
  bool get hasSynced => _hasSynced;

  /// Triggers a state bump and notifies all Riverpod provider listeners.
  void notifyListeners() {
    _dataVersion++;
    onChanged?.call();
  }

  @override
  bool operator ==(Object other) => false;

  @override
  int get hashCode => _dataVersion.hashCode;

  PaymentRepository({required this.apiClient, required this.prefs, this.onChanged}) {
    final savedBaseUrl = prefs.getString('custom_base_url');
    if (savedBaseUrl != null && savedBaseUrl.isNotEmpty) {
      apiClient.updateBaseUrl(savedBaseUrl);
    }
    _loadOfflineQueue();
  }

  void _loadOfflineQueue() {
    try {
      final raw = prefs.getString(_offlineQueueStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _offlineQueue.clear();
        for (final item in list) {
          _offlineQueue.add(PaymentTransaction.fromJson(item as Map<String, dynamic>));
        }
        // Merge unsynced offline transactions into local memory ledger
        final existingIds = _transactions.map((t) => t.id).toSet();
        for (final off in _offlineQueue) {
          if (!existingIds.contains(off.id)) {
            _transactions.insert(0, off);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistOfflineQueue() async {
    try {
      final list = _offlineQueue.map((t) => t.toJson()).toList();
      await prefs.setString(_offlineQueueStorageKey, jsonEncode(list));
    } catch (_) {}
  }

  final Set<String> _deletedTellerIds = {};
  final Set<String> _deletedPosIds = {};

  Future<void>? _activeSync;

  /// Startup, the periodic timer and pull-to-refresh would otherwise issue
  /// overlapping copies of the same requests.
  Future<void> refreshFromBackend({bool force = false}) {
    if (force) {
      return _activeSync = _syncFromBackend().whenComplete(() => _activeSync = null);
    }
    return _activeSync ??= _syncFromBackend().whenComplete(() => _activeSync = null);
  }

  Future<void> _syncFromBackend() async {
    _isLoading = true;
    notifyListeners();
    try {
      _lastSyncError = null;
      final userSnapshot = tokenVault.readUserSnapshot();
      final isTeller = userSnapshot?['role'] == 'teller';
      final currentUserId = userSnapshot?['id'] as String?;
      final currentPosId = userSnapshot?['posId'] as String?;

      // 1. Fetch real transactions with server-side teller scoping
      try {
        String scopeQuery = '';
        if (isTeller) {
          final params = <String>[];
          params.add('scope=me');
          if (currentUserId != null && currentUserId.isNotEmpty) params.add('tellerId=$currentUserId');
          if (currentPosId != null && currentPosId.isNotEmpty) params.add('posId=$currentPosId');
          scopeQuery = '?${params.join('&')}';
        }

        final txRes = await apiClient.get<List<dynamic>>('${ApiConfig.transactions}$scopeQuery');
        if (txRes.data != null) {
          final serverTxns = txRes.data!.map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>)).toList();
          
          // Keep offline counter transactions the server has not received yet
          final serverRefs = serverTxns.map((t) => t.reference).toSet();
          final localOnly = _transactions.where((t) => t.id.startsWith('tx_off_') && !serverRefs.contains(t.reference));
          
          _transactions = [...localOnly, ...serverTxns];
        }
      } catch (e) {
        _lastSyncError ??= e;
      }

      // 2. Fetch real tellers
      try {
        final telRes = await apiClient.get<List<dynamic>>(ApiConfig.tellers);
        if (telRes.data != null) {
          _tellers = telRes.data!
              .map((e) {
                final m = e as Map<String, dynamic>;
                return AppUser(
                  id: (m['id'] ?? '').toString(),
                  fullName: (m['name'] ?? 'Staff Member').toString(),
                  email: (m['email'] ?? '').toString(),
                  phone: (m['phone'] ?? '').toString(),
                  role: (m['role']?.toString().toUpperCase() ?? '').contains('ADMIN') ? UserRole.admin : UserRole.teller,
                  assignedPos: [m['posId']?.toString() ?? 'pos_01'],
                  singleTxnLimit: (m['singleTxnLimit'] as num?)?.toDouble() ?? 500000.0,
                  dailyLimit: (m['dailyLimit'] as num?)?.toDouble() ?? 5000000.0,
                  isActive: (m['active'] as num?)?.toInt() == 1,
                );
              })
              .where((t) => !_deletedTellerIds.contains(t.id))
              .toList();
        }
      } catch (_) {}

      // 3. Fetch real POS terminals
      try {
        final posRes = await apiClient.get<List<dynamic>>(ApiConfig.posDevices);
        if (posRes.data != null) {
          _posDevices = posRes.data!
              .map((e) {
                final m = e as Map<String, dynamic>;
                return PosDevice(
                  id: (m['id'] ?? '').toString(),
                  name: (m['name'] ?? 'POS Terminal').toString(),
                  serialNumber: (m['code'] ?? m['serialNumber'] ?? '').toString(),
                  deviceFingerprint: (m['code'] ?? m['serialNumber'] ?? '').toString(),
                  branch: (m['location'] ?? m['branch'] ?? 'Main').toString(),
                  location: (m['location'] ?? m['branch'] ?? '').toString(),
                  status: (m['active'] as num?)?.toInt() == 1 ? PosStatus.online : PosStatus.offline,
                  isWhitelisted: true,
                  lastSeen: DateTime.now(),
                );
              })
              .where((p) => !_deletedPosIds.contains(p.id))
              .toList();
        }
      } catch (_) {}

      // 4. Fetch real refund requests
      try {
        final refRes = await apiClient.get<List<dynamic>>(ApiConfig.refunds);
        if (refRes.data != null) {
          _refundRequests = refRes.data!.map((e) => RefundRequest.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      // 5. Fetch real settlements
      try {
        final setRes = await apiClient.get<List<dynamic>>(ApiConfig.settlements);
        if (setRes.data != null) {
          _settlements = setRes.data!.map((e) => SettlementRecord.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      // 6. Fetch real client remote IP and audit logs
      try {
        final ipRes = await apiClient.get<Map<String, dynamic>>('/api/system/network-info');
        if (ipRes.data != null && ipRes.data!['clientIp'] != null) {
          _clientRemoteIp = ipRes.data!['clientIp'].toString();
        }
      } catch (_) {}

      try {
        final audRes = await apiClient.get<List<dynamic>>(ApiConfig.auditLogs);
        if (audRes.data != null) {
          _auditLogs = audRes.data!.map((e) {
            final m = e as Map<String, dynamic>;
            final actorDisplay = m['userName'] as String? ?? m['actorId'] as String? ?? 'System';
            final roleDisplay = m['userRole'] as String? ?? 'Admin/Staff';
            final target = '${m['targetType'] ?? ''} ${m['targetId'] ?? ''}'.trim();

            String deviceDisplay = 'Web Portal';
            String detailsDisplay = '—';
            final rawMeta = m['metadata'];
            if (rawMeta != null) {
              if (rawMeta is Map) {
                if (rawMeta['device'] != null) deviceDisplay = rawMeta['device'].toString();
                final copy = Map<String, dynamic>.from(rawMeta)..remove('device');
                detailsDisplay = copy.isNotEmpty ? copy.toString() : '—';
              } else {
                final str = rawMeta.toString().trim();
                if (str.isNotEmpty && str != 'null' && str != 'NULL') {
                  try {
                    final decoded = jsonDecode(str);
                    if (decoded is Map) {
                      if (decoded['device'] != null) deviceDisplay = decoded['device'].toString();
                      final copy = Map<String, dynamic>.from(decoded)..remove('device');
                      detailsDisplay = copy.isNotEmpty ? jsonEncode(copy) : '—';
                    } else {
                      detailsDisplay = str;
                    }
                  } catch (_) {
                    detailsDisplay = str;
                  }
                }
              }
            }

            var recordedIp = (m['ipAddress'] ?? '').toString().trim();
            if (recordedIp.isEmpty || recordedIp == '127.0.0.1' || recordedIp == '::1') {
              if (_clientRemoteIp.isNotEmpty && _clientRemoteIp != '127.0.0.1') {
                recordedIp = _clientRemoteIp;
              } else {
                recordedIp = '127.0.0.1';
              }
            }

            return AuditLog(
              id: (m['id'] ?? 'log_${DateTime.now().millisecondsSinceEpoch}').toString(),
              timestamp: m['createdAt'] != null ? DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
              user: actorDisplay,
              role: roleDisplay,
              action: (m['action'] ?? 'EVENT').toString(),
              entity: target.isNotEmpty ? target : 'SYSTEM',
              details: detailsDisplay,
              ip: recordedIp,
              device: deviceDisplay,
            );
          }).toList();
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      _isLoading = false;
      _hasSynced = true;
      notifyListeners();
    }
  }

  // --- REAL CUSTOMER LOOKUP (WHITSUNPAY) ---
  Future<Customer?> lookupCustomer(String phone, {MoMoNetwork? network}) async {
    final clean = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.length < 9) return null;

    try {
      final query = network != null ? '?network=${network.name}' : '';
      final res = await apiClient.get<Map<String, dynamic>>('${ApiConfig.accountLookup}/$clean$query');
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

    return null;
  }

  // --- REAL MOMO PAYMENT INITIATION ---
  Future<Map<String, dynamic>> initiateMoMoPayment({
    required String momoNumber,
    required double amount,
    String? customerName,
    required String tellerId,
    required String posId,
    MoMoNetwork? network,
  }) async {
    final effectivePos = posId.trim().isNotEmpty
        ? posId.trim()
        : (_posDevices.isNotEmpty ? _posDevices.first.id : 'POS-01');

    final res = await apiClient.post<Map<String, dynamic>>(
      ApiConfig.initiatePayment,
      data: {
        'momoNumber': momoNumber,
        'amount': amount,
        if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
        'tellerId': tellerId,
        'posId': effectivePos,
        if (network != null) 'network': network.name,
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
      final idx = _transactions.indexWhere((t) => t.reference == reference);
      if (idx != -1) {
        _transactions[idx] = txn;
      } else {
        _transactions.insert(0, txn);
      }
      onChanged?.call();
      return txn;
    }
    throw ApiException(message: 'Could not fetch transaction status');
  }

  // --- TRANSACTIONS WITH STRICT LOCAL & ROLE SCOPING ---
  List<PaymentTransaction> getTransactions({
    String? searchQuery,
    TransactionStatus? statusFilter,
    MoMoNetwork? networkFilter,
    String? tellerId,
  }) {
    final userSnapshot = tokenVault.readUserSnapshot();
    final isTeller = userSnapshot?['role'] == 'teller';
    final currentUserId = tellerId ?? userSnapshot?['id'] as String?;

    return _transactions.where((t) {
      // Strict teller isolation: each teller sees ONLY transactions they processed
      if (isTeller && currentUserId != null && currentUserId.isNotEmpty) {
        if (t.tellerId != currentUserId && !t.id.startsWith('tx_off_')) {
          return false;
        }
      }

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

  // --- REFUNDS WITH SAFETY GUARDS & RE-VALIDATION ---
  List<RefundRequest> getRefundRequests() => List.unmodifiable(_refundRequests);

  Future<void> submitRefundRequest({
    required String transactionId,
    required String reason,
    String? notes,
    required String tellerId,
    required String tellerName,
  }) async {
    final txn = getTransactionById(transactionId);
    if (txn == null) {
      throw ApiException(message: 'Transaction not found in local or server ledger');
    }

    if (txn.status != TransactionStatus.success) {
      throw ApiException(message: 'Only successful transactions can be submitted for refund');
    }

    // Check for existing pending refund
    final hasPending = _refundRequests.any((r) => r.transactionId == txn.id && r.status == RefundStatus.pending);
    if (hasPending) {
      throw ApiException(message: 'A refund request is already pending for this transaction');
    }

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
    final idx = _refundRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final current = _refundRequests[idx];
      _refundRequests[idx] = RefundRequest(
        id: current.id,
        transactionId: current.transactionId,
        reference: current.reference,
        amount: current.amount,
        customerNumber: current.customerNumber,
        tellerId: current.tellerId,
        tellerName: current.tellerName,
        reason: current.reason,
        notes: current.notes,
        status: approve ? RefundStatus.approved : RefundStatus.rejected,
        createdAt: current.createdAt,
        reviewedAt: DateTime.now(),
        reviewedBy: adminName ?? 'Admin',
        rejectionReason: reason,
      );
      notifyListeners();
    }
    try {
      await apiClient.post(
        '${ApiConfig.refunds}/$requestId/review',
        data: {
          'approve': approve,
          'reviewerName': adminName ?? 'Admin',
          'rejectionReason': reason,
        },
      );
      await refreshFromBackend();
    } catch (_) {
      await refreshFromBackend();
      rethrow;
    }
  }

  // --- GETTERS ---
  List<AppUser> getTellers() => List.unmodifiable(_tellers);
  List<PosDevice> getPosDevices() => List.unmodifiable(_posDevices);
  List<SettlementRecord> getSettlements() => List.unmodifiable(_settlements);
  List<AuditLog> getAuditLogs() => List.unmodifiable(_auditLogs);
  List<AppNotificationItem> getNotifications() => List.unmodifiable(_notifications);

  Future<String?> addTeller(AppUser teller, {String? initialPassword}) async {
    // Optimistic local add
    _tellers.add(teller);
    notifyListeners();
    try {
      final res = await apiClient.post<Map<String, dynamic>>(
        ApiConfig.tellers,
        data: {
          'id': teller.id,
          'name': teller.fullName,
          'email': teller.email,
          'phone': teller.phone,
          'role': teller.role == UserRole.admin ? 'ADMIN' : 'TELLER',
          'posId': teller.assignedPos.isNotEmpty ? teller.assignedPos.first : 'ANY_POS',
          'singleTxnLimit': teller.singleTxnLimit,
          'dailyLimit': teller.dailyLimit,
          'initialPassword': initialPassword ?? 'Swag@1234',
        },
      );
      await refreshFromBackend(force: true);
      return (res.data?['initialPassword'] ?? res.data?['tempSecret']) as String? ?? initialPassword ?? 'Swag@1234';
    } catch (e) {
      _tellers.removeWhere((t) => t.id == teller.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTeller(String tellerId) async {
    _deletedTellerIds.add(tellerId);
    final backup = List<AppUser>.from(_tellers);
    _tellers.removeWhere((t) => t.id == tellerId);
    notifyListeners();
    try {
      await apiClient.delete('${ApiConfig.tellers}/$tellerId');
      await refreshFromBackend(force: true);
    } catch (e) {
      _deletedTellerIds.remove(tellerId);
      _tellers = backup;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTellerLimits(
    String tellerId, {
    required double singleTxnLimit,
    required double dailyLimit,
  }) async {
    final idx = _tellers.indexWhere((t) => t.id == tellerId);
    if (idx != -1) {
      _tellers[idx] = _tellers[idx].copyWith(
        singleTxnLimit: singleTxnLimit,
        dailyLimit: dailyLimit,
      );
      notifyListeners();
    }
    try {
      await apiClient.put(
        '${ApiConfig.tellers}/$tellerId/limits',
        data: {
          'singleTxnLimit': singleTxnLimit,
          'dailyLimit': dailyLimit,
        },
      );
      await refreshFromBackend(force: true);
    } catch (e) {
      await refreshFromBackend(force: true);
      rethrow;
    }
  }

  Future<void> addPosDevice(PosDevice pos) async {
    _posDevices.add(pos);
    notifyListeners();
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
      await refreshFromBackend(force: true);
    } catch (e) {
      _posDevices.removeWhere((p) => p.id == pos.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updatePosDevice(PosDevice pos) async {
    final idx = _posDevices.indexWhere((p) => p.id == pos.id);
    if (idx != -1) {
      _posDevices[idx] = pos;
      notifyListeners();
    }
    try {
      await apiClient.put(
        '${ApiConfig.posDevices}/${pos.id}',
        data: {
          'name': pos.name,
          'code': pos.serialNumber,
          'location': pos.location,
          'active': pos.status == PosStatus.online ? 1 : 0,
        },
      );
      await refreshFromBackend(force: true);
    } catch (_) {}
  }

  Future<void> deletePosDevice(String posId) async {
    _deletedPosIds.add(posId);
    final backup = List<PosDevice>.from(_posDevices);
    _posDevices.removeWhere((p) => p.id == posId);
    notifyListeners();
    try {
      await apiClient.delete('${ApiConfig.posDevices}/$posId');
      await refreshFromBackend(force: true);
    } catch (e) {
      _deletedPosIds.remove(posId);
      _posDevices = backup;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final res = await apiClient.post<Map<String, dynamic>>(
      ApiConfig.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    if (res.data != null && res.data!['success'] == true) {
      return;
    }
    throw ApiException(message: res.data?['message']?.toString() ?? 'Failed to change password');
  }

  // --- PERSISTENT OFFLINE QUEUE (OUTBOX PATTERN) ---
  List<PaymentTransaction> getOfflineQueue() => List.unmodifiable(_offlineQueue);

  PaymentTransaction recordOfflineTransaction({
    required String momoNumber,
    required double amount,
    String? customerName,
    required String tellerId,
    String tellerName = 'Counter Teller',
    required String posId,
    MoMoNetwork? network,
  }) {
    final effectivePos = posId.trim().isNotEmpty
        ? posId.trim()
        : (_posDevices.isNotEmpty ? _posDevices.first.id : 'POS-01');
    final now = DateTime.now();
    final ref = 'OFF-${now.millisecondsSinceEpoch}-${(1000 + (now.microsecond % 9000))}';
    final rcpt = 'RCPT-OFF-${now.millisecondsSinceEpoch % 1000000}';
    final txn = PaymentTransaction(
      id: 'tx_off_${now.millisecondsSinceEpoch}',
      reference: ref,
      amount: amount,
      currency: 'GH₵',
      status: TransactionStatus.success,
      network: network ?? MoMoNetwork.mtn,
      customerNumber: momoNumber,
      customerPhone: momoNumber,
      customerName: customerName ?? 'Counter Customer',
      tellerId: tellerId,
      tellerName: tellerName,
      posId: effectivePos,
      timestamp: now,
      receiptNumber: rcpt,
      idempotencyKey: 'idemp_off_${now.millisecondsSinceEpoch}',
    );
    _offlineQueue.insert(0, txn);
    _transactions.insert(0, txn);
    _persistOfflineQueue();
    onChanged?.call();
    return txn;
  }

  /// Syncs offline collections by uploading each item with deduplicating Idempotency Key.
  /// Transactions remain in the queue until acknowledged by the server.
  Future<int> syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return 0;

    int syncedCount = 0;
    final toSync = List<PaymentTransaction>.from(_offlineQueue);

    for (final txn in toSync) {
      try {
        final res = await apiClient.post<Map<String, dynamic>>(
          ApiConfig.initiatePayment,
          data: {
            'momoNumber': txn.customerNumber,
            'amount': txn.amount,
            'customerName': txn.customerName,
            'tellerId': txn.tellerId,
            'posId': txn.posId,
            'offlineReference': txn.reference,
            'offlineRecordedAt': txn.timestamp.toIso8601String(),
          },
          idempotencyKey: txn.idempotencyKey,
        );

        if (res.data != null && res.data!['success'] == true) {
          _offlineQueue.removeWhere((item) => item.id == txn.id || item.reference == txn.reference);
          syncedCount++;
        }
      } catch (e) {
        // Stop batch on network breakdown, retain remaining in outbox queue
        break;
      }
    }

    await _persistOfflineQueue();
    await refreshFromBackend();
    onChanged?.call();
    return syncedCount;
  }

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
