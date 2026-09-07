# SANC Tracker UI/UX 전면 개편 및 모듈화 계획 (2026-09-07)

## 1. 개요 및 목표

SANC Tracker의 기본 기능(GPS 백그라운드 수집, 복구, 사진/동영상 마커, 세션 관리)이 정상 동작함에 따라, 프로토타입 형태의 단일 스크롤뷰 UI를 전문 아웃도어/GPS 트래킹 앱(Strava, AllTrails 등) 수준의 **모던하고 직관적인 풀캔버스(Full-Canvas) 지도 기반 UI**로 전면 개편합니다.

1,700라인에 달하는 거대 위젯([`TrackingPage`](../lib/tracking/presentation/tracking_page.dart))을 컴포넌트 단위(지도 뷰, 실시간 HUD 대시보드, 기록 보관함, 장소 마커, 설정)로 분리하여 유지보수성을 극대화합니다.

---

## 2. 주요 UI/UX 개선 방향

### 2.1 주요 변경 사항 비교

1. **지도 화면 (Map Canvas)**
   - **기존**: 280px 고정 박스 형태로 ListView 내부에 있어 스크롤 제스처 간섭 발생.
   - **개편**: 화면 전체를 채우는 **풀스크린 인터랙티브 지도 (Full Canvas)**.
2. **실시간 트래킹 HUD 대시보드 (Live HUD)**
   - **기존**: 화면 하단 스크롤 후 단순 텍스트(`수집된 위치: N개`)와 작은 버튼 표시.
   - **개편**: 하단 플로팅 글래스모피즘 HUD 카드. 큰 폰트의 **경과 시간(Stopwatch)**, **이동 거리(km)**, **현재 속도(km/h)** 실시간 표시 및 직관적인 대형 시작/중지 버튼.
3. **내비게이션 구조 (Navigation Architecture)**
   - **기존**: 모든 기능(추적, 설정, 세션 목록, 마커 목록)이 단일 세로 스크롤에 배치.
   - **개편**: 하단 내비게이션 바(BottomNavigationBar) 기반 **4개 전용 탭**:
     - 🗺️ **추적 (Track)**: 풀스크린 지도 + 실시간 HUD
     - 📂 **기록 (History)**: 저장된 세션 카드 목록, 상세 통계, 다중 선택 삭제
     - 📍 **마커 (Places)**: 저장된 마커 목록, 카테고리 필터, 미디어 미리보기
     - ⚙️ **설정 (Settings)**: 배터리 절약 모드, Android 수집 주기, 권한 관리
4. **마커 상세 바텀 시트 (Marker Sheet)**
   - **기존**: `showModalBottomSheet` 내에서 `AlertDialog`가 중첩 호출되는 어색한 UI.
   - **개편**: 미디어 사진 캐러셀, 카테고리 칩, 메모, 빠른 액션 버튼(이동, 추가, 수정, 삭제)을 갖춘 전용 모던 바텀 시트.

---

## 3. 계층별 모듈화 및 신규 파일 구조

```text
lib/
  ├─ core/
  │   └─ theme/
  │       ├─ app_colors.dart            // 트레킹 고시인성 컬러 팔레트
  │       └─ app_theme.dart             // Material 3 폰트, 카드, 버튼 테마
  ├─ tracking/
  │   ├─ domain/
  │   │   └─ tracking_state.dart        // duration, distance, speed 필드 추가
  │   ├─ presentation/
  │   │   ├─ main_navigation_page.dart  // 4개 탭 하단 내비게이션 진입점
  │   │   ├─ track_map_screen.dart       // 풀스크린 지도 + 플로팅 HUD
  │   │   ├─ tracking_controller.dart    // 실시간 타이머 및 거리 계산
  │   │   └─ widgets/
  │   │       ├─ tracking_hud_card.dart  // 실시간 통계 및 시작/중지 카드
  │   │       ├─ tracking_stat_cell.dart // 수치 셀 (숫자 + 단위 + 라벨)
  │   │       ├─ map_floating_actions.dart // 내위치, 사진촬영, 마커추가 FAB
  │   │       └─ gps_status_badge.dart   // 상단 GPS 신호/정확도 배지
  ├─ history/
  │   ├─ presentation/
  │   │   ├─ history_screen.dart         // 저장된 세션 목록 화면
  │   │   └─ widgets/
  │   │       └─ session_card.dart       // 세션 요약 카드 위젯
  ├─ map/
  │   ├─ presentation/
  │   │   ├─ markers_screen.dart         // 저장된 마커 탭 화면
  │   │   └─ widgets/
  │   │       ├─ marker_detail_sheet.dart // 모던 마커 상세 바텀 시트
  │   │       └─ marker_edit_dialog.dart // 마커 생성/수정 다이얼로그
  └─ settings/
      └─ presentation/
          └─ settings_screen.dart        // 백그라운드 추적 및 권한 설정 화면
```

---

## 4. 단계별 실행 계획

1. **1단계: 디자인 시스템 및 실시간 통계 상태 추가**
   - `app_colors.dart`, `app_theme.dart` 정의
   - `TrackingState` 및 `TrackingController`에 실시간 경과 시간(초), 이동 거리(km), 현재 속도(km/h) 반영
2. **2단계: 풀스크린 지도 및 플로팅 HUD 대시보드 구현**
   - `track_map_screen.dart` 및 HUD 위젯 구현
   - 지도 위젯 분리 및 스크롤 간섭 제거
3. **3단계: 4개 탭 내비게이션 분리 (`main_navigation_page.dart`)**
   - `HistoryScreen`: 저장 세션 카드 뷰 및 다중 선택 삭제 이동
   - `MarkersScreen`: 마커 목록 및 카테고리 필터링
   - `SettingsScreen`: 배터리 절약 모드 및 수집 간격 설정 이동
4. **4단계: 마커 상세 바텀 시트 폴리싱 및 다이얼로그 개선**
   - `marker_detail_sheet.dart`: 사진 캐러셀 및 모던 바텀 시트 완성
5. **5단계: 회귀 테스트 및 검증**
   - `flutter analyze` 0 경고 유지 및 `flutter test` 전체 테스트 통과
