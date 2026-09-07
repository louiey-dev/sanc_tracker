# SANC Tracker 실행 TODO

전체 방향은 [로드맵](./doc/roadmap.md) (`.agents/doc/roadmap.md`), 현재 백업 구현은
[프로젝트 구조와 백업 계약](./doc/project-structure.md)
(`.agents/doc/project-structure.md`)을 따른다.
이 파일을 실행 순서의 기준으로 삼는다. 향후 서버 API 계약은 현재 구현 대상이 아니다.
각 항목은 구현과 해당 검증을 마친 뒤에만 `[x]`로 표시한다.

현재 위젯 테스트는 추적 화면의 초기 상태를 검증한다. 향후 기능을 추가할 때에도
화면 동작과 권한·오류 상태에 대한 테스트를 함께 갱신한다.

## Phase 0 — 프로젝트 기반

- [x] Flutter 프로젝트와 Android/iOS/Web/Windows 타깃 생성
- [x] 기존 카운터 테스트를 현재 추적 화면 테스트로 교체하고 테스트 통과
- [x] GPS 위치 스트림 의존성 및 Android/iOS 권한 선언
- [x] 프로젝트 문서·소스 계층 설계 작성
- [x] 상태 관리 방식 결정·적용: Riverpod `Notifier`를 기본 상태 관리로 사용
- [x] 라우팅·로깅·개발/운영 환경 설정 결정
- [x] 실제 코드를 도메인·데이터·화면 계층으로 분리
- [x] 로컬 DB·파일 저장·Export 패키지 선택 결과 기록
- [x] 카카오맵 개발자 앱과 Android 플랫폼 키 등록
- [ ] 카카오맵 iOS/Web 플랫폼 키 등록
- [x] 카카오맵 쿼터·비용·약관 검토 결과 기록
- [x] `MapProvider` 계약과 카카오맵 어댑터 경계 정의
- [x] 지도 키를 빌드 설정으로 분리하고 소스 노출 여부 확인
- [x] 개인정보·로컬 삭제·Drive 백업 보관 기간 정책 확정
- [x] 로컬 DB/미디어 암호화와 Export 암호 설정 여부 확정
- [x] 백업 암호화 결정 기록: 검증된 라이브러리, 키 파생·인증 암호화 방식/매개변수,
  암호 정책, 형식 버전, 키 교체·이전 백업 복원 정책 확정

## MVP 1 — GPS 기록

### 위치 모델·로컬 저장

- [x] `LocationPoint`·`TrackingSession` 모델 작성
- [x] 좌표·시각·정확도·고도·속도·방향·배터리 필드 정의
- [x] 로컬 고유 ID와 `updatedAt` 정의 및 Import/복원 시 ID 유지
- [x] 로컬 삭제·이전 백업의 기록 잔존·명시적 백업 삭제 규칙 정의
- [x] 로컬 저장소 인터페이스와 영속 구현
- [x] 위치 기록을 로컬 저장소에 기록
- [x] 추적 세션 시작·종료·복구
- [x] 위치 모델·거리/시간 필터 단위 테스트

### 지도·추적 화면

- [x] 추적 시작·중지 UI
- [x] 현재 좌표·정확도 표시
- [x] 화면의 GPS 플러그인 직접 호출을 위치 서비스 인터페이스로 이동
- [x] 카카오맵 지도 및 현재 위치 표시
- [x] 임시 20m 거리 필터를 50m 또는 최대 30초의 도메인 수집 정책으로 교체
- [x] 정지 상태 수집 주기 완화 및 드리프트 억제
- [x] 저정확도·권한 거부·위치 서비스 중지 처리
- [x] 위치 기록을 로컬 저장소에 기록
- [x] 날짜별 세션 목록과 이동 경로 표시
- [x] 이동 경로 상세 정보 표시(시작 시각·종료 시각·총 소요 시간·이동 거리)
- [x] 이동 경로 선택 지점의 시각·좌표 상세 표시
- [x] 현재 위치로 이동하는 지도 버튼
- [x] 지도 전체화면 확대 및 원복 버튼

### MVP 1 검증

- [x] Android 실기기 권한·GPS 수집 확인
- [ ] iOS 실기기 권한·GPS 수집 확인
- [ ] 앱 재실행 후 로컬 기록 복구 확인
- [ ] 네트워크 단절 중 로컬 데이터 유실 없음 확인

## MVP 2 — 장소 기록

