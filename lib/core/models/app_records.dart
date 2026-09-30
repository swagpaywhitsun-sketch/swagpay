class AuditLog {
  final String id;
  final DateTime timestamp;
  final String user;
  final String role;
  final String action;
  final String entity;
  final String details;
  final String ip;
  final String device;

  const AuditLog({
    required this.id,
    required this.timestamp,
    required this.user,
    required this.role,
    required this.action,
    required this.entity,
    required this.details,
    required this.ip,
    required this.device,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user': user,
        'role': role,
        'action': action,
        'entity': entity,
        'details': details,
        'ip': ip,
        'device': device,
      };

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now() : DateTime.now()),
        user: json['user'] as String? ?? json['userName'] as String? ?? 'System',
        role: json['role'] as String? ?? json['userRole'] as String? ?? 'Staff',
        action: json['action'] as String? ?? 'EVENT',
        entity: json['entity'] as String? ?? json['targetType'] as String? ?? 'SYSTEM',
        details: json['details'] as String? ?? json['metadata'] as String? ?? '',
        ip: json['ip'] as String? ?? json['ipAddress'] as String? ?? '127.0.0.1',
        device: json['device'] as String? ?? 'SwagPay Node',
      );
}

class ShiftRecord {
  final String id;
  final String tellerId;
  final String tellerName;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalCollected;
  final int totalCount;
  final int successCount;
  final int failedCount;
  final double cashExpected;
  final double? cashActual;
  final double variance;
  final bool isClosed;
  final String? notes;

  const ShiftRecord({
    required this.id,
    required this.tellerId,
    required this.tellerName,
    required this.startTime,
    this.endTime,
    required this.totalCollected,
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.cashExpected,
    this.cashActual,
    this.variance = 0.0,
    this.isClosed = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tellerId': tellerId,
        'tellerName': tellerName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'totalCollected': totalCollected,
        'totalCount': totalCount,
        'successCount': successCount,
        'failedCount': failedCount,
        'cashExpected': cashExpected,
        'cashActual': cashActual,
        'variance': variance,
        'isClosed': isClosed,
        'notes': notes,
      };

  factory ShiftRecord.fromJson(Map<String, dynamic> json) => ShiftRecord(
        id: json['id'] as String,
        tellerId: json['tellerId'] as String,
        tellerName: json['tellerName'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'] as String) : null,
        totalCollected: (json['totalCollected'] as num).toDouble(),
        totalCount: json['totalCount'] as int,
        successCount: json['successCount'] as int,
        failedCount: json['failedCount'] as int,
        cashExpected: (json['cashExpected'] as num).toDouble(),
        cashActual: (json['cashActual'] as num?)?.toDouble(),
        variance: (json['variance'] as num?)?.toDouble() ?? 0.0,
        isClosed: json['isClosed'] as bool? ?? false,
        notes: json['notes'] as String?,
      );

  ShiftRecord copyWith({
    String? id,
    String? tellerId,
    String? tellerName,
    DateTime? startTime,
    DateTime? endTime,
    double? totalCollected,
    int? totalCount,
    int? successCount,
    int? failedCount,
    double? cashExpected,
    double? cashActual,
    double? variance,
    bool? isClosed,
    String? notes,
  }) {
    return ShiftRecord(
      id: id ?? this.id,
      tellerId: tellerId ?? this.tellerId,
      tellerName: tellerName ?? this.tellerName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalCollected: totalCollected ?? this.totalCollected,
      totalCount: totalCount ?? this.totalCount,
      successCount: successCount ?? this.successCount,
      failedCount: failedCount ?? this.failedCount,
      cashExpected: cashExpected ?? this.cashExpected,
      cashActual: cashActual ?? this.cashActual,
      variance: variance ?? this.variance,
      isClosed: isClosed ?? this.isClosed,
      notes: notes ?? this.notes,
    );
  }
}

enum NotificationType {
  transaction,
  system,
  alert,
  refund,
}

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? targetRoute;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.targetRoute,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'isRead': isRead,
        'targetRoute': targetRoute,
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) => AppNotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: NotificationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => NotificationType.system,
        ),
        isRead: json['isRead'] as bool? ?? false,
        targetRoute: json['targetRoute'] as String?,
      );

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    String? targetRoute,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute ?? this.targetRoute,
    );
  }
}
