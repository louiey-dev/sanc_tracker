import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanc_tracker/map/map_marker.dart';
import 'package:sanc_tracker/map/presentation/widgets/marker_detail_sheet.dart';
import 'package:sanc_tracker/media/media_item.dart';

void main() {
  testWidgets('MarkerDetailSheet renders all buttons without overflow on vertical screens', (tester) async {
    // Set a narrow portrait/vertical screen constraint (360x640 - standard Android phone)
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const marker = MapMarker(
      id: 'test-marker',
      title: '산 정상 전망대',
      latitude: 37.5665,
      longitude: 126.9780,
      note: '경치가 좋은 곳',
      category: '사진',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkerDetailSheet(
            marker: marker,
            mediaFuture: Future.value(const <MediaItem>[]),
            onMove: () {},
            onEdit: () {},
            onDelete: () {},
            onCaptureMedia: () {},
            onPickGallery: () {},
            onOpenMedia: (_) {},
            onShowFullScreenPhoto: (_) {},
            onPlayVideo: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify all action buttons are present and visible
    expect(find.text('촬영'), findsOneWidget);
    expect(find.text('갤러리'), findsOneWidget);
    expect(find.text('위치 이동'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);

    // Verify no RenderFlex overflow exception occurred
    expect(tester.takeException(), isNull);
  });

  testWidgets('MarkerDetailSheet renders on ultra-narrow 320px screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const marker = MapMarker(
      id: 'narrow-marker',
      title: '아주 긴 이름의 마커 테스트',
      latitude: 37.123456,
      longitude: 127.123456,
      category: '동영상',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkerDetailSheet(
            marker: marker,
            mediaFuture: Future.value(const <MediaItem>[]),
            onMove: () {},
            onEdit: () {},
            onDelete: () {},
            onCaptureMedia: () {},
            onPickGallery: () {},
            onOpenMedia: (_) {},
            onShowFullScreenPhoto: (_) {},
            onPlayVideo: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('촬영'), findsOneWidget);
    expect(find.text('갤러리'), findsOneWidget);
    expect(find.text('위치 이동'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
