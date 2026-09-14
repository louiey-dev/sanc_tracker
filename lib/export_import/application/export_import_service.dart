import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../tracking/domain/location_point.dart';
import '../../tracking/domain/tracking_repository.dart';
import '../../tracking/domain/tracking_session.dart';
import '../../tracking/presentation/tracking_controller.dart';
import '../domain/geojson_converter.dart';
import '../domain/gpx_converter.dart';
import '../domain/import_export_bundle.dart';

enum UniversalExportFormat {
  gpx('gpx', 'GPX (.gpx)', 'GPS 표준 포맷 (스마트워치·타 지도 앱 호환)'),
  geojson('geojson', 'GeoJSON (.geojson)', '표준 지리 정보 포맷 (웹 지도·GIS 호환)');

  const UniversalExportFormat(this.extension, this.label, this.description);
  final String extension;
  final String label;
  final String description;
}

enum ExportAction {
  saveToDeviceGpx,
  saveToDeviceGeoJson,
  shareGpx,
  shareGeoJson,
}

final exportImportServiceProvider = Provider<ExportImportService>((ref) {
  final repository = ref.watch(trackingRepositoryProvider);
  return ExportImportService(repository: repository);
});

class ExportImportService {
  ExportImportService({required this.repository});

  final TrackingRepository repository;

  /// Exports a single tracking session and its points to a temporary file.
  Future<File> exportSessionToFile({
    required TrackingSession session,
    required UniversalExportFormat format,
  }) async {
    final points = await repository.loadPoints(session.id);
    final safeTitle = (session.title?.isNotEmpty == true
            ? session.title!
            : 'track_${session.startedAt.toLocal().toIso8601String().substring(0, 10)}')
        .replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
    final shortId = session.id.length > 8 ? session.id.substring(0, 8) : session.id;
    final fileName = '${safeTitle}_$shortId.${format.extension}';

    final content = format == UniversalExportFormat.gpx
        ? GpxConverter.toGpx(sessions: [session], points: points)
        : GeoJsonConverter.toGeoJson(sessions: [session], points: points);

    final tempDir = await getTemporaryDirectory();
    final exportFile = File('${tempDir.path}/$fileName');
    await exportFile.writeAsString(content, flush: true);
    return exportFile;
  }

  /// Saves a single tracking session directly to device storage using the system file save dialog.
  Future<String?> saveSessionToDevice({
    required TrackingSession session,
    required UniversalExportFormat format,
  }) async {
    final points = await repository.loadPoints(session.id);
    final safeTitle = (session.title?.isNotEmpty == true
            ? session.title!
            : 'track_${session.startedAt.toLocal().toIso8601String().substring(0, 10)}')
        .replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
    final shortId = session.id.length > 8 ? session.id.substring(0, 8) : session.id;
    final fileName = '${safeTitle}_$shortId.${format.extension}';

    final content = format == UniversalExportFormat.gpx
        ? GpxConverter.toGpx(sessions: [session], points: points)
        : GeoJsonConverter.toGeoJson(sessions: [session], points: points);

    final bytes = Uint8List.fromList(utf8.encode(content));

    return FilePicker.saveFile(
      dialogTitle: '기록 파일 저장 위치 선택',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [format.extension],
      bytes: bytes,
    );
  }

  /// Exports all saved sessions, points, and markers to a temporary file.
  Future<File> exportAllToFile({
    required UniversalExportFormat format,
  }) async {
    final sessions = await repository.loadSessions();
    final allPoints = <LocationPoint>[];
    for (final s in sessions) {
      final pts = await repository.loadPoints(s.id);
      allPoints.addAll(pts);
    }
    final markers = await repository.loadMarkers();

    final dateStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
    final fileName = 'sanc_tracker_all_$dateStr.${format.extension}';

    final content = format == UniversalExportFormat.gpx
        ? GpxConverter.toGpx(sessions: sessions, points: allPoints, markers: markers)
        : GeoJsonConverter.toGeoJson(sessions: sessions, points: allPoints, markers: markers);

    final tempDir = await getTemporaryDirectory();
    final exportFile = File('${tempDir.path}/$fileName');
    await exportFile.writeAsString(content, flush: true);
    return exportFile;
  }

  /// Shares a file via the OS native share sheet.
  Future<void> shareFile(File file, {String? subject, String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject ?? 'SANC Tracker 경로 공유',
        text: text,
      ),
    );
  }

  /// Picks a file (.gpx, .geojson, .json, .xml) using the system file picker.
  Future<({String fileName, String content})?> pickAndReadImportFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx', 'geojson', 'json', 'xml'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    String content;

    if (picked.bytes != null) {
      content = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      final file = File(picked.path!);
      content = await file.readAsString();
    } else {
      return null;
    }

    return (fileName: picked.name, content: content);
  }

  /// Parses file content and automatically determines format (GPX or GeoJSON).
  ImportExportBundle parseContent(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('<') ||
        trimmed.contains('<gpx') ||
        trimmed.contains('<trk') ||
        trimmed.contains('<wpt') ||
        trimmed.contains('<rte')) {
      return GpxConverter.fromGpx(trimmed);
    } else if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return GeoJsonConverter.fromGeoJson(trimmed);
    } else {
      throw const FormatException('지원하지 않거나 형식이 올바르지 않은 파일입니다.');
    }
  }

  /// Commits imported bundle to repository without overwriting existing data.
  Future<void> commitImport(ImportExportBundle bundle) async {
    for (final session in bundle.sessions) {
      await repository.saveSession(session);
    }
    for (final point in bundle.points) {
      await repository.savePoint(point);
    }
    for (final marker in bundle.markers) {
      await repository.saveMarker(marker);
    }
  }
}
