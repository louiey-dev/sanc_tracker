import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/map/map_marker.dart';

void main() {
  test('marker round trips title, coordinates, note, and category', () {
    const marker = MapMarker(
      id: 'marker-1',
      title: '북한산 입구',
      latitude: 37.6581,
      longitude: 126.9772,
      note: '등산 시작점',
      category: '출발지',
    );

    final restored = MapMarker.fromJson(marker.toJson());

    expect(restored.id, marker.id);
    expect(restored.title, marker.title);
    expect(restored.latitude, marker.latitude);
    expect(restored.longitude, marker.longitude);
    expect(restored.note, marker.note);
    expect(restored.category, marker.category);
  });

  test('marker supports coordinates without an address', () {
    const marker = MapMarker(
      id: 'marker-2',
      title: '바위 쉼터',
      latitude: 35.123456,
      longitude: 128.654321,
    );

    final restored = MapMarker.fromJson(marker.toJson());

    expect(restored.note, isNull);
    expect(restored.category, isNull);
    expect(restored.latitude, 35.123456);
    expect(restored.longitude, 128.654321);
  });
}
