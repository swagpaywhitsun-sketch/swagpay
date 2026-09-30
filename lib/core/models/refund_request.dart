enum RefundStatus {
  pending,
  approved,
  rejected,
}

class RefundRequest {
  final String id;
  final String transactionId;
  final String reference;
  final double amount;
  final String customerNumber;
  final String tellerId;
  final String tellerName;
  final String reason;
  final String? notes;
  final RefundStatus status;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const RefundRequest({
    required this.id,
    required this.transactionId,
    required this.reference,
    required this.amount,
    required this.customerNumber,
    required this.tellerId,
    required this.tellerName,
    required this.reason,
    this.notes,
    this.status = RefundStatus.pending,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'reference': reference,
        'amount': amount,
        'customerNumber': customerNumber,
        'tellerId': tellerId,
        'tellerName': tellerName,
        'reason': reason,
        'notes': notes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
      };

  factory RefundRequest.fromJson(Map<String, dynamic> json) => RefundRequest(
        id: json['id'] as String? ?? '',
        transactionId: json['transactionId'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        customerNumber: json['customerNumber'] as String? ?? '',
        tellerId: json['tellerId'] as String? ?? '',
        tellerName: json['tellerName'] as String? ?? 'Counter Cashier',
        reason: json['reason'] as String? ?? '',
        notes: json['notes'] as String?,
        status: RefundStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == (json['status'] as String? ?? '').toLowerCase(),
          orElse: () => RefundStatus.pending,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        reviewedBy: json['reviewedBy'] as String?,
        reviewedAt: json['reviewedAt'] != null ? DateTime.tryParse(json['reviewedAt'] as String) : null,
        rejectionReason: json['rejectionReason'] as String?,
      );

  RefundRequest copyWith({
    String? id,
    String? transactionId,
    String? reference,
    double? amount,
    String? customerNumber,
    String? tellerId,
    String? tellerName,
    String? reason,
    String? notes,
    RefundStatus? status,
    DateTime? createdAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
  }) {
    return RefundRequest(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      reference: reference ?? this.reference,
      amount: amount ?? this.amount,
      customerNumber: customerNumber ?? this.customerNumber,
      tellerId: tellerId ?? this.tellerId,
      tellerName: tellerName ?? this.tellerName,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
