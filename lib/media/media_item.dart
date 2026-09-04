enum MediaType { photo, video }

enum MediaLocationSource { exact, lastKnown, unknown }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.markerId,
    required this.type,
    required this.filePath,
    required this.thumbnailPath,
    required this.recordedAt,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locationSource = MediaLocationSource.unknown,
  });

  final String id;
  final String markerId;
  final MediaType type;
  final String filePath;
  final String thumbnailPath;
  final DateTime recordedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final MediaLocationSource locationSource;

  Map<String, Object?> toJson() => {
    'id': id,
    'markerId': markerId,
    'type': type.name,
    'filePath': filePath,
    'thumbnailPath': thumbnailPath,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracyM': accuracyM,
    'locationSource': locationSource.name,
  };

  factory MediaItem.fromJson(Map<String, Object?> json) => MediaItem(
    id: json['id']! as String,
    markerId: json['markerId']! as String,
    type: MediaType.values.byName(json['type']! as String),
    filePath: json['filePath']! as String,
    thumbnailPath: json['thumbnailPath']! as String,
    recordedAt: DateTime.parse(json['recordedAt']! as String),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    accuracyM: (json['accuracyM'] as num?)?.toDouble(),
    locationSource: MediaLocationSource.values.byName(
      json['locationSource'] as String? ?? 'unknown',
    ),
  );
}
