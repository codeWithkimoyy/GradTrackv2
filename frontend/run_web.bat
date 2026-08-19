@echo off
title GradTrack Web Launcher
echo ==================================================
echo  Starting GradTrack Web on http://localhost:3000
echo  Ensure http://localhost:3000 is added to:
echo  1. Google Cloud Console - Authorized JavaScript origins
echo  2. Firebase Console - Auth - Authorized domains
echo ==================================================

cd /d "%~dp0"
where flutter >nul 2>nul
if %errorlevel%==0 (
	flutter run -d chrome --web-port=3000
) else if exist "%USERPROFILE%\flutter\flutter\bin\flutter.bat" (
	"%USERPROFILE%\flutter\flutter\bin\flutter.bat" run -d chrome --web-port=3000
) else (
	echo Flutter command not found. Install Flutter or add it to PATH.
	echo Expected fallback: %USERPROFILE%\flutter\flutter\bin\flutter.bat
	pause
	exit /b 1
)
pause
