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
        id: json['id'] as String,
        name: json['name'] as String,
        serialNumber: json['serialNumber'] as String,
        deviceFingerprint: json['deviceFingerprint'] as String? ?? json['serialNumber'] as String,
        branch: json['branch'] as String,
        location: json['location'] as String? ?? '',
        assignedTellerIds: (json['assignedTellerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        status: PosStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => PosStatus.online,
        ),
        isWhitelisted: json['isWhitelisted'] as bool? ?? true,
        lastSeen: DateTime.parse(json['lastSeen'] as String),
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
