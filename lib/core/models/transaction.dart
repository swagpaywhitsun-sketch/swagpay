enum TransactionStatus {
  pending,
  success,
  failed,
  refunded,
}

enum MoMoNetwork {
  mtn,
  vodafone,
  airtel,
}

extension MoMoNetworkHelper on MoMoNetwork {
  String get carrierName {
    switch (this) {
      case MoMoNetwork.mtn:
        return 'MTN';
      case MoMoNetwork.vodafone:
        return 'Telecel';
      case MoMoNetwork.airtel:
        return 'AT';
    }
  }

  String get serviceName {
    switch (this) {
      case MoMoNetwork.mtn:
        return 'MTN MoMo';
      case MoMoNetwork.vodafone:
        return 'Telecel Cash';
      case MoMoNetwork.airtel:
        return 'AT Money';
    }
  }

  String get label {
    switch (this) {
      case MoMoNetwork.mtn:
        return 'MTN';
      case MoMoNetwork.vodafone:
        return 'Telecel';
      case MoMoNetwork.airtel:
        return 'AT';
    }
  }
}

class PaymentTransaction {
  final String id;
  final String reference;
  final String customerNumber;
  final String customerName;
  final String customerPhone;
  final double amount;
  final String currency;
  final TransactionStatus status;
  final MoMoNetwork network;
  final DateTime timestamp;
  final String tellerId;
  final String tellerName;
  final String posId;
  final String? branch;
  final String? receiptNumber;
  final String? notes;
  final String? failureReason;
  final String idempotencyKey;

  const PaymentTransaction({
    required this.id,
    required this.reference,
    required this.customerNumber,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    this.currency = 'GH₵',
    required this.status,
    this.network = MoMoNetwork.mtn,
    required this.timestamp,
    required this.tellerId,
    required this.tellerName,
    required this.posId,
    this.branch,
    this.receiptNumber,
    this.notes,
    this.failureReason,
    required this.idempotencyKey,
  });

  String get networkDisplay {
    switch (network) {
      case MoMoNetwork.mtn:
        return 'MTN MoMo';
      case MoMoNetwork.vodafone:
        return 'Telecel Cash';
      case MoMoNetwork.airtel:
        return 'AT Money';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'customerNumber': customerNumber,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'amount': amount,
        'currency': currency,
        'status': status.name,
        'network': network.name,
        'timestamp': timestamp.toIso8601String(),
        'tellerId': tellerId,
        'tellerName': tellerName,
        'posId': posId,
        'branch': branch,
        'receiptNumber': receiptNumber,
        'notes': notes,
        'failureReason': failureReason,
        'idempotencyKey': idempotencyKey,
      };

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String? ?? 'PENDING').toLowerCase();
    TransactionStatus s;
    if (rawStatus.contains('success') || rawStatus.contains('paid')) {
      s = TransactionStatus.success;
    } else if (rawStatus.contains('fail') || rawStatus.contains('reject')) {
      s = TransactionStatus.failed;
    } else if (rawStatus.contains('refund')) {
      s = TransactionStatus.refunded;
    } else {
      s = TransactionStatus.pending;
    }

    final netStr = (json['network'] as String? ?? 'MTN').toLowerCase();
    MoMoNetwork net = MoMoNetwork.mtn;
    if (netStr.contains('voda') || netStr.contains('telecel')) {
      net = MoMoNetwork.vodafone;
    } else if (netStr.contains('airtel') || netStr.contains('at')) {
      net = MoMoNetwork.airtel;
    }

    return PaymentTransaction(
      id: json['id'] as String? ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
      reference: json['reference'] as String? ?? '',
      customerNumber: json['momoNumber'] as String? ?? json['customerNumber'] as String? ?? '',
      customerName: json['customerName'] as String? ??
          (json['momoNumber'] as String? ?? json['customerNumber'] as String?) ??
          'Counter Customer',
      customerPhone: json['momoNumber'] as String? ?? json['customerPhone'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: 'GH₵',
      status: s,
      network: net,
      timestamp: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now() : DateTime.now()),
      tellerId: json['tellerId'] as String? ?? '',
      tellerName: json['tellerName'] as String? ?? 'Counter Cashier',
      posId: json['posId'] as String? ?? 'pos_01',
      branch: json['branch'] as String?,
      receiptNumber: json['receiptNumber'] as String?,
      notes: json['notes'] as String?,
      failureReason: json['failureReason'] as String?,
      idempotencyKey: json['idempotencyKey'] as String? ?? json['reference'] as String? ?? '',
    );
  }

  PaymentTransaction copyWith({
    String? id,
    String? reference,
    String? customerNumber,
    String? customerName,
    String? customerPhone,
    double? amount,
    String? currency,
    TransactionStatus? status,
    MoMoNetwork? network,
    DateTime? timestamp,
    String? tellerId,
    String? tellerName,
    String? posId,
    String? branch,
    String? receiptNumber,
    String? notes,
    String? failureReason,
    String? idempotencyKey,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      customerNumber: customerNumber ?? this.customerNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      network: network ?? this.network,
      timestamp: timestamp ?? this.timestamp,
      tellerId: tellerId ?? this.tellerId,
      tellerName: tellerName ?? this.tellerName,
      posId: posId ?? this.posId,
      branch: branch ?? this.branch,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
      failureReason: failureReason ?? this.failureReason,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}
