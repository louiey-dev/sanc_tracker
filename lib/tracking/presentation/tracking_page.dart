import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'tracking_controller.dart';

class TrackingPage extends ConsumerWidget {
  const TrackingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingControllerProvider);
    final position = tracking.currentPosition;
    return Scaffold(
      appBar: AppBar(title: const Text('SANC Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 280,
            child: KakaoMap(
              initialPosition: LatLng(
                latitude: position?.latitude ?? 37.5665,
                longitude: position?.longitude ?? 126.9780,
              ),
              initialLevel: 15,
              onMapCreated: (_) {},
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
          const SizedBox(height: 12),
          const Text(
            '현재 버전은 수집한 경로를 앱 메모리에 보관합니다. 다음 단계에서 로컬 DB와 백그라운드 추적을 연결합니다.',
          ),
        ],
      ),
    );
  }
}
