# Test Open Brush API Script
# This tests the HTTP API calls to Open Brush

Write-Host "Testing Open Brush API Integration" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor DarkGray
Write-Host ""

# Get first device
$devices = & ".\adb.exe" devices 2>&1 | Select-String "device$"
if ($devices.Count -eq 0) {
    Write-Host "ERROR: No devices found!" -ForegroundColor Red
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
    Write-Host ""
    
    # Test API endpoints using concatenation to avoid PowerShell interpolation issues
    $endpoints = @(
        @{Name = "Save New"; Url = ("http://" + $ipAddress + ":40074/api/v1?save.new") },
        @{Name = "Export Current"; Url = ("http://" + $ipAddress + ":40074/api/v1?export.current") },
        @{Name = "New Sketch"; Url = ("http://" + $ipAddress + ":40074/api/v1?new") },
        @{Name = "Env Pistachio"; Url = ("http://" + $ipAddress + ":40074/api/v1?environment.type=pistachio") },
        @{Name = "Env Passthrough"; Url = ("http://" + $ipAddress + ":40074/api/v1?environment.type=passtrough") },
        @{Name = "Custom Command"; Url = ("http://" + $ipAddress + ":40074/api/v1?brush.type=Ink") }
    )
    
    foreach ($endpoint in $endpoints) {
        Write-Host "Testing: $($endpoint.Name)" -ForegroundColor Yellow
        Write-Host "  URL: $($endpoint.Url)" -ForegroundColor Gray
        
        try {
            $response = Invoke-WebRequest -Uri $endpoint.Url -Method Get -TimeoutSec 5 -ErrorAction Stop
            Write-Host "  [OK] Status: $($response.StatusCode)" -ForegroundColor Green
            Write-Host "  [OK] Content: $($response.Content)" -ForegroundColor Green
        }
        catch {
            Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host "====================================" -ForegroundColor DarkGray
    Write-Host "Test completed!" -ForegroundColor Cyan
}
else {
    Write-Host "  Could not get IP address - ensure Wi-Fi is connected" -ForegroundColor Red
}
