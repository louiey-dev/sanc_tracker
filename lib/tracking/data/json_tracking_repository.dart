import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../domain/location_point.dart';
import '../domain/tracking_repository.dart';
import '../domain/tracking_session.dart';

class JsonTrackingRepository implements TrackingRepository {
  Future<void> _queue = Future<void>.value();
  Future<File> get _file async => File(
    '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}sanc-tracking.json',
  );
  Future<Map<String, dynamic>> _read() async {
    final file = await _file;
    if (!await file.exists())
      return {'sessions': <Object?>[], 'points': <Object?>[]};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final file = await _file;
    await file.writeAsString(const JsonEncoder().convert(data), flush: true);
  }

  @override
  Future<void> saveSession(TrackingSession session) async {
    _queue = _queue.then((_) async {
      final data = await _read();
      (data['sessions'] as List).add(session.toJson());
      await _write(data);
    });
    await _queue;
  }

  @override
  Future<void> updateSession(TrackingSession session) async {
    _queue = _queue.then((_) async {
      final data = await _read();
      final list = data['sessions'] as List;
      final index = list.indexWhere(
        (item) => (item as Map)['id'] == session.id,
      );
      if (index >= 0) list[index] = session.toJson();
      await _write(data);
    });
    await _queue;
  }

  @override
  Future<void> savePoint(LocationPoint point) async {
    _queue = _queue.then((_) async {
      final data = await _read();
      (data['points'] as List).add(point.toJson());
      await _write(data);
    });
    await _queue;
  }

  @override
  Future<List<TrackingSession>> loadSessions() async =>
      (await _read())['sessions']
          .map<TrackingSession>(
            (item) => TrackingSession.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList();

  @override
  Future<TrackingSession?> loadActiveSession() async {
    final sessions = await loadSessions();
    for (final session in sessions) {
      if (session.status == TrackingSessionStatus.active) return session;
    }
    return null;
  }

  @override
  Future<List<LocationPoint>> loadPoints(String sessionId) async =>
      (await _read())['points']
          .where((item) => (item as Map)['sessionId'] == sessionId)
          .map<LocationPoint>(
            (item) =>
                LocationPoint.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList();
}
