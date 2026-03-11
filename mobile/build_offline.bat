@echo off
cd /d "%~dp0"
flutter build apk --release --target-platform android-arm64 --no-pub
pause

