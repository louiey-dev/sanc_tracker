import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '../map/map_marker.dart';
import '../tracking/domain/tracking_repository.dart';
import 'media_item.dart';

Future<String> createPhotoThumbnail(String original, String destination) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(original);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      final scale = 512 / (w > h ? w : h);
      return ui.TargetImageSize(
        width: scale < 1 ? (w * scale).round().clamp(1, 512) : w,
        height: scale < 1 ? (h * scale).round().clamp(1, 512) : h,
      );
    },
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (bytes == null) throw StateError('Thumbnail encoding failed');
      await File(destination).parent.create(recursive: true);
      await File(
        destination,
      ).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return destination;
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// Persists capture context before leaving the app. Stable IDs make replay safe.
class PhotoCaptureService {
  PhotoCaptureService(
    this.root,
    this.repository, {
    ImagePicker? picker,
    this.thumbnail = createPhotoThumbnail,
  }) : picker = picker ?? ImagePicker();
  final Directory root;
  final TrackingRepository repository;
  final ImagePicker picker;
  final Future<String> Function(String, String) thumbnail;
  File get journal => File('${root.path}/pending-photo.json');

  Future<void> _write(Map<String, dynamic> data) async {
    await root.create(recursive: true);
    final temp = File('${journal.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(journal.path);
  }

  Future<MapMarker?> capture(MapMarker marker, ImageSource source) async {
    if (await journal.exists()) throw StateError('이전 사진 복구를 먼저 완료해 주세요.');
    final data = <String, dynamic>{
      'marker': marker.toJson(),
      'id': 'photo-${DateTime.now().microsecondsSinceEpoch}',
      'time': DateTime.now().toUtc().toIso8601String(),
    };
    await _write(data);
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) {
      await journal.delete();
      return null;
    }
    data['path'] = file.path;
    await _write(data);
    return _finish(data);
  }

  Future<MapMarker?> recover() async {
    if (!await journal.exists()) return null;
    final data =
        jsonDecode(await journal.readAsString()) as Map<String, dynamic>;
    if (data['path'] == null) {
      if (!Platform.isAndroid) {
        await journal.delete();
        return null;
      }
      final result = await picker.retrieveLostData();
      if (result.exception != null) throw result.exception!;
      if (result.files == null || result.files!.isEmpty) {
        await journal.delete();
        return null;
      }
      data['path'] = result.files!.first.path;
      await _write(data);
    }
    return _finish(data);
  }

  Future<MapMarker> _finish(Map<String, dynamic> data) async {
    final marker = MapMarker.fromJson(
      Map<String, Object?>.from(data['marker'] as Map),
    );
    final original = File(
      '${root.path}/media/originals/${data['id']}${_extension(data['path'] as String)}',
    );
    await original.parent.create(recursive: true);
    // Copy to a temporary file first so interrupted copies are never reused.
    if (!await original.exists()) {
      final temp = await File(
        data['path'] as String,
      ).copy('${original.path}.tmp');
      await temp.rename(original.path);
    }
    final thumb = await thumbnail(
      original.path,
      '${root.path}/media/thumbnails/${data['id']}.png',
    );
    if (!(await repository.loadMarkers()).any((m) => m.id == marker.id)) {
      await repository.saveMarker(marker);
    }
    if (!(await repository.loadMedia(
      marker.id,
    )).any((m) => m.id == data['id'])) {
      await repository.saveMedia(
        MediaItem(
          id: data['id'] as String,
          markerId: marker.id,
          type: MediaType.photo,
          filePath: original.path,
          thumbnailPath: thumb,
          recordedAt: DateTime.parse(data['time'] as String),
          latitude: marker.latitude,
          longitude: marker.longitude,
          locationSource: MediaLocationSource.lastKnown,
        ),
      );
    }
    await journal.delete();
    return marker;
  }

  String _extension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    return name.contains('.') ? name.substring(name.lastIndexOf('.')) : '.jpg';
  }
}
