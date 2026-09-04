class MapMarker {
  const MapMarker({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.note,
    this.category,
    this.preferredMediaId,
  });
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final String? note;
  final String? category;
  final String? preferredMediaId;
  factory MapMarker.fromJson(Map<String, Object?> json) => MapMarker(
    id: json['id']! as String,
    title: json['title']! as String,
    latitude: (json['latitude']! as num).toDouble(),
    longitude: (json['longitude']! as num).toDouble(),
    note: json['note'] as String?,
    category: json['category'] as String?,
    preferredMediaId: json['preferredMediaId'] as String?,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'latitude': latitude,
    'longitude': longitude,
    'note': note,
    'category': category,
    'preferredMediaId': preferredMediaId,
  };
}
