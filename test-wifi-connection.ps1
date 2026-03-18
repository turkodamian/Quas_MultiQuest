# Test ADB Wi-Fi Connection Script
# This script tests the Wi-Fi connection logic

Write-Host "Testing ADB Wi-Fi Connection Logic" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor DarkGray
Write-Host ""

# Get first USB device
$devices = & ".\adb.exe" devices 2>&1 | Select-String "device$"
if ($devices.Count -eq 0) {
    Write-Host "ERROR: No USB devices found!" -ForegroundColor Red
    exit 1
}

# Extract first device serial
$serial = ($devices[0] -split '\s+')[0]
Write-Host "Found device: $serial" -ForegroundColor Green
Write-Host ""

# Get IP address
Write-Host "Getting IP address..." -ForegroundColor Yellow
$ipOutput = & ".\adb.exe" -s $serial shell ip addr show wlan0 2>&1
$ipString = $ipOutput -join "`n"

if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
    $ipAddress = $Matches[1]
    Write-Host "  IP Address: $ipAddress" -ForegroundColor White
    
    # Enable TCP/IP
    Write-Host ""
    Write-Host "Enabling ADB over Wi-Fi..." -ForegroundColor Yellow
    $tcpipOutput = & ".\adb.exe" -s $serial tcpip 5555 2>&1
    Write-Host "  $tcpipOutput" -ForegroundColor Gray
    Start-Sleep -Seconds 1
    
    # Connect
    Write-Host ""
    $wifiAddress = "$ipAddress" + ":5555"
    Write-Host "Connecting to $wifiAddress..." -ForegroundColor Yellow
    $connectOutput = & ".\adb.exe" connect $wifiAddress 2>&1
    Write-Host "  Result: $connectOutput" -ForegroundColor White
    
    if ($connectOutput -match 'connected to') {
        Write-Host ""
        Write-Host "[SUCCESS] Wi-Fi connection established!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Listing devices:" -ForegroundColor Cyan
        & ".\adb.exe" devices
    }
    else {
        Write-Host ""
        Write-Host "[FAIL] Connection failed" -ForegroundColor Red
    }
}
else {
    Write-Host "  Could not get IP address - ensure Wi-Fi is connected" -ForegroundColor Red
}