### 사용자 마커

- [x] `MapMarker` 모델 작성
- [x] 지도 롱프레스 마커 추가
- [x] 제목·메모·분류 저장
- [x] 바다 등 주소 없는 좌표 마커 저장
- [x] 마커 이동·수정·목록 연동
- [x] 저장된 마커 삭제
- [x] 저장 세션 목록 중복 제거 및 저장 마커 목록 표시
- [x] 저장된 세션 롱프레스 다중 선택·선택 취소·일괄 삭제 및 위치 데이터 함께 삭제 구현
- [x] 저장된 세션 다중 선택·일괄 삭제 실기기 검증
- [x] 마커 선택 후 지도 터치로 위치 이동 및 이름·좌표 표시
- [x] 마커 단위·위젯 테스트

### 사진·동영상

- [x] `MediaItem` 모델 작성
- [x] 사진·동영상 촬영 및 갤러리 가져오기
- [x] 촬영 위치·시각·정확도와 `exact/last_known/unknown` 저장
- [x] 미디어 파일·메타데이터·썸네일 저장 경로 분리
- [x] `marker_media` 연결 관계 구현
- [x] 사진 마커 상세 미리보기 및 전체화면 확대
- [x] GPS 확보 실패·저장공간 부족 처리
- [x] 미디어 위치 연결 테스트
- [x] 사진·동영상 마커 팝업 미리보기 및 직접 열기·재생 검증
- [x] Android 종료 기록에서 백그라운드 LOW_MEMORY 종료 확인
- [x] 사진 촬영 전 마커 정보 저장 및 앱 재실행 시 중단된 사진 저장 복구
- [x] 신규 사진 마커 이름·메모 입력을 촬영 전으로 이동하여 복구 정보에 포함
- [x] 사진 저장 재시도 중복 방지 및 지도 준비 여부와 독립적인 저장
- [x] 사진 처리 오류 안내 및 저장 실패 시 원본·복구 정보 보존
- [x] 실제 512px 사진 썸네일 생성 및 미리보기 디코딩 크기 제한
- [x] 사진 복구·저장 실패 재시도·중복 방지·썸네일 크기 회귀 테스트
- [x] iOS 카메라·마이크·사진 보관함 권한 설명 추가 및 plist 키/값 검증
- [x] 사진 복구 수정 포함 Android debug APK 빌드
- [x] Release native crash 원인 확인: Kakao Vector Map reflection class 제거
- [x] Release R8 keep rule for Kakao Vector Map 추가
- [ ] 수정 APK 실기기 설치 및 사진 마커 촬영·취소·저장 확인
- [ ] 실기기 카메라 촬영 중 프로세스 종료 후 사진·마커 복구 검증
- [ ] 실기기 연속 촬영·미리보기 메모리 사용 및 추적 병행 검증
- [ ] iOS 실기기 카메라·사진 보관함 권한 및 촬영 검증

## Phase 2 — 백그라운드 안정화

구현 및 검증 범위는 [Phase 2 기록](./doc/background_tracking_20260907_1200.md)을 참조한다.
구현·자동 검증과 실기기 검증을 분리한다. 사진 복구 테스트를 포함한 전체 자동 테스트 18개 통과 및
Android debug APK 빌드 성공을 확인했다. 정적 분석의 기존 경고·스타일 안내는 남아 있다.
개발 편의를 위해 debug 빌드에서는 화면 켜짐을 유지한다.
release 빌드에서는 화면 자동 꺼짐을 허용하며 추적 중 백그라운드 수집 설정을 유지한다.
저메모리 프로세스 종료 자체의 방지 및 종료 중 위치 수집을 보장하지 않는다.

### 구현 및 자동 검증

- [x] Android foreground location service·권한·CPU wake lock 설정 및 병합 manifest 확인
- [x] iOS background location 설정·권한 설명·AppleSettings 구성 및 plist 키/값 검증
- [x] 앱 재실행 시 기존 세션 복원·GPS 재구독 구현 및 회귀 테스트
- [x] 권한 거부·저장 실패 시 추적 상태 및 저장된 위치 반영 회귀 테스트
- [x] 위치 스트림 종료 시 추적 중 표시 해제 처리
- [x] debug 빌드 화면 켜짐 유지·release 빌드 자동 꺼짐 허용 및 백그라운드 지도 카메라 갱신 생략
- [x] 제조사별 배터리 최적화 안내
- [x] 배터리 절약 모드·Android 수집 요청 주기 설정 및 로컬 저장 구현
- [x] Android/iOS 위치 설정·사진 복구 포함 전체 자동 테스트 18개 통과
- [x] Android debug APK 빌드 검증
- [x] 스토어 위치 권한·개인정보 설명 초안 작성

