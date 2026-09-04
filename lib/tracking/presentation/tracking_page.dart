import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'tracking_controller.dart';
import '../../map/map_marker.dart';
import '../domain/tracking_repository.dart';
import '../domain/tracking_session.dart';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});
  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage>
    with WidgetsBindingObserver {
  KakaoMapController? _mapController;
  Poi? _currentPoi;
  Polyline? _trackingRouteLine;
  Poi? _routeStartPoi;
  Poi? _routeEndPoi;
  bool _isMapExpanded = false;
  bool _isUpdatingCurrentPoi = false;
  LatLng? _pendingCurrentPosition;
  Poi? _selectedMarkerPoi;
  MapMarker? _selectedMarker;
  bool _isMarkerMoveMode = false;
  bool _isViewingSavedRoute = false;
  final List<MapMarker> _markers = [];
  late final ValueNotifier<List<MapMarker>> _markersNotifier;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _markersNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markersNotifier = ValueNotifier(_markers);
    _loadSavedMarkers();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final controller = _mapController;
    final position = ref.read(trackingControllerProvider).currentPosition;
    if (controller != null && position != null) {
      _setCurrentLocationMarker(
        controller,
        LatLng(position.latitude, position.longitude),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingControllerProvider);
    final p = tracking.currentPosition;
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('SANC Tracker')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomSafeArea),
        children: [
          SizedBox(
            height: _isMapExpanded
                ? MediaQuery.sizeOf(context).height -
                      kToolbarHeight -
                      bottomSafeArea -
                      64
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
                    _restoreSavedMarkers(c);
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
              return ExpansionTile(
                leading: const Icon(Icons.route),
                title: const Text('저장된 세션'),
                trailing: _isViewingSavedRoute
                    ? IconButton(
                        tooltip: '저장 경로 보기 종료',
                        icon: const Icon(Icons.close),
                        onPressed: _exitSavedRoute,
                      )
                    : null,
                children: sessions
                    .map(
                      (session) => ListTile(
                        leading: const Icon(Icons.route),
                        title: Text(session.startedAt.toLocal().toString()),
                        subtitle: Text(session.status.name),
                        onTap: () => _confirmLoadSession(session),
                        onLongPress: () => _deleteSession(session),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            leading: const Icon(Icons.place, color: Colors.red),
            title: const Text('저장된 마커'),
            children: [
              ValueListenableBuilder<List<MapMarker>>(
                valueListenable: _markersNotifier,
                builder: (context, markers, child) {
                  if (markers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('저장된 마커 없음'),
                    );
                  }
                  return Column(
                    children: markers
                        .map(
                          (marker) => ListTile(
                            leading: const Icon(Icons.place, color: Colors.red),
                            title: Text(marker.title),
                            subtitle: Text(
                              '${marker.latitude.toStringAsFixed(6)}, '
                              '${marker.longitude.toStringAsFixed(6)}',
                            ),
                            onTap: () => _focusMarker(marker),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
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

  void _focusMarker(MapMarker marker) {
    _mapController?.moveCamera(
      CameraUpdate.newCenterPosition(LatLng(marker.latitude, marker.longitude)),
    );
  }

  void _exitSavedRoute() {
    final routeLine = _trackingRouteLine;
    if (routeLine != null && _mapController != null) {
      _mapController!.shapeLayer.removePolylineShape(routeLine);
      _trackingRouteLine = null;
    }
    if (_mapController != null) {
      if (_routeStartPoi != null) {
        _mapController!.labelLayer.removePoi(_routeStartPoi!);
      }
      if (_routeEndPoi != null) {
        _mapController!.labelLayer.removePoi(_routeEndPoi!);
      }
    }
    _routeStartPoi = null;
    _routeEndPoi = null;
    ref.read(trackingControllerProvider.notifier).clearLoadedSessionRoute();
    _isViewingSavedRoute = false;
    _moveToCurrentLocation();
  }

  Future<void> _confirmLoadSession(TrackingSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장된 경로 보기'),
        content: const Text('이 세션의 저장된 이동 경로를 보시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _isViewingSavedRoute = true;
    await ref
        .read(trackingControllerProvider.notifier)
        .loadSessionRoute(session);
    if (mounted && _mapController != null) {
      await _drawRoute(ref.read(trackingControllerProvider).route);
      setState(() {});
    }
  }

  Future<void> _deleteSession(TrackingSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('세션 삭제'),
        content: const Text('이 세션과 저장된 위치 데이터를 삭제하시겠습니까?'),
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
    await ref.read(trackingRepositoryProvider).deleteSession(session.id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('세션과 위치 데이터가 삭제되었습니다.')));
    }
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
      _markersNotifier.value = List.unmodifiable(_markers);
      await ref.read(trackingRepositoryProvider).saveMarker(marker);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('마커를 저장하지 못했습니다: $error')));
      }
    }
  }

  Future<void> _restoreSavedMarkers(KakaoMapController controller) async {
    for (final marker in _markers) {
      try {
        final poi = await controller.labelLayer.addPoi(
          LatLng(marker.latitude, marker.longitude),
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
      } catch (error) {
        debugPrint('저장 마커 복원 지연: $error');
      }
    }
  }

  Future<void> _loadSavedMarkers() async {
    final saved = await ref.read(trackingRepositoryProvider).loadMarkers();
    if (!mounted || saved.isEmpty) return;
    _markers
      ..clear()
      ..addAll(saved);
    _markersNotifier.value = List.unmodifiable(_markers);
    if (_mapController != null) await _restoreSavedMarkers(_mapController!);
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
    final index = _markers.indexWhere((item) => item.id == marker.id);
    if (index >= 0) {
      _markers[index] = _selectedMarker!;
      _markersNotifier.value = List.unmodifiable(_markers);
      await ref.read(trackingRepositoryProvider).updateMarker(_selectedMarker!);
    }
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
    await ref.read(trackingRepositoryProvider).deleteMarker(marker.id);
    _markers.removeWhere((item) => item.id == marker.id);
    _markersNotifier.value = List.unmodifiable(_markers);
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
    if (_routeStartPoi != null) {
      await _mapController!.labelLayer.removePoi(_routeStartPoi!);
      _routeStartPoi = null;
    }
    if (_routeEndPoi != null) {
      await _mapController!.labelLayer.removePoi(_routeEndPoi!);
      _routeEndPoi = null;
    }
    final previousLine = _trackingRouteLine;
    if (previousLine != null) {
      await _mapController!.shapeLayer.removePolylineShape(previousLine);
    }
    _trackingRouteLine = await _mapController!.shapeLayer.addPolylineShape(
      MapPoint(points.map((p) => LatLng(p.latitude, p.longitude)).toList()),
      PolylineStyle(Colors.indigo, 10),
      PolylineCap.round,
      id: 'tracking-route',
    );
    final start = LatLng(points.first.latitude, points.first.longitude);
    final end = LatLng(points.last.latitude, points.last.longitude);
    final routeLabelStyle = PoiStyle(
      icon: KImage.fromAsset('assets/icon/sanc_tracker_icon.png', 20, 20),
      padding: 8,
      textGravity: const MapGravity(HorizontalAlign.center, VerticalAlign.top),
      textStyle: const [
        PoiTextStyle(
          size: 36,
          color: Colors.black,
          stroke: 6,
          strokeColor: Colors.white,
        ),
      ],
    );
    _routeStartPoi = await _mapController!.labelLayer.addPoi(
      start,
      id: 'tracking-route-start',
      text: '출발',
      style: routeLabelStyle,
    );
    _routeEndPoi = await _mapController!.labelLayer.addPoi(
      end,
      id: 'tracking-route-end',
      text: '도착',
      style: routeLabelStyle,
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
        final previousPoi = _currentPoi;
        _currentPoi = null;
        if (previousPoi != null) {
          try {
            await controller.labelLayer.removePoi(previousPoi);
          } catch (error) {
            debugPrint('이전 현재 위치 마커 제거 지연: $error');
          }
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
