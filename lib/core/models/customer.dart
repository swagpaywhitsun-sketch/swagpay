class Customer {
  final String id;
  final String accountNumber;
  final String name;
  final String phone;
  final String email;
  final double outstandingBalance;
  final DateTime? lastPaymentDate;

  const Customer({
    required this.id,
    required this.accountNumber,
    required this.name,
    required this.phone,
    required this.email,
    this.outstandingBalance = 0.0,
    this.lastPaymentDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountNumber': accountNumber,
        'name': name,
        'phone': phone,
        'email': email,
        'outstandingBalance': outstandingBalance,
        'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: (json['id'] ?? '').toString(),
        accountNumber: (json['accountNumber'] ?? json['account'] ?? '').toString(),
        name: (json['name'] ?? 'Valued Customer').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        outstandingBalance: (json['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
        lastPaymentDate: json['lastPaymentDate'] != null
            ? DateTime.tryParse(json['lastPaymentDate'].toString())
            : null,
      );
}
