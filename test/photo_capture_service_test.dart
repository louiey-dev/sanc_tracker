import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/media/photo_capture_service.dart';
import 'package:sanc_tracker/media/media_item.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/tracking/domain/tracking_repository.dart';

class PhotoRepository implements TrackingRepository {
  final markers = <MapMarker>[];
  final media = <MediaItem>[];
  bool failSave = false;
  @override
  Future<List<MapMarker>> loadMarkers() async => markers;
  @override
  Future<List<MediaItem>> loadMedia(String id) async =>
      media.where((m) => m.markerId == id).toList();
  @override
  Future<void> saveMarker(MapMarker marker) async {
    markers.add(marker);
  }

  @override
  Future<void> saveMedia(MediaItem item) async {
    if (failSave) throw StateError('disk full');
    media.add(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PhotoRepository repository;
  const marker = MapMarker(
    id: 'marker-1',
    title: 'Photo',
    latitude: 37,
    longitude: 127,
    note: 'memo',
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sanc-photo-test-');
    repository = PhotoRepository();
    final input = File('${root.path}/camera.jpg');
    await input.writeAsBytes([1, 2, 3]);
    await File('${root.path}/pending-photo.json').writeAsString(
      jsonEncode({
        'marker': marker.toJson(),
        'id': 'photo-1',
        'path': input.path,
        'time': DateTime.utc(2026, 9, 7).toIso8601String(),
      }),
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  PhotoCaptureService service() => PhotoCaptureService(
    root,
    repository,
    thumbnail: (input, output) async => input,
  );

  test(
    'restart recovers photo and marker without a map or current GPS',
    () async {
      final result = await service().recover();
      expect(result!.note, 'memo');
      expect(repository.media.single.latitude, 37);
      expect(
        repository.media.single.locationSource,
        MediaLocationSource.lastKnown,
      );
      expect(await File(repository.media.single.filePath).readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect(await service().recover(), isNull);
    },
  );

  test(
    'failed save keeps journal and retry does not duplicate marker',
    () async {
      repository.failSave = true;
      await expectLater(service().recover(), throwsStateError);
      expect(await service().journal.exists(), isTrue);
      repository.failSave = false;
      await service().recover();
      expect(repository.markers, hasLength(1));
      expect(repository.media, hasLength(1));
    },
  );

  test('replay after metadata save does not duplicate media', () async {
    final journal = await service().journal.readAsString();
    await service().recover();
    await service().journal.writeAsString(journal);
    await service().recover();
    expect(repository.markers, hasLength(1));
    expect(repository.media, hasLength(1));
  });

  test('thumbnail is resized and preserves aspect ratio', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff123456), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1600, 800);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final input = File('${root.path}/large.png');
    await input.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    final path = await createPhotoThumbnail(
      input.path,
      '${root.path}/thumb.png',
    );
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 512);
    expect(frame.image.height, 256);
    frame.image.dispose();
    codec.dispose();
  });
}
