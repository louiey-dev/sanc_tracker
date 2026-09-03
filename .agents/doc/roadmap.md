# SANC Tracker 개발 로드맵

## 제품 목표

Android/iOS 휴대폰에서 사용자가 추적을 시작하면 위치를 주기적으로 수집하고,
네트워크가 끊겨도 로컬에 보존한 뒤 Google Drive에 선택적으로 백업·복원한다.
사용자는 모바일과 추후 PC 앱/웹에서 Drive 백업을 가져와 날짜별 이동 경로,
현재 장소와 주변 정보를 지도에서 확인한다.
사진·동영상 촬영 시 촬영 위치를 함께 저장하고, 지도에서 해당 미디어를 볼 수 있어야
한다. 사용자가 지도에 기억할 장소를 직접 마크하고 기록을 가져오거나 내보낼 수 있어야 한다.

## 권장 1차 구조

```text
Flutter mobile (Android/iOS)
  ├─ location service: foreground/background GPS
  ├─ local database: location, marker, media metadata
  ├─ encrypted local media files
  └─ Google Drive backup/restore client
             ↓ OAuth + Drive API
        Google Drive appDataFolder
             ↓
        PC app/web backup restore viewer
```

Flutter를 모바일 공통 UI와 향후 Windows/Linux 확장의 기반으로 사용한다.
PC는 동일 Google 계정으로 Drive 백업을 복원하는 웹 뷰어를 우선 제공하고,
오프라인·시스템 통합 요구가 확실해질 때 Flutter Desktop을 추가한다.

### 지도 공급자 정책

- 기본 지도 공급자는 카카오맵으로 한다.
- 초기 릴리스에서는 카카오맵만 지원하고, 이후 공급자 추가를 위해 `MapProvider` 인터페이스를 둔다.
- 실제로 두 번째 공급자가 지원되기 전에는 지도 변경 UI를 제공하지 않는다.
- 이후 네이버·Google Maps·Mapbox를 어댑터로 추가한다.
- 위치·경로·사용자 마커·미디어 좌표는 공급자와 무관한 내부 좌표 모델로 저장한다.
- 지도 SDK 키와 공급자별 약관/비용은 앱 빌드 설정으로 분리하고 저장소에 키를 커밋하지 않는다.

## MVP 완료 기준

MVP(Minimum Viable Product)는 모든 기능을 포함한 최종 제품이 아니라,
앱의 핵심 목적을 실제로 검증할 수 있는 최소 기능 제품이다. 각 단계는
독립적으로 실행·검증할 수 있을 때 완료한 것으로 본다.

### MVP 1 — GPS 기록

- 추적 시작·중지, 카카오맵 기본 지도, 현재 위치·정확도 표시
- 시간/거리 기준 위치 수집 및 로컬 저장
- 날짜별 이동 경로 표시
- 권한 거부·위치 서비스 중지·저정확도 안내
- 네트워크 단절 중에도 위치를 로컬에 보존하고 앱 재실행 후 복구되는지 검증

### MVP 2 — 장소 기록

- 지도 사용자 마커 추가·수정·삭제 및 제목·메모·분류 저장
- 바다 등 주소 없는 장소도 위도·경도만으로 저장
- 사진·동영상 촬영 위치·시각 저장
- 미디어가 있는 위치의 아이콘과 썸네일 표시

### MVP 3 — 데이터 관리

- Google Drive 백업·복원 및 PC 날짜별 경로 조회
- PC에서 Drive 백업의 마커·미디어 조회
- JSON/GeoJSON/GPX Import/Export
- Google Drive 개인 백업·복원 동기화
- 잘못된 파일·중복 데이터·부분 업로드 처리
- 사용자 데이터 삭제

## 위치 수집 정책 초안

- 일반 모드: 이동 거리 50m 또는 최대 30초마다 수집
- 정지 감지 시: 최대 5분 간격으로 완화
- 각 점에 `recordedAt`, 좌표, 정확도, 고도, 속도, 방향, 배터리 상태를 저장
- 정확도가 임계값보다 나쁜 점은 표시용 경로에서 제외할 수 있으나 원본은 보존
- 주소/주변 장소 API는 모든 GPS 점에 호출하지 않고, 이동 거리·시간 변화가
  충분할 때만 조회하여 비용과 배터리를 제한

## 핵심 데이터 모델

### `users`

