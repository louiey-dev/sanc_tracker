import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const SancTrackerApp());

class SancTrackerApp extends StatelessWidget {
  const SancTrackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SANC Tracker',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const TrackingPage(),
  );
}

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  StreamSubscription<Position>? _subscription;
  Position? _currentPosition;
  final List<Position> _route = [];
  String? _message;
  bool _isTracking = false;

  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _subscription?.cancel();
      _subscription = null;
      setState(() { _isTracking = false; _message = '추적이 중지되었습니다. ${_route.length}개의 위치가 수집되었습니다.'; });
      return;
    }
    setState(() => _message = null);
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _message = '휴대폰의 위치 서비스를 켜 주세요.'); return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _message = '위치 권한이 필요합니다. 설정에서 권한을 허용해 주세요.'); return;
    }
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen(_onPosition, onError: (Object error) {
      if (mounted) setState(() => _message = '위치 수집 오류: $error');
    });
    setState(() => _isTracking = true);
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    setState(() { _currentPosition = position; _route.add(position); _message = null; });
  }

  @override
  Widget build(BuildContext context) {
    final position = _currentPosition;
    return Scaffold(
      appBar: AppBar(title: const Text('SANC Tracker')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: SizedBox(height: 280, child: Center(child: position == null
          ? const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.map_outlined, size: 56), SizedBox(height: 12), Text('추적을 시작하면 현재 위치가 표시됩니다.')])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.my_location, size: 56), const SizedBox(height: 12),
              Text('${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'),
              Text('정확도 ±${position.accuracy.toStringAsFixed(1)}m'),
            ])))),
        const SizedBox(height: 16),
        ListTile(leading: Icon(_isTracking ? Icons.gps_fixed : Icons.gps_off), title: Text(_isTracking ? '추적 중' : '추적 대기'), subtitle: Text('수집된 위치: ${_route.length}개'), trailing: FilledButton.icon(onPressed: _toggleTracking, icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow), label: Text(_isTracking ? '중지' : '시작'))),
        if (_message != null) Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(_message!))),
        const SizedBox(height: 12),
        const Text('현재 버전은 수집한 경로를 앱 메모리에 보관합니다. 다음 단계에서 로컬 DB와 백그라운드 추적을 연결합니다.'),
      ]),
    );
  }
}
