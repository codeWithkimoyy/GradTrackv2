# GradTrack - Launch Flutter Web with Fixed Port for Google Sign-In
param (
    [int]$Port = 3000,
    [ValidateSet("chrome", "web-server", "release")]
    [string]$Mode = "chrome"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrontendDir = Join-Path $ScriptDir "frontend"
$BuildWebDir = Join-Path $FrontendDir "build\web"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Starting GradTrack Web on http://localhost:$Port (Mode: $Mode)" -ForegroundColor Green
Write-Host " Ensure http://localhost:$Port is added to:" -ForegroundColor Yellow
Write-Host " 1. Google Cloud Console -> Authorized JavaScript origins" -ForegroundColor Yellow
Write-Host " 2. Firebase Console -> Auth -> Authorized domains (localhost)" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan

if ($Mode -eq "release") {
    if (-not (Test-Path $BuildWebDir)) {
        Write-Host "Building production web bundle..." -ForegroundColor Yellow
        Set-Location -LiteralPath $FrontendDir
        flutter build web --release
    }
    Write-Host "Serving production bundle on http://localhost:$Port..." -ForegroundColor Green
    Start-Process "chrome.exe" "http://localhost:$Port" -ErrorAction SilentlyContinue
    python -m http.server $Port --directory $BuildWebDir
} elseif ($Mode -eq "chrome") {
    Set-Location -LiteralPath $FrontendDir
    flutter run -d chrome --web-port=$Port
} else {
    Write-Host "Note: On web-server mode, press F5 in Chrome to reload changes." -ForegroundColor Yellow
    Start-Process "chrome.exe" "http://localhost:$Port" -ErrorAction SilentlyContinue
    Set-Location -LiteralPath $FrontendDir
    flutter run -d web-server --web-port=$Port
}
