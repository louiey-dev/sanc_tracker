import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'tracking_controller.dart';
import '../../map/map_marker.dart';
import '../domain/tracking_repository.dart';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});
  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  KakaoMapController? _mapController;
  Poi? _currentPoi;
  bool _isMapExpanded = false;
  bool _isUpdatingCurrentPoi = false;
  LatLng? _pendingCurrentPosition;
  Poi? _selectedMarkerPoi;
  MapMarker? _selectedMarker;
  bool _isMarkerMoveMode = false;
  final List<MapMarker> _markers = [];
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
      _setCurrentLocationMarker(c, ll);
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
            height: _isMapExpanded
                ? MediaQuery.sizeOf(context).height - kToolbarHeight - 24
                : 280,
            child: Stack(
              children: [
                KakaoMap(
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
                    if (p != null)
                      _setCurrentLocationMarker(
                        c,
                        LatLng(p.latitude, p.longitude),
                      );
                    _drawRoute(tracking.route);
                  },
                  onTerrainLongClick: (_, position) => _addMarker(position),
                  onMapClick: (_, position) => _moveSelectedMarker(position),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'move-to-current-location',
                    tooltip: '현재 위치로 이동',
                    onPressed: _moveToCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'toggle-map-size',
                    tooltip: _isMapExpanded ? '지도 축소' : '지도 전체화면',
                    onPressed: () =>
                        setState(() => _isMapExpanded = !_isMapExpanded),
                    child: Icon(
                      _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                  ),
                ),
              ],
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

  void _moveToCurrentLocation() {
    final controller = _mapController;
    final position = ref.read(trackingControllerProvider).currentPosition;
    if (controller == null || position == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 위치를 아직 확인하지 못했습니다.')));
      return;
    }
    controller.moveCamera(
      CameraUpdate.newCenterPosition(
        LatLng(position.latitude, position.longitude),
      ),
    );
  }

  Future<void> _addMarker(LatLng position) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final titleController = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('장소 마커 추가'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: '제목'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, titleController.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (!mounted || title == null || title.isEmpty || _mapController == null)
      return;
    final marker = MapMarker(
      id: 'marker-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    try {
      final poi = await _mapController!.labelLayer.addPoi(
        position,
        id: marker.id,
        text: marker.title,
        style: PoiStyle(
          icon: KImage.fromAsset('assets/icon/sanc_tracker_icon.png', 24, 24),
          textStyle: const [
            PoiTextStyle(
              size: 18,
              color: Colors.black,
              stroke: 3,
              strokeColor: Colors.white,
            ),
          ],
        ),
      );
      poi.onClick = () => _selectMarker(marker, poi);
      // Keep the native map view mounted. Rebuilding it immediately after a
      // platform-view overlay is added can trigger Flutter's dependents assertion.
      _markers.add(marker);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('마커를 저장하지 못했습니다: $error')));
      }
    }
  }

  void _selectMarker(MapMarker marker, Poi poi) {
    _selectedMarker = marker;
    _selectedMarkerPoi = poi;
    _isMarkerMoveMode = false;
    _showMarkerDetails(marker, poi.position);
  }

  Future<void> _moveSelectedMarker(LatLng position) async {
    final poi = _selectedMarkerPoi;
    final marker = _selectedMarker;
    if (!_isMarkerMoveMode || poi == null || marker == null) return;
    await poi.move(position);
    _isMarkerMoveMode = false;
    _selectedMarker = MapMarker(
      id: marker.id,
      title: marker.title,
      latitude: position.latitude,
      longitude: position.longitude,
      note: marker.note,
      category: marker.category,
    );
    _selectedMarkerPoi = poi;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${marker.title} 마커를 새 위치로 이동했습니다.')),
      );
    }
  }

  Future<void> _deleteMarker(MapMarker marker, Poi poi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마커 삭제'),
        content: Text('“${marker.title}” 마커를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await poi.remove();
    _markers.removeWhere((item) => item.id == marker.id);
    if (_selectedMarker?.id == marker.id) {
      _selectedMarker = null;
      _selectedMarkerPoi = null;
      _isMarkerMoveMode = false;
    }
  }

  Future<void> _showMarkerDetails(MapMarker marker, LatLng position) async {
    final poi = _selectedMarkerPoi;
    if (!mounted || poi == null) return;
    final shouldMove = await showDialog<Object?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장된 마커'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              marker.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '위도: ${position.latitude.toStringAsFixed(6)}\n'
              '경도: ${position.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text('이 마커를 이동하시겠습니까?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('이동'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (shouldMove == 'delete') {
      await _deleteMarker(marker, poi);
    } else if (mounted && shouldMove == true) {
      _isMarkerMoveMode = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이동할 새 위치를 지도에서 눌러주세요.')));
    }
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

  Future<void> _setCurrentLocationMarker(
    KakaoMapController controller,
    LatLng position,
  ) async {
    _pendingCurrentPosition = position;
    if (_isUpdatingCurrentPoi) return;
    _isUpdatingCurrentPoi = true;
    try {
      while (mounted && _pendingCurrentPosition != null) {
        final nextPosition = _pendingCurrentPosition!;
        _pendingCurrentPosition = null;
        final currentLocationIcon = await KImage.fromWidget(
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
          const Size(24, 24),
        );
        if (_currentPoi != null) {
          await controller.labelLayer.removePoi(_currentPoi!);
        }
        _currentPoi = await controller.labelLayer.addPoi(
          nextPosition,
          id: 'current-location',
          style: PoiStyle(icon: currentLocationIcon),
        );
      }
    } catch (error) {
      // The map can be temporarily detached while a scroll moves it offscreen.
      // Ignore that transient native-overlay error; the next GPS update retries.
      debugPrint('현재 위치 마커 갱신 지연: $error');
    } finally {
      _isUpdatingCurrentPoi = false;
    }
  }
}
