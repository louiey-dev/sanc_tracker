import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/theme/app_colors.dart';
import '../../map/map_marker.dart';
import '../../map/presentation/widgets/marker_detail_sheet.dart';
import '../../map/presentation/widgets/marker_input_dialog.dart';
import '../../map/presentation/widgets/video_player_dialog.dart';
import '../../media/media_item.dart';
import '../../media/photo_capture_service.dart';
import '../data/tracking_preferences.dart';
import '../domain/tracking_session.dart';
import 'tracking_controller.dart';
import 'widgets/map_floating_actions.dart';
import 'widgets/map_legend_chip.dart';
import 'widgets/tracking_hud_card.dart';

class TrackMapScreen extends ConsumerStatefulWidget {
  const TrackMapScreen({
    super.key,
    this.onSavedRouteStatusChanged,
  });

  final ValueChanged<bool>? onSavedRouteStatusChanged;

  @override
  ConsumerState<TrackMapScreen> createState() => TrackMapScreenState();
}

class TrackMapScreenState extends ConsumerState<TrackMapScreen>
    with WidgetsBindingObserver {
  KakaoMapController? _mapController;
  Poi? _currentPoi;
  Polyline? _liveRouteLine;
  Polyline? _savedRouteLine;
  Poi? _savedRouteStartPoi;
  Poi? _savedRouteEndPoi;
  bool _isUpdatingCurrentPoi = false;
  LatLng? _pendingCurrentPosition;
  Poi? _selectedMarkerPoi;
  MapMarker? _selectedMarker;
  bool _isMarkerMoveMode = false;
  bool _isMarkerSheetOpen = false;
  bool _isViewingSavedRoute = false;
  bool _photoBusy = true;
  bool _isCameraActive = false;
  bool _isMapInitialStateReady = false;
  final List<MapMarker> _markers = [];
  final Map<String, Poi> _markerPois = {};

  bool get isViewingSavedRoute => _isViewingSavedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recoverPhotoCapture();
    _initializeTracking();
    ref.listenManual(trackingControllerProvider, (previous, next) {
      final p = next.currentPosition;
      final c = _mapController;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      if (p == null || c == null) {
        return;
      }
      final ll = LatLng(p.latitude, p.longitude);
      c.moveCamera(CameraUpdate.newCenterPosition(ll));
      _setCurrentLocationMarker(c, ll);
      if (!_isViewingSavedRoute && next.isTracking) {
        _drawLiveRoute(next.route);
      } else if (!next.isTracking && _liveRouteLine != null) {
        _mapController?.shapeLayer.removePolylineShape(_liveRouteLine!);
        _liveRouteLine = null;
      }
    });
    ref.listenManual(markersListProvider, (previous, next) {
      next.whenData((markers) {
        if (mounted) {
          _syncMapMarkers(markers);
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    final controller = _mapController;
    final position = ref.read(trackingControllerProvider).currentPosition;
    if (controller != null && position != null) {
      _setCurrentLocationMarker(
        controller,
        LatLng(position.latitude, position.longitude),
      );
    }
  }

  Future<void> _initializeTracking() async {
    try {
      await ref.read(trackingPreferencesProvider.notifier).load();
    } catch (_) {
      // Missing or damaged preferences must not prevent session recovery.
    }
    if (!mounted) {
      return;
    }
    final controller = ref.read(trackingControllerProvider.notifier);
    await controller.restoreActiveSession();
    await controller.loadLastKnownPosition();
    if (!mounted) {
      return;
    }
    setState(() => _isMapInitialStateReady = true);
    unawaited(controller.loadCurrentPosition());
  }

  Future<PhotoCaptureService> _photoService() async => PhotoCaptureService(
    await getApplicationDocumentsDirectory(),
    ref.read(trackingRepositoryProvider),
  );

  void _photoMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _recoverPhotoCapture() async {
    try {
      final service = await _photoService();
      final marker = await service.recover();
      if (marker != null) {
        _photoMessage('중단된 사진과 마커를 복구했습니다.');
        ref.invalidate(markersListProvider);
      }
    } catch (error) {
      _photoMessage('사진 복구 실패: $error. 원본과 복구 정보는 보존됩니다.');
    } finally {
      _photoBusy = false;
      if (mounted) await _loadSavedMarkers();
    }
  }

  Future<bool> _runPhotoCapture(MapMarker marker, ImageSource source) async {
    final service = await _photoService();
    final usingCamera = source == ImageSource.camera;
    if (usingCamera) await _suspendMapForCamera();
    try {
      final saved = await service.capture(marker, source);
      if (saved == null) return false;
      _photoMessage('사진과 위치 정보를 저장했습니다.');
      ref.invalidate(markersListProvider);
      if (usingCamera) {
        try {
          final media = await service.repository.loadMedia(marker.id);
          await Gal.putImage(media.last.filePath, album: 'SANC Tracker');
        } catch (error) {
          debugPrint('갤러리 저장 실패 (앱 원본 보존): $error');
        }
      }
    } finally {
      if (usingCamera && mounted) await _restoreMapAfterCamera();
    }
    if (mounted) {
      try {
        await _loadSavedMarkers();
      } catch (error) {
        _photoMessage('사진은 저장되었습니다. 지도 표시 실패: $error');
      }
    }
    return true;
  }

  Future<void> _suspendMapForCamera() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (mounted) setState(() => _isCameraActive = true);
  }

  Future<void> _restoreMapAfterCamera() async {
    if (mounted) setState(() => _isCameraActive = false);
  }

  Future<void> _loadSavedMarkers() async {
    final saved = await ref.read(trackingRepositoryProvider).loadMarkers();
    if (!mounted) return;
    await _syncMapMarkers(saved);
  }

  Future<void> _syncMapMarkers(List<MapMarker> saved) async {
    _markers
      ..clear()
      ..addAll(saved);
    final controller = _mapController;
    if (controller == null) return;

    final incomingIds = saved.map((m) => m.id).toSet();
    final removedIds =
        _markerPois.keys.where((id) => !incomingIds.contains(id)).toList();

    for (final id in removedIds) {
      final poi = _markerPois.remove(id);
      if (poi != null) {
        try {
          await controller.labelLayer.removePoi(poi);
        } catch (error) {
          debugPrint('마커 POI 제거 지연: $error');
        }
      }
    }

    for (final marker in saved) {
      if (_markerPois.containsKey(marker.id)) continue;
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

  void moveToCurrentLocation() {
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

  void focusMarker(MapMarker marker) {
    _mapController?.moveCamera(
      CameraUpdate.newCenterPosition(LatLng(marker.latitude, marker.longitude)),
    );
  }

  Future<void> viewSessionRoute(TrackingSession session) async {
    _isViewingSavedRoute = true;
    widget.onSavedRouteStatusChanged?.call(true);
    await ref
        .read(trackingControllerProvider.notifier)
        .loadSessionRoute(session);
    final savedRoute = ref.read(trackingControllerProvider).savedRoute;
    if (_mapController != null && savedRoute.isNotEmpty) {
      await _drawSavedRoute(savedRoute);
      _mapController!.moveCamera(
        CameraUpdate.newCenterPosition(
          LatLng(savedRoute.first.latitude, savedRoute.first.longitude),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  void exitSavedRoute() {
    final savedLine = _savedRouteLine;
    if (savedLine != null && _mapController != null) {
      _mapController!.shapeLayer.removePolylineShape(savedLine);
      _savedRouteLine = null;
    }
    if (_mapController != null) {
      if (_savedRouteStartPoi != null) {
        _mapController!.labelLayer.removePoi(_savedRouteStartPoi!);
        _savedRouteStartPoi = null;
      }
      if (_savedRouteEndPoi != null) {
        _mapController!.labelLayer.removePoi(_savedRouteEndPoi!);
        _savedRouteEndPoi = null;
      }
    }
    _savedRouteStartPoi = null;
    _savedRouteEndPoi = null;
    ref.read(trackingControllerProvider.notifier).clearLoadedSessionRoute();
    _isViewingSavedRoute = false;
    widget.onSavedRouteStatusChanged?.call(false);
    moveToCurrentLocation();
    if (mounted) setState(() {});
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
      await ref.read(trackingRepositoryProvider).updateMarker(_selectedMarker!);
      ref.invalidate(markersListProvider);
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
    ref.invalidate(markersListProvider);
    if (_selectedMarker?.id == marker.id) {
      _selectedMarker = null;
      _selectedMarkerPoi = null;
      _isMarkerMoveMode = false;
    }
  }

  Future<void> _showMarkerDetails(MapMarker marker, LatLng position) async {
    final poi = _selectedMarkerPoi;
    if (!mounted || poi == null || _isMarkerSheetOpen) return;
    _isMarkerSheetOpen = true;
    final mediaFuture = ref
        .read(trackingRepositoryProvider)
        .loadMedia(marker.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MarkerDetailSheet(
        marker: marker,
        mediaFuture: mediaFuture,
        onMove: () {
          Navigator.pop(context);
          setState(() => _isMarkerMoveMode = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이동할 새 위치를 지도에서 눌러주세요.')),
          );
        },
        onEdit: () {
          Navigator.pop(context);
          _editMarker(marker, poi);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteMarker(marker, poi);
        },
        onCaptureMedia: () => _chooseCameraMedia(marker),
        onPickGallery: () => _pickMedia(marker, ImageSource.gallery),
        onOpenMedia: (item) => _openMedia(item, marker),
        onShowFullScreenPhoto: _showFullScreenPhoto,
        onPlayVideo: _playVideo,
      ),
    );
    _isMarkerSheetOpen = false;
  }

  Future<void> _addMarker(LatLng position) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final result = await MarkerInputDialog.show(
      context,
      dialogTitle: '장소 마커 추가',
      initialTitle: '장소 마커',
      titleLabel: '제목',
      submitLabel: '저장',
    );
    final title = result?['title'];
    if (!mounted || title == null || title.isEmpty || _mapController == null) {
      return;
    }
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
      _markers.add(marker);
      await ref.read(trackingRepositoryProvider).saveMarker(marker);
      ref.invalidate(markersListProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('마커를 저장하지 못했습니다: $error')));
      }
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
            child: Image.file(
              File(path),
              cacheWidth: 2048,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
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
    await ref.read(trackingRepositoryProvider).updateMarker(updated);
    ref.invalidate(markersListProvider);
    if (mounted) _showFullScreenPhoto(item.filePath);
  }

  Future<void> _playVideo(String path) async {
    try {
      await VideoPlayerDialog.show(context, path);
    } catch (error) {
      debugPrint('동영상 재생 실패: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('동영상 파일을 재생할 수 없습니다.')));
      }
    }
  }

  Future<void> _editMarker(MapMarker marker, Poi poi) async {
    final result = await MarkerInputDialog.show(
      context,
      dialogTitle: '마커 수정',
      initialTitle: marker.title,
      initialNote: marker.note,
      initialCategory: marker.category,
      titleLabel: '이름',
      submitLabel: '저장',
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
    await ref.read(trackingRepositoryProvider).updateMarker(updated);
    ref.invalidate(markersListProvider);
  }

  Future<void> _pickMedia(MapMarker marker, ImageSource source) async {
    if (_photoBusy) return;
    _photoBusy = true;
    try {
      await _runPhotoCapture(marker, source);
    } catch (error) {
      _photoMessage('사진 처리 실패: $error. 앱을 다시 열면 저장을 재시도합니다.');
    } finally {
      _photoBusy = false;
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
        ).showSnackBar(SnackBar(content: Text('미디어를 저장하지 못했습니다: $error')));
      }
      return null;
    }
  }

  Future<void> capturePhotoAtCurrentLocation() async {
    if (_photoBusy) return;
    final position = ref.read(trackingControllerProvider).currentPosition;
    if (position == null) {
      _photoMessage('현재 위치를 아직 확인하지 못했습니다.');
      return;
    }
    _photoBusy = true;
    try {
      final defaultTitle =
          '사진 ${DateTime.now().toLocal().toString().substring(0, 16)}';
      final marker = MapMarker(
        id: 'marker-${DateTime.now().microsecondsSinceEpoch}',
        title: defaultTitle,
        latitude: position.latitude,
        longitude: position.longitude,
        note: null,
        category: '사진',
      );
      final captured = await _runPhotoCapture(marker, ImageSource.camera);
      if (!captured) return;

      if (!mounted) return;
      final photoInfo = await PhotoMemoDialog.show(
        context,
        defaultTitle: defaultTitle,
      );
      if (!mounted || photoInfo == null) return;
      final updated = MapMarker(
        id: marker.id,
        title: photoInfo['title']?.isNotEmpty == true
            ? photoInfo['title']!
            : defaultTitle,
        latitude: marker.latitude,
        longitude: marker.longitude,
        note: photoInfo['note']?.isNotEmpty == true ? photoInfo['note'] : null,
        category: marker.category,
      );
      final index = _markers.indexWhere((item) => item.id == marker.id);
      if (index >= 0) _markers[index] = updated;
      await ref.read(trackingRepositoryProvider).updateMarker(updated);
      ref.invalidate(markersListProvider);
      final poi = _markerPois[marker.id];
      if (poi != null) await poi.changeText(updated.title);
    } catch (error) {
      _photoMessage('사진 처리 실패: $error. 앱을 다시 열면 저장을 재시도합니다.');
    } finally {
      _photoBusy = false;
    }
  }

  Future<void> _showNearestRoutePoint(LatLng position) async {
    final tracking = ref.read(trackingControllerProvider);
    final points = _isViewingSavedRoute && tracking.savedRoute.isNotEmpty
        ? tracking.savedRoute
        : tracking.route;
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
          '기록 시각: ${point.timestamp.toLocal()}\n'
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

  Future<void> _drawLiveRoute(List<Position> points) async {
    if (_mapController == null) return;
    if (points.length < 2) {
      if (_liveRouteLine != null) {
        await _mapController!.shapeLayer.removePolylineShape(_liveRouteLine!);
        _liveRouteLine = null;
      }
      return;
    }
    final previousLine = _liveRouteLine;
    if (previousLine != null) {
      await _mapController!.shapeLayer.removePolylineShape(previousLine);
    }
    _liveRouteLine = await _mapController!.shapeLayer.addPolylineShape(
      MapPoint(points.map((p) => LatLng(p.latitude, p.longitude)).toList()),
      PolylineStyle(AppColors.trackingLive, 8),
      PolylineCap.round,
      id: 'tracking-live-route',
    );
  }

  Future<void> _drawSavedRoute(List<Position> points) async {
    if (_mapController == null || points.length < 2) return;
    if (_savedRouteStartPoi != null) {
      await _mapController!.labelLayer.removePoi(_savedRouteStartPoi!);
      _savedRouteStartPoi = null;
    }
    if (_savedRouteEndPoi != null) {
      await _mapController!.labelLayer.removePoi(_savedRouteEndPoi!);
      _savedRouteEndPoi = null;
    }
    final previousLine = _savedRouteLine;
    if (previousLine != null) {
      await _mapController!.shapeLayer.removePolylineShape(previousLine);
    }
    _savedRouteLine = await _mapController!.shapeLayer.addPolylineShape(
      MapPoint(points.map((p) => LatLng(p.latitude, p.longitude)).toList()),
      PolylineStyle(AppColors.primary, 8),
      PolylineCap.round,
      id: 'tracking-saved-route',
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
    _savedRouteStartPoi = await _mapController!.labelLayer.addPoi(
      start,
      id: 'saved-route-start',
      text: '출발',
      style: routeLabelStyle,
    );
    _savedRouteEndPoi = await _mapController!.labelLayer.addPoi(
      end,
      id: 'saved-route-end',
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
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
      debugPrint('현재 위치 마커 갱신 지연: $error');
    } finally {
      _isUpdatingCurrentPoi = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingControllerProvider);
    final p = tracking.currentPosition;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        // Full Canvas Kakao Map
        if (!_isMapInitialStateReady)
          const ColoredBox(
            color: AppColors.backgroundLight,
            child: Center(child: CircularProgressIndicator()),
          )
        else
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
              if (p != null) {
                _setCurrentLocationMarker(
                  c,
                  LatLng(p.latitude, p.longitude),
                );
              }
              _syncMapMarkers(_markers);
              if (tracking.isTracking) {
                _drawLiveRoute(tracking.route);
              }
              if (tracking.savedRoute.isNotEmpty) {
                _drawSavedRoute(tracking.savedRoute);
              }
            },
            onTerrainLongClick: (_, position) => _addMarker(position),
            onMapClick: (_, position) => _isViewingSavedRoute
                ? _showNearestRoutePoint(position)
                : _moveSelectedMarker(position),
          ),

        // Camera preview suspension overlay
        if (_isCameraActive)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xfff5f5f5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 40),
                    SizedBox(height: 8),
                    Text('카메라 실행 중'),
                  ],
                ),
              ),
            ),
          ),

        // Top Floating HUD Card
        Positioned(
          top: topPadding + 10,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrackingHudCard(
                tracking: tracking,
                onToggleTracking: () => ref
                    .read(trackingControllerProvider.notifier)
                    .toggleTracking(),
              ),
              if (_isViewingSavedRoute) ...[
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  color: AppColors.safetyAmber.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.safetyAmber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.safetyAmber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tracking.viewedSession?.title?.isNotEmpty == true
                                ? '저장 경로 보기 중: “${tracking.viewedSession!.title}”'
                                : '저장 경로 보기 중',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: exitSavedRoute,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text(
                            '보기 종료',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!tracking.isTracking &&
                  !_isViewingSavedRoute &&
                  tracking.message == null) ...[
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final pos = tracking.currentPosition;
                    final isReady = pos != null;
                    final accuracy = pos?.accuracy ?? 0.0;
                    final isHighAccuracy = isReady && accuracy <= 30;

                    final icon = !isReady
                        ? Icons.satellite_alt_rounded
                        : (isHighAccuracy
                            ? Icons.gps_fixed_rounded
                            : Icons.gps_not_fixed_rounded);
                    final color = !isReady
                        ? AppColors.textMuted
                        : (isHighAccuracy
                            ? AppColors.trackingLive
                            : AppColors.safetyAmber);
                    final text = !isReady
                        ? 'GPS 위성 신호 수신 대기 중... (실외 권장)'
                        : (isHighAccuracy
                            ? 'GPS 준비 완료 (±${accuracy.toStringAsFixed(0)}m) · 시작을 누르면 기록됩니다'
                            : 'GPS 신호 안정화 중 (±${accuracy.toStringAsFixed(0)}m)');

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              if (tracking.message != null) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isInfo = tracking.message!.startsWith('추적') ||
                        tracking.message!.startsWith('저장 경로') ||
                        tracking.message!.contains('불러왔습니다');
                    final containerColor = isInfo
                        ? AppColors.primaryContainer
                        : AppColors.errorContainer;
                    final contentColor = isInfo
                        ? AppColors.onPrimaryContainer
                        : AppColors.error;

                    return Card(
                      elevation: 2,
                      color: containerColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isInfo
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isInfo
                                  ? Icons.info_outline_rounded
                                  : Icons.warning_amber_rounded,
                              size: 18,
                              color: isInfo
                                  ? AppColors.primary
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tracking.message!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: contentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkResponse(
                              onTap: () => ref
                                  .read(trackingControllerProvider.notifier)
                                  .clearMessage(),
                              radius: 16,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: contentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        // Map Legend Overlay (Left Bottom)
        const Positioned(
          left: 16,
          bottom: 20,
          child: MapLegendChip(),
        ),

        // Floating Action Buttons (Right Bottom)
        Positioned(
          right: 16,
          bottom: 20,
          child: MapFloatingActions(
            onMoveToCurrentLocation: moveToCurrentLocation,
            onCaptureCurrentLocation: capturePhotoAtCurrentLocation,
            isViewingSavedRoute: _isViewingSavedRoute,
            onExitSavedRoute: exitSavedRoute,
          ),
        ),
      ],
    );
  }
}
