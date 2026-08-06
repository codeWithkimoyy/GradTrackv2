$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.2-stable.zip"
$out = "$env:TEMP\flutter.zip"
$extractTo = "$env:USERPROFILE\flutter"

Write-Output "Starting Flutter SDK download (this may take a while on slow connections)..."
Remove-Item $out -Force -ErrorAction SilentlyContinue

$job = Start-BitsTransfer -Source $url -Destination $out -Asynchronous -Priority Low
do {
    Start-Sleep -Seconds 10
    $j = Get-BitsTransfer -JobId $job.JobId
    $pct = if ($j.BytesTotal -gt 0) { [math]::Round($j.BytesTransferred / $j.BytesTotal * 100, 1) } else { 0 }
    Write-Output "... $pct% ($([math]::Round($j.BytesTransferred/1MB,1))MB transferred)"
} while ($j.JobState -eq "Connecting" -or $j.JobState -eq "Transferring" -or $j.JobState -eq "TransientError")

if ($j.JobState -eq "Transferred") {
    Complete-BitsTransfer -BitsJob $j
    Write-Output "Download complete! Extracting..."
    
    New-Item -ItemType Directory -Path $extractTo -Force | Out-Null
    Expand-Archive -Path $out -DestinationPath $extractTo -Force
    
    $flutterBin = "$extractTo\flutter\bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$flutterBin*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")
    }
    
    Write-Output "Flutter SDK installed at: $extractTo\flutter"
    Write-Output "Run 'flutter doctor' to verify installation"
    Write-Output "A new terminal will be needed for PATH changes to take effect"
} else {
    Write-Output "Download failed with state: $($j.JobState)"
}
