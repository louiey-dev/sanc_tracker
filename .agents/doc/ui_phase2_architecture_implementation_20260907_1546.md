# UI Phase 2 아키텍처 및 상태 동기화 개선 보고서

본 문서는 Phase 2 UI 권장 개선 사항 5개 항목의 구현 내용과 검증 결과를 기록합니다.

---

## 1. 개선 항목 개요

1. **IndexedStack 탭 간 데이터 자동 갱신 (Data Refresh)**
   - 문제: `IndexedStack`으로 화면이 유지되면서 다른 탭에서 생성/삭제된 세션이나 마커가 즉시 반영되지 않던 문제.
   - 해결: Riverpod `sessionsListProvider` 및 `markersListProvider` (`FutureProvider.autoDispose`)를 도입하고, 탭 전환 시점(`MainNavigationPage._onTabSelected`) 및 세션/마커 추가·수정·삭제 시점에 `ref.invalidate`를 트리거하여 화면 간 실시간 동기화를 구축함.

2. **카카오맵 마커 삭제 동기화 및 고스트 마커 방지 (Marker Deletion Synchronization)**
   - 문제: `TrackMapScreen._loadSavedMarkers()`가 빈 목록일 때 조기 반환하여 마커 전체 삭제 시 네이티브 POI가 지도에 영구 잔존하던 문제.
   - 해결: `_syncMapMarkers(List<MapMarker> saved)` 메서드를 통해 들어오는 마커 ID 집합과 기존 `_markerPois`를 비교하여, 삭제된 모든 POI를 안전하게 `removePoi()`로 정리하도록 수정.

3. **저장된 세션 경로 상태 격리 (Saved Route State Isolation)**
   - 문제: 과거 세션 경로 조회 시 활성 추적의 `route`를 덮어쓰고, 조회 종료 시 `route`를 초기화하여 백그라운드 추적 기록이 유실되던 문제.
   - 해결: `TrackingState`에 `savedRoute`와 `viewedSession`을 신설하여 실시간 추적선(`_liveRouteLine`, emerald)과 저장 경로선(`_savedRouteLine`, teal)을 물리적·상태적으로 완전 분리. 조회 종료 시 `_savedRouteLine`과 출발/도착 핀만 제거함.

4. **설정 화면 가독성 및 아코디언 도입 (Settings Readability)**
   - 문제: 백그라운드 위치 추적 안내문이 길어 한눈에 들어오지 않던 문제.
   - 해결: 핵심 요약 카드를 상단에 배치하고, 제조사별 상세 설정(기본 Android, Samsung, Xiaomi, 자동 복구 안내)을 `ExpansionTile` 아코디언으로 구성하여 깔끔하게 정리.

5. **지도 심볼 명확성 및 범례 오버레이 (Map Legend Chip)**
   - 문제: 실시간 추적선, 저장 경로선, 현재 위치 핀, 일반/사진 마커의 구분이 직관적이지 않던 문제.
   - 해결: 좌측 하단에 미니멀한 플로팅 칩 `MapLegendChip`을 추가하여 탭 한 번으로 언제든지 심볼 범례를 확인하고 접을 수 있도록 구현.

---

## 2. 변경된 파일 목록

- [lib/tracking/domain/tracking_state.dart](../lib/tracking/domain/tracking_state.dart): `savedRoute`, `viewedSession`, `clearSavedRoute`, `clearViewedSession` 추가
- [lib/tracking/presentation/tracking_controller.dart](../lib/tracking/presentation/tracking_controller.dart): `sessionsListProvider`, `markersListProvider` 추가 및 경로 분리
- [lib/tracking/presentation/track_map_screen.dart](../lib/tracking/presentation/track_map_screen.dart): `_syncMapMarkers()`, `_liveRouteLine`/`_savedRouteLine` 분리, `markersListProvider` 연동, `MapLegendChip` 배치
- [lib/tracking/presentation/widgets/map_legend_chip.dart](../lib/tracking/presentation/widgets/map_legend_chip.dart): 확장형 범례 칩 신규 생성
- [lib/tracking/presentation/main_navigation_page.dart](../lib/tracking/presentation/main_navigation_page.dart): `ConsumerStatefulWidget` 변환 및 탭 전환 시 캐시 무효화
- [lib/history/presentation/history_screen.dart](../lib/history/presentation/history_screen.dart): `sessionsListProvider` 리액티브 연동
- [lib/map/presentation/markers_screen.dart](../lib/map/presentation/markers_screen.dart): `markersListProvider` 리액티브 연동
- [lib/settings/presentation/settings_screen.dart](../lib/settings/presentation/settings_screen.dart): 제조사별 `ExpansionTile` 아코디언 적용
- [test/saved_route_isolation_test.dart](../test/saved_route_isolation_test.dart): 실시간 추적 및 저장 경로 상태 격리 회귀 테스트
- [test/marker_sync_deletion_test.dart](../test/marker_sync_deletion_test.dart): 마커 삭제 동기화 및 빈 상태 전환 테스트
- [test/map_legend_chip_test.dart](../test/map_legend_chip_test.dart): 지도 범례 칩 토글 테스트
- [test/settings_accordion_test.dart](../test/settings_accordion_test.dart): 설정 화면 아코디언 테스트

---

## 3. 검증 결과

1. **정적 분석 (Static Analysis)**
   - `flutter analyze` 실행 결과: **0 issues** (경고 및 오류 없음).

2. **단위 및 위젯 테스트 (Unit & Widget Tests)**
   - `flutter test` 실행 결과: 총 **29개 테스트 전체 통과** (0 failures).
   - 기기 설치 방침: 사용자 요청에 따라 기기 설치(`adb install`)는 실행하지 않음.
