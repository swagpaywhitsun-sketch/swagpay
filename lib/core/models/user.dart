enum UserRole {
  teller,
  seniorTeller,
  admin,
  superAdmin,
}

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String? branch;
  final List<String> assignedPos;
  final double singleTxnLimit;
  final double dailyLimit;
  final bool isActive;
  final DateTime? lastLogin;
  final String? token;
  final String? refreshToken;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.branch,
    this.assignedPos = const [],
    this.singleTxnLimit = 500000.0,
    this.dailyLimit = 5000000.0,
    this.isActive = true,
    this.lastLogin,
    this.token,
    this.refreshToken,
  });

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isTeller => role == UserRole.teller || role == UserRole.seniorTeller;

  String get roleDisplay {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.seniorTeller:
        return 'Senior Teller';
      case UserRole.teller:
        return 'Teller / Cashier';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role.name,
        'branch': branch,
        'assignedPos': assignedPos,
        'singleTxnLimit': singleTxnLimit,
        'dailyLimit': dailyLimit,
        'isActive': isActive,
        'lastLogin': lastLogin?.toIso8601String(),
        'token': token,
        'refreshToken': refreshToken,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.teller,
        ),
        branch: json['branch'] as String?,
        assignedPos: (json['assignedPos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        singleTxnLimit: (json['singleTxnLimit'] as num?)?.toDouble() ?? 500000.0,
        dailyLimit: (json['dailyLimit'] as num?)?.toDouble() ?? 5000000.0,
        isActive: json['isActive'] as bool? ?? true,
        lastLogin: json['lastLogin'] != null ? DateTime.tryParse(json['lastLogin'] as String) : null,
        token: json['token'] as String?,
        refreshToken: json['refreshToken'] as String?,
      );

  AppUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? branch,
    List<String>? assignedPos,
    double? singleTxnLimit,
    double? dailyLimit,
    bool? isActive,
    DateTime? lastLogin,
    String? token,
    String? refreshToken,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      branch: branch ?? this.branch,
      assignedPos: assignedPos ?? this.assignedPos,
      singleTxnLimit: singleTxnLimit ?? this.singleTxnLimit,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}
