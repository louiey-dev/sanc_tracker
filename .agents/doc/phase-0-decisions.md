# Phase 0 결정 기록

## 앱 기반

- 상태 관리: Riverpod `Notifier`
- 라우팅: `MaterialApp` named routes. 화면 수가 늘면 `go_router` 도입을 별도 결정한다.
- 로깅: `dart:developer` 기반 `AppLogger`; 운영 빌드에서는 기본 비활성화한다.
- 환경: `--dart-define=SANC_ENV=development|production` 및 `SANC_LOGGING`을 사용한다.
- 지도 키: `--dart-define=KAKAO_NATIVE_APP_KEY=...`, `KAKAO_WEB_APP_KEY=...`로 주입하며 소스와 저장소에 키를 커밋하지 않는다.
- Flutter 지도 패키지: 현재 Dart SDK(3.9.2)와 호환되는 `kakao_maps_flutter ^0.1.2`를 사용한다. 최신 0.2.x는 Dart 3.12 이상이 필요하므로 SDK 업그레이드 때 재검토한다.

## 저장·Export 패키지

- 로컬 DB: `drift` + `drift_flutter`를 선택한다. SQLite 기반이며 Android/iOS/Windows/Web 확장 경계를 유지하기 쉽다.
- 파일 경로: `path_provider`로 앱 전용 문서 디렉터리를 사용한다.
- 압축/Export: `archive`로 앱 백업 패키지를 만들고, `share_plus`로 사용자가 요청한 파일만 공유한다.
- 선택 근거: 모델·스키마·트랜잭션을 타입 안전하게 관리하고, 절대 경로를 백업 포맷에 넣지 않기 위해서다.

## 지도

- 1차 공급자: 카카오맵 SDK.
- 경계: 앱 내부 좌표 모델과 `MapProvider` 계약만 도메인에 노출하고 카카오 SDK 타입은 어댑터 안에 가둔다.
- 등록 상태: 개발자 콘솔 앱과 Android/iOS/Web 플랫폼 키는 계정 소유자의 등록이 필요하므로 아직 미등록이다.
- 쿼터/비용: 카카오 공식 쿼터 문서 기준 지도 Android/iOS/Web SDK 무료 쿼터는 일 300,000 calls이며, 첫 활성 앱에 무료 쿼터가 적용된다. 초과분은 유료 사용 설정과 Biz Wallet이 필요하다. 실제 요율과 정책은 출시 직전에 재확인한다.

## 개인정보·삭제·보관

- 위치, 미디어, 마커는 민감한 개인 데이터로 취급하고 외부 전송은 HTTPS로 제한한다.
- 로컬 삭제와 Drive 백업 삭제는 별도 동작이다. 로컬 삭제 후 과거 백업에 기록이 남을 수 있음을 복원 전에 표시한다.
- 기본 보관 기간은 사용자가 설정하며, 초기 기본값은 90일로 제안한다. 기간 만료 자동 삭제는 명시적 설정 이후에만 실행한다.
- 계정 연결 해제는 로컬 데이터나 Drive 백업을 삭제하지 않는다.
- 백업 원본 공유는 기본 차단하고, 사용자가 명시적으로 Export할 때만 공유 기능을 제공한다.

## 암호화

- 로컬 DB/미디어: MVP 1에서는 앱 전용 저장소에 보관하고, 실제 암호화 적용 전까지 민감 데이터가 평문임을 배포 범위에서 제한한다. Drive 연동 전 SQLCipher 또는 검증된 대안을 별도 검증한다.
- 사용자 Export: 기본은 비암호화 호환 Export로 하되, 전체 백업과 Drive 자동 백업은 암호화 필수로 한다.
- 백업: 검증된 `cryptography` 계열 라이브러리의 Argon2id 키 파생 + AEAD(ChaCha20-Poly1305 또는 AES-GCM) 조합을 채택 후보로 기록한다. 라이브러리/매개변수는 구현 시작 전에 패키지 버전과 함께 고정한다.
- 형식: `formatVersion`과 `encryptionVersion`을 헤더에 포함하고, salt와 nonce는 저장하되 암호·평문 키는 저장하지 않는다.
- 암호 변경은 새 백업부터 적용한다. 이전 백업은 이전 암호가 있어야 복원하며, 암호 분실 복구는 제공하지 않는다.

## 참고

- [Kakao Maps 개념/사용 정책](https://developers.kakao.com/docs/ko/kakaomap/common)
- [Kakao API 쿼터·비용](https://developers.kakao.com/docs/ko/getting-started/quota)
