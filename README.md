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

## 개발 기준

작업 순서와 체크 상태는 [TODOs.md](./.agents/TODOs.md)를 기준으로 관리합니다.
현재 목표는 개인 휴대폰 로컬 저장과 Google Drive 백업·복원입니다.
PC 조회는 모바일 MVP 이후 단계이며 자체 서버는 향후 선택 사항입니다.

- [제품 로드맵](./.agents/doc/roadmap.md)
- [백업·복원 계약](./.agents/doc/project-structure.md)
- [향후 자체 서버 API 참고](./.agents/doc/api-contract.md)

## Repository

Repository: [sanc_tracker](https://github.com/louiey-dev/sanc_tracker.git)

---

## History

- 2026.09.03
  - kakao map displayed
