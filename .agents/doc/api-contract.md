# SANC Tracker 향후 자체 서버 API 계약 초안

현재 제품 범위는 휴대폰 로컬 저장과 Google Drive 백업·복원이다. 이 문서는 향후
실시간 공유 또는 자체 다중 기기 동기화가 필요할 때만 사용할 선택적 서버 설계이며,
현재 활성 TODO의 구현 대상은 아니다.

모든 API는 HTTPS를 사용한다. 인증은 `Authorization: Bearer <token>` 형식으로
전달하며, 서버는 토큰의 사용자 소유 데이터만 반환한다.

## 세션

### `POST /v1/sessions`

추적 세션을 시작한다.

```json
{
  "clientSessionId": "uuid",
  "deviceId": "device-identifier",
  "startedAt": "2026-09-03T02:00:00Z"
}
```

응답은 서버 `sessionId`와 상태를 반환한다. 같은 `clientSessionId`를 재전송해도
새 세션을 만들지 않는 멱등 API로 구현한다.

### `POST /v1/sessions/{sessionId}/finish`

세션 종료 시각과 종료 상태를 기록한다. 앱 강제 종료처럼 정상 종료되지 않은
세션은 서버가 다음 동기화 시 `interrupted`로 남길 수 있다.

## 위치 업로드

### `POST /v1/location-points:batch`

한 번에 여러 위치를 업로드한다. `clientEventId`가 중복되면 기존 결과를 반환하고
중복 행을 만들지 않는다.

```json
{
  "points": [
    {
      "clientEventId": "uuid",
      "clientSessionId": "uuid",
      "latitude": 37.5665,
      "longitude": 126.9780,
      "recordedAt": "2026-09-03T02:01:00Z",
      "accuracyM": 12.4,
      "altitudeM": 35.2,
      "speedMps": 1.8,
      "headingDeg": 90.0,
      "batteryPercent": 82
    }
  ]
}
```

응답에는 성공한 `clientEventId`와 실패 항목별 오류 코드를 포함한다. 모바일은
성공한 항목만 로컬 `synced` 상태로 변경하고, 실패 항목은 지수 백오프로 재시도한다.

## 경로 조회

### `GET /v1/tracks?from=2026-09-03T00:00:00Z&to=2026-09-04T00:00:00Z`

기간 내 세션 목록과 요약 정보를 반환한다.

### `GET /v1/sessions/{sessionId}/location-points`

지도 표시용 위치를 시간순으로 반환한다. `simplify=true`를 지원해 장거리 경로의
점 수를 줄일 수 있으나, 원본 데이터는 서버에 보존한다.

## 미디어

### `POST /v1/media/upload`

사진·동영상 파일과 메타데이터를 업로드한다. 대용량 동영상은 재개 가능한 업로드를
사용하고, 서버는 썸네일을 별도로 생성한다. 메타데이터에는 `clientMediaId`,
`capturedAt`, 좌표, `locationStatus`, `sessionId`를 포함한다.

### `GET /v1/media?from=...&to=...`

기간 또는 지도 영역 내 미디어 목록을 반환한다. 지도용 응답에는 썸네일 URL과
좌표만 우선 제공하고, 원본 다운로드는 사용자가 선택했을 때 수행한다.

## 사용자 지도 마커

### `POST /v1/markers`, `PATCH /v1/markers/{id}`, `DELETE /v1/markers/{id}`

제목·메모·분류·좌표·첨부 미디어를 저장하고 수정·삭제한다. `clientMarkerId`를
멱등 키로 사용해 오프라인 재시도를 지원한다.

### `GET /v1/markers?bounds=...`

지도 영역에 포함된 사용자의 마커를 반환한다.

## Import/Export

### `POST /v1/import`

앱이 생성한 JSON/GeoJSON 또는 지원하는 GPX 파일을 검증·미리보기한 후 가져온다.
기본 동작은 기존 데이터를 덮어쓰지 않고 새 기록으로 추가하는 방식으로 한다.

### `GET /v1/export?from=...&to=...&includeMedia=false`

위치·세션·마커와 선택된 미디어 메타데이터를 하나의 버전 관리된 압축 파일로
내보낸다. 원본 동영상 포함 여부는 별도 옵션으로 둔다.

## 동기화·삭제 규칙

로컬 `location_points`에는 다음 상태를 둔다.

- `pending`: 아직 업로드하지 않음
- `uploading`: 업로드 중
- `synced`: 서버 저장 확인
- `failed`: 마지막 업로드 실패, 재시도 대상

앱 시작 시 `uploading` 상태를 `pending`으로 되돌려 앱 중단으로 인한 유실을
방지한다. 기기 시각이 바뀔 수 있으므로 서버 저장 시 `recordedAt`과
`receivedAt`을 모두 보존한다.

모든 동기화 대상에는 `clientEventId`, `updatedAt`, 선택적 `deletedAt`을 둔다.
삭제 요청은 우선 tombstone으로 동기화하고, 모든 연결된 기기에서 반영된 뒤에만
물리 삭제한다. 마커와 미디어는 `marker_media` 연결 자원으로 관계를 관리한다.

## Export 포맷 규칙

- 앱 전용 JSON은 전체 백업 포맷이며 `formatVersion`을 필수로 포함한다.
- GeoJSON/GPX는 경로와 좌표 마커 호환용이며, 미디어 원본과 앱 전용 메모는 포함하지 않는다.
- 미디어 원본을 포함하는 Export는 압축 파일로 생성하며, 포함 여부를 사용자가 선택한다.

## Google Drive 백업 계약

Google Drive 자동 백업은 서버 API가 아닌 클라이언트 측 동기화로 수행한다. 기본 대상은
`appDataFolder`이며, 일반 Drive 폴더에는 사용자가 명시적으로 Export할 때만 파일을 만든다.

백업 매니페스트에는 다음 필드를 포함한다.

```json
{
  "formatVersion": 1,
  "backupId": "uuid",
  "deviceId": "device-identifier",
  "createdAt": "2026-09-03T02:00:00Z",
  "lastModifiedAt": "2026-09-03T02:10:00Z",
  "encrypted": true,
  "contentHash": "sha256"
}
```

복원 전에는 매니페스트 버전과 콘텐츠 해시를 검증한다. 같은 `backupId`의 변경본은
변경 시각과 해시를 비교하고, 충돌하면 자동 덮어쓰기 대신 복사본을 만들거나 사용자에게
선택을 요청한다.

## 오류 규칙

- `401`: 토큰 갱신 또는 재로그인
- `409`: 멱등 키 충돌 또는 세션 상태 충돌
- `422`: 좌표·시간 등 입력값 오류; 자동 재시도하지 않음
- `429`: 서버가 제시한 지연 후 재시도
- `5xx`/네트워크 오류: 로컬 보존 후 재시도
