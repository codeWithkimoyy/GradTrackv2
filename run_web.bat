@echo off
title GradTrack Web Launcher
echo ==================================================
echo  Starting GradTrack Web on http://localhost:3000
echo  Ensure http://localhost:3000 is added to:
echo  1. Google Cloud Console - Authorized JavaScript origins
echo  2. Firebase Console - Auth - Authorized domains
echo ==================================================

cd /d "%~dp0frontend"
flutter run -d chrome --web-port=3000
pause
