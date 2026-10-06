enum PosStatus {
  online,
  offline,
  disabled,
}

class PosDevice {
  final String id;
  final String name;
  final String serialNumber;
  final String deviceFingerprint;
  final String branch;
  final String location;
  final List<String> assignedTellerIds;
  final PosStatus status;
  final bool isWhitelisted;
  final DateTime lastSeen;
  final String? ipAddress;

  bool get isActive => status != PosStatus.disabled;
  String get code => serialNumber;

  const PosDevice({
    required this.id,
    required this.name,
    required this.serialNumber,
    required this.deviceFingerprint,
    required this.branch,
    this.location = '',
    this.assignedTellerIds = const [],
    this.status = PosStatus.online,
    this.isWhitelisted = true,
    required this.lastSeen,
    this.ipAddress,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serialNumber': serialNumber,
        'deviceFingerprint': deviceFingerprint,
        'branch': branch,
        'location': location,
        'assignedTellerIds': assignedTellerIds,
        'status': status.name,
        'isWhitelisted': isWhitelisted,
        'lastSeen': lastSeen.toIso8601String(),
        'ipAddress': ipAddress,
      };

  factory PosDevice.fromJson(Map<String, dynamic> json) => PosDevice(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Terminal',
        serialNumber: json['code'] as String? ?? json['serialNumber'] as String? ?? '',
        deviceFingerprint: json['deviceFingerprint'] as String? ?? json['code'] as String? ?? json['serialNumber'] as String? ?? '',
        branch: json['branch'] as String? ?? json['location'] as String? ?? 'Main Branch',
        location: json['location'] as String? ?? '',
        assignedTellerIds: (json['assignedTellerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        status: PosStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == (json['status'] as String? ?? '').toLowerCase(),
          orElse: () => ((json['active'] as num?)?.toInt() == 0 ? PosStatus.offline : PosStatus.online),
        ),
        isWhitelisted: json['isWhitelisted'] as bool? ?? ((json['active'] as num?)?.toInt() != 0),
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse(json['lastSeen'] as String) ?? DateTime.now()
            : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now() : DateTime.now()),
        ipAddress: json['ipAddress'] as String?,
      );

  PosDevice copyWith({
    String? id,
    String? name,
    String? serialNumber,
    String? deviceFingerprint,
    String? branch,
    String? location,
    List<String>? assignedTellerIds,
    PosStatus? status,
    bool? isWhitelisted,
    DateTime? lastSeen,
    String? ipAddress,
  }) {
    return PosDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      serialNumber: serialNumber ?? this.serialNumber,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      branch: branch ?? this.branch,
      location: location ?? this.location,
      assignedTellerIds: assignedTellerIds ?? this.assignedTellerIds,
      status: status ?? this.status,
      isWhitelisted: isWhitelisted ?? this.isWhitelisted,
      lastSeen: lastSeen ?? this.lastSeen,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }
}