### 남은 구현 및 실기기 검증

- [ ] 재부팅 직후 앱을 열지 않아도 추적하는 native/headless 기록기 설계·구현
- [ ] 재부팅 후 앱 재실행 시 동일 세션으로 기록 재개 실기기 검증
- [ ] Android 잠금·백그라운드 전환 중 foreground service 및 권한 동작 검증
- [ ] iOS 빌드 및 실기기 백그라운드 위치 권한·수집 검증
- [ ] 화면 잠금·백그라운드·네트워크 단절 중 위치 유실 검증
- [ ] 일반·절약 모드별 Android/iOS 30분 이상 안정성·배터리 변화 측정
- [ ] 설정 저장 후 앱 재실행 시 유지 실기기 검증
- [ ] 스토어 제출용 개인정보처리방침 URL·운영자 정보·SDK 데이터 수집 감사 확정
- [ ] Google Play 데이터 보안·Apple 개인정보 라벨 및 권한 시연 자료 준비

## MVP 3 — Google Drive 백업·복원

### Import/Export

- [ ] `formatVersion`·`schemaVersion` 포함 앱 전용 기록 JSON 정의
- [ ] 기록 백업과 미디어 포함 전체 백업의 필수 항목·누락 표시 구현
- [ ] GeoJSON·GPX의 경로/좌표 마커 전용 범위 정의
- [ ] JSON·GeoJSON·GPX Export
- [ ] Import 파일 선택·미리보기·유효성 검증
- [ ] 기존 데이터 보존형 Import
- [ ] `clientEventId`·콘텐츠 해시 기반 중복 탐지
- [ ] 미디어 원본·썸네일 포함 여부 선택
- [ ] 미디어 ID·상대 경로 기반 패키지 생성과 복원 경로 재생성
- [ ] 지원하지 않는/악성 파일 차단
- [ ] Import/Export 테스트

### Google Drive 백업·복원

- [ ] Google OAuth 클라이언트와 `drive.appdata` 최소 권한 설정
- [ ] Google 계정 연결·해제 및 토큰 안전 저장
- [ ] 계정 전환 시 백업 분리와 자동 병합 방지
- [ ] 앱 전용 Drive 백업 매니페스트와 `formatVersion` 구현
- [ ] 추적 중 일관된 읽기 시점에서 기록·미디어 목록 스냅샷 생성
- [ ] 고유 백업 ID의 독립 스냅샷 업로드
- [ ] 선택형 미디어 원본 백업 및 네트워크·저장공간 제한 처리
- [ ] 백업 암호 설정·키 파생·인증 암호화 및 안전한 기기 내 키 보관
- [ ] 암호 분실·변경 시 이전 백업의 복원 조건 안내
- [ ] 파일 검증 후 완료 표식 등록·불완전 백업 제외
- [ ] 업로드 중단·재시도 시 중복 방지와 이전 정상 백업 유지
- [ ] 백업 목록에 종류·완료 시각·기록/미디어 수·크기·암호화·정상/부분/실패 상태 표시
- [ ] 백업 목록·복원 미리보기·복원 실행
- [ ] 임시 저장소에서 버전·해시·관계 검증 후 복원 적용 및 실패 시 롤백
- [ ] 기존 데이터 교체 복원과 추가 Import를 구분하고 충돌 확인
- [ ] 자동 백업 주기·Wi-Fi 전용·수동 실행 설정
- [ ] Google 계정 연결 해제와 원격 백업 삭제
- [ ] 기존 기기 없이 새 휴대폰에서 Google 계정·백업 암호로 복원 검증
- [ ] 복원 전후 기록 수·관계·미디어 원본 해시 비교
- [ ] 잘못된 암호·손상·부분 업로드·저장공간 부족 시 기존 데이터 보존 검증
- [ ] 로컬 삭제 후 새 백업·이전 백업 복원·원격 백업 삭제 검증

## Phase 4 — 주변 정보와 분석

- [ ] 좌표→주소 변환과 호출 빈도 제한·캐시
- [ ] 주변 장소 검색과 결과 캐시
- [ ] 체류 장소·체류 시간·이동 거리·속도 통계
- [ ] 사진·동영상과 경로 타임라인
- [ ] CSV/GPX Export·보관 기간·미디어 Export 옵션

