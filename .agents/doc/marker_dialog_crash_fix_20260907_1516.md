# 마커 입력 후 시스템 크래시(빨간 화면) 원인 분석 및 수정 보고서

- 작성 일시: 2026-09-07 15:16
- 대상 파일:
  - [lib/map/presentation/widgets/marker_input_dialog.dart](../../lib/map/presentation/widgets/marker_input_dialog.dart)
  - [lib/map/presentation/widgets/video_player_dialog.dart](../../lib/map/presentation/widgets/video_player_dialog.dart)
  - [lib/tracking/presentation/track_map_screen.dart](../../lib/tracking/presentation/track_map_screen.dart)
  - [test/add_marker_dialog_test.dart](../../test/add_marker_dialog_test.dart)

---

## 1. 문제 현상

지도 화면에서 롱프레스로 장소 마커를 추가하거나, 마커 수정, 사진 촬영 후 메모를 저장하는 시점에 Flutter 레드 스크린(Red Screen of Death) 또는 시스템 크래시가 발생하는 오류가 발생함.

---

## 2. 원인 분석 (Root Cause)

### 컨트롤러의 비동기 생명주기 불일치 (Premature Controller Disposal)

기존 `_addMarker`, `_editMarker`, `capturePhotoAtCurrentLocation` 메서드에서는 `TextEditingController`를 함수 스코프에서 생성한 뒤, `showDialog`를 `try-finally` 블록으로 감싸 `finally`에서 `dispose()`를 직접 호출하고 있었습니다:

```dart
final titleController = TextEditingController(text: '장소 마커');
final noteController = TextEditingController();
final categoryController = TextEditingController();
try {
  result = await showDialog<Map<String, String>>(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        children: [
          TextField(controller: titleController),
          // ...
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, {...}),
          child: const Text('저장'),
        ),
      ],
    ),
  );
} finally {
  titleController.dispose();
  noteController.dispose();
  categoryController.dispose();
}
```

#### 발생 메커니즘

1. 사용자가 "저장" 버튼을 누르면 `Navigator.pop(context, ...)`이 호출됩니다.
2. `Navigator.pop`이 실행되면 `showDialog`의 `Future`가 **즉시 완료(resolve)**됩니다.
3. 이에 따라 함수 실행 흐름이 곧바로 `finally` 블록으로 넘어가 `titleController.dispose()` 등이 즉시 실행됩니다.
4. 그러나 Flutter의 다이얼로그 라우트(`DialogRoute`)는 화면에서 사라지기까지 약 200~300ms 동안 **팝 닫힘 애니메이션(Exit Transition Animation)**을 진행합니다.
5. 팝 애니메이션이 진행되는 동안 `AlertDialog`와 내부 `TextField` 및 `EditableText` 위젯은 여전히 엘리먼트 트리에 활성 상태로 마운트되어 있습니다.
6. 포커스 해제 처리 또는 다음 애니메이션 프레임 렌더링 시 `TextField`가 이미 `dispose()`된 컨트롤러를 참조하게 되면서 다음과 같은 치명적 예외가 발생합니다:
   - `FlutterError: A TextEditingController was used after being disposed. Once you have called dispose() on a TextEditingController, it can no longer be used.`
7. 프레임 렌더링 파이프라인에서 처리되지 않은 FlutterError로 인해 화면에 레드 스크린(ErrorWidget)이 출력되거나 앱이 비정상 종료됩니다.

### 부가 원인: 키보드 팝업 시 `RenderFlex` 오버플로우

다이얼로그의 `content`가 `Column`으로만 구성되어 있고 `SingleChildScrollView`나 `scrollable: true`가 지정되지 않아, 소프트웨어 가상 키보드가 노출되었을 때 하단 픽셀 오버플로우가 유발될 수 있는 잠재 위험이 존재했습니다.

---

## 3. 해결 방안 및 구현 내용

### 3.1 독립적인 `StatefulWidget`으로 분리 (`MarkerInputDialog`, `PhotoMemoDialog`)

다이얼로그 내 텍스트 컨트롤러의 생명주기를 다이얼로그 위젯의 상태(`State`)에 완벽하게 일치시켰습니다:

- **생성**: `State.initState()`에서 초기화
- **해제**: `State.dispose()`에서 안전하게 해제
  - Flutter 프레임워크는 라우트의 닫힘 애니메이션이 완전히 종료되고 위젯 트리가 언마운트된 후에만 `State.dispose()`를 호출하므로, 애니메이션 도중 컨트롤러가 해제되는 문제를 근본적으로 방지합니다.
- **스크롤 보호**: `AlertDialog`의 본문을 `SingleChildScrollView`로 감싸 모바일 키보드 표시 시 오버플로우가 발생하지 않도록 방지하였습니다.

### 3.2 `VideoPlayerDialog` 생성

마찬가지로 동영상 팝업 시 비동기 `finally`에서 `VideoPlayerController.dispose()`가 호출되던 잠재적 위험을 제거하기 위해, 컨트롤러의 초기화 및 해제를 위젯 수명과 함께 관리하는 `VideoPlayerDialog`를 신설했습니다.

### 3.3 `track_map_screen.dart` 호출부 정리

수동 컨트롤러 생성 및 `finally { dispose(); }` 코드를 전면 제거하고 전용 다이얼로그 정적 메서드로 교체했습니다:

```dart
// 마커 추가
final result = await MarkerInputDialog.show(
  context,
  dialogTitle: '장소 마커 추가',
  initialTitle: '장소 마커',
  titleLabel: '제목',
  submitLabel: '저장',
);

// 마커 수정
final result = await MarkerInputDialog.show(
  context,
  dialogTitle: '마커 수정',
  initialTitle: marker.title,
  initialNote: marker.note,
  initialCategory: marker.category,
  titleLabel: '이름',
  submitLabel: '저장',
);

// 사진 메모
final photoInfo = await PhotoMemoDialog.show(
  context,
  defaultTitle: defaultTitle,
);
```

---

## 4. 검증 결과

1. **단위 및 위젯 테스트 (`test/add_marker_dialog_test.dart`)**:
   - `MarkerInputDialog submits and disposes without error` 통과
   - `PhotoMemoDialog submits and disposes without error` 통과
   - 다이얼로그 입력 후 저장 탭 시 닫힘 애니메이션 종료까지 0개의 예외 발생 검증
2. **전체 테스트 스위트**:
   - 22개 전체 테스트 통과 (`flutter test`: 22/22 passed)
3. **정적 분석**:
   - `flutter analyze`: No issues found! (0 경고, 0 오류)
4. **실기기 빌드 및 배포**:
   - Android debug APK 빌드 완료 (`assembleDebug` 19.9s)
   - 연결된 실기기(`R3CXB0P55MB`)로 스트리밍 설치(`adb install -r`) 및 재실행 완료
