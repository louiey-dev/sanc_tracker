# UI/UX 전면 개편 및 모듈화 완료 보고서

## 1. 개요

단일 1,750줄의 모놀리식 구조(`TrackingPage`)로 관리되던 지도 화면, 설정, 기록 목록, 마커 관리, 미디어 뷰어를 야외 활동 및 등산·트레킹에 최적화된 모듈형 아키텍처와 아웃도어 전용 Material 3 디자인 시스템으로 전면 개편하였습니다.

- 작업 브랜치: `phase2`
- 변경 대상: UI/UX 레이아웃, 내비게이션, 테마 시스템, 도메인 상태 확장
- 분석 및 테스트 결과: `flutter analyze` 0 경고/오류, 전체 자동 테스트 18개(100%) 통과

---

## 2. 주요 개선 사항

### 2.1 아웃도어 특화 디자인 시스템 구축

- **색상 팔레트 ([app_colors.dart](../../lib/core/theme/app_colors.dart))**:
  - Forest Teal (`#0F766E`): 신뢰성과 자연환경에 어우러지는 브랜드 메인 컬러
  - Safety Amber (`#F59E0B`): 직사광선 야외 환경에서도 시인성이 높은 보조 강조 컬러
  - Live Emerald (`#10B981`): 활성 GPS 추적 및 기록 진행 상태 표시
  - High-contrast Neutral (`#0F172A`, `#64748B`, `#F8FAFC`): 직관적인 카드 및 텍스트 대비 확보
- **Material 3 테마 ([app_theme.dart](../../lib/core/theme/app_theme.dart))**:
  - `NavigationBar`, `Card`, `FilledButton`, `AppBar` 테마 일괄 정립

### 2.2 하단 4탭 내비게이션 및 네이티브 지도 뷰 보존

- **[MainNavigationPage](../../lib/tracking/presentation/main_navigation_page.dart)**:
  - 4개 주요 기능 탭 분리: `추적`, `기록`, `마커`, `설정`
  - **`IndexedStack` 채택**: 탭 전환 시 카카오맵(KakaoMap) 네이티브 플랫폼 뷰와 OpenGL/EGL 컨텍스트가 파괴되거나 재생성되지 않고 백그라운드 메모리에 안전하게 유지됩니다.

### 2.3 풀 캔버스 지도 및 실시간 플로팅 HUD

- **[TrackMapScreen](../../lib/tracking/presentation/track_map_screen.dart)**:
  - 화면 전체를 인터랙티브 카카오맵 캔버스로 활용
  - 상단 플로팅 HUD 카드([`TrackingHudCard`](../../lib/tracking/presentation/widgets/tracking_hud_card.dart)):
    - 실시간 타이머(`00:00:00`), 이동 거리(km), 현재 속도(km/h, 실시간 GPS 센서 기반 계산)
    - 원터치 추적 시작/중지 토글 버튼
  - 우측 하단 플로팅 액션([`MapFloatingActions`](../../lib/tracking/presentation/widgets/map_floating_actions.dart)):
    - 현재 위치 복귀, 원터치 사진 마커 촬영, 저장 경로 닫기 버튼
  - 마커 상세 바텀 시트([`MarkerDetailSheet`](../../lib/map/presentation/widgets/marker_detail_sheet.dart)):
    - 기존의 팝업형 `AlertDialog`를 현대적인 모달 바텀 시트로 교체하고 사진/동영상 뷰어 및 촬영 연동

### 2.4 독립된 기록, 마커, 설정 화면

- **[HistoryScreen](../../lib/history/presentation/history_screen.dart)**:
  - 과거 추적 세션 카드화([`SessionCard`](../../lib/history/presentation/widgets/session_card.dart))
  - 시작/종료 시각, 소요 시간, 이동 거리 실시간 계산
  - 세션 다중 선택 모드 및 일괄 삭제 기능
  - 세션 터치 시 지도 탭으로 자동 전환하여 이동 경로 표시
- **[MarkersScreen](../../lib/map/presentation/markers_screen.dart)**:
  - 카테고리 필터 칩(`전체`, `사진`, `동영상`, 사용자 정의)
  - 마커 터치 시 지도 탭으로 전환 후 해당 좌표로 카메라 포커스 이동
  - 마커 개별 삭제 및 메모 미리보기
- **[SettingsScreen](../../lib/settings/presentation/settings_screen.dart)**:
  - 배터리 절약 모드 스위치
  - Android GPS 요청 주기(10초 / 30초 / 60초) 선택
  - 시스템 앱 권한 설정 바로가기
  - OS별(Android/Samsung/Xiaomi/iOS) 백그라운드 최적화 가이드 제공

---

## 3. 구조 변경 요약

```text
lib/
├── core/
│   └── theme/
│       ├── app_colors.dart          # 신규 아웃도어 컬러 정의
│       └── app_theme.dart           # Material 3 테마 정의
├── history/
│   └── presentation/
│       ├── history_screen.dart      # 기록 탭 전용 화면
│       └── widgets/
│           └── session_card.dart    # 세션 카드 컴포넌트
├── map/
│   └── presentation/
│       ├── markers_screen.dart      # 마커 탭 전용 화면
│       └── widgets/
│           └── marker_detail_sheet.dart # 마커 상세 모달 시트
├── settings/
│   └── presentation/
│       └── settings_screen.dart     # 설정 탭 전용 화면
└── tracking/
    ├── domain/
    │   └── tracking_state.dart      # duration, distance, speed 필드 추가
    └── presentation/
        ├── main_navigation_page.dart# 4탭 루트 페이지 (IndexedStack)
        ├── track_map_screen.dart    # 풀 캔버스 지도 화면
        ├── tracking_controller.dart # 실시간 속도/거리/타이머 계산 로직
        └── widgets/
            ├── map_floating_actions.dart
            ├── tracking_hud_card.dart
            └── tracking_stat_cell.dart
```

---

## 4. 검증 결과

1. **정적 분석 (`flutter analyze`)**:
   - 경고 및 에러 0건 (`No issues found!`)
2. **테스트 스위트 (`flutter test`)**:
   - `location_settings_test.dart`: 3 passed
   - `map_marker_test.dart`: 2 passed
   - `media_item_test.dart`: 2 passed
   - `photo_capture_service_test.dart`: 4 passed
   - `tracking_model_test.dart`: 3 passed
   - `tracking_recovery_test.dart`: 3 passed
   - `widget_test.dart`: 1 passed (네비게이션 탭 전환 및 4개 화면 렌더링 검증)
   - **총 18개 테스트 전체 통과 (0 failed)**
