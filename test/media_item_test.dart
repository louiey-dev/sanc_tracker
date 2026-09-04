import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/media/media_item.dart';

void main() {
  test('media item round trips metadata and location source', () {
    final item = MediaItem(
      id: 'media-1',
      markerId: 'marker-1',
      type: MediaType.photo,
      filePath: '/media/photo.jpg',
      thumbnailPath: '/media/thumb.jpg',
      recordedAt: DateTime.utc(2026, 9, 4, 12),
      latitude: 37.5,
      longitude: 127,
      accuracyM: 5,
      locationSource: MediaLocationSource.exact,
    );

    final restored = MediaItem.fromJson(item.toJson());
    expect(restored.id, item.id);
    expect(restored.type, MediaType.photo);
    expect(restored.recordedAt, item.recordedAt);
    expect(restored.locationSource, MediaLocationSource.exact);
    expect(restored.latitude, item.latitude);
  });

  test('media item preserves marker location and source variants', () {
    for (final source in MediaLocationSource.values) {
      final item = MediaItem(
        id: 'media-${source.name}',
        markerId: 'marker-1',
        type: MediaType.photo,
        filePath: '/media/photo.jpg',
        thumbnailPath: '/media/thumb.jpg',
        recordedAt: DateTime.utc(2026, 9, 4),
        latitude: 37.5,
        longitude: 127.0,
        locationSource: source,
      );
      final restored = MediaItem.fromJson(item.toJson());
      expect(restored.markerId, 'marker-1');
      expect(restored.locationSource, source);
      expect(restored.latitude, 37.5);
      expect(restored.longitude, 127.0);
    }
  });
}
