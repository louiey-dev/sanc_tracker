import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'tracking_controller.dart';
import '../domain/location_point.dart';
import '../../map/map_marker.dart';
import '../domain/tracking_repository.dart';
import '../domain/tracking_session.dart';
import '../../media/media_item.dart';

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
  bool _isMarkerSheetOpen = false;
  bool _isViewingSavedRoute = false;
  final List<MapMarker> _markers = [];
  final Map<String, Poi> _markerPois = {};
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
    ref.read(trackingControllerProvider.notifier).loadCurrentPosition();
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
                  onMapClick: (_, position) => _isViewingSavedRoute
                      ? _showNearestRoutePoint(position)
                      : _moveSelectedMarker(position),
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
                  left: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'capture-current-location',
                    tooltip: '현재 위치에서 사진 촬영',
                    onPressed: _captureAtCurrentLocation,
                    child: const Icon(Icons.camera_alt),
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
                        subtitle: FutureBuilder<String>(
                          future: _sessionSummary(session),
                          builder: (context, snapshot) => Text(
                            snapshot.data ??
                                '${session.status.name}\n상세 정보 계산 중...',
                          ),
                        ),
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
                            onLongPress: () => _deleteMarkerFromList(marker),
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

  Future<void> _showNearestRoutePoint(LatLng position) async {
    final points = ref.read(trackingControllerProvider).route;
    if (points.isEmpty || !mounted) return;
    Position? nearest;
    var nearestDistance = double.infinity;
    for (final point in points) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = point;
      }
    }
    if (nearest == null) return;
    final point = nearest;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('경로 기록 위치'),
        content: Text(
          '기록 시각: ${point.timestamp?.toLocal() ?? '-'}\n'
          '위도: ${point.latitude.toStringAsFixed(6)}\n'
          '경도: ${point.longitude.toStringAsFixed(6)}\n'
          '정확도: ${point.accuracy.toStringAsFixed(1)} m\n'
          '선택 위치와 거리: ${nearestDistance.toStringAsFixed(1)} m',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<String> _sessionSummary(TrackingSession session) async {
    final points = await ref
        .read(trackingRepositoryProvider)
        .loadPoints(session.id);
    final sorted = [...points]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final start = sorted.isEmpty ? session.startedAt : sorted.first.recordedAt;
    final end =
        session.endedAt ??
        (sorted.isEmpty ? session.updatedAt : sorted.last.recordedAt);
    final distance = _calculateDistance(sorted);
    return '${session.status.name}  ·  ${_formatDuration(end.difference(start))}\n'
        '시작 ${_formatDateTime(start)}  /  종료 ${_formatDateTime(end)}\n'
        '이동 거리 ${distance.toStringAsFixed(2)} km';
  }

  double _calculateDistance(List<LocationPoint> points) {
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return meters / 1000;
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return hours > 0 ? '${hours}시간 ${minutes}분' : '${minutes}분 ${secs}초';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
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
    final titleController = TextEditingController(text: '장소 마커');
    final noteController = TextEditingController();
    final categoryController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('장소 마커 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: '메모(선택)'),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: '분류(선택)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'note': noteController.text.trim(),
              'category': categoryController.text.trim(),
            }),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    final title = result?['title'];
    if (!mounted || title == null || title.isEmpty || _mapController == null)
      return;
    final marker = MapMarker(
      id: 'marker-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      latitude: position.latitude,
      longitude: position.longitude,
      note: result?['note']?.isEmpty == true ? null : result?['note'],
      category: result?['category']?.isEmpty == true
          ? null
          : result?['category'],
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
      _markerPois[marker.id] = poi;
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
            icon: KImage.fromAsset(
              marker.category == '사진'
                  ? 'assets/icon/sanc_photo_marker.png'
                  : 'assets/icon/sanc_tracker_icon.png',
              marker.category == '사진' ? 48 : 24,
              marker.category == '사진' ? 48 : 24,
            ),
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
        _markerPois[marker.id] = poi;
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
    final currentMarker = _markers.firstWhere(
      (item) => item.id == marker.id,
      orElse: () => marker,
    );
    _selectedMarker = currentMarker;
    _selectedMarkerPoi = poi;
    _isMarkerMoveMode = false;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _showMarkerDetails(currentMarker, poi.position);
    });
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
      preferredMediaId: marker.preferredMediaId,
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
    _markerPois.remove(marker.id);
    await ref.read(trackingRepositoryProvider).deleteMarker(marker.id);
    _markers.removeWhere((item) => item.id == marker.id);
    _markersNotifier.value = List.unmodifiable(_markers);
    if (_selectedMarker?.id == marker.id) {
      _selectedMarker = null;
      _selectedMarkerPoi = null;
      _isMarkerMoveMode = false;
    }
  }

  Future<void> _deleteMarkerFromList(MapMarker marker) async {
    final poi = _markerPois[marker.id];
    if (poi == null) {
      await ref.read(trackingRepositoryProvider).deleteMarker(marker.id);
      _markers.removeWhere((item) => item.id == marker.id);
      _markersNotifier.value = List.unmodifiable(_markers);
      return;
    }
    await _deleteMarker(marker, poi);
  }

  Future<void> _showMarkerDetails(MapMarker marker, LatLng position) async {
    final poi = _selectedMarkerPoi;
    if (!mounted || poi == null || _isMarkerSheetOpen) return;
    _isMarkerSheetOpen = true;
    final mediaFuture = ref
        .read(trackingRepositoryProvider)
        .loadMedia(marker.id);
    final shouldMove = await showModalBottomSheet<Object?>(
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      showDragHandle: true,
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
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
            FutureBuilder<List<MediaItem>>(
              future: mediaFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('사진 정보를 불러오지 못했습니다.');
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final media = snapshot.data;
                if (media == null || media.isEmpty) {
                  return const Text('연결된 사진 없음');
                }
                if (media.length > 1) {
                  return Column(
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: media.map((item) {
                          return GestureDetector(
                            onTap: () => _openMedia(item, marker),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.file(
                                  File(
                                    item.type == MediaType.photo
                                        ? item.filePath
                                        : (item.thumbnailPath ?? item.filePath),
                                  ),
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                        color: Colors.black12,
                                        child: SizedBox(
                                          width: 120,
                                          height: 120,
                                        ),
                                      ),
                                ),
                                if (item.type == MediaType.video)
                                  const Icon(
                                    Icons.play_circle,
                                    size: 42,
                                    color: Colors.white,
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }
                final item = media.single;
                if (item.type == MediaType.photo) {
                  return GestureDetector(
                    onTap: () => _showFullScreenPhoto(item.filePath),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(item.filePath),
                        height: 180,
                        width: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 180,
                          width: 280,
                          child: Center(child: Text('사진 파일을 찾을 수 없습니다.')),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => _playVideo(item.filePath),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.file(
                            File(item.thumbnailPath ?? item.filePath),
                            height: 180,
                            width: 280,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 180,
                              width: 280,
                              child: ColoredBox(color: Colors.black12),
                            ),
                          ),
                          const Icon(
                            Icons.play_circle,
                            size: 56,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _playVideo(item.filePath),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('동영상 재생'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (marker.category != null) Text('분류: ${marker.category}'),
            if (marker.note != null) Text('메모: ${marker.note}'),
            if (marker.category != null || marker.note != null)
              const SizedBox(height: 8),
            const Text('이 마커를 이동하시겠습니까?'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _chooseCameraMedia(marker),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('촬영'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pickMedia(marker, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('갤러리'),
                  ),
                  FutureBuilder<List<MediaItem>>(
                    future: mediaFuture,
                    builder: (context, snapshot) {
                      final media = snapshot.data ?? const <MediaItem>[];
                      if (media.length != 1) return const SizedBox.shrink();
                      final item = media.single;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => item.type == MediaType.photo
                              ? _showFullScreenPhoto(item.filePath)
                              : _playVideo(item.filePath),
                          icon: Icon(
                            item.type == MediaType.photo
                                ? Icons.photo
                                : Icons.play_arrow,
                          ),
                          label: Text(
                            item.type == MediaType.photo ? '사진 보기' : '동영상 보기',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('이동'),
                ),
                TextButton(
                  onPressed: () => _editMarker(marker, poi),
                  child: const Text('수정'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  child: const Text('삭제'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    _isMarkerSheetOpen = false;
    if (shouldMove == 'delete') {
      await _deleteMarker(marker, poi);
    } else if (mounted && shouldMove == true) {
      _isMarkerMoveMode = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이동할 새 위치를 지도에서 눌러주세요.')));
    }
  }

  Future<void> _chooseCameraMedia(MapMarker marker) async {
    final type = await showModalBottomSheet<MediaType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, MediaType.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('동영상 촬영'),
              onTap: () => Navigator.pop(context, MediaType.video),
            ),
          ],
        ),
      ),
    );
    if (!mounted || type == null) return;
    if (type == MediaType.photo) {
      await _pickMedia(marker, ImageSource.camera);
    } else {
      await _pickVideo(marker, ImageSource.camera);
    }
  }

  void _showFullScreenPhoto(String path) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _showMediaChoice(MapMarker marker, List<MediaItem> media) async {
    final selected = await showModalBottomSheet<MediaItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: media.map((item) {
            final isPhoto = item.type == MediaType.photo;
            return ListTile(
              leading: Icon(isPhoto ? Icons.photo : Icons.videocam),
              title: Text(isPhoto ? '사진 보기' : '동영상 재생'),
              subtitle: Text(item.recordedAt.toLocal().toString()),
              onTap: () => Navigator.pop(context, item),
            );
          }).toList(),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected.type == MediaType.photo) {
      final updated = MapMarker(
        id: marker.id,
        title: marker.title,
        latitude: marker.latitude,
        longitude: marker.longitude,
        note: marker.note,
        category: marker.category,
        preferredMediaId: selected.id,
      );
      final index = _markers.indexWhere((item) => item.id == marker.id);
      if (index >= 0) _markers[index] = updated;
      _markersNotifier.value = List.unmodifiable(_markers);
      await ref.read(trackingRepositoryProvider).updateMarker(updated);
      if (mounted) _showFullScreenPhoto(selected.filePath);
    } else {
      await _playVideo(selected.filePath);
    }
  }

  Future<void> _openMedia(MediaItem item, MapMarker marker) async {
    if (item.type == MediaType.video) {
      await _playVideo(item.filePath);
      return;
    }
    final updated = MapMarker(
      id: marker.id,
      title: marker.title,
      latitude: marker.latitude,
      longitude: marker.longitude,
      note: marker.note,
      category: marker.category,
      preferredMediaId: item.id,
    );
    final index = _markers.indexWhere((m) => m.id == marker.id);
    if (index >= 0) _markers[index] = updated;
    _markersNotifier.value = List.unmodifiable(_markers);
    await ref.read(trackingRepositoryProvider).updateMarker(updated);
    if (mounted) _showFullScreenPhoto(item.filePath);
  }

  Future<void> _showMarkerPhotos(MapMarker marker) async {
    final media = await ref
        .read(trackingRepositoryProvider)
        .loadMedia(marker.id);
    if (!mounted) return;
    if (media.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 마커에 연결된 사진이 없습니다.')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: media
              .where((item) => File(item.filePath).existsSync())
              .map((item) => _buildMediaEntry(item, marker))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildMediaEntry(MediaItem item, MapMarker marker) {
    if (item.type == MediaType.video) {
      return ListTile(
        leading: const Icon(Icons.play_circle),
        title: const Text('동영상'),
        onTap: () => _playVideo(item.filePath),
        trailing: TextButton(
          onPressed: () => _deleteMedia(item),
          child: const Text('연결 해제'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final updated = MapMarker(
                id: marker.id,
                title: marker.title,
                latitude: marker.latitude,
                longitude: marker.longitude,
                note: marker.note,
                category: marker.category,
                preferredMediaId: item.id,
              );
              final index = _markers.indexWhere((m) => m.id == marker.id);
              if (index >= 0) _markers[index] = updated;
              _markersNotifier.value = List.unmodifiable(_markers);
              await ref.read(trackingRepositoryProvider).updateMarker(updated);
              if (mounted) _showFullScreenPhoto(item.filePath);
            },
            child: Image.file(
              File(item.filePath),
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _deleteMedia(item),
              icon: const Icon(Icons.delete_outline),
              label: const Text('사진 제거'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playVideo(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.play();
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      );
    } catch (error) {
      debugPrint('동영상 재생 실패: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('동영상 파일을 재생할 수 없습니다.')));
      }
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _deleteMedia(MediaItem item) async {
    await ref.read(trackingRepositoryProvider).deleteMedia(item.id);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('사진을 제거했습니다.')));
  }

  Future<void> _editMarker(MapMarker marker, Poi poi) async {
    final titleController = TextEditingController(text: marker.title);
    final noteController = TextEditingController(text: marker.note ?? '');
    final categoryController = TextEditingController(
      text: marker.category ?? '',
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마커 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: '분류'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'note': noteController.text.trim(),
              'category': categoryController.text.trim(),
            }),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    final title = result?['title'];
    if (!mounted || title == null || title.isEmpty) return;
    final updated = MapMarker(
      id: marker.id,
      title: title,
      latitude: marker.latitude,
      longitude: marker.longitude,
      note: result?['note']?.isEmpty == true ? null : result?['note'],
      category: result?['category']?.isEmpty == true
          ? null
          : result?['category'],
    );
    await poi.changeText(updated.title);
    final index = _markers.indexWhere((item) => item.id == marker.id);
    if (index >= 0) _markers[index] = updated;
    _markersNotifier.value = List.unmodifiable(_markers);
    await ref.read(trackingRepositoryProvider).updateMarker(updated);
  }

  Future<void> _pickMedia(MapMarker marker, ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (!mounted || file == null) return;
    final savedPath = await _persistMediaFile(file);
    if (!mounted || savedPath == null) return;
    final thumbnailPath = await _persistPhotoThumbnail(savedPath);
    final item = MediaItem(
      id: 'media-${DateTime.now().microsecondsSinceEpoch}',
      markerId: marker.id,
      type: MediaType.photo,
      filePath: savedPath,
      thumbnailPath: thumbnailPath ?? savedPath,
      recordedAt: DateTime.now().toUtc(),
      latitude: marker.latitude,
      longitude: marker.longitude,
      locationSource: MediaLocationSource.exact,
    );
    if (!await _saveMediaSafely(item)) return;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진과 위치 정보를 저장했습니다.')));
    }
  }

  Future<void> _pickVideo(MapMarker marker, ImageSource source) async {
    final file = await ImagePicker().pickVideo(source: source);
    if (!mounted || file == null) return;
    final savedPath = await _persistMediaFile(file);
    if (!mounted || savedPath == null) return;
    String? thumbnailPath;
    try {
      final root = await getApplicationDocumentsDirectory();
      thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: savedPath,
        thumbnailPath: root.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 240,
        quality: 75,
      );
    } catch (error) {
      debugPrint('동영상 썸네일 생성 실패: $error');
    }
    final item = MediaItem(
      id: 'media-${DateTime.now().microsecondsSinceEpoch}',
      markerId: marker.id,
      type: MediaType.video,
      filePath: savedPath,
      thumbnailPath: thumbnailPath ?? savedPath,
      recordedAt: DateTime.now().toUtc(),
      latitude: marker.latitude,
      longitude: marker.longitude,
      locationSource: MediaLocationSource.exact,
    );
    if (!await _saveMediaSafely(item)) return;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('동영상과 위치 정보를 저장했습니다.')));
    }
  }

  Future<bool> _saveMediaSafely(MediaItem item) async {
    try {
      await ref.read(trackingRepositoryProvider).saveMedia(item);
      return true;
    } catch (error) {
      debugPrint('미디어 메타데이터 저장 실패: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('미디어 정보를 저장하지 못했습니다. 원본 파일은 보존됩니다.')),
        );
      }
      return false;
    }
  }

  Future<String?> _persistMediaFile(XFile file) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final mediaDirectory = Directory(
        '${root.path}${Platform.pathSeparator}media${Platform.pathSeparator}originals',
      );
      await mediaDirectory.create(recursive: true);
      final extension = file.path.contains('.')
          ? file.path.substring(file.path.lastIndexOf('.'))
          : '.jpg';
      final destination = File(
        '${mediaDirectory.path}${Platform.pathSeparator}media-'
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      return (await File(file.path).copy(destination.path)).path;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진을 저장하지 못했습니다: $error')));
      }
      return null;
    }
  }

  Future<String?> _persistPhotoThumbnail(String originalPath) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final thumbnailDirectory = Directory(
        '${root.path}${Platform.pathSeparator}media${Platform.pathSeparator}thumbnails',
      );
      await thumbnailDirectory.create(recursive: true);
      final extension = originalPath.contains('.')
          ? originalPath.substring(originalPath.lastIndexOf('.'))
          : '.jpg';
      final destination = File(
        '${thumbnailDirectory.path}${Platform.pathSeparator}thumb-'
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      return (await File(originalPath).copy(destination.path)).path;
    } catch (error) {
      debugPrint('사진 썸네일 저장 실패: $error');
      return null;
    }
  }

  Future<void> _captureAtCurrentLocation() async {
    final type = await showModalBottomSheet<MediaType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(context, MediaType.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('동영상 촬영'),
              onTap: () => Navigator.pop(context, MediaType.video),
            ),
          ],
        ),
      ),
    );
    if (!mounted || type == null) return;
    if (type == MediaType.video) {
      await _captureVideoAtCurrentLocation();
      return;
    }
    await _capturePhotoAtCurrentLocation();
  }

  Future<void> _capturePhotoAtCurrentLocation() async {
    final position = ref.read(trackingControllerProvider).currentPosition;
    if (position == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 위치를 아직 확인하지 못했습니다.')));
      return;
    }
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (!mounted || file == null || _mapController == null) return;
    final savedPath = await _persistMediaFile(file);
    if (!mounted || savedPath == null) return;
    final thumbnailPath = await _persistPhotoThumbnail(savedPath);
    final titleController = TextEditingController(
      text: '사진 ${DateTime.now().toLocal().toString().substring(0, 16)}',
    );
    final memoController = TextEditingController();
    final photoInfo = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 메모'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '마커 이름'),
            ),
            TextField(
              controller: memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모(선택)',
                hintText: '사진에 대한 메모를 입력하세요',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('건너뛰기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'note': memoController.text.trim(),
            }),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final capturedAt = DateTime.now().toUtc();
    final markerTitle = photoInfo?['title'];
    if (!mounted || markerTitle == null || markerTitle.isEmpty) return;
    final marker = MapMarker(
      id: 'marker-${DateTime.now().microsecondsSinceEpoch}',
      title: markerTitle,
      latitude: position.latitude,
      longitude: position.longitude,
      note: photoInfo?['note']?.isEmpty == true ? null : photoInfo?['note'],
      category: '사진',
    );
    final mapController = _mapController!;
    final poi = await mapController.labelLayer.addPoi(
      LatLng(marker.latitude, marker.longitude),
      id: marker.id,
      text: marker.title,
      rank: 100,
      style: PoiStyle(
        icon: KImage.fromAsset('assets/icon/sanc_photo_marker.png', 48, 48),
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
    mapController.moveCamera(
      CameraUpdate.newCenterPosition(LatLng(marker.latitude, marker.longitude)),
    );
    _markerPois[marker.id] = poi;
    _markers.add(marker);
    _markersNotifier.value = List.unmodifiable(_markers);
    await ref.read(trackingRepositoryProvider).saveMarker(marker);
    final savedMedia = await _saveMediaSafely(
      MediaItem(
        id: 'media-${DateTime.now().microsecondsSinceEpoch}',
        markerId: marker.id,
        type: MediaType.photo,
        filePath: savedPath,
        thumbnailPath: thumbnailPath ?? savedPath,
        recordedAt: capturedAt,
        latitude: position.latitude,
        longitude: position.longitude,
        locationSource: MediaLocationSource.exact,
      ),
    );
    if (!savedMedia) return;
    try {
      await Gal.putImage(savedPath, album: 'SANC Tracker');
    } catch (error) {
      debugPrint('카메라 사진 갤러리 저장 지연: $error');
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진과 촬영 위치·시간을 저장했습니다.')));
    }
  }

  Future<void> _captureVideoAtCurrentLocation() async {
    final position = ref.read(trackingControllerProvider).currentPosition;
    if (position == null || _mapController == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('현재 위치를 아직 확인하지 못했습니다.')));
      }
      return;
    }
    final file = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (!mounted || file == null) return;
    final savedPath = await _persistMediaFile(file);
    if (!mounted || savedPath == null) return;
    String? thumbnailPath;
    try {
      final root = await getApplicationDocumentsDirectory();
      thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: savedPath,
        thumbnailPath: root.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 240,
        quality: 75,
      );
    } catch (error) {
      debugPrint('동영상 썸네일 생성 실패: $error');
    }
    final marker = MapMarker(
      id: 'marker-${DateTime.now().microsecondsSinceEpoch}',
      title: '동영상 ${DateTime.now().toLocal().toString().substring(0, 16)}',
      latitude: position.latitude,
      longitude: position.longitude,
      category: '동영상',
    );
    final poi = await _mapController!.labelLayer.addPoi(
      LatLng(marker.latitude, marker.longitude),
      id: marker.id,
      text: marker.title,
      rank: 100,
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
    _markerPois[marker.id] = poi;
    _markers.add(marker);
    _markersNotifier.value = List.unmodifiable(_markers);
    await ref.read(trackingRepositoryProvider).saveMarker(marker);
    await _saveMediaSafely(
      MediaItem(
        id: 'media-${DateTime.now().microsecondsSinceEpoch}',
        markerId: marker.id,
        type: MediaType.video,
        filePath: savedPath,
        thumbnailPath: thumbnailPath ?? savedPath,
        recordedAt: DateTime.now().toUtc(),
        latitude: position.latitude,
        longitude: position.longitude,
        locationSource: MediaLocationSource.exact,
      ),
    );
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
