echo "Android build & deploy"
cd /d D:\GIT\GitHub\sanc_tracker

call flutter clean
if errorlevel 1 pause & exit /b 1

call flutter pub get
if errorlevel 1 pause & exit /b 1

call flutter run -d R3CXB0P55MB ^
  --dart-define=SANC_ENV=development ^
  --dart-define=KAKAO_NATIVE_APP_KEY=f55dc1925aa320a11a555036b3d248da

echo "Android build & deploy completed"