`id`, `email`, `created_at`

### `tracking_sessions`

`id`, `user_id`, `started_at`, `ended_at`, `device_id`, `status`

### `location_points`

`id`, `session_id`, `user_id`, `latitude`, `longitude`, `recorded_at`,
`accuracy_m`, `altitude_m`, `speed_mps`, `heading_deg`, `battery_percent`,
`address`, `place_name`, `sync_state`, `created_at`

### `media_items`

사진과 동영상 파일은 로컬 파일/오브젝트 스토리지에 저장하고 DB에는 메타데이터를
저장한다. `id`, `user_id`, `session_id`, `location_point_id`, `type`(`photo`/`video`),
`file_uri`, `thumbnail_uri`, `captured_at`, `latitude`, `longitude`, `accuracy_m`,
`width`, `height`, `duration_ms`, `sync_state`, `created_at`을 사용한다.

촬영 당시 위치를 확보하지 못한 경우에도 미디어는 저장하되 `location_status`를
`exact`, `last_known`, `unknown`으로 구분한다. 지도에는 좌표가 있는 미디어만 표시하고,
미디어가 있는 위치 점에는 카메라/동영상 아이콘을 표시한다.

### `map_markers`

사용자가 직접 남기는 기억 장소다. `id`, `user_id`, `title`, `note`, `category`,
`latitude`, `longitude`, `created_at`, `updated_at`, `sync_state`를 저장한다.
자동 수집 위치와 구분하고 지도에서 추가·이동·편집·삭제할 수 있도록 한다.

마커와 미디어의 연결은 `marker_media(marker_id, media_id)`로 별도 관리한다. 미디어의
기본 위치는 촬영 좌표이며, `location_point_id`는 동일 시점의 자동 수집 위치를 가리키는
선택 참조로만 사용한다.

서버에서는 좌표를 PostGIS `geography(Point, 4326)`로도 저장하면 거리 계산과
지리 검색을 효율적으로 처리할 수 있다. 모바일 로컬 DB에는 서버 ID와
`client_event_id`를 함께 두어 재시도 시 멱등성을 보장한다. 동기화 대상에는
`updated_at`, `deleted_at`을 두며, 삭제는 서버 동기화 전까지 tombstone으로 보존한다.

## Import/Export 범위

- 앱 전용 버전 관리 JSON은 위치·세션·마커·미디어 메타데이터를 포함하는 완전 백업 포맷이다.
- GeoJSON과 GPX는 위치·경로·좌표 마커만 내보내는 호환 포맷이며, 사진·동영상 원본과
  앱 전용 메모는 보장하지 않는다.
- 미디어 원본은 선택적으로 압축 파일에 포함할 수 있고, 포함하지 않을 때는 메타데이터와
  썸네일만 내보낸다.
- 가져오기는 기본적으로 기존 데이터를 덮어쓰지 않으며, `client_event_id`와 콘텐츠 해시를
  이용해 중복을 탐지한다.

## Google Drive 백업·복원

- Google Drive는 자체 서버 동기화를 대체하기보다, 사용자의 개인 백업·기기 간 복원을
  위한 선택적 동기화 대상으로 제공한다.
- 자동 백업은 Google Drive의 앱 전용 숨김 저장소(`appDataFolder`)를 사용한다. 사용자가
  요청한 수동 Export만 일반 Drive 폴더 또는 공유 가능한 파일로 만든다.
- OAuth 권한은 `drive.appdata`를 우선 사용하며, 일반 Drive 폴더를 선택하는 Export에만
  필요한 최소 추가 권한을 요청한다.
- 백업 파일은 `formatVersion`, 생성 시각, 기기 ID, 변경 시각, 암호화 버전, 콘텐츠 해시를
  포함한다. 위치·미디어 원본은 사용자가 선택한 경우에만 포함한다.
- 동기화는 마지막 성공 시각 이후 변경분을 업로드하고, 충돌 시 자동 덮어쓰기 대신
  복사본 생성 또는 사용자 선택으로 처리한다.
- Google 계정 연결 해제, 백업 삭제, 자동 동기화 중지 기능을 제공한다.

## 개인정보와 데이터 보호 기준

