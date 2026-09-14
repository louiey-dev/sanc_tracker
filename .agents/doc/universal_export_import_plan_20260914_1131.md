# 범용 포맷(GPX·GeoJSON) 내보내기/가져오기 구현 계획

## 1. 개요

사용자가 기록한 이동 경로(세션·GPS 좌표) 및 장소 마커를 다른 기기나 타 지도 앱(카카오맵, 네이버 지도, Strava, Google Earth 등)과 공유하고, 외부에서 생성된 경로 및 백업 파일을 앱으로 다시 가져올 수 있도록 표준 범용 포맷인 **GPX (v1.1)** 및 **GeoJSON (RFC 7946)** 기반의 Export/Import 기능을 구현한다.

---

## 2. 포맷 사양 및 매핑 정의

### 2.1 GPX (GPS Exchange Format v1.1)

- **Waypoints (`<wpt>`)**: 장소 마커(`MapMarker`)와 매핑
  - `lat`, `lon`: 위도 및 경도
  - `<name>`: 마커 제목
  - `<desc>`: 마커 메모
  - `<type>`: 마커 카테고리
  - `<time>`: 마커 생성 일시 (ISO-8601 UTC)
- **Track (`<trk>`)**: 추적 세션(`TrackingSession`)과 매핑
  - `<name>`: 세션 제목 (없을 경우 날짜 기반 기본 이름)
  - `<trkseg>`: 연속 경로 구간
  - `<trkpt>`: `LocationPoint`와 매핑
    - `lat`, `lon`: 위도 및 경도
    - `<ele>`: 고도(미터)
    - `<time>`: 기록 일시 (ISO-8601 UTC)
    - `<speed>`: 속도 (m/s)

### 2.2 GeoJSON (RFC 7946)

- 루트: `FeatureCollection`
- **LineString Feature**: 세션 이동 경로
  - `geometry.coordinates`: `[[경도, 위도, 고도], ...]`
  - `properties`:
    - `type`: `"session_track"`
    - `sessionId`: 세션 ID
    - `title`: 세션 제목
    - `startedAt`, `endedAt`: 세션 시작/종료 일시
    - `coordTimes`: 각 좌표의 기록 일시 배열 (`["2026-09-14T...", ...]`)
    - `speeds`: 각 좌표의 속도 배열
- **Point Feature**: 장소 마커
  - `geometry.coordinates`: `[경도, 위도]`
  - `properties`:
    - `type`: `"marker"`
    - `markerId`: 마커 ID
    - `title`: 마커 제목
    - `notes`: 메모
    - `category`: 카테고리
    - `createdAt`: 생성 일시

---

## 3. 데이터 무결성 및 가져오기(Import) 정책

1. **기존 데이터 보존 원칙**:
   - 가져오기는 기존 로컬 데이터를 덮어쓰거나 삭제하지 않는다.
   - 가져오는 세션과 마커는 고유한 새 ID를 발급하거나, 기존 ID와 중복되지 않도록 처리하여 안전하게 추가(Append/Merge)한다.
2. **사전 검증 및 미리보기**:
   - 파일 선택 후 즉시 파싱하여 세션 수, 위치 좌표 수, 마커 수를 추출한다.
   - 사용자에게 요약 팝업을 표시하고 사용자가 '가져오기'를 확인한 경우에만 DB에 반영한다.
3. **유효하지 않은 파일 처리**:
   - 좌표가 없거나 포맷이 깨진 파일은 명확한 에러 메시지를 표시하고 가져오기를 중단한다.

---

## 4. UI/UX 구성

1. **내보내기 (Export & Share)**:
   - `HistoryScreen`: 세션 상세 또는 세션 카드 메뉴에 [내보내기/공유] 버튼 배치.
   - 포맷 선택 팝업: `GPX (.gpx)` 또는 `GeoJSON (.geojson)` 선택.
   - OS 기본 공유 시트(`share_plus`)를 열어 카카오톡, 메시지, 이메일, 클라우드 저장소 등으로 바로 전송하거나 기기에 저장.
2. **가져오기 (Import)**:
   - `HistoryScreen` 상단 액션바에 [가져오기] 아이콘 버튼 배치.
   - 파일 선택기(`file_picker`)로 `.gpx`, `.geojson`, `.json` 파일 선택.
   - 미리보기 다이얼로그 확인 후 저장소에 추가하고 목록을 즉시 갱신.

---

## 5. 구현 단계

1. **의존성 추가**:
   - `xml: ^6.6.1`: GPX XML 파싱 및 빌드.
   - `share_plus: ^12.0.2`: 파일 공유 시트 연동.
   - `file_picker: ^11.0.3`: 기기 내 파일 탐색 및 선택.
2. **코어 변환기(Converters) 구현 및 단위 테스트**:
   - `lib/export_import/domain/gpx_converter.dart`: GPX 직렬화 및 역직렬화.
   - `lib/export_import/domain/geojson_converter.dart`: GeoJSON 직렬화 및 역직렬화.
   - `test/gpx_converter_test.dart`, `test/geojson_converter_test.dart`: 단위 테스트 100% 통과 검증.
3. **서비스 계층 구현**:
   - `lib/export_import/application/export_import_service.dart`: 파일 읽기/쓰기, 임시 파일 생성, 저장소 저장, 공유 트리거.
4. **UI 연동**:
   - 세션 내보내기/공유 다이얼로그 및 공유 시트 호출.
   - 가져오기 파일 선택, 요약 확인 다이얼로그, 저장 후 Riverpod 상태 갱신.
5. **통합 및 위젯 테스트 검증**:
   - 내보내기/가져오기 동작 및 UI 반응 검증.
