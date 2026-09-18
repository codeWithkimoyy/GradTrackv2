@echo off
title GradTrack Web Launcher
echo ==================================================
echo  Starting GradTrack Web on http://localhost:8080
echo  Ensure http://localhost:8080 is added to:
echo  1. Google Cloud Console - Authorized JavaScript origins
echo ==================================================
echo  NOTE: The backend API runs on http://localhost:3000
echo  (JavaEase/GradTrack backend must be started separately)
echo ==================================================

cd /d "%~dp0frontend"
flutter run -d chrome --web-port=8080
pause