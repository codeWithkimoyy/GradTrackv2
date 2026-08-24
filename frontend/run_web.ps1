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
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -ne $flutterCmd) {
    & flutter run -d chrome --web-port=$Port
    exit $LASTEXITCODE
}

$fallbackFlutter = Join-Path $env:USERPROFILE "flutter\flutter\bin\flutter.bat"
if (Test-Path $fallbackFlutter) {
    & $fallbackFlutter run -d chrome --web-port=$Port
    exit $LASTEXITCODE
}

Write-Error "Flutter command not found. Install Flutter or add it to PATH. Expected fallback: $fallbackFlutter"
exit 1
