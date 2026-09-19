<#
.SYNOPSIS
    GradTrack - Unified One-Click Launcher for Backend & Frontend.

.DESCRIPTION
    Boots the Node.js MySQL backend API on port 3000, checks database availability,
    verifies environment configurations, and launches the Flutter application.
    Pressing Ctrl+C automatically shuts down both backend and frontend cleanly.

.PARAMETER Device
    The target device/browser to run Flutter on (default: "chrome").
    Options include: "chrome", "edge", "windows", or a connected device ID.

.PARAMETER WebPort
    Port to serve the Flutter Web app on (default: 8080 to prevent collision with backend :3000).

.PARAMETER SkipBackend
    If passed, skips launching the Node.js backend.

.PARAMETER SkipMigrate
    If passed, skips running database migrations.

.EXAMPLE
    .\run_all.ps1
    .\run_all.ps1 -Device windows
    .\run_all.ps1 -Device chrome -WebPort 8080
#>

param(
    [string]$Device = "chrome",
    [int]$WebPort = 8080,
    [switch]$SkipBackend,
    [switch]$SkipMigrate
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $ScriptRoot "backend"
$FrontendDir = Join-Path $ScriptRoot "frontend"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                GRADTRACK UNIFIED RUNNER                    " -ForegroundColor Blue
Write-Host "       Bohol Island State University - Tracer Study        " -ForegroundColor DarkCyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verify Prerequisites
Write-Host "[1/5] Checking tools & dependencies..." -ForegroundColor Yellow

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[-] Node.js is not found in PATH! Please install Node.js 20+." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[-] Flutter SDK is not found in PATH! Please install Flutter." -ForegroundColor Red
    exit 1
}

$nodeVer = (node -v).Trim()
Write-Host "  [OK] Node.js ($nodeVer) detected" -ForegroundColor Green
Write-Host "  [OK] Flutter SDK detected" -ForegroundColor Green

# 2. Verify Environment Config Files
Write-Host "[2/5] Checking environment files..." -ForegroundColor Yellow

$backendEnv = Join-Path $BackendDir ".env"
$backendEnvExample = Join-Path $BackendDir ".env.example"
if ((-not (Test-Path $backendEnv)) -and (Test-Path $backendEnvExample)) {
    Write-Host "  [!] backend/.env not found, creating from .env.example..." -ForegroundColor Yellow
    Copy-Item -Path $backendEnvExample -Destination $backendEnv
}

$frontendEnv = Join-Path $FrontendDir "assets\.env"
$frontendEnvExample = Join-Path $FrontendDir "assets\.env.example"
if ((-not (Test-Path $frontendEnv)) -and (Test-Path $frontendEnvExample)) {
    Write-Host "  [!] frontend/assets/.env not found, creating from .env.example..." -ForegroundColor Yellow
    Copy-Item -Path $frontendEnvExample -Destination $frontendEnv
}

# 3. Check Local MySQL Service (if installed)
Write-Host "[3/5] Checking database services..." -ForegroundColor Yellow
$mysqlServices = Get-Service -Name *wampmysqld*,*mysql*,*mariadb* -ErrorAction SilentlyContinue
foreach ($svc in $mysqlServices) {
    if ($svc.Status -ne "Running") {
        Write-Host "  [!] Starting $($svc.DisplayName)..." -ForegroundColor Yellow
        try {
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            Write-Host "  [OK] Started $($svc.DisplayName)" -ForegroundColor Green
        } catch {
            Write-Host "  [!] Could not start $($svc.Name). Will attempt DB connection anyway." -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  [OK] Service $($svc.DisplayName) is Running" -ForegroundColor Green
    }
}

# Install backend dependencies if node_modules is missing
$backendModules = Join-Path $BackendDir "node_modules"
if (-not (Test-Path $backendModules)) {
    Write-Host "  [!] Installing backend dependencies (npm install)..." -ForegroundColor Yellow
    Push-Location $BackendDir
    try {
        & npm install
    } finally {
        Pop-Location
    }
}

# Run DB Migrations
if (-not $SkipMigrate) {
    Write-Host "  Running database migrations..." -ForegroundColor DarkCyan
    Push-Location $BackendDir
    try {
        & node src/db/migrate.js 2>$null
    } catch {
        Write-Host "  (Notice: Database offline or host pending. Migration deferred.)" -ForegroundColor DarkGray
    } finally {
        Pop-Location
    }
}

# 4. Start Backend Process
$backendProcess = $null
if (-not $SkipBackend) {
    Write-Host "[4/5] Starting Backend API Server on http://localhost:3000..." -ForegroundColor Yellow
    
    $backendProcess = Start-Process -FilePath "node" `
        -ArgumentList "src/server.js" `
        -WorkingDirectory $BackendDir `
        -PassThru `
        -NoNewWindow

    # Poll health check
    $backendReady = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Milliseconds 400
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:3000/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($resp -and ($resp.status -eq "ok")) {
                $backendReady = $true
                break
            }
        } catch {
            # Still waiting for server
        }
    }

    if ($backendReady) {
        Write-Host "  [OK] Backend API is live on http://localhost:3000" -ForegroundColor Green
    } else {
        Write-Host "  [OK] Backend process started (PID: $($backendProcess.Id))." -ForegroundColor Yellow
    }
} else {
    Write-Host "[4/5] Skipping backend (SkipBackend requested)" -ForegroundColor DarkGray
}

# Function to clean up background processes on exit
function Stop-GradTrackServices {
    Write-Host ""
    Write-Host "Stopping GradTrack services..." -ForegroundColor Yellow
    if ($backendProcess -and (-not $backendProcess.HasExited)) {
        try {
            Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Backend API stopped cleanly." -ForegroundColor Green
        } catch {
            # Ignored
        }
    }
    Write-Host "Goodbye Boss Kim!" -ForegroundColor Cyan
}

# 5. Launch Frontend App
Write-Host "[5/5] Launching GradTrack Frontend on '$Device'..." -ForegroundColor Yellow
Push-Location $FrontendDir
try {
    $flutterArgs = @("run", "-d", $Device)
    if (($Device -eq "chrome") -or ($Device -eq "edge") -or ($Device -eq "web-server")) {
        $flutterArgs += "--web-port=$WebPort"
        Write-Host "  Opening web app on http://localhost:$WebPort" -ForegroundColor Cyan
    }

    & flutter $flutterArgs
} finally {
    Pop-Location
    Stop-GradTrackServices
}