## 후속 단계 — Windows/Linux PC 조회

모바일 MVP 완료 조건과 분리한다. 아래 항목은 해당 단계에 착수할 때 검증한다.

- [ ] 웹·데스크톱 제공 방식과 지도·OAuth 지원 검증
- [ ] Google 계정 연결·Drive 또는 로컬 Export 백업 선택
- [ ] 백업 암호 입력·복호화·기록과 미디어 복원
- [ ] 날짜/기간 필터·경로·위치 상세 정보·마커·미디어 조회
- [ ] Import/Export 화면
- [ ] Windows·Linux에서 각각 실행 또는 지원 브라우저 검증

## 공통 품질·보안 점검

- [ ] API 키·HTTPS·인증 토큰 보안 점검
- [ ] 위치·미디어·마커의 개별/전체 삭제 검증
- [ ] EXIF 위치와 앱 수집 위치 우선순위 확정
- [ ] 대용량 동영상·저장공간 부족·재개 업로드 테스트
- [ ] 시간 변경·중복 업로드·앱 강제 종료 테스트
- [ ] 단위·위젯·통합 테스트 통과
- [ ] 모바일 배포 전 Android/iOS 빌드 검증
- [ ] PC 제공 방식 확정 후 해당 Web/데스크톱 빌드·Windows/Linux 동작 검증

### Map/GPS release verification (2026-09-07)

- [x] Do not block map creation on a cold GPS fix; acquire fresh GPS in the background.
- [x] Use the last-known position before falling back to the default map center.
- [x] Use hybrid composition for the Kakao native map inside the scrollable tracking page.
- [ ] Verify GPS outdoors with Location Services enabled; the test phone reports NO_SATELLITE/usedSv=0 indoors.

### UI/UX 전면 개편 및 모듈화 구조 (2026-09-07)

- [x] 산림 테마(Forest Teal `#0F766E`, Safety Amber `#F59E0B`, Live Tracking Emerald `#10B981`) 및 Material 3 테마 시스템 구현
- [x] 단일 1,750줄 `TrackingPage` 해체 및 4탭 하단 네비게이션(`추적`, `기록`, `마커`, `설정`) 모듈 분리
- [x] `IndexedStack` 적용을 통한 탭 전환 시 카카오맵 OpenGL/EGL 플랫폼 뷰 컨텍스트 영구 보존
- [x] 풀 캔버스 인터랙티브 지도 및 실시간 상태 플로팅 HUD 카드(시간/거리/속도/수집 개수/토글 버튼) 구현
- [x] 마커 상세 모달 바텀 시트(`MarkerDetailSheet`: 사진/동영상 뷰어 및 촬영·수정·이동·삭제) 분리
- [x] 세션 목록 화면(`HistoryScreen`) 및 다중 선택 일괄 삭제 구현
- [x] 마커 목록 화면(`MarkersScreen`) 및 카테고리 필터 칩 구현
- [x] 설정 화면(`SettingsScreen`) 및 배터리 절약 모드·GPS 주기 설정 분리
- [x] 전체 자동 테스트 18개 및 위젯 네비게이션 테스트 통과, flutter analyze 0건 유지
- [x] 마커 추가/수정/사진 메모 다이얼로그의 컨트롤러 조기 해제로 인한 팝 애니메이션 중 크래시(빨간 화면) 수정 (`MarkerInputDialog`, `PhotoMemoDialog`, `VideoPlayerDialog` 분리 및 생명주기 관리)
- [x] 신규 마커/사진 다이얼로그 회귀 방지 테스트 작성 및 전체 22개 테스트 통과, 실기기 APK 설치 검증

### UI/UX Phase 2 아키텍처 및 상태 동기화 개선 (2026-09-07)

