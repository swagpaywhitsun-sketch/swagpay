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
  final String? gatewayReference;
  final String customerNumber;
  final String customerName;
  final String customerPhone;
  final double amount;
  final double fee;
  final double totalCharged;
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
  final String? merchantName;
  final String? merchantAddress;
  final String? shopLocation;

  const PaymentTransaction({
    required this.id,
    required this.reference,
    this.gatewayReference,
    required this.customerNumber,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    this.fee = 0.0,
    this.totalCharged = 0.0,
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
    this.merchantName,
    this.merchantAddress,
    this.shopLocation,
  });

  /// Total amount including processing fee (not separated)
  double get totalAmount {
    if (totalCharged > 0) return totalCharged;
    return amount + fee;
  }

  /// Reference coming from the Mobile operator (falls back to system reference if not yet assigned)
  String get operatorReference {
    if (gatewayReference != null && gatewayReference!.trim().isNotEmpty) {
      return gatewayReference!.trim();
    }
    return reference;
  }

  static String defaultMerchantName = 'KOFI & SONS ELECTRONICS';
  static String defaultMerchantAddress = 'Plot 48 Spintex Road, Accra';
  static String defaultShopLocation = 'Accra Mall Branch #12';

  /// Effective merchant / shop name for receipt header
  String get effectiveMerchantName {
    if (merchantName != null && merchantName!.trim().isNotEmpty) return merchantName!.trim();
    return defaultMerchantName;
  }

  /// Effective merchant address for receipt header
  String get effectiveMerchantAddress {
    if (merchantAddress != null && merchantAddress!.trim().isNotEmpty) return merchantAddress!.trim();
    return defaultMerchantAddress;
  }

  /// Effective shop location for receipt header
  String get effectiveShopLocation {
    if (shopLocation != null && shopLocation!.trim().isNotEmpty) return shopLocation!.trim();
    if (branch != null && branch!.trim().isNotEmpty) return branch!.trim();
    return defaultShopLocation;
  }

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

  String get displayPhone {
    final num = customerNumber.trim();
    if (num.isNotEmpty && num != 'null') return num;
    final phone = customerPhone.trim();
    if (phone.isNotEmpty && phone != 'null') return phone;
    return '—';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'gatewayReference': gatewayReference,
        'customerNumber': displayPhone,
        'customerName': customerName,
        'customerPhone': displayPhone,
        'amount': amount,
        'fee': fee,
        'totalCharged': totalAmount,
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
        'merchantName': merchantName,
        'merchantAddress': merchantAddress,
        'shopLocation': shopLocation,
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

    final rawPhone = (json['momoNumber'] as String? ??
            json['customerPhone'] as String? ??
            json['customerNumber'] as String? ??
            json['phone'] as String? ??
            '')
        .trim();

    final rawName = (json['customerName'] as String? ??
            json['name'] as String? ??
            json['accountName'] as String? ??
            json['customer_name'] as String? ??
            json['payerName'] as String? ??
            json['debitPartyName'] as String? ??
            (json['data'] is Map ? (json['data']['customerName'] ?? json['data']['name'] ?? json['data']['accountName']) as String? : null))
        ?.trim();
    final resolvedName = (rawName != null && rawName.isNotEmpty && rawName != rawPhone)
        ? rawName
        : (rawPhone.isNotEmpty ? rawPhone : 'Walk-in Customer');

    return PaymentTransaction(
      id: json['id'] as String? ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
      reference: json['reference'] as String? ?? '',
      gatewayReference: json['gatewayReference'] as String? ??
          json['gateway_reference'] as String? ??
          json['operatorReference'] as String? ??
          json['operator_reference'] as String? ??
          json['externalReference'] as String?,
      customerNumber: rawPhone,
      customerName: resolvedName,
      customerPhone: rawPhone,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      totalCharged: (json['totalCharged'] as num?)?.toDouble() ??
          (json['total_charged'] as num?)?.toDouble() ??
          0.0,
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
      merchantName: json['merchantName'] as String? ?? json['merchant_name'] as String?,
      merchantAddress: json['merchantAddress'] as String? ?? json['merchant_address'] as String?,
      shopLocation: json['shopLocation'] as String? ?? json['shop_location'] as String?,
    );
  }

  PaymentTransaction copyWith({
    String? id,
    String? reference,
    String? gatewayReference,
    String? customerNumber,
    String? customerName,
    String? customerPhone,
    double? amount,
    double? fee,
    double? totalCharged,
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
    String? merchantName,
    String? merchantAddress,
    String? shopLocation,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      gatewayReference: gatewayReference ?? this.gatewayReference,
      customerNumber: customerNumber ?? this.customerNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      totalCharged: totalCharged ?? this.totalCharged,
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
      merchantName: merchantName ?? this.merchantName,
      merchantAddress: merchantAddress ?? this.merchantAddress,
      shopLocation: shopLocation ?? this.shopLocation,
    );
  }
}
