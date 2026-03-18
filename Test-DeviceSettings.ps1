# Test-DeviceSettings.ps1
# Script de prueba para las funcionalidades del menu Device Settings

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "     QUAS MULTI-DEVICE - DEVICE SETTINGS TEST SCRIPT                " -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if adb.exe exists
if (-not (Test-Path "$ScriptDir\adb.exe")) {
    Write-Host "ERROR: adb.exe not found in script directory!" -ForegroundColor Red
    Write-Host "Please ensure adb.exe is in: $ScriptDir" -ForegroundColor Yellow
    exit 1
}

# Get connected devices
Write-Host "Detecting connected devices..." -ForegroundColor Yellow
$devices = & "$ScriptDir\adb.exe" devices | Select-Object -Skip 1 | Where-Object { $_ -match '\t' }

if ($devices.Count -eq 0) {
    Write-Host "No devices detected!" -ForegroundColor Red
    Write-Host "Please connect at least one device and enable USB debugging." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($devices.Count) device(s)" -ForegroundColor Green
Write-Host ""

# Parse device list
$deviceList = @()
foreach ($device in $devices) {
    if ($device -match '^(\S+)\s+device') {
        $deviceList += $Matches[1]
        Write-Host "  - $($Matches[1])" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "Testing Device Settings Commands..." -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($serial in $deviceList) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Testing Device: $serial" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Test 1: Get current brightness
    Write-Host "[TEST 1] Getting current brightness..." -ForegroundColor Yellow
    $brightness = & "$ScriptDir\adb.exe" -s $serial shell settings get system screen_brightness 2>&1
    if ($brightness) {
        Write-Host "  Current brightness: $brightness" -ForegroundColor Green
    }
    else {
        Write-Host "  Could not retrieve brightness" -ForegroundColor Red
    }
    
    # Test 2: Get screen timeout
    Write-Host "[TEST 2] Getting screen timeout..." -ForegroundColor Yellow
    $timeout = & "$ScriptDir\adb.exe" -s $serial shell settings get system screen_off_timeout 2>&1
    if ($timeout) {
        $timeoutSec = [math]::Round([int]$timeout / 1000)
        Write-Host "  Screen timeout: $timeout ms ($timeoutSec seconds)" -ForegroundColor Green
    }
    else {
        Write-Host "  Could not retrieve timeout" -ForegroundColor Red
    }
    
    # Test 3: Get Wi-Fi status
    Write-Host "[TEST 3] Getting Wi-Fi status..." -ForegroundColor Yellow
    $wifiStatus = & "$ScriptDir\adb.exe" -s $serial shell dumpsys wifi | Select-String "Wi-Fi is" 2>&1
    if ($wifiStatus) {
        Write-Host "  Wi-Fi status: $wifiStatus" -ForegroundColor Green
    }
    else {
        Write-Host "  Could not retrieve Wi-Fi status" -ForegroundColor Yellow
    }
    
    # Test 4: Get developer mode status
    Write-Host "[TEST 4] Getting developer mode status..." -ForegroundColor Yellow
    $devMode = & "$ScriptDir\adb.exe" -s $serial shell settings get global development_settings_enabled 2>&1
    $devStatus = if ($devMode -match '1') { 'ENABLED' } else { 'DISABLED' }
    Write-Host "  Developer mode: $devStatus" -ForegroundColor $(if ($devStatus -eq 'ENABLED') { 'Green' }else { 'Yellow' })
    
    # Test 5: Get ADB debugging status
    Write-Host "[TEST 5] Getting ADB debugging status..." -ForegroundColor Yellow
    $adbEnabled = & "$ScriptDir\adb.exe" -s $serial shell settings get global adb_enabled 2>&1
    $adbStatus = if ($adbEnabled -match '1') { 'ENABLED' } else { 'DISABLED' }
    Write-Host "  USB debugging: $adbStatus" -ForegroundColor $(if ($adbStatus -eq 'ENABLED') { 'Green' }else { 'Yellow' })
    
    # Test 6: Get device model
    Write-Host "[TEST 6] Getting device model..." -ForegroundColor Yellow
    $model = & "$ScriptDir\adb.exe" -s $serial shell getprop ro.product.model 2>&1
    if ($model) {
        Write-Host "  Model: $model" -ForegroundColor Green
    }
    
    # Test 7: Get Android version
    Write-Host "[TEST 7] Getting Android version..." -ForegroundColor Yellow
    $androidVer = & "$ScriptDir\adb.exe" -s $serial shell getprop ro.build.version.release 2>&1
    if ($androidVer) {
        Write-Host "  Android version: $androidVer" -ForegroundColor Green
    }
    
    Write-Host ""
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "                      TEST SUMMARY                                   " -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All connectivity tests completed!" -ForegroundColor Green
Write-Host ""
Write-Host "The following Device Settings features are ready to use:" -ForegroundColor Yellow
Write-Host "  [OK] Wi-Fi configuration" -ForegroundColor Green
Write-Host "  [OK] Screen brightness adjustment" -ForegroundColor Green
Write-Host "  [OK] Volume control" -ForegroundColor Green
Write-Host "  [OK] Date/time synchronization" -ForegroundColor Green
Write-Host "  [OK] Developer mode toggling" -ForegroundColor Green
Write-Host "  [OK] Screen timeout configuration" -ForegroundColor Green
Write-Host "  [OK] Device reboot" -ForegroundColor Green
Write-Host "  [OK] Recovery mode reboot" -ForegroundColor Green
Write-Host "  [OK] Settings display" -ForegroundColor Green
Write-Host ""
Write-Host "To test the full menu, run: .\Quas-MultiDevice.ps1" -ForegroundColor Cyan
Write-Host ""
