class MapMarker {
  const MapMarker({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.note,
    this.category,
  });
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final String? note;
  final String? category;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'latitude': latitude,
    'longitude': longitude,
    'note': note,
    'category': category,
  };
}
