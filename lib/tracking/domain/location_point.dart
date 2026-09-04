class LocationPoint {
  const LocationPoint({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.updatedAt,
    this.accuracyM,
    this.altitudeM,
    this.speedMps,
    this.headingDeg,
    this.batteryPercent,
  });

  final String id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final DateTime updatedAt;
  final double? accuracyM;
  final double? altitudeM;
  final double? speedMps;
  final double? headingDeg;
  final int? batteryPercent;

  Map<String, Object?> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'latitude': latitude,
    'longitude': longitude,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'accuracyM': accuracyM,
    'altitudeM': altitudeM,
    'speedMps': speedMps,
    'headingDeg': headingDeg,
    'batteryPercent': batteryPercent,
  };

  factory LocationPoint.fromJson(Map<String, Object?> json) => LocationPoint(
    id: json['id']! as String,
    sessionId: json['sessionId']! as String,
    latitude: (json['latitude']! as num).toDouble(),
    longitude: (json['longitude']! as num).toDouble(),
    recordedAt: DateTime.parse(json['recordedAt']! as String).toUtc(),
    updatedAt: DateTime.parse(
      (json['updatedAt'] ?? json['recordedAt'])! as String,
    ).toUtc(),
    accuracyM: (json['accuracyM'] as num?)?.toDouble(),
    altitudeM: (json['altitudeM'] as num?)?.toDouble(),
    speedMps: (json['speedMps'] as num?)?.toDouble(),
    headingDeg: (json['headingDeg'] as num?)?.toDouble(),
    batteryPercent: (json['batteryPercent'] as num?)?.toInt(),
  );
}
