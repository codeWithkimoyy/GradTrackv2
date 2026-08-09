# GradTrack - Launch Flutter Web with Fixed Port for Google Sign-In
param (
    [int]$Port = 3000
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Starting GradTrack Web on http://localhost:$Port" -ForegroundColor Green
Write-Host " Ensure http://localhost:$Port is added to:" -ForegroundColor Yellow
Write-Host " 1. Google Cloud Console -> Authorized JavaScript origins" -ForegroundColor Yellow
Write-Host " 2. Firebase Console -> Auth -> Authorized domains (localhost)" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan

Set-Location -LiteralPath $ScriptDir
flutter run -d chrome --web-port=$Port
