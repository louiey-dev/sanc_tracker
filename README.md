# SANC Tracker

휴대폰 GPS로 이동 경로를 기록하고 지도에서 확인하는 개인 위치 기록 앱입니다.

## 현재 상태

- Flutter 기반 Android/iOS/Web/Windows 프로젝트 생성
- GPS 권한 확인 및 위치 스트림 연결
- 추적 시작/중지와 현재 좌표·정확도 표시
- 위치는 다음 단계에서 로컬 영속 저장소로 전환 예정

## 실행

```shell
flutter pub get
flutter run
```

실제 GPS 테스트는 Android 또는 iOS 기기에서 수행합니다.

## 다음 구현 순서

1. 저장 계층과 로컬 영속 저장소
2. 추적 세션 및 날짜별 경로
3. 지도 SDK 연결
4. Android/iOS 백그라운드 추적
5. 서버 동기화와 PC 웹 뷰어

상세 범위는 `.agents/doc/roadmap.md`, API 계약은 `.agents/doc/api-contract.md`를 참고합니다.