- 위치·미디어·마커는 민감 데이터로 취급하며 외부 전송은 HTTPS로 제한한다.
- 로컬 DB·미디어 암호화 적용 여부와 Export 파일 암호 설정은 Google Drive 연동 전에 확정한다.
- Google Drive 자동 백업도 암호화된 앱 전용 백업 파일만 사용하며, OAuth 토큰은 안전한
  플랫폼 저장소에 보관한다.
- 보관 기간, 전체 삭제, 개별 삭제, 백업 파일의 공유 책임을 사용자에게 명확히 안내한다.

## 단계별 작업

### Phase 0 — 프로젝트 기반

- Flutter 프로젝트 생성 및 Android/iOS 빌드 확인
- 상태 관리, 라우팅, 로깅, 환경별 설정 결정
- 지도 공급자와 Google Drive 백업 방식 결정
- 카카오맵 앱 등록, 플랫폼 키, 무료 쿼터와 유료 전환 기준 확인
- 개인정보 처리·위치 권한 문구 초안 작성

### Phase 1 — 단말 로컬 MVP

- 지도와 현재 위치
- 추적 시작/중지
- 로컬 DB 저장 및 세션 관리
- 날짜별 로컬 경로 재생
- 권한 거부, 위치 서비스 꺼짐, 저정확도 처리
- 지도 롱프레스 기반 사용자 마커 추가·편집·삭제
- 카카오맵을 기본 공급자로 연결하고 지도 공급자 추상화 검증
- 사진 촬영 및 촬영 위치 메타데이터 저장
- 지도상의 미디어 아이콘과 썸네일 미리보기
- JSON/GeoJSON 기반 로컬 Import/Export

### Phase 2 — 백그라운드 안정화

- Android foreground service
- iOS background location capability
- 재부팅/앱 재실행 후 상태 복구
- 배터리 절약 및 수집 주기 설정
- 실제 기기 장시간 테스트
- 화면 잠금·백그라운드·네트워크 단절 중 위치 유실 여부 검증

### Phase 3 — Google Drive 및 PC 뷰어

- Google OAuth와 앱 전용 Drive 백업·복원
- PC 웹 지도, 날짜 필터, 점 상세 정보
- Drive 백업에서 미디어·마커를 가져와 표시
- 모바일/PC 간 Import/Export
- Google Drive 수동 Export와 자동 백업 설정

## 향후 선택 확장 — 자체 서버

여러 사용자 공유, 실시간 위치 공유, Drive를 거치지 않는 다중 기기 동기화가 필요할 때만
자체 서버를 도입한다. 이때 기존 API 계약의 세션·위치 배치 업로드·PostgreSQL/PostGIS·인증
설계를 다시 활성화한다. 현재 MVP와 활성 TODO에는 포함하지 않는다.

### Phase 4 — 주변 정보와 분석

- 좌표→주소 변환
- 주변 장소 검색
- 체류 장소·체류 시간 추정
- 이동 거리/속도 통계
- CSV/GPX 내보내기 및 보관 기간 설정
- 사진·동영상과 이동 경로의 시간순 타임라인
- 미디어 포함/제외, 원본/썸네일 포함 여부를 선택하는 Export 옵션

## 반드시 검증할 위험 요소

- iOS/Android의 백그라운드 권한과 스토어 심사 요건
- 제조사별 배터리 최적화로 인한 위치 수집 중단
- GPS 오차와 실내·지하 환경
- 위치 API 및 지도/주변 장소 API 비용
- 민감정보 암호화, 삭제, 접근제어, 보관기간
- 네트워크 단절·시간 변경·중복 업로드·앱 강제 종료
- 대용량 동영상 업로드 재개, 썸네일 생성, 저장공간 부족
- 미디어 EXIF 위치와 앱 수집 위치의 우선순위 및 개인정보 노출
- Import 파일 검증, 악성 파일 차단, 중복 마커/미디어 병합 정책

## 첫 구현 권장 순서

1. Flutter 빈 앱을 초기화하고 실제 Android/iOS 빌드를 통과시킨다.
2. 로컬 위치 수집과 로컬 경로 표시만 먼저 완성한다.
3. 실기기에서 30분 이상 백그라운드 테스트를 한다.
4. 그 결과를 바탕으로 수집 정책을 확정한다.
5. 사진·동영상과 사용자 마커를 로컬에서 먼저 완성한다.
6. Import/Export를 추가해 데이터 이동성을 검증한다.
7. Google Drive 백업·복원과 PC 뷰어를 추가한다.
