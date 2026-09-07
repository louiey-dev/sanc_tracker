# Phase 2 UI 및 상태 동기화 아키텍처 구현 계획서

- 작성 일시: 2026-09-07 15:36
- 대상 파일:
  - [lib/tracking/domain/tracking_state.dart](../../lib/tracking/domain/tracking_state.dart)
  - [lib/tracking/presentation/tracking_controller.dart](../../lib/tracking/presentation/tracking_controller.dart)
  - [lib/tracking/presentation/track_map_screen.dart](../../lib/tracking/presentation/track_map_screen.dart)
  - [lib/tracking/presentation/main_navigation_page.dart](../../lib/tracking/presentation/main_navigation_page.dart)
  - [lib/history/presentation/history_screen.dart](../../lib/history/presentation/history_screen.dart)
  - [lib/map/presentation/markers_screen.dart](../../lib/map/presentation/markers_screen.dart)
  - [lib/settings/presentation/settings_screen.dart](../../lib/settings/presentation/settings_screen.dart)

---

## 1. 개요 및 피드백 검토 의견

전달해주신 5가지 피드백은 **앱의 데이터 무결성과 사용성을 획기적으로 끌어올리는 대단히 핵심적이고 날카로운 지적**입니다:

1. **데이터 갱신 (Data Refresh)**:
   `IndexedStack` 특성상 탭 간 이동 시 기존 화면 상태가 유지되므로, 마커나 세션을 추가/삭제한 후 다른 탭으로 이동했을 때 최신 데이터가 반영되지 않는 현상이 발생합니다.
2. **마커 삭제 동기화 (Marker Deletion Sync)**:
   현재 `_loadSavedMarkers()`가 `saved.isEmpty`일 때 조기 리턴되어, 마커를 전체 삭제하거나 일부 삭제했을 때 카카오맵 상의 POI가 제거되지 않고 잔존(Ghost Marker)하는 심각한 동기화 누락이 있습니다.
3. **저장 경로 상태 격리 (Saved Route State Isolation)**:
   현재 `viewSessionRoute()`가 기존 컨트롤러의 `state.route`를 덮어쓰고, 종료 시 빈 리스트(`[]`)로 초기화하여 **실시간 추적 중이던 위치 데이터가 영구 유실되는 치명적 버그**가 존재합니다.
4. **설정 화면 가독성 (Settings Readability)**:
   장문의 텍스트가 나열되어 있는 백그라운드 안내를 제조사별 접이식 아코디언(`ExpansionTile`)으로 정리하여 가독성을 높여야 합니다.
5. **지도 상호작용 명확성 (Map Legend)**:
   현재 위치, 실시간 추적선, 저장 경로선, 일반 마커, 사진 마커가 지도 위에 복합적으로 표시되므로 컴팩트한 범례(Legend) 칩/툴팁이 필요합니다.

> [!NOTE]
> **권고 수용**:
> 제안해주신 대로 시각적 장식(Polish)에 앞서 **1~3번 데이터 갱신 및 상태 무결성 문제(Data Refresh & State Sync)**를 최우선으로 해결한 뒤, 4~5번 UI 개선을 진행하는 것이 완벽한 접근 순서입니다.

---

## 2. 세부 구현 계획

### 2.1 [최우선] 실시간 추적 경로와 저장 경로 상태 완벽 분리

- **`TrackingState` 확장**:
  - `route` (`List<Position>`): **오직 실시간 GPS 추적 기록 데이터만 유지**
  - `savedRoute` (`List<Position>?`): 과거 저장 세션 조회 시 로드되는 별도 경로 데이터
  - `viewedSession` (`TrackingSession?`): 조회 중인 과거 세션 메타데이터
- **`TrackingControllerNotifier` 로직 개편**:
  - `loadSessionRoute(session)`: `savedRoute`와 `viewedSession`에만 데이터를 할당하고, 실시간 `route` 및 추적 타이머/통계는 일절 건드리지 않음.
  - `clearLoadedSessionRoute()`: `savedRoute`만 `null`로 초기화하고 실시간 `route`는 온전히 보존.
- **`TrackMapScreen` 지도 폴리라인 분리**:
  - 실시간 추적 폴리라인(`_trackingRouteLine`): 에메랄드 색상(`AppColors.trackingLive`)으로 실시간 갱신.
  - 과거 저장 경로 폴리라인(`_savedRouteLine`): 인디고/틸 색상(`AppColors.primary`)과 시작/종료 깃발 핀으로 렌더링.
  - 저장 경로 보기 종료 시 `_savedRouteLine`만 삭제되며, 백그라운드 실시간 추적선은 그대로 지도에 유지됨.

### 2.2 [최우선] 마커 동기화 및 잔존 POI 제거 로직 구현

- **양방향 동기화 알고리즘 (`_syncMapMarkers`)**:
  1. 현재 지도에 표시 중인 `_markerPois.keys`와 새로 전달받은 마커 목록 `newMarkers.map((m) => m.id)` 비교.
  2. `newMarkers`에 없는 기존 ID는 카카오맵 라벨 레이어에서 `removePoi` 실행 및 `_markerPois`에서 제거 (마커 전체 삭제 시 모든 POI 완벽 제거).
  3. `newMarkers` 중 아직 지도에 없는 신규 마커만 `addPoi`로 추가.

### 2.3 [최우선] 반응형 Riverpod Provider 도입으로 탭 간 자동 갱신

- `sessionsListProvider` 및 `markersListProvider` 도입.
- 마커 또는 세션 추가/삭제 시 Provider를 무효화(`ref.invalidate`)하여, `IndexedStack`으로 살아있는 `TrackMapScreen`, `HistoryScreen`, `MarkersScreen`이 수동 새로고침 없이 즉각 최신 상태를 렌더링하도록 전환.

### 2.4 설정 화면 가독성 개선 (접이식 안내)

- `SettingsScreen`의 장문 안내 텍스트를 제조사별 4단 접이식 `ExpansionTile`로 재구성:
  - 📱 **삼성 Galaxy (One UI)**: 절전 예외 앱 등록 및 배터리 무제한 설정
  - ⚡ **샤오미 / 기타 제조사**: 자동 시작 허용 및 백그라운드 제한 해제
  - 🌐 **공통 Android 설정**: 위치 권한 '항상 허용' 및 알림 권한 가이드
  - 🔄 **세션 자동 복구**: 비정상 종료 시 재실행 복구 정책 설명

### 2.5 지도 범례(Legend) 칩 추가

- `TrackMapScreen` 좌측 상단 또는 하단에 작고 세련된 `범례` 칩 배치.
- 탭 시 팝오버/모달로 5가지 심볼의 명확한 설명 제공:
  - 🔵 현재 위치 (Current GPS Position)
  - 🟢 실시간 이동 경로 (Active Tracking Line)
  - 🔷 불러온 저장 경로 (Saved Route Line)
  - 📍 장소 마커 (Place Marker)
  - 📷 사진 마커 (Photo Marker)

---

## 3. 검증 전략

1. **자동화 테스트 (`flutter test`)**:
   - `test/saved_route_isolation_test.dart`: 추적 중 과거 세션 조회 및 종료 시 실시간 추적 좌표 유실 없음 검증.
   - `test/marker_sync_deletion_test.dart`: 마커 전체/일부 삭제 시 지도 POI 잔존 방지 검증.
   - `test/tab_data_refresh_test.dart`: 탭 전환 시 데이터 자동 갱신 검증.
2. **정적 분석 (`flutter analyze`)**: 0 issues 유지.
3. **규칙 준수**: 지시하신 대로 기기 자동 설치(`adb install`)는 실행하지 않음.
