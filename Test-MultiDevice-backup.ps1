# Test-MultiDevice.ps1
# Quick test script to verify multi-device functionality

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor Cyan
Write-Host "           Quas Multi-Device - Device Detection Test" -ForegroundColor Cyan
Write-Host "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor Cyan
Write-Host ""

# Import DeviceManager module
try {
    Import-Module (Join-Path $ScriptDir "Modules\DeviceManager.psm1") -Force
    Write-Host "âœ“ DeviceManager module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "âœ— Failed to load DeviceManager module: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Detecting ADB devices..." -ForegroundColor Yellow
Write-Host ""

# Get devices
$devices = Get-AdbDevices

if ($devices.Count -eq 0) {
    Write-Host "No devices detected!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Ensure devices are connected via USB" -ForegroundColor White
    Write-Host "  2. Enable Developer Mode on your Quest headsets" -ForegroundColor White
    Write-Host "  3. Accept USB debugging authorization on devices" -ForegroundColor White
    Write-Host "  4. Check if ADB drivers are installed" -ForegroundColor White
    Write-Host ""
    Write-Host "Try running: adb devices" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host "Found $($devices.Count) device(s):" -ForegroundColor Green
Write-Host ""

# Display device information
foreach ($device in $devices) {
    Write-Host "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
    Write-Host "Serial:      " -NoNewline -ForegroundColor Yellow
    Write-Host $device.Serial -ForegroundColor White
    
    Write-Host "Status:      " -NoNewline -ForegroundColor Yellow
    $statusColor = if ($device.Status -eq "device") { "Green" } else { "Red" }
    Write-Host $device.Status -ForegroundColor $statusColor
    
    if ($device.Model) {
        Write-Host "Model:       " -NoNewline -ForegroundColor Yellow
        Write-Host $device.Model -ForegroundColor White
    }
    
    if ($device.Product) {
        Write-Host "Product:     " -NoNewline -ForegroundColor Yellow
        Write-Host $device.Product -ForegroundColor White
    }
    
    if ($device.Device) {
        Write-Host "Device:      " -NoNewline -ForegroundColor Yellow
        Write-Host $device.Device -ForegroundColor White
    }
    
    # Get detailed info
    Write-Host ""
    Write-Host "Getting detailed information..." -ForegroundColor Gray
    
    try {
        $info = Get-DeviceInfo -Serial $device.Serial
        
        if ($info) {
            if ($info.Manufacturer) {
                Write-Host "Manufacturer:" -NoNewline -ForegroundColor Yellow
                Write-Host " $($info.Manufacturer)" -ForegroundColor White
            }
            
            if ($info.Model) {
                Write-Host "Model Name:  " -NoNewline -ForegroundColor Yellow
                Write-Host $info.Model -ForegroundColor White
            }
            
            if ($info.AndroidVersion) {
                Write-Host "Android:     " -NoNewline -ForegroundColor Yellow
                Write-Host $info.AndroidVersion -ForegroundColor White
            }
            
            if ($info.BuildNumber) {
                Write-Host "Build:       " -NoNewline -ForegroundColor Yellow
                Write-Host $info.BuildNumber -ForegroundColor White
            }
            
            if ($info.IPAddress) {
                Write-Host "IP Address:  " -NoNewline -ForegroundColor Yellow
                Write-Host $info.IPAddress -ForegroundColor White
            }
            
            if ($info.BatteryLevel) {
                Write-Host "Battery:     " -NoNewline -ForegroundColor Yellow
                
                # Color code battery level
                $batteryNum = [int]($info.BatteryLevel -replace '%', '')
                $batteryColor = if ($batteryNum -ge 50) { "Green" } elseif ($batteryNum -ge 20) { "Yellow" } else { "Red" }
                Write-Host $info.BatteryLevel -ForegroundColor $batteryColor
            }
        }
    }
    catch {
        Write-Host "Could not retrieve detailed info: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Device detection test completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run .\Quas-MultiDevice.ps1 to start the multi-device manager" -ForegroundColor White
Write-Host "  2. Select one or more devices from the menu" -ForegroundColor White
Write-Host "  3. Execute commands on selected devices" -ForegroundColor White
Write-Host ""
Write-Host "All commands and responses will be logged to:" -ForegroundColor Yellow
$logPath = "Logs\quas-multi-$(Get-Date -Format 'yyyy-MM-dd').log"
Write-Host "  $logPath" -ForegroundColor Gray
Write-Host ""

