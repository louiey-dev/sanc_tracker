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

```bash
# Android 실행
flutter clean
flutter pub get
flutter run -d R3CXB0P55MB --dart-define=SANC_ENV=development --dart-define=KAKAO_NATIVE_APP_KEY=516e70905f94b10af9e3b6b6942f360f
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
- 2026.09.04
  - 저장된 경로 표시 및 open 하여 경로확인 가능
  - 현재 위치 마커를 빨간색 원형으로 변경
  - 저장 마커 크기를 1/2로 축소
  - 저장 마커 이름 표시
  - 저장 마커 터치 기능 추가
  - 이름·위도·경도 상세 정보 표시
  - 마커 이동 기능 추가  - 마커 선택
  - 이동 확인
  - 지도에서 새 위치 선택
  - 저장 마커 삭제 기능 추가
  - 현재 위치로 이동하는 버튼 추가
  - 지도 전체화면 확대 및 원복 기능 추가
  - 스크롤 중 마커 갱신 오류 안정화
  - 중복 표시되던 저장된 세션 목록을 하나로 통합
  - 저장된 마커 목록 추가
  - 마커 이름과 위도·경도 표시
  - 목록에서 마커를 누르면 해당 위치로 지도 이동
  - 새 마커 저장·삭제 시 목록도 갱신
  - 전체화면에서도 현재 위치 이동 아이콘 유지
  - 저장된 세션 삭제 기능 추가
  - 경로 불러오기 메뉴 추가
  - 마커 저장/불러오기 추가
  - 추적을 시작하지 않아도 현재 위치를 한 번 확인
  - 현재 위치 마커 표시
  - 잠금·백그라운드 상태에서 동작
  - 제목·메모·분류 입력 및 저장
  - 주소가 없는 장소도 위도·경도 기반으로 저장
  - 마커 이동 후 좌표 저장
  - 마커 삭제 시 로컬 데이터에서도 삭제
  - 마커 목록 표시 및 위치 이동, 삭제
  - 사진·동영상 마커 팝업 미리보기
  - 사진 즉시 열기
  - 동영상 즉시 재생
  - 실제 동작 검증 완료
  - 이동 경로 상세 정보 표시- 시작 시각
  - 종료 시각
  - 총 소요 시간
  - 이동 거리
  - 경로에 포인트 선택시 위치에 정보 표시
