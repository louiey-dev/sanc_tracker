# GPS 오차 및 궤적 개선 구현 (2026-09-07)

## 1. 개요 및 목적

야외 산행 및 트레킹 중 발생하는 GPS 오차(튀는 현상, 정지 시 가짜 이동 거리 누적, 절벽/건물 주변 반사파 스파이크)를 앱 내부 소프트웨어 필터링을 통해 원천 제거하고, 부드럽고 정확한 등산로 궤적을 기록하기 위한 개선 작업을 진행했다.

---

## 2. 주요 개선 내역

### 2.1. GPS 정확도 모드 상향 (`bestForNavigation`)

- **파일**: [location_service.dart](../../lib/tracking/data/location_service.dart)
- 기존 `LocationAccuracy.high`에서 `LocationAccuracy.bestForNavigation`으로 변경.
- **효과**:
  - Android: Google Play Services Fused Location Provider의 최고 정밀도 모드 활성화.
  - iOS: `kCLLocationAccuracyBestForNavigation` 적용을 통해 가속도 센서·나침반 융합 및 내비게이션 전용 고출력 GPS 센서 활용.

### 2.2. 다단계 도메인 위치 필터 (`LocationFilter`) 고도화

- **파일**: [location_filter.dart](../../lib/tracking/domain/location_filter.dart)
- 5단계 필터링 파이프라인 구축:
  1. **정확도 게이트 (Accuracy Gate)**:
     - 초기 위치 고정: `accuracy > 35m`인 불완전한 GPS 신호는 시작 지점으로 채택하지 않고 안정화될 때까지 대기.
     - 이동 중 신호: `accuracy > 25m`인 신호는 기록에서 배제하여 궤적 왜곡 방지.
  2. **정지 상태 드리프트 억제 (Stationary Drift Suppression)**:
     - 휴식 중에는 GPS 수신기가 위성 배치 변화로 3~6m씩 제자리에서 요동침.
     - 이전 지점과의 거리가 `stationaryRadiusM (8.0m)` 미만이면 30초가 경과해도 기록하지 않음.
     - **결과**: 쉬는 동안 이동 거리가 누적되는 현상 원천 차단.
  3. **반사파 스파이크/순간 이동 제거 (Multipath Spike Gate)**:
     - 절벽이나 장애물로 인해 GPS 좌표가 갑자기 튈 때 속도(`distance / elapsedSeconds`)를 계산.
     - 도보/등산 중 물리적으로 불가능한 속도인 `30 m/s` (약 108 km/h)를 초과하는 점은 즉시 기각.
  4. **지그재그 등산로 턴 복원력**:
     - 기존 50m 직선 컷을 `minimumDistanceM = 20m`로 완화하여 헤어핀/스위치백 등산로를 원본 그대로 기록.
  5. **완만한 보행 주기 반영**:
     - 8m 이상 이동한 상태에서 30초가 경과하면 가파른 오르막길 보행도 누락 없이 기록.

### 2.3. 2D 칼만 필터 도입 (`GpsKalmanFilter`)

- **파일**: [gps_kalman_filter.dart](../../lib/tracking/domain/gps_kalman_filter.dart)
- **알고리즘**:
  - 상태 벡터: 위도(Latitude), 경도(Longitude), 고도(Altitude).
  - 측정 분산 $R$: GPS 측정 오차 반경 $accuracy^2$을 위도/경도 도 단위 분산으로 변환.
  - 프로세스 노이즈 $Q$: 보행 동특성($q = 3.0\text{ m/s}$)과 시간 변화량 $\Delta t$를 반영.
  - 정확도가 높은 측정치는 신속하게 수렴하고, 정확도가 떨어지는 측정치는 칼만 게인을 낮춰 궤적의 요동을 억제.
  - 30초 이상의 공백(휴식 후 재개 등) 발생 시 드래그 현상을 막기 위해 현재 좌표로 즉시 재고정(re-anchor).

### 2.4. 컨트롤러 연동 (`TrackingController`)

- **파일**: [tracking_controller.dart](../../lib/tracking/presentation/tracking_controller.dart)
- 세션 시작/종료 시 칼만 필터 초기화(`reset`).
- 이전 활성 세션 복구 시 마지막 위치 좌표를 칼만 필터 상태로 복원(`setState`).
- 필터링된 보정 좌표를 DB 저장 및 지도 궤적(`route`), 이동 거리 누적에 적용.
- 실시간 속도 표시 시 0.5 m/s 이하의 미세 떨림은 0.0 km/h로 표시하여 정지 상태 안정성 확보.

---

## 3. 검증 결과

### 3.1. 자동화 테스트

- 신규 테스트 파일: [gps_accuracy_filter_test.dart](../../test/gps_accuracy_filter_test.dart) (12개 테스트 추가)
  - 저정확도 시작/이동 신호 기각 검증.
  - 정지 상태 드리프트 억제 검증.
  - 100 m/s 이상 스파이크 기각 검증.
  - 칼만 필터 노이즈 감쇠율 50% 이상 검증.
  - 30초 경과 시 재고정 및 세션 상태 복원 검증.
- 기존 설정 테스트: [location_settings_test.dart](../../test/location_settings_test.dart) (`bestForNavigation` 확인 추가)
- **전체 테스트 결과**: 총 45개 테스트 100% 통과 (`All tests passed!`).

### 3.2. 정적 분석

- `flutter analyze` 실행 결과 경고 및 오류 0건 (`No issues found!`).
