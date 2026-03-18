# DeviceManager.psm1
# Module for managing multiple ADB devices

$script:AdbPath = Join-Path $PSScriptRoot "..\adb.exe"

<#
.SYNOPSIS
    Gets all connected ADB devices
.DESCRIPTION
    Enumerates all devices visible to ADB and returns their details
.OUTPUTS
    Array of device objects with Serial, Status, Model, and other properties
#>
function Get-AdbDevices {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Detecting ADB devices..."
        
        # Get raw device list
        $output = & $script:AdbPath devices -l 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "ADB command failed with exit code $LASTEXITCODE"
            return @()
        }
        
        $devices = @()
        $lines = $output -split "`n" | Where-Object { $_ -match '\S' }
        
        foreach ($line in $lines) {
            # Skip header line
            if ($line -match "^List of devices") { continue }
            
            # Parse device line: serial status model:... product:... device:...
            if ($line -match '^(\S+)\s+(\S+)(.*)') {
                $serial = $Matches[1]
                $status = $Matches[2]
                $details = $Matches[3]
                
                # Extract additional properties
                $model = ""
                $product = ""
                $device = ""
                $transport_id = ""
                
                if ($details -match 'model:(\S+)') { $model = $Matches[1] }
                if ($details -match 'product:(\S+)') { $product = $Matches[1] }
                if ($details -match 'device:(\S+)') { $device = $Matches[1] }
                if ($details -match 'transport_id:(\S+)') { $transport_id = $Matches[1] }
                
                $deviceObj = [PSCustomObject]@{
                    Serial      = $serial
                    Status      = $status
                    Model       = $model
                    Product     = $product
                    Device      = $device
                    TransportId = $transport_id
                    Alias       = ""
                    LastSeen    = Get-Date
                }
                
                $devices += $deviceObj
            }
        }
        
        Write-Verbose "Found $($devices.Count) device(s)"
        return $devices
    }
    catch {
        Write-Error "Error detecting devices: $_"
        return @()
    }
}

<#
.SYNOPSIS
    Gets detailed information for a specific device
.PARAMETER Serial
    Device serial number
.OUTPUTS
    Hashtable with device properties from getprop
#>
function Get-DeviceInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Serial
    )
    
    try {
        Write-Verbose "Getting device info for $Serial"
        
        # Get device properties
        $output = & $script:AdbPath -s $Serial shell getprop 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to get device properties for $Serial"
            return $null
        }
        
        $props = @{}
        $lines = $output -split "`n"
        
        foreach ($line in $lines) {
            if ($line -match '^\[([^\]]+)\]:\s*\[([^\]]*)\]') {
                $key = $Matches[1]
                $value = $Matches[2]
                $props[$key] = $value
            }
        }
        
        # Extract commonly used properties
        $deviceInfo = @{
            Serial         = $Serial
            Manufacturer   = $props['ro.product.manufacturer']
            Model          = $props['ro.product.model']
            Device         = $props['ro.product.device']
            AndroidVersion = $props['ro.build.version.release']
            BuildNumber    = $props['ro.build.display.id']
            SDKVersion     = $props['ro.build.version.sdk']
            SerialNumber   = $props['ro.serialno']
            Brand          = $props['ro.product.brand']
            IPAddress      = ""
            BatteryLevel   = ""
            AllProperties  = $props
        }
        
        # Get battery level
        try {
            $battOutput = & $script:AdbPath -s $Serial shell dumpsys battery 2>&1
            $battOutput = $battOutput -join "`n"
            if ($battOutput -match 'level:\s*(\d+)') {
                $deviceInfo.BatteryLevel = $Matches[1] + "%"
            }
        }
        catch {
            # Battery info not available
        }
        
        # Get IP address
        try {
            $ipOutput = & $script:AdbPath -s $Serial shell "ip addr show wlan0 | grep inet" 2>&1
            $ipOutput = $ipOutput -join "`n"
            if ($ipOutput -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                $deviceInfo.IPAddress = $Matches[1]
            }
        }
        catch {
            # IP not available
        }
        
        return $deviceInfo
    }
    catch {
        Write-Error "Error getting device info for ${Serial}: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Tests if a device is still connected
.PARAMETER Serial
    Device serial number
.OUTPUTS
    Boolean indicating if device is accessible
#>
function Test-DeviceConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Serial
    )
    
    try {
        $devices = Get-AdbDevices
        return ($devices | Where-Object { $_.Serial -eq $Serial -and $_.Status -eq 'device' }) -ne $null
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Groups devices by model
.PARAMETER Devices
    Array of device objects
.OUTPUTS
    Hashtable with model names as keys and device arrays as values
#>
function Group-DevicesByModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices
    )
    
    $grouped = @{}
    
    foreach ($device in $Devices) {
        $model = if ($device.Model) { $device.Model } else { "Unknown" }
        
        if (-not $grouped.ContainsKey($model)) {
            $grouped[$model] = @()
        }
        
        $grouped[$model] += $device
    }
    
    return $grouped
}

<#
.SYNOPSIS
    Restarts ADB server
#>
function Restart-AdbServer {
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "Stopping ADB server..." -ForegroundColor Yellow
        & $script:AdbPath kill-server 2>&1 | Out-Null
        
        Start-Sleep -Seconds 1
        
        Write-Host "Starting ADB server..." -ForegroundColor Yellow
        & $script:AdbPath start-server 2>&1 | Out-Null
        
        Write-Host "ADB server restarted successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to restart ADB server: $_"
        return $false
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Get-AdbDevices',
    'Get-DeviceInfo',
    'Test-DeviceConnection',
    'Group-DevicesByModel',
    'Restart-AdbServer'
)
