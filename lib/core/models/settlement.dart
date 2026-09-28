enum SettlementStatus {
  settled,
  unsettled,
  discrepancy,
}

class SettlementRecord {
  final String id;
  final DateTime date;
  final double totalCollected;
  final double totalSettled;
  final double variance;
  final int transactionCount;
  final SettlementStatus status;
  final String? notes;

  const SettlementRecord({
    required this.id,
    required this.date,
    required this.totalCollected,
    required this.totalSettled,
    required this.variance,
    required this.transactionCount,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'totalCollected': totalCollected,
        'totalSettled': totalSettled,
        'variance': variance,
        'transactionCount': transactionCount,
        'status': status.name,
        'notes': notes,
      };

  factory SettlementRecord.fromJson(Map<String, dynamic> json) => SettlementRecord(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        totalCollected: (json['totalCollected'] as num).toDouble(),
        totalSettled: (json['totalSettled'] as num).toDouble(),
        variance: (json['variance'] as num).toDouble(),
        transactionCount: json['transactionCount'] as int,
        status: SettlementStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == (json['status'] as String? ?? '').toLowerCase(),
          orElse: () => SettlementStatus.settled,
        ),
        notes: json['notes'] as String?,
      );
}
