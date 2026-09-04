import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'tracking_controller.dart';
import '../domain/tracking_repository.dart';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});
  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  KakaoMapController? _mapController;
  @override
  void initState() {
    super.initState();
    ref.read(trackingControllerProvider.notifier).restoreActiveSession();
    ref.listenManual(trackingControllerProvider, (previous, next) {
      final p = next.currentPosition;
      final c = _mapController;
      if (p == null || c == null) return;
      final ll = LatLng(p.latitude, p.longitude);
      c.moveCamera(CameraUpdate.newCenterPosition(ll));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingControllerProvider);
    final p = tracking.currentPosition;
    return Scaffold(
      appBar: AppBar(title: const Text('SANC Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 280,
            child: KakaoMap(
              forceHybridComposition: true,
              option: KakaoMapOption(
                position: LatLng(
                  p?.latitude ?? 37.5665,
                  p?.longitude ?? 126.9780,
                ),
                zoomLevel: 15,
              ),
              onMapReady: (c) {
                _mapController = c;
                _drawRoute(tracking.route);
              },
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(
              tracking.isTracking ? Icons.gps_fixed : Icons.gps_off,
            ),
            title: Text(tracking.isTracking ? '추적 중' : '추적 대기'),
            subtitle: Text('수집된 위치: ${tracking.route.length}개'),
            trailing: FilledButton.icon(
              onPressed: () => ref
                  .read(trackingControllerProvider.notifier)
                  .toggleTracking(),
              icon: Icon(tracking.isTracking ? Icons.stop : Icons.play_arrow),
              label: Text(tracking.isTracking ? '중지' : '시작'),
            ),
          ),
          FutureBuilder(
            future: ref.read(trackingRepositoryProvider).loadSessions(),
            builder: (context, snapshot) {
              final sessions = snapshot.data;
              if (sessions == null || sessions.isEmpty) {
                return const Text('저장된 세션 없음');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '저장된 세션',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...sessions.map(
                    (session) => FutureBuilder(
                      future: ref
                          .read(trackingRepositoryProvider)
                          .loadPoints(session.id),
                      builder: (context, pointSnapshot) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.route),
                        title: Text(session.startedAt.toLocal().toString()),
                        subtitle: Text(
                          '저장된 위치: ${pointSnapshot.data?.length ?? 0}개',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (tracking.message != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tracking.message!),
              ),
            ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: ref.read(trackingRepositoryProvider).loadSessions(),
            builder: (context, snapshot) {
              final sessions = snapshot.data;
              if (sessions == null || sessions.isEmpty)
                return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '저장된 세션',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...sessions.map(
                    (session) => ListTile(
                      leading: const Icon(Icons.route),
                      title: Text(session.startedAt.toLocal().toString()),
                      subtitle: Text(session.status.name),
                      onTap: () async {
                        await ref
                            .read(trackingControllerProvider.notifier)
                            .loadSessionRoute(session);
                        if (mounted && _mapController != null)
                          await _drawRoute(
                            ref.read(trackingControllerProvider).route,
                          );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _drawRoute(List<Position> points) async {
    if (_mapController == null || points.length < 2) return;
    await _mapController!.shapeLayer.addPolylineShape(
      MapPoint(points.map((p) => LatLng(p.latitude, p.longitude)).toList()),
      PolylineStyle(Colors.indigo, 10),
      PolylineCap.round,
      id: 'tracking-route',
    );
  }
}