- [x] IndexedStack 탭 간 데이터 자동 갱신: Riverpod `sessionsListProvider` 및 `markersListProvider` 도입, 탭 전환 및 삭제/추가/수정 시 실시간 동기화
- [x] 카카오맵 마커 삭제 동기화 및 고스트 마커 방지: `_syncMapMarkers()` 구현으로 전체 마커 삭제 시 즉시 메모리 및 카카오맵 네이티브 POI 제거
- [x] 저장된 세션 경로 상태 격리: `TrackingState` 내 `route`(실시간)와 `savedRoute`(조회용) 완전 분리, 과거 경로 조회/종료 시 실시간 추적 경로 보존
- [x] 설정 화면 가독성 개선: 제조사별 백그라운드 최적화 안내(기본 Android, Samsung, Xiaomi, 자동 복구)를 `ExpansionTile` 아코디언으로 분리
- [x] 지도 시각적 명확성 및 범례 오버레이: 좌측 하단 확장형 `MapLegendChip` 구현(현재 위치, 실시간 추적선, 저장 경로, 장소 마커, 사진 마커)
- [x] 자동화 테스트 4개 추가 (`saved_route_isolation_test.dart`, `map_legend_chip_test.dart`, `marker_sync_deletion_test.dart`, `settings_accordion_test.dart`), 총 29개 테스트 통과 및 `flutter analyze` 0건 검증 완료
- [x] '기록' 탭 세션 이름 수정 기능 추가: `TrackingSession` 모델에 `title` 필드 및 직렬화/`copyWith` 추가, `SessionTitleDialog` 신설, `SessionCard` 수정 버튼 및 이름/일시 구분 표시 연동, 회귀 테스트 추가 (`test/session_title_edit_test.dart`), 총 32개 테스트 통과

### GPS 오차 및 궤적 개선 (2026-09-07)

- [x] GPS 수신 모드 최고 정밀도 상향: `LocationAccuracy.bestForNavigation` 적용 (Android Fused Location Provider 최고 정밀도 모드 및 iOS 내비게이션 전용 센서 융합)
- [x] 다단계 도메인 위치 필터(`LocationFilter`) 고도화:
  - 정확도 게이트: 시작 지점 >35m, 이동 중 >25m 불량 신호 필터링
  - 정지 상태 드리프트 억제: 8m 이내 미세 떨림 수집 억제(휴식 중 가짜 이동 거리 누적 원천 차단)
  - 반사파 스파이크 기각: 순간 이동 속도 >30 m/s (108 km/h) 기각
  - 등산로 곡선 복원력: 최소 이동 거리 20m로 완화하여 지그재그 코스 보존
- [x] 2D 칼만 필터(`GpsKalmanFilter`) 구현: GPS 측정 오차 분산과 보행 동특성($q = 3.0\text{ m/s}$)을 융합하여 튀는 신호 감쇠 및 궤적 스무딩
- [x] `TrackingController` 연동: 세션 시작/복구/종료 시 필터 생명주기 관리, 보정 좌표 DB 저장 및 이동 거리 누적, 0.5 m/s 이하 속도 정지 표시
- [x] 자동화 테스트 13개 추가/갱신 (`gps_accuracy_filter_test.dart`, `location_settings_test.dart`), 총 45개 전체 테스트 통과 및 `flutter analyze` 0건 검증

### UI/UX 정밀 고도화 및 사용성 개선 (2026-09-07)

- [x] 지도 화면 가시성 극대화: `TrackingHudCard` 초기 상태 접힘(`initiallyCollapsed: true`) 기본화로 지도 면적 85%+ 확보, 탭 시 3열 메트릭 부드러운 확장
- [x] 추적 전 준비 상태 단계별 안내: GPS 수신 대기, 신호 안정화, 준비 완료(오차 반경 표시) 단계별 안내 바 구현
- [x] 기록 세션 카드 시각화: 줄글 텍스트에서 거리(`km`), 시간(`시간/분`), 위치 수(`개`) 시각적 칩 그리드 및 상태 뱃지(`완료`/`기록 중`)로 전면 개편
- [x] 마커 화면 미디어 썸네일: 사진/동영상 마커에 실제 로컬 썸네일 이미지(44x44) 및 미디어 뱃지(카메라/비디오 아이콘) 표시
- [x] 설정 화면 컴팩트화: 중복 문구 제거 및 단일 아코디언 카드로 통합하여 핵심 설정 접근성 대폭 개선
- [x] 저장 경로 상태 명시: 하단 `NavigationBar` '추적'/'기록' 탭 뱃지 및 지도 상단 전용 플로팅 배너(`[저장 경로 보기 중 | 보기 종료]`) 연동
- [x] 자동화 테스트 4개 추가/갱신 (`tracking_hud_card_test.dart`, `session_card_metrics_test.dart`, `markers_screen_thumbnail_test.dart`), 총 49개 전체 테스트 통과 및 `flutter analyze` 0건 검증

