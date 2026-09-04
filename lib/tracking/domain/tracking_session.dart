enum TrackingSessionStatus { active, completed }

class TrackingSession {
  const TrackingSession({
    required this.id,
    required this.startedAt,
    required this.updatedAt,
    this.endedAt,
    this.status = TrackingSessionStatus.active,
  });
  final String id;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? endedAt;
  final TrackingSessionStatus status;
  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'status': status.name,
  };
  factory TrackingSession.fromJson(Map<String, Object?> json) =>
      TrackingSession(
        id: json['id']! as String,
        startedAt: DateTime.parse(json['startedAt']! as String).toUtc(),
        updatedAt: DateTime.parse(
          (json['updatedAt'] ?? json['startedAt'])! as String,
        ).toUtc(),
        endedAt: (json['endedAt'] as String?) == null
            ? null
            : DateTime.parse(json['endedAt']! as String).toUtc(),
        status: TrackingSessionStatus.values.byName(json['status']! as String),
      );
}
