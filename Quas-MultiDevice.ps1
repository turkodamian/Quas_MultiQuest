# Quas-MultiDevice.ps1
# Main script for managing multiple ADB devices simultaneously
# Author: Enhanced version based on original Quas by Varset
# Version: 1.0.0

param(
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

# Set error action preference
$ErrorActionPreference = 'Continue'

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import modules
Import-Module (Join-Path $ScriptDir 'Modules\DeviceManager.psm1') -Force
Import-Module (Join-Path $ScriptDir 'Modules\CommandExecutor.psm1') -Force
Import-Module (Join-Path $ScriptDir 'Modules\UIComponents.psm1') -Force

# Configuration file path
$ConfigPath = Join-Path $ScriptDir 'Config'
$ConfigFile = Join-Path $ConfigPath 'devices.json'

# Ensure config directory exists
if (-not (Test-Path $ConfigPath)) {
    New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
}

# Global variables
$script:SelectedDevices = @()
$script:AllDevices = @()
$script:DeviceConfig = $null

function Load-Configuration {
    if (Test-Path $ConfigFile) {
        try {
            $script:DeviceConfig = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            Write-Log -Message "Configuration loaded from $ConfigFile" -Level INFO
        }
        catch {
            Write-Log -Message "Error loading configuration: $_" -Level WARNING
            Initialize-Configuration
        }
    }
    else {
        Initialize-Configuration
    }
}

function Initialize-Configuration {
    $script:DeviceConfig = @{
        devices     = @()
        preferences = @{
            defaultExecutionMode = 'parallel'
            maxParallelJobs      = 5
            commandTimeout       = 300
            autoRefreshDevices   = $true
        }
        lastUpdated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    Save-Configuration
}

function Save-Configuration {
    try {
        $script:DeviceConfig.lastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $script:DeviceConfig | ConvertTo-Json -Depth 5 | Out-File $ConfigFile -Encoding UTF8
        Write-Log -Message "Configuration saved to $ConfigFile" -Level INFO
    }
    catch {
        Write-Log -Message "Error saving configuration: $_" -Level ERROR
    }
}

function Update-DeviceAlias {
    param(
        [string]$Serial,
        [string]$Alias,
        [string]$CustomNumber = '',
        [string]$Model = '',
        [string]$Notes = ''
    )
    
    $existingDevice = $script:DeviceConfig.devices | Where-Object { $_.serial -eq $Serial }
    
    if ($existingDevice) {
        $existingDevice.alias = $Alias
        $existingDevice.lastSeen = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        
        if ($CustomNumber) { $existingDevice.customNumber = $CustomNumber }
        if ($Model) { $existingDevice.model = $Model }
        if ($Notes) { $existingDevice.notes = $Notes }
    }
    else {
        $newDevice = @{
            serial       = $Serial
            alias        = $Alias
            customNumber = $CustomNumber
            model        = $Model
            notes        = $Notes
            lastSeen     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            firstSeen    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        $script:DeviceConfig.devices += $newDevice
    }
    
    Save-Configuration
}

function Get-DeviceAlias {
    param([string]$Serial)
    
    $device = $script:DeviceConfig.devices | Where-Object { $_.serial -eq $Serial }
    if ($device) {
        return $device.alias
    }
    return ''
}

function Refresh-Devices {
    Write-Log -Message 'Refreshing device list...' -Level INFO
    
    $script:AllDevices = Get-AdbDevices
    
    # Apply aliases from configuration
    foreach ($device in $script:AllDevices) {
        $alias = Get-DeviceAlias -Serial $device.Serial
        if ($alias) {
            $device.Alias = $alias
        }
    }
    
    Write-Log -Message "Found $($script:AllDevices.Count) device(s)" -Level SUCCESS
    return $script:AllDevices
}

function Show-ScreenshotMediaMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '              SCREENSHOT & MEDIA MANAGEMENT                          ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Create Screenshot (single)' -ForegroundColor White
    Write-Host '  [2] Create Screenshots (series with delay)' -ForegroundColor White
    Write-Host '  [3] Copy Screenshots from devices to PC' -ForegroundColor White
    Write-Host '  [4] Copy Videos from devices to PC' -ForegroundColor White
    Write-Host '  [5] Copy All Media from devices to PC' -ForegroundColor White
    Write-Host '  [6] Send file to devices' -ForegroundColor White
    Write-Host '  [7] Delete file from devices' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell screencap -p /sdcard/screenshot_$timestamp.png" -Description 'Create screenshot'
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '2' {
            Write-Host 'Enter delay between screenshots (seconds): ' -NoNewline -ForegroundColor Yellow
            $delay = Read-Host
            Write-Host 'Enter number of screenshots: ' -NoNewline -ForegroundColor Yellow
            $count = Read-Host
            
            for ($i = 1; $i -le $count; $i++) {
                Write-Host "`nCapturing screenshot $i of $count..." -ForegroundColor Yellow
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell screencap -p /sdcard/screenshot_$timestamp.png" -Description "Screenshot $i"
                if ($i -lt $count) {
                    Start-Sleep -Seconds $delay
                }
            }
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '3' {
            foreach ($serial in $SelectedDevices) {
                Write-Host "`nCopying screenshots from device: $serial" -ForegroundColor Yellow
                $timestamp = Get-Date -Format 'yyyy-MM-dd'
                $destDir = Join-Path $ScriptDir "Screenshots\$serial\$timestamp"
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                
                & "$ScriptDir\adb.exe" -s $serial pull /sdcard/DCIM/Screenshots $destDir
                Write-Host "Screenshots copied to: $destDir" -ForegroundColor Green
            }
            Wait-UserInput
        }
        '4' {
            foreach ($serial in $SelectedDevices) {
                Write-Host "`nCopying videos from device: $serial" -ForegroundColor Yellow
                $timestamp = Get-Date -Format 'yyyy-MM-dd'
                $destDir = Join-Path $ScriptDir "Videos\$serial\$timestamp"
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                
                & "$ScriptDir\adb.exe" -s $serial pull /sdcard/DCIM/Videoshots $destDir
                Write-Host "Videos copied to: $destDir" -ForegroundColor Green
            }
            Wait-UserInput
        }
        '5' {
            foreach ($serial in $SelectedDevices) {
                Write-Host "`nCopying all media from device: $serial" -ForegroundColor Yellow
                $timestamp = Get-Date -Format 'yyyy-MM-dd'
                $destDir = Join-Path $ScriptDir "Media\$serial\$timestamp"
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                
                & "$ScriptDir\adb.exe" -s $serial pull /sdcard/DCIM $destDir
                Write-Host "Media copied to: $destDir" -ForegroundColor Green
            }
            Wait-UserInput
        }
        '6' {
            Write-Host 'Enter full path to file to send: ' -NoNewline -ForegroundColor Yellow
            $filePath = Read-Host
            
            if (Test-Path $filePath) {
                Write-Host 'Destination on device - example /sdcard/Download/' -NoNewline -ForegroundColor Yellow
                $destPath = Read-Host
                
                Write-Host ''
                Write-Host 'Sending file to devices in parallel...' -ForegroundColor Cyan
                Write-Host ''
                
                $jobs = @()
                foreach ($serial in $SelectedDevices) {
                    Write-Host "Starting transfer to $serial..." -ForegroundColor Yellow
                    
                    # Start parallel job for each device
                    $job = Start-Job -ScriptBlock {
                        param($AdbPath, $Serial, $FilePath, $DestPath)
                        & $AdbPath -s $Serial push $FilePath $DestPath 2>&1
                    } -ArgumentList "$ScriptDir\adb.exe", $serial, $filePath, $destPath
                    
                    $jobs += @{Serial = $serial; Job = $job }
                }
                
                Write-Host ''
                Write-Host 'Waiting for transfers to complete...' -ForegroundColor Yellow
                Write-Host ''
                
                # Wait for all jobs and show results
                $successCount = 0
                $failCount = 0
                
                foreach ($jobInfo in $jobs) {
                    $result = Receive-Job -Job $jobInfo.Job -Wait
                    $exitCode = $jobInfo.Job.State
                    
                    Write-Host "Device: $($jobInfo.Serial)" -ForegroundColor Cyan
                    if ($exitCode -eq 'Completed') {
                        Write-Host "  [OK] Transfer completed" -ForegroundColor Green
                        $successCount++
                    }
                    else {
                        Write-Host "  [FAIL] Transfer failed" -ForegroundColor Red
                        $failCount++
                    }
                    
                    # Show output if any
                    if ($result) {
                        Write-Host "  Output: $result" -ForegroundColor Gray
                    }
                    
                    # Clean up job
                    Remove-Job -Job $jobInfo.Job
                    Write-Host ''
                }
                
                Write-Host '=====================================================================' -ForegroundColor DarkGray
                Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
                Write-Host ''
                
                Wait-UserInput
            }
            else {
                Write-Host 'File not found!' -ForegroundColor Red
                Wait-UserInput
            }
        }
        '7' {
            # Delete file from devices
            Write-Host ''
            Write-Host 'Enter file path on device (e.g., /sdcard/Download/file.txt): ' -NoNewline -ForegroundColor Yellow
            $filePath = Read-Host
            
            if ($filePath) {
                Write-Host ''
                Write-Host 'WARNING: This will delete the file from ALL selected devices!' -ForegroundColor Red
                Write-Host 'File to delete: ' -NoNewline -ForegroundColor Yellow
                Write-Host $filePath -ForegroundColor White
                Write-Host ''
                Write-Host 'Are you sure? (yes/no): ' -NoNewline -ForegroundColor Yellow
                $confirmation = Read-Host
                
                if ($confirmation -eq 'yes') {
                    Write-Host ''
                    Write-Host 'Deleting file from devices in parallel...' -ForegroundColor Cyan
                    Write-Host ''
                    
                    $jobs = @()
                    foreach ($serial in $SelectedDevices) {
                        Write-Host "Starting deletion on $serial..." -ForegroundColor Yellow
                        
                        # Start parallel job for each device
                        $job = Start-Job -ScriptBlock {
                            param($AdbPath, $Serial, $FilePath)
                            & $AdbPath -s $Serial shell rm -f $FilePath 2>&1
                        } -ArgumentList "$ScriptDir\adb.exe", $serial, $filePath
                        
                        $jobs += @{Serial = $serial; Job = $job }
                    }
                    
                    Write-Host ''
                    Write-Host 'Waiting for deletions to complete...' -ForegroundColor Yellow
                    Write-Host ''
                    
                    # Wait for all jobs and show results
                    $successCount = 0
                    $failCount = 0
                    
                    foreach ($jobInfo in $jobs) {
                        $result = Receive-Job -Job $jobInfo.Job -Wait
                        $exitCode = $jobInfo.Job.State
                        
                        Write-Host "Device: $($jobInfo.Serial)" -ForegroundColor Cyan
                        if ($exitCode -eq 'Completed' -and -not $result) {
                            Write-Host "  [OK] File deleted" -ForegroundColor Green
                            $successCount++
                        }
                        else {
                            Write-Host "  [FAIL] Deletion failed" -ForegroundColor Red
                            $failCount++
                            if ($result) {
                                Write-Host "  Error: $result" -ForegroundColor DarkRed
                            }
                        }
                        
                        # Clean up job
                        Remove-Job -Job $jobInfo.Job
                        Write-Host ''
                    }
                    
                    Write-Host '=====================================================================' -ForegroundColor DarkGray
                    Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
                    Write-Host ''
                }
                else {
                    Write-Host ''
                    Write-Host 'Operation cancelled.' -ForegroundColor Yellow
                    Write-Host ''
                }
            }
            else {
                Write-Host ''
                Write-Host 'No file path specified.' -ForegroundColor Red
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-ScreenshotMediaMenu -SelectedDevices $SelectedDevices
}

function Show-AppManagementMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                  APPLICATION MANAGEMENT                             ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Install APK from PC' -ForegroundColor White
    Write-Host '  [2] Uninstall app (by package name)' -ForegroundColor White
    Write-Host '  [3] List installed apps' -ForegroundColor White
    Write-Host '  [4] Clear app data and cache' -ForegroundColor White
    Write-Host '  [5] Stop app' -ForegroundColor White
    Write-Host '  [6] Start app' -ForegroundColor White
    Write-Host '  [7] Enable app' -ForegroundColor White
    Write-Host '  [8] Disable app' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            Write-Host 'Enter full path to APK file: ' -NoNewline -ForegroundColor Yellow
            $apkPath = Read-Host
            
            if (Test-Path $apkPath) {
                $results = @()
                foreach ($serial in $SelectedDevices) {
                    Write-Host "`nInstalling on $serial..." -ForegroundColor Yellow
                    $output = & "$ScriptDir\adb.exe" -s $serial install -r "$apkPath" 2>&1
                    $success = $output -match 'Success'
                    
                    $results += [PSCustomObject]@{
                        Serial      = $serial
                        Success     = $success
                        Output      = $output -join "`n"
                        Description = 'Install APK'
                    }
                    
                    if ($success) {
                        Write-Host 'OK - Installed successfully' -ForegroundColor Green
                    }
                    else {
                        Write-Host 'ERROR - Installation failed' -ForegroundColor Red
                    }
                }
                Show-ResultsSummary -Results $results
                Wait-UserInput
            }
            else {
                Write-Host 'APK file not found!' -ForegroundColor Red
                Wait-UserInput
            }
        }
        '2' {
            Write-Host 'Enter package name to uninstall: ' -NoNewline -ForegroundColor Yellow
            $package = Read-Host
            
            if (Show-ConfirmationDialog -Message "Uninstall $package from $($SelectedDevices.Count) device(s)?") {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "uninstall $package" -Description "Uninstall $package"
                Show-ResultsSummary -Results $results
                Wait-UserInput
            }
        }
        '3' {
            Write-Host "`nInstalled packages:" -ForegroundColor Yellow
            foreach ($serial in $SelectedDevices) {
                Write-Host "`n--- Device: $serial ---" -ForegroundColor Cyan
                & "$ScriptDir\adb.exe" -s $serial shell pm list packages -3
            }
            Wait-UserInput
        }
        '4' {
            Write-Host 'Enter package name: ' -NoNewline -ForegroundColor Yellow
            $package = Read-Host
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell pm clear $package" -Description "Clear data for $package"
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '5' {
            Write-Host 'Enter package name: ' -NoNewline -ForegroundColor Yellow
            $package = Read-Host
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell am force-stop $package" -Description "Stop $package"
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '6' {
            Write-Host 'Enter package name: ' -NoNewline -ForegroundColor Yellow
            $package = Read-Host
            Write-Host 'Enter activity name (or leave blank for main): ' -NoNewline -ForegroundColor Yellow
            $activity = Read-Host
            
            $cmd = if ($activity) { "shell am start -n $package/$activity" } else { "shell monkey -p $package 1" }
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command $cmd -Description "Start $package"
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '7' {
            Write-Host 'Enter package name: ' -NoNewline -ForegroundColor Yellow
            $package = Read-Host
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell pm enable $package" -Description "Enable $package"
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '8' {
            Write-Host 'Enter package name: ' -NoNewline -ForegroundColor Yellow
            $package = Read-Host
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell pm disable-user $package" -Description "Disable $package"
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-AppManagementMenu -SelectedDevices $SelectedDevices
}

function Show-SystemInfoMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                     SYSTEM INFORMATION                              ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Show device info (model, Android version, etc.)' -ForegroundColor White
    Write-Host '  [2] Show battery status' -ForegroundColor White
    Write-Host '  [3] Show storage info' -ForegroundColor White
    Write-Host '  [4] Show IP address' -ForegroundColor White
    Write-Host '  [5] Show all properties (getprop)' -ForegroundColor White
    Write-Host '  [6] Export device info to file' -ForegroundColor White
    Write-Host '  [7] Show controller battery status' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            foreach ($serial in $SelectedDevices) {
                Write-Host "`n--- Device: $serial ---" -ForegroundColor Cyan
                $info = Get-DeviceInfo -Serial $serial
                if ($info) {
                    Write-Host "Manufacturer: $($info.Manufacturer)" -ForegroundColor White
                    Write-Host "Model: $($info.Model)" -ForegroundColor White
                    Write-Host "Android Version: $($info.AndroidVersion)" -ForegroundColor White
                    Write-Host "Build: $($info.BuildNumber)" -ForegroundColor White
                    Write-Host "IP Address: $($info.IPAddress)" -ForegroundColor White
                    Write-Host "Battery: $($info.BatteryLevel)" -ForegroundColor White
                }
            }
            Wait-UserInput
        }
        '2' {
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell dumpsys battery' -Description 'Battery status'
            foreach ($result in $results) {
                Write-Host "`n--- Device: $($result.Serial) ---" -ForegroundColor Cyan
                Write-Host $result.Output -ForegroundColor Gray
            }
            Wait-UserInput
        }
        '3' {
            $cmd = 'shell df /data /sdcard'
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command $cmd -Description 'Storage info'
            foreach ($result in $results) {
                Write-Host "`n--- Device: $($result.Serial) ---" -ForegroundColor Cyan
                Write-Host $result.Output -ForegroundColor Gray
            }
            Wait-UserInput
        }
        '4' {
            $cmd = 'shell ip addr show wlan0'
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command $cmd -Description 'IP address'
            foreach ($result in $results) {
                Write-Host "`n--- Device: $($result.Serial) ---" -ForegroundColor Cyan
                if ($result.Output -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    Write-Host "IP Address: $($Matches[1])" -ForegroundColor Green
                }
                else {
                    Write-Host 'IP not found' -ForegroundColor Yellow
                }
            }
            Wait-UserInput
        }
        '5' {
            Write-Host "`nRetrieving properties from all devices..." -ForegroundColor Yellow
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell getprop' -Description 'Get all properties'
            
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            $outputDir = Join-Path $ScriptDir "DeviceInfo\$timestamp"
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            
            foreach ($result in $results) {
                $fileName = "$($result.Serial)_getprop.txt"
                $filePath = Join-Path $outputDir $fileName
                $result.Output | Out-File -FilePath $filePath -Encoding UTF8
                Write-Host "Saved: $filePath" -ForegroundColor Green
            }
            Wait-UserInput
        }
        '6' {
            Write-Host "`nExporting device information..." -ForegroundColor Yellow
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            $outputDir = Join-Path $ScriptDir "DeviceInfo\$timestamp"
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing: $serial" -ForegroundColor Yellow
                $info = Get-DeviceInfo -Serial $serial
                
                if ($info) {
                    $fileName = "$serial-info.json"
                    $filePath = Join-Path $outputDir $fileName
                    $info | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
                    Write-Host "OK - Saved: $filePath" -ForegroundColor Green
                }
            }
            Wait-UserInput
        }
        '7' {
            # Controller Battery Status
            Write-Host ''
            Write-Host 'Controller Battery Status' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Device: $serial" -ForegroundColor Cyan
                Write-Host '---------------------------------------------------------------------' -ForegroundColor DarkGray
                
                # Get controller info from OVRRemoteService
                $controllerInfo = & "$ScriptDir\adb.exe" -s $serial shell dumpsys OVRRemoteService 2>&1
                $controllerOutput = $controllerInfo -join "`n"
                
                # Parse battery levels for left and right controllers
                $leftBattery = 'N/A'
                $rightBattery = 'N/A'
                $leftConnected = $false
                $rightConnected = $false
                
                # Look for battery percentage patterns
                if ($controllerOutput -match 'Left.*?battery.*?(\d+)%') {
                    $leftBattery = $Matches[1] + '%'
                    $leftConnected = $true
                }
                elseif ($controllerOutput -match 'remote0.*?battery.*?(\d+)%') {
                    $leftBattery = $Matches[1] + '%'
                    $leftConnected = $true
                }
                
                if ($controllerOutput -match 'Right.*?battery.*?(\d+)%') {
                    $rightBattery = $Matches[1] + '%'
                    $rightConnected = $true
                }
                elseif ($controllerOutput -match 'remote1.*?battery.*?(\d+)%') {
                    $rightBattery = $Matches[1] + '%'
                    $rightConnected = $true
                }
                
                # Display results
                Write-Host '  Left Controller:  ' -NoNewline -ForegroundColor White
                if ($leftConnected) {
                    $battNum = [int]($leftBattery -replace '%', '')
                    $color = if ($battNum -ge 50) { 'Green' } elseif ($battNum -ge 20) { 'Yellow' } else { 'Red' }
                    Write-Host "$leftBattery" -ForegroundColor $color
                }
                else {
                    Write-Host 'Not Connected' -ForegroundColor DarkGray
                }
                
                Write-Host '  Right Controller: ' -NoNewline -ForegroundColor White
                if ($rightConnected) {
                    $battNum = [int]($rightBattery -replace '%', '')
                    $color = if ($battNum -ge 50) { 'Green' } elseif ($battNum -ge 20) { 'Yellow' } else { 'Red' }
                    Write-Host "$rightBattery" -ForegroundColor $color
                }
                else {
                    Write-Host 'Not Connected' -ForegroundColor DarkGray
                }
                
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-SystemInfoMenu -SelectedDevices $SelectedDevices
}

function Show-DeviceSettingsMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                       DEVICE SETTINGS                               ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Configure Wi-Fi (enable/disable/status)' -ForegroundColor White
    Write-Host '  [2] Connect to custom Wi-Fi network' -ForegroundColor White
    Write-Host '  [3] Set screen brightness' -ForegroundColor White
    Write-Host '  [4] Set volume level' -ForegroundColor White
    Write-Host '  [5] Set date and time' -ForegroundColor White
    Write-Host '  [6] Enable/Disable Developer mode' -ForegroundColor White
    Write-Host '  [7] Set screen timeout' -ForegroundColor White
    Write-Host '  [8] Stand by mode (sleep)' -ForegroundColor White
    Write-Host '  [9] Wake up from stand by' -ForegroundColor White
    Write-Host '  [A] Enable/Disable Passthrough' -ForegroundColor White
    Write-Host '  [B] Reboot devices' -ForegroundColor White
    Write-Host '  [C] Show current settings' -ForegroundColor White
    Write-Host '  [D] Power Off devices' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # Wi-Fi Configuration (enable/disable/status)
            Clear-Host
            Write-Host ''
            Write-Host 'Wi-Fi Configuration:' -ForegroundColor Yellow
            Write-Host '  [1] Enable Wi-Fi' -ForegroundColor White
            Write-Host '  [2] Disable Wi-Fi' -ForegroundColor White
            Write-Host '  [3] Show Wi-Fi status' -ForegroundColor White
            Write-Host ''
            Write-Host 'Select: ' -NoNewline -ForegroundColor Yellow
            $wifiChoice = Read-Host
            
            switch ($wifiChoice) {
                '1' {
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell svc wifi enable' -Description 'Enable Wi-Fi'
                    Show-ResultsSummary -Results $results
                }
                '2' {
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell svc wifi disable' -Description 'Disable Wi-Fi'
                    Show-ResultsSummary -Results $results
                }
                '3' {
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell dumpsys wifi | grep "Wi-Fi is"' -Description 'Wi-Fi status'
                    foreach ($result in $results) {
                        Write-Host "`n--- Device: $($result.Serial) ---" -ForegroundColor Cyan
                        Write-Host $result.Output -ForegroundColor White
                    }
                }
            }
            Wait-UserInput
        }
        '2' {
            # Connect to custom Wi-Fi network
            Write-Host ''
            Write-Host 'Connect to Custom Wi-Fi Network' -ForegroundColor Yellow
            Write-Host '--------------------------------------------------------------------' -ForegroundColor DarkGray
            Write-Host ''
            Write-Host 'Enter Wi-Fi Network Name (SSID): ' -NoNewline -ForegroundColor Yellow
            $ssid = Read-Host
            
            if (-not $ssid) {
                Write-Host 'SSID cannot be empty!' -ForegroundColor Red
                Wait-UserInput
                Show-DeviceSettingsMenu -SelectedDevices $SelectedDevices
                return
            }
            
            Write-Host 'Enter Wi-Fi Password: ' -NoNewline -ForegroundColor Yellow
            $password = Read-Host -AsSecureString
            $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
            )
            
            if (-not $passwordPlain) {
                Write-Host 'Password cannot be empty!' -ForegroundColor Red
                Wait-UserInput
                Show-DeviceSettingsMenu -SelectedDevices $SelectedDevices
                return
            }
            
            Write-Host ''
            Write-Host "Connecting to Wi-Fi network: $ssid" -ForegroundColor Cyan
            Write-Host ''
            
            # First, ensure Wi-Fi is enabled
            $enableResults = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell svc wifi enable' -Description 'Enable Wi-Fi'
            Start-Sleep -Seconds 2
            
            # Connect to the network using wpa_cli or settings command
            $results = @()
            foreach ($serial in $SelectedDevices) {
                Write-Host "Connecting device $serial..." -ForegroundColor Yellow
                
                # Method 1: Try using cmd wifi connect
                $output = & "$ScriptDir\adb.exe" -s $serial shell "cmd wifi connect-network `"$ssid`" wpa2 `"$passwordPlain`"" 2>&1
                
                $success = $output -notmatch 'error|failed|unable'
                
                $results += [PSCustomObject]@{
                    Serial      = $serial
                    Success     = $success
                    Output      = $output -join "`n"
                    Description = "Connect to $ssid"
                }
                
                if ($success) {
                    Write-Host "  Connected successfully" -ForegroundColor Green
                }
                else {
                    Write-Host "  Connection may have failed - check device" -ForegroundColor Yellow
                }
            }
            
            Write-Host ''
            Write-Host 'Note: Some devices may require manual confirmation on the headset.' -ForegroundColor Gray
            Write-Host 'Give it a few seconds to establish connection...' -ForegroundColor Gray
            
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '3' {
            # Set screen brightness
            Write-Host 'Enter brightness level (0-255): ' -NoNewline -ForegroundColor Yellow
            $brightness = Read-Host
            
            if ($brightness -match '^\d+$' -and [int]$brightness -ge 0 -and [int]$brightness -le 255) {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell settings put system screen_brightness $brightness" -Description "Set brightness to $brightness"
                Show-ResultsSummary -Results $results
            }
            else {
                Write-Host 'Invalid brightness value! Must be between 0-255' -ForegroundColor Red
            }
            Wait-UserInput
        }
        '4' {
            # Set volume level
            Write-Host 'Enter volume level (0-15): ' -NoNewline -ForegroundColor Yellow
            $volume = Read-Host
            
            if ($volume -match '^\d+$' -and [int]$volume -ge 0 -and [int]$volume -le 15) {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell media volume --show --stream 3 --set $volume" -Description "Set volume to $volume"
                Show-ResultsSummary -Results $results
            }
            else {
                Write-Host 'Invalid volume value! Must be between 0-15' -ForegroundColor Red
            }
            Wait-UserInput
        }
        '5' {
            # Set date and time
            Write-Host 'Setting date and time to current PC time...' -ForegroundColor Yellow
            $currentTime = Get-Date -Format 'MMddHHmmyyyy.ss'
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell date $currentTime" -Description 'Set date/time'
            Show-ResultsSummary -Results $results
            Wait-UserInput
        }
        '6' {
            # Enable/Disable Developer mode
            Clear-Host
            Write-Host ''
            Write-Host 'Developer Mode:' -ForegroundColor Yellow
            Write-Host '  [1] Enable USB debugging' -ForegroundColor White
            Write-Host '  [2] Disable USB debugging' -ForegroundColor White
            Write-Host '  [3] Show developer options status' -ForegroundColor White
            Write-Host ''
            Write-Host 'Select: ' -NoNewline -ForegroundColor Yellow
            $devChoice = Read-Host
            
            switch ($devChoice) {
                '1' {
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell settings put global adb_enabled 1' -Description 'Enable USB debugging'
                    Show-ResultsSummary -Results $results
                }
                '2' {
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell settings put global adb_enabled 0' -Description 'Disable USB debugging'
                    Show-ResultsSummary -Results $results
                }
                '3' {
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell settings get global development_settings_enabled' -Description 'Developer mode status'
                    foreach ($result in $results) {
                        Write-Host "`n--- Device: $($result.Serial) ---" -ForegroundColor Cyan
                        $status = if ($result.Output -match '1') { 'ENABLED' } else { 'DISABLED' }
                        Write-Host "Developer Mode: $status" -ForegroundColor $(if ($status -eq 'ENABLED') { 'Green' }else { 'Yellow' })
                    }
                }
            }
            Wait-UserInput
        }
        '7' {
            # Set screen timeout
            Write-Host 'Enter screen timeout in milliseconds (e.g., 60000 = 1 min, 300000 = 5 min): ' -NoNewline -ForegroundColor Yellow
            $timeout = Read-Host
            
            if ($timeout -match '^\d+$') {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell settings put system screen_off_timeout $timeout" -Description "Set screen timeout to $timeout ms"
                Show-ResultsSummary -Results $results
            }
            else {
                Write-Host 'Invalid timeout value!' -ForegroundColor Red
            }
            Wait-UserInput
        }
        '8' {
            # Stand by mode (sleep)
            Write-Host ''
            Write-Host 'Putting devices into stand by mode (sleep)...' -ForegroundColor Yellow
            Write-Host ''
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell input keyevent KEYCODE_SLEEP' -Description 'Stand by mode'
            Show-ResultsSummary -Results $results
            
            Write-Host ''
            Write-Host 'Devices should now be in stand by mode (screen off)' -ForegroundColor Green
            Wait-UserInput
        }
        '9' {
            # Wake up from stand by
            Write-Host ''
            Write-Host 'Waking up devices from stand by...' -ForegroundColor Yellow
            Write-Host ''
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell input keyevent KEYCODE_WAKEUP' -Description 'Wake up'
            Show-ResultsSummary -Results $results
            
            Write-Host ''
            Write-Host 'Devices should now be awake (screen on)' -ForegroundColor Green
            Wait-UserInput
        }
        'A' {
            # Enable/Disable Passthrough
            Clear-Host
            Write-Host ''
            Write-Host 'Passthrough Control:' -ForegroundColor Yellow
            Write-Host '  [1] Enable Passthrough' -ForegroundColor White
            Write-Host '  [2] Disable Passthrough' -ForegroundColor White
            Write-Host '  [3] Toggle Passthrough' -ForegroundColor White
            Write-Host ''
            Write-Host 'Select: ' -NoNewline -ForegroundColor Yellow
            $passthroughChoice = Read-Host
            
            switch ($passthroughChoice) {
                '1' {
                    Write-Host ''
                    Write-Host 'Enabling passthrough...' -ForegroundColor Yellow
                    # Enable passthrough using broadcast intent
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell am broadcast -a com.oculus.vrpowermanager.prox_close' -Description 'Enable Passthrough'
                    Show-ResultsSummary -Results $results
                }
                '2' {
                    Write-Host ''
                    Write-Host 'Disabling passthrough...' -ForegroundColor Yellow
                    # Disable passthrough
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell am broadcast -a com.oculus.vrpowermanager.automation_disable' -Description 'Disable Passthrough'
                    Show-ResultsSummary -Results $results
                }
                '3' {
                    Write-Host ''
                    Write-Host 'Toggling passthrough...' -ForegroundColor Yellow
                    # Using home button press can toggle passthrough on Quest
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell input keyevent KEYCODE_HOME' -Description 'Toggle Passthrough'
                    Write-Host 'Sent HOME button command (double-tap HOME manually to toggle)' -ForegroundColor Cyan
                    Show-ResultsSummary -Results $results
                }
            }
            Wait-UserInput
        }
        'a' {
            # Enable/Disable Passthrough (lowercase)
            Clear-Host
            Write-Host ''
            Write-Host 'Passthrough Control:' -ForegroundColor Yellow
            Write-Host '  [1] Enable Passthrough' -ForegroundColor White
            Write-Host '  [2] Disable Passthrough' -ForegroundColor White
            Write-Host '  [3] Toggle Passthrough' -ForegroundColor White
            Write-Host ''
            Write-Host 'Select: ' -NoNewline -ForegroundColor Yellow
            $passthroughChoice = Read-Host
            
            switch ($passthroughChoice) {
                '1' {
                    Write-Host ''
                    Write-Host 'Enabling passthrough...' -ForegroundColor Yellow
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell am broadcast -a com.oculus.vrpowermanager.prox_close' -Description 'Enable Passthrough'
                    Show-ResultsSummary -Results $results
                }
                '2' {
                    Write-Host ''
                    Write-Host 'Disabling passthrough...' -ForegroundColor Yellow
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell am broadcast -a com.oculus.vrpowermanager.automation_disable' -Description 'Disable Passthrough'
                    Show-ResultsSummary -Results $results
                }
                '3' {
                    Write-Host ''
                    Write-Host 'Toggling passthrough...' -ForegroundColor Yellow
                    $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell input keyevent KEYCODE_HOME' -Description 'Toggle Passthrough'
                    Write-Host 'Sent HOME button command (double-tap HOME manually to toggle)' -ForegroundColor Cyan
                    Show-ResultsSummary -Results $results
                }
            }
            Wait-UserInput
        }
        'B' {
            # Reboot devices
            if (Show-ConfirmationDialog -Message "Reboot $($SelectedDevices.Count) device(s)?") {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'reboot' -Description 'Reboot device'
                Show-ResultsSummary -Results $results
            }
            Wait-UserInput
        }
        'b' {
            # Reboot devices (lowercase)
            if (Show-ConfirmationDialog -Message "Reboot $($SelectedDevices.Count) device(s)?") {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'reboot' -Description 'Reboot device'
                Show-ResultsSummary -Results $results
            }
            Wait-UserInput
        }
        'C' {
            # Show current settings
            Write-Host "`nRetrieving current settings..." -ForegroundColor Yellow
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "`n========================================" -ForegroundColor Cyan
                Write-Host "Device: $serial" -ForegroundColor Cyan
                Write-Host "========================================" -ForegroundColor Cyan
                
                # Brightness
                $brightness = & "$ScriptDir\adb.exe" -s $serial shell settings get system screen_brightness 2>&1
                Write-Host "Brightness: $brightness" -ForegroundColor White
                
                # Screen timeout
                $timeout = & "$ScriptDir\adb.exe" -s $serial shell settings get system screen_off_timeout 2>&1
                $timeoutSec = [math]::Round([int]$timeout / 1000)
                Write-Host "Screen Timeout: $timeout ms ($timeoutSec seconds)" -ForegroundColor White
                
                # Wi-Fi status
                $wifi = & "$ScriptDir\adb.exe" -s $serial shell dumpsys wifi | Select-String "Wi-Fi is" 2>&1
                Write-Host "Wi-Fi: $wifi" -ForegroundColor White
                
                # Developer mode
                $devMode = & "$ScriptDir\adb.exe" -s $serial shell settings get global development_settings_enabled 2>&1
                $devStatus = if ($devMode -match '1') { 'ENABLED' } else { 'DISABLED' }
                Write-Host "Developer Mode: $devStatus" -ForegroundColor $(if ($devStatus -eq 'ENABLED') { 'Green' }else { 'Yellow' })
            }
            Wait-UserInput
        }
        'c' {
            # Show current settings (lowercase)
            Write-Host "`nRetrieving current settings..." -ForegroundColor Yellow
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "`n========================================" -ForegroundColor Cyan
                Write-Host "Device: $serial" -ForegroundColor Cyan
                Write-Host "========================================" -ForegroundColor Cyan
                
                # Brightness
                $brightness = & "$ScriptDir\adb.exe" -s $serial shell settings get system screen_brightness 2>&1
                Write-Host "Brightness: $brightness" -ForegroundColor White
                
                # Screen timeout
                $timeout = & "$ScriptDir\adb.exe" -s $serial shell settings get system screen_off_timeout 2>&1
                $timeoutSec = [math]::Round([int]$timeout / 1000)
                Write-Host "Screen Timeout: $timeout ms ($timeoutSec seconds)" -ForegroundColor White
                
                # Wi-Fi status
                $wifi = & "$ScriptDir\adb.exe" -s $serial shell dumpsys wifi | Select-String "Wi-Fi is" 2>&1
                Write-Host "Wi-Fi: $wifi" -ForegroundColor White
                
                # Developer mode
                $devMode = & "$ScriptDir\adb.exe" -s $serial shell settings get global development_settings_enabled 2>&1
                $devStatus = if ($devMode -match '1') { 'ENABLED' } else { 'DISABLED' }
                Write-Host "Developer Mode: $devStatus" -ForegroundColor $(if ($devStatus -eq 'ENABLED') { 'Green' }else { 'Yellow' })
            }
            Wait-UserInput
        }
        'D' {
            # Power Off devices
            if (Show-ConfirmationDialog -Message "POWER OFF $($SelectedDevices.Count) device(s)?") {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell reboot -p' -Description 'Power Off'
                Show-ResultsSummary -Results $results
            }
            Wait-UserInput
        }
        'd' {
            # Power Off devices (lowercase)
            if (Show-ConfirmationDialog -Message "POWER OFF $($SelectedDevices.Count) device(s)?") {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell reboot -p' -Description 'Power Off'
                Show-ResultsSummary -Results $results
            }
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-DeviceSettingsMenu -SelectedDevices $SelectedDevices
}

function Show-StreamingConnectivityMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                  STREAMING & CONNECTIVITY                           ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Start screen streaming (scrcpy)' -ForegroundColor White
    Write-Host '  [2] Enable ADB over Wi-Fi' -ForegroundColor White
    Write-Host '  [3] Disable ADB over Wi-Fi (return to USB)' -ForegroundColor White
    Write-Host '  [4] Show current IP addresses' -ForegroundColor White
    Write-Host '  [5] Connect to device via Wi-Fi' -ForegroundColor White
    Write-Host '  [6] Disconnect Wi-Fi ADB connection' -ForegroundColor White
    Write-Host '  [7] Port forwarding setup' -ForegroundColor White
    Write-Host '  [8] Enable MTP (File Transfer)' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # Start screen streaming
            Write-Host ''
            Write-Host 'Screen Streaming with scrcpy' -ForegroundColor Yellow
            Write-Host '--------------------------------------------------------------------' -ForegroundColor DarkGray
            Write-Host ''
            
            if ($SelectedDevices.Count -gt 1) {
                Write-Host 'Select device to stream:' -ForegroundColor Yellow
                for ($i = 0; $i -lt $SelectedDevices.Count; $i++) {
                    Write-Host "  [$($i + 1)] $($SelectedDevices[$i])" -ForegroundColor White
                }
                Write-Host ''
                Write-Host 'Device number: ' -NoNewline -ForegroundColor Yellow
                $deviceChoice = Read-Host
                $deviceIndex = [int]$deviceChoice - 1
                
                if ($deviceIndex -ge 0 -and $deviceIndex -lt $SelectedDevices.Count) {
                    $streamSerial = $SelectedDevices[$deviceIndex]
                }
                else {
                    Write-Host 'Invalid selection!' -ForegroundColor Red
                    Wait-UserInput
                    Show-StreamingConnectivityMenu -SelectedDevices $SelectedDevices
                    return
                }
            }
            else {
                $streamSerial = $SelectedDevices[0]
            }
            
            Write-Host ''
            Write-Host "Starting screen stream for device: $streamSerial" -ForegroundColor Green
            Write-Host ''
            Write-Host 'Note: scrcpy must be installed and in PATH' -ForegroundColor Gray
            Write-Host 'If not installed, download from: https://github.com/Genymobile/scrcpy' -ForegroundColor Gray
            Write-Host ''
            Write-Host 'Press Ctrl+C to stop streaming when done' -ForegroundColor Yellow
            Write-Host ''
            Start-Sleep -Seconds 2
            
            try {
                & scrcpy -s $streamSerial
            }
            catch {
                Write-Host "Error: scrcpy not found or failed to start" -ForegroundColor Red
                Write-Host "Install scrcpy from: https://github.com/Genymobile/scrcpy" -ForegroundColor Yellow
            }
            
            Wait-UserInput
        }
        '2' {
            # Enable ADB over Wi-Fi
            Write-Host ''
            Write-Host 'Enabling ADB over Wi-Fi...' -ForegroundColor Yellow
            Write-Host ''
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing device: $serial" -ForegroundColor Cyan
                
                # Get IP address
                $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                $ipString = $ipOutput -join "`n"
                if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    $ipAddress = $Matches[1]
                    Write-Host "  IP Address: $ipAddress" -ForegroundColor White
                    
                    # Enable TCP/IP on port 5555
                    $tcpipOutput = & "$ScriptDir\adb.exe" -s $serial tcpip 5555 2>&1
                    Write-Host "  $tcpipOutput" -ForegroundColor Gray
                    
                    Write-Host "  ADB over Wi-Fi enabled!" -ForegroundColor Green
                    Write-Host "  To connect: adb connect $ipAddress`:5555" -ForegroundColor Yellow
                }
                else {
                    Write-Host "  Could not get IP address - ensure Wi-Fi is connected" -ForegroundColor Red
                }
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '3' {
            # Disable ADB over Wi-Fi
            Write-Host ''
            Write-Host 'Returning to USB mode...' -ForegroundColor Yellow
            Write-Host ''
            
            foreach ($serial in $SelectedDevices) {
                if ($serial -match '^\d+\.\d+\.\d+\.\d+') {
                    # This is a Wi-Fi connection, disconnect it
                    $disconnectOutput = & "$ScriptDir\adb.exe" disconnect $serial 2>&1
                    Write-Host "Disconnected: $serial" -ForegroundColor Cyan
                }
                else {
                    # This is USB, switch back to USB mode
                    $usbOutput = & "$ScriptDir\adb.exe" -s $serial usb 2>&1
                    Write-Host "Device $serial returned to USB mode" -ForegroundColor Green
                }
            }
            
            Write-Host ''
            Write-Host 'Devices returned to USB mode' -ForegroundColor Green
            Wait-UserInput
        }
        '4' {
            # Show IP addresses
            Write-Host ''
            Write-Host 'Current IP Addresses:' -ForegroundColor Yellow
            Write-Host ''
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Device: $serial" -ForegroundColor Cyan
                $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                $ipString = $ipOutput -join "`n"
                
                if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    Write-Host "  IP: $($Matches[1])" -ForegroundColor Green
                }
                else {
                    Write-Host "  No IP (Wi-Fi not connected)" -ForegroundColor Yellow
                }
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '5' {
            # Connect via Wi-Fi
            Write-Host ''
            Write-Host 'Connect to Device via Wi-Fi' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            Write-Host '  [1] Auto-connect to all USB devices' -ForegroundColor White
            Write-Host '  [2] Manual IP connection' -ForegroundColor White
            Write-Host ''
            Write-Host '  [0] Cancel' -ForegroundColor Red
            Write-Host ''
            Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
            $wifiChoice = Read-Host
            
            if ($wifiChoice -eq '1') {
                # Auto-connect to all USB devices
                Write-Host ''
                Write-Host 'Auto-connecting to all USB devices...' -ForegroundColor Cyan
                Write-Host '=====================================================================' -ForegroundColor DarkGray
                Write-Host ''
                
                # Get all currently connected USB devices
                $usbDevices = Refresh-Devices | Where-Object { $_.Serial -notmatch '^\d+\.\d+\.\d+\.\d+' }
                
                if ($usbDevices.Count -eq 0) {
                    Write-Host 'No USB devices found!' -ForegroundColor Red
                    Wait-UserInput
                    Show-StreamingConnectivityMenu -SelectedDevices $SelectedDevices
                    return
                }
                
                Write-Host "Found $($usbDevices.Count) USB device(s)" -ForegroundColor Green
                Write-Host ''
                
                $successCount = 0
                $failCount = 0
                
                foreach ($device in $usbDevices) {
                    $serial = $device.Serial
                    Write-Host "Processing device: $serial" -ForegroundColor Cyan
                    
                    # Get IP address
                    $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                    $ipString = $ipOutput -join "`n"
                    
                    if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                        $ipAddress = $Matches[1]
                        Write-Host "  IP Address: $ipAddress" -ForegroundColor White
                        
                        # Enable TCP/IP on port 5555
                        Write-Host "  Enabling ADB over Wi-Fi..." -ForegroundColor Gray
                        $tcpipOutput = & "$ScriptDir\adb.exe" -s $serial tcpip 5555 2>&1
                        Start-Sleep -Milliseconds 500
                        
                        # Connect via Wi-Fi
                        $wifiAddress = "$ipAddress" + ":5555"
                        Write-Host "  Connecting to $wifiAddress..." -ForegroundColor Gray
                        $connectOutput = & "$ScriptDir\adb.exe" connect $wifiAddress 2>&1
                        
                        if ($connectOutput -match 'connected to') {
                            Write-Host "  [OK] Successfully connected!" -ForegroundColor Green
                            $successCount++
                        }
                        else {
                            Write-Host "  [FAIL] Connection failed: $connectOutput" -ForegroundColor Red
                            $failCount++
                        }
                    }
                    else {
                        Write-Host "  [FAIL] Could not get IP address - ensure Wi-Fi is connected" -ForegroundColor Red
                        $failCount++
                    }
                    Write-Host ''
                }
                
                # Summary
                Write-Host '=====================================================================' -ForegroundColor DarkGray
                Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
                Write-Host ''
                Write-Host 'IMPORTANT: You can now disconnect the USB cables!' -ForegroundColor Cyan
                Write-Host 'Devices will remain connected via Wi-Fi.' -ForegroundColor Gray
                Write-Host ''
            }
            elseif ($wifiChoice -eq '2') {
                # Manual IP connection
                Write-Host ''
                Write-Host 'Enter device IP address (e.g., 192.168.1.100): ' -NoNewline -ForegroundColor Yellow
                $ipAddress = Read-Host
                
                if ($ipAddress -match '^\d+\.\d+\.\d+\.\d+$') {
                    Write-Host ''
                    $wifiAddress = "$ipAddress" + ":5555"
                    Write-Host "Connecting to $wifiAddress..." -ForegroundColor Cyan
                    $connectOutput = & "$ScriptDir\adb.exe" connect $wifiAddress 2>&1
                    Write-Host $connectOutput -ForegroundColor White
                }
                else {
                    Write-Host 'Invalid IP address format!' -ForegroundColor Red
                }
                
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '6' {
            # Disconnect Wi-Fi
            Write-Host ''
            Write-Host 'Disconnecting Wi-Fi ADB connections...' -ForegroundColor Yellow
            
            foreach ($serial in $SelectedDevices) {
                if ($serial -match '^\d+\.\d+\.\d+\.\d+') {
                    $disconnectOutput = & "$ScriptDir\adb.exe" disconnect $serial 2>&1
                    Write-Host "Disconnected: $serial" -ForegroundColor Green
                }
            }
            
            Wait-UserInput
        }
        '7' {
            # Port forwarding
            Write-Host ''
            Write-Host 'Port Forwarding Setup' -ForegroundColor Yellow
            Write-Host '--------------------------------------------------------------------' -ForegroundColor DarkGray
            Write-Host ''
            Write-Host 'Enter local port: ' -NoNewline -ForegroundColor Yellow
            $localPort = Read-Host
            Write-Host 'Enter remote port: ' -NoNewline -ForegroundColor Yellow
            $remotePort = Read-Host
            
            if ($localPort -match '^\d+$' -and $remotePort -match '^\d+$') {
                foreach ($serial in $SelectedDevices) {
                    $forwardOutput = & "$ScriptDir\adb.exe" -s $serial forward tcp:$localPort tcp:$remotePort 2>&1
                    Write-Host "Device $serial`: $forwardOutput" -ForegroundColor Green
                }
            }
            else {
                Write-Host 'Invalid port numbers!' -ForegroundColor Red
            }
            
            Wait-UserInput
        }
        '8' {
            # Enable MTP (File Transfer)
            Write-Host ''
            Write-Host 'Enabling MTP (File Transfer) mode...' -ForegroundColor Yellow
            Write-Host 'This will allow you to browse device files in Windows Explorer.' -ForegroundColor Gray
            Write-Host ''
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'shell svc usb setFunctions mtp,adb' -Description 'Enable MTP'
            Show-ResultsSummary -Results $results
            
            Write-Host ''
            Write-Host 'Note: You may hear the USB disconnect/connect sound.' -ForegroundColor Cyan
            Write-Host 'If it does not appear, try unplugging and replugging the USB cable.' -ForegroundColor Yellow
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-StreamingConnectivityMenu -SelectedDevices $SelectedDevices
}

function Show-TextInputMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                         TEXT INPUT                                  ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Send text to devices' -ForegroundColor White
    Write-Host '  [2] Send keyevent' -ForegroundColor White
    Write-Host '  [3] Send special characters' -ForegroundColor White
    Write-Host '  [4] Simulate tap at coordinates' -ForegroundColor White
    Write-Host '  [5] Simulate swipe gesture' -ForegroundColor White
    Write-Host '  [6] Send common keycodes' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # Send text
            Write-Host ''
            Write-Host 'Enter text to send to devices: ' -NoNewline -ForegroundColor Yellow
            $textToSend = Read-Host
            
            if ($textToSend) {
                # Escape special characters for ADB
                $escapedText = $textToSend -replace ' ', '%s' -replace '&', '\&'
                
                Write-Host ''
                Write-Host "Sending text: $textToSend" -ForegroundColor Cyan
                
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell input text `"$escapedText`"" -Description "Send text"
                Show-ResultsSummary -Results $results
            }
            else {
                Write-Host 'No text entered!' -ForegroundColor Red
            }
            
            Wait-UserInput
        }
        '2' {
            # Send keyevent
            Write-Host ''
            Write-Host 'Enter keycode number (e.g., 3 for HOME, 4 for BACK): ' -NoNewline -ForegroundColor Yellow
            $keycode = Read-Host
            
            if ($keycode -match '^\d+$') {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell input keyevent $keycode" -Description "Send keycode $keycode"
                Show-ResultsSummary -Results $results
            }
            else {
                Write-Host 'Invalid keycode!' -ForegroundColor Red
            }
            
            Wait-UserInput
        }
        '3' {
            # Special characters
            Clear-Host
            Write-Host ''
            Write-Host 'Special Characters:' -ForegroundColor Yellow
            Write-Host '  [1] @ (at symbol)' -ForegroundColor White
            Write-Host '  [2] . (period/dot)' -ForegroundColor White
            Write-Host '  [3] , (comma)' -ForegroundColor White
            Write-Host '  [4] - (dash)' -ForegroundColor White
            Write-Host '  [5] _ (underscore)' -ForegroundColor White
            Write-Host '  [6] / (slash)' -ForegroundColor White
            Write-Host ''
            Write-Host 'Select: ' -NoNewline -ForegroundColor Yellow
            $specialChoice = Read-Host
            
            $specialChar = switch ($specialChoice) {
                '1' { '@' }
                '2' { '.' }
                '3' { ',' }
                '4' { '-' }
                '5' { '_' }
                '6' { '/' }
                default { '' }
            }
            
            if ($specialChar) {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell input text '$specialChar'" -Description "Send $specialChar"
                Show-ResultsSummary -Results $results
            }
            
            Wait-UserInput
        }
        '4' {
            # Tap at coordinates
            Write-Host ''
            Write-Host 'Enter X coordinate: ' -NoNewline -ForegroundColor Yellow
            $x = Read-Host
            Write-Host 'Enter Y coordinate: ' -NoNewline -ForegroundColor Yellow
            $y = Read-Host
            
            if ($x -match '^\d+$' -and $y -match '^\d+$') {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell input tap $x $y" -Description "Tap at ($x, $y)"
                Show-ResultsSummary -Results $results
            }
            else {
                Write-Host 'Invalid coordinates!' -ForegroundColor Red
            }
            
            Wait-UserInput
        }
        '5' {
            # Swipe gesture
            Write-Host ''
            Write-Host 'Swipe Gesture Setup' -ForegroundColor Yellow
            Write-Host 'Enter start X: ' -NoNewline -ForegroundColor Yellow
            $x1 = Read-Host
            Write-Host 'Enter start Y: ' -NoNewline -ForegroundColor Yellow
            $y1 = Read-Host
            Write-Host 'Enter end X: ' -NoNewline -ForegroundColor Yellow
            $x2 = Read-Host
            Write-Host 'Enter end Y: ' -NoNewline -ForegroundColor Yellow
            $y2 = Read-Host
            Write-Host 'Duration in ms (e.g., 300): ' -NoNewline -ForegroundColor Yellow
            $duration = Read-Host
            
            if ($x1 -match '^\d+$' -and $y1 -match '^\d+$' -and $x2 -match '^\d+$' -and $y2 -match '^\d+$' -and $duration -match '^\d+$') {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell input swipe $x1 $y1 $x2 $y2 $duration" -Description "Swipe gesture"
                Show-ResultsSummary -Results $results
            }
            else {
                Write-Host 'Invalid input!' -ForegroundColor Red
            }
            
            Wait-UserInput
        }
        '6' {
            # Common keycodes
            Clear-Host
            Write-Host ''
            Write-Host 'Common Keycodes:' -ForegroundColor Yellow
            Write-Host '  [1] HOME (3)' -ForegroundColor White
            Write-Host '  [2] BACK (4)' -ForegroundColor White
            Write-Host '  [3] MENU (82)' -ForegroundColor White
            Write-Host '  [4] ENTER (66)' -ForegroundColor White
            Write-Host '  [5] DELETE (67)' -ForegroundColor White
            Write-Host '  [6] SPACE (62)' -ForegroundColor White
            Write-Host '  [7] VOLUME UP (24)' -ForegroundColor White
            Write-Host '  [8] VOLUME DOWN (25)' -ForegroundColor White
            Write-Host ''
            Write-Host 'Select: ' -NoNewline -ForegroundColor Yellow
            $keycodeChoice = Read-Host
            
            $keycode = switch ($keycodeChoice) {
                '1' { '3' }
                '2' { '4' }
                '3' { '82' }
                '4' { '66' }
                '5' { '67' }
                '6' { '62' }
                '7' { '24' }
                '8' { '25' }
                default { '' }
            }
            
            if ($keycode) {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell input keyevent $keycode" -Description "Send keycode $keycode"
                Show-ResultsSummary -Results $results
            }
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-TextInputMenu -SelectedDevices $SelectedDevices
}

function Show-AdvancedToolsMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                       ADVANCED TOOLS                                ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Interactive shell (single device)' -ForegroundColor White
    Write-Host '  [2] Execute custom shell command' -ForegroundColor White
    Write-Host '  [3] View logcat (live logs)' -ForegroundColor White
    Write-Host '  [4] Save logcat to file' -ForegroundColor White
    Write-Host '  [5] Clear logcat buffer' -ForegroundColor White
    Write-Host '  [6] Get detailed device info' -ForegroundColor White
    Write-Host '  [7] List running processes' -ForegroundColor White
    Write-Host '  [8] Kill process by name' -ForegroundColor White
    Write-Host '  [9] Execute custom ADB command' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # Interactive shell
            if ($SelectedDevices.Count -gt 1) {
                Write-Host ''
                Write-Host 'Select device for interactive shell:' -ForegroundColor Yellow
                for ($i = 0; $i -lt $SelectedDevices.Count; $i++) {
                    Write-Host "  [$($i + 1)] $($SelectedDevices[$i])" -ForegroundColor White
                }
                Write-Host ''
                Write-Host 'Device number: ' -NoNewline -ForegroundColor Yellow
                $deviceChoice = Read-Host
                $deviceIndex = [int]$deviceChoice - 1
                
                if ($deviceIndex -ge 0 -and $deviceIndex -lt $SelectedDevices.Count) {
                    $shellSerial = $SelectedDevices[$deviceIndex]
                }
                else {
                    Write-Host 'Invalid selection!' -ForegroundColor Red
                    Wait-UserInput
                    Show-AdvancedToolsMenu -SelectedDevices $SelectedDevices
                    return
                }
            }
            else {
                $shellSerial = $SelectedDevices[0]
            }
            
            Write-Host ''
            Write-Host "Opening interactive shell for: $shellSerial" -ForegroundColor Green
            Write-Host "Type 'exit' to return to menu" -ForegroundColor Yellow
            Write-Host ''
            
            & "$ScriptDir\adb.exe" -s $shellSerial shell
            
            Wait-UserInput
        }
        '2' {
            # Custom shell command
            Write-Host ''
            Write-Host 'Enter shell command (e.g., ls, pwd, getprop): ' -NoNewline -ForegroundColor Yellow
            $shellCommand = Read-Host
            
            if ($shellCommand) {
                Write-Host ''
                Write-Host "Executing: $shellCommand" -ForegroundColor Cyan
                Write-Host ''
                
                foreach ($serial in $SelectedDevices) {
                    Write-Host "========================================" -ForegroundColor DarkGray
                    Write-Host "Device: $serial" -ForegroundColor Cyan
                    Write-Host "========================================" -ForegroundColor DarkGray
                    
                    $output = & "$ScriptDir\adb.exe" -s $serial shell $shellCommand 2>&1
                    Write-Host $output -ForegroundColor White
                    Write-Host ''
                }
            }
            
            Wait-UserInput
        }
        '3' {
            # View logcat
            if ($SelectedDevices.Count -gt 1) {
                Write-Host ''
                Write-Host 'Select device for logcat:' -ForegroundColor Yellow
                for ($i = 0; $i -lt $SelectedDevices.Count; $i++) {
                    Write-Host "  [$($i + 1)] $($SelectedDevices[$i])" -ForegroundColor White
                }
                Write-Host ''
                Write-Host 'Device number: ' -NoNewline -ForegroundColor Yellow
                $deviceChoice = Read-Host
                $deviceIndex = [int]$deviceChoice - 1
                
                if ($deviceIndex -ge 0 -and $deviceIndex -lt $SelectedDevices.Count) {
                    $logcatSerial = $SelectedDevices[$deviceIndex]
                }
                else {
                    Write-Host 'Invalid selection!' -ForegroundColor Red
                    Wait-UserInput
                    Show-AdvancedToolsMenu -SelectedDevices $SelectedDevices
                    return
                }
            }
            else {
                $logcatSerial = $SelectedDevices[0]
            }
            
            Write-Host ''
            Write-Host "Starting logcat for: $logcatSerial" -ForegroundColor Green
            Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
            Write-Host ''
            
            & "$ScriptDir\adb.exe" -s $logcatSerial logcat
            
            Wait-UserInput
        }
        '4' {
            # Save logcat to file
            Write-Host ''
            Write-Host 'Saving logcat to file...' -ForegroundColor Yellow
            
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            $logDir = Join-Path $ScriptDir "Logs\$timestamp"
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            
            foreach ($serial in $SelectedDevices) {
                $logFile = Join-Path $logDir "$serial-logcat.txt"
                Write-Host "Saving logcat for $serial..." -ForegroundColor Cyan
                
                & "$ScriptDir\adb.exe" -s $serial logcat -d > $logFile
                
                Write-Host "  Saved: $logFile" -ForegroundColor Green
            }
            
            Write-Host ''
            Write-Host "Logs saved to: $logDir" -ForegroundColor Green
            Wait-UserInput
        }
        '5' {
            # Clear logcat
            Write-Host ''
            Write-Host 'Clearing logcat buffer...' -ForegroundColor Yellow
            
            $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command 'logcat -c' -Description 'Clear logcat'
            Show-ResultsSummary -Results $results
            
            Wait-UserInput
        }
        '6' {
            # Detailed device info
            Write-Host ''
            Write-Host 'Retrieving detailed device information...' -ForegroundColor Yellow
            Write-Host ''
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "======================================================================" -ForegroundColor Cyan
                Write-Host "Device: $serial" -ForegroundColor Cyan
                Write-Host "======================================================================" -ForegroundColor Cyan
                
                # Model
                $model = & "$ScriptDir\adb.exe" -s $serial shell getprop ro.product.model 2>&1
                Write-Host "Model: $model" -ForegroundColor White
                
                # Brand
                $brand = & "$ScriptDir\adb.exe" -s $serial shell getprop ro.product.brand 2>&1
                Write-Host "Brand: $brand" -ForegroundColor White
                
                # Android version
                $androidVer = & "$ScriptDir\adb.exe" -s $serial shell getprop ro.build.version.release 2>&1
                Write-Host "Android Version: $androidVer" -ForegroundColor White
                
                # SDK version
                $sdkVer = & "$ScriptDir\adb.exe" -s $serial shell getprop ro.build.version.sdk 2>&1
                Write-Host "SDK Version: $sdkVer" -ForegroundColor White
                
                # Build ID
                $buildId = & "$ScriptDir\adb.exe" -s $serial shell getprop ro.build.id 2>&1
                Write-Host "Build ID: $buildId" -ForegroundColor White
                
                # Resolution
                $resolution = & "$ScriptDir\adb.exe" -s $serial shell wm size 2>&1
                Write-Host "Resolution: $resolution" -ForegroundColor White
                
                # Density
                $density = & "$ScriptDir\adb.exe" -s $serial shell wm density 2>&1
                Write-Host "Density: $density" -ForegroundColor White
                
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '7' {
            # List processes
            Write-Host ''
            Write-Host 'Running Processes:' -ForegroundColor Yellow
            Write-Host ''
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Device: $serial" -ForegroundColor Cyan
                Write-Host "--------------------------------------------------------------------" -ForegroundColor DarkGray
                
                $processes = & "$ScriptDir\adb.exe" -s $serial shell ps 2>&1 | Select-Object -First 20
                Write-Host $processes -ForegroundColor White
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '8' {
            # Kill process
            Write-Host ''
            Write-Host 'Enter process name or package to kill: ' -NoNewline -ForegroundColor Yellow
            $processName = Read-Host
            
            if ($processName) {
                $results = Invoke-ParallelAdbCommand -Devices $SelectedDevices -Command "shell am force-stop $processName" -Description "Kill $processName"
                Show-ResultsSummary -Results $results
            }
            
            Wait-UserInput
        }
        '9' {
            # Custom ADB command
            Write-Host ''
            Write-Host 'Enter custom ADB command (excluding "adb -s SERIAL"): ' -NoNewline -ForegroundColor Yellow
            $customCommand = Read-Host
            
            if ($customCommand) {
                Write-Host ''
                Write-Host "Executing: adb $customCommand" -ForegroundColor Cyan
                Write-Host ''
                
                foreach ($serial in $SelectedDevices) {
                    Write-Host "========================================" -ForegroundColor DarkGray
                    Write-Host "Device: $serial" -ForegroundColor Cyan
                    Write-Host "========================================" -ForegroundColor DarkGray
                    
                    $output = & "$ScriptDir\adb.exe" -s $serial $customCommand.Split(' ') 2>&1
                    Write-Host $output -ForegroundColor White
                    Write-Host ''
                }
            }
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-AdvancedToolsMenu -SelectedDevices $SelectedDevices
}

function Show-OpenBrushMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Green
    Write-Host '                        OPEN BRUSH API                               ' -ForegroundColor Green
    Write-Host '=====================================================================' -ForegroundColor Green
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Save New - Save current sketch with new filename' -ForegroundColor White
    Write-Host '  [2] Export Current - Export current sketch' -ForegroundColor White
    Write-Host '  [3] New - Create new blank sketch' -ForegroundColor White
    Write-Host '  [4] Environment Pistachio - Set environment to Pistachio' -ForegroundColor White
    Write-Host '  [5] Environment Passthrough - Set environment to Passthrough' -ForegroundColor White
    Write-Host '  [6] Custom Command - Enter custom API command' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # Save New
            Write-Host ''
            Write-Host 'Executing: save.new on all devices...' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            
            $successCount = 0
            $failCount = 0
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing device: $serial" -ForegroundColor Cyan
                
                # Get IP address
                $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                $ipString = $ipOutput -join "`n"
                
                if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    $ipAddress = $Matches[1]
                    Write-Host "  IP: $ipAddress" -ForegroundColor White
                    
                    # Call Open Brush API
                    $apiUrl = "http://" + $ipAddress + ":40074/api/v1?save.new"
                    Write-Host "  Calling API: $apiUrl" -ForegroundColor Gray
                    
                    try {
                        $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
                        Write-Host "  [OK] Response: $($response.StatusCode) - $($response.Content)" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
                        $failCount++
                    }
                }
                else {
                    Write-Host "  [FAIL] Could not get IP address" -ForegroundColor Red
                    $failCount++
                }
                Write-Host ''
            }
            
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host ''
            
            Wait-UserInput
        }
        '2' {
            # Export Current
            Write-Host ''
            Write-Host 'Executing: export.current on all devices...' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            
            $successCount = 0
            $failCount = 0
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing device: $serial" -ForegroundColor Cyan
                
                # Get IP address
                $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                $ipString = $ipOutput -join "`n"
                
                if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    $ipAddress = $Matches[1]
                    Write-Host "  IP: $ipAddress" -ForegroundColor White
                    
                    # Call Open Brush API
                    $apiUrl = "http://" + $ipAddress + ":40074/api/v1?export.current"
                    Write-Host "  Calling API: $apiUrl" -ForegroundColor Gray
                    
                    try {
                        $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
                        Write-Host "  [OK] Response: $($response.StatusCode) - $($response.Content)" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
                        $failCount++
                    }
                }
                else {
                    Write-Host "  [FAIL] Could not get IP address" -ForegroundColor Red
                    $failCount++
                }
                Write-Host ''
            }
            
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host ''
            
            Wait-UserInput
        }
        '3' {
            # New Sketch
            Write-Host ''
            Write-Host 'Executing: new on all devices...' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            
            $successCount = 0
            $failCount = 0
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing device: $serial" -ForegroundColor Cyan
                
                # Get IP address
                $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                $ipString = $ipOutput -join "`n"
                
                if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    $ipAddress = $Matches[1]
                    Write-Host "  IP: $ipAddress" -ForegroundColor White
                    
                    # Call Open Brush API
                    $apiUrl = "http://" + $ipAddress + ":40074/api/v1?new"
                    Write-Host "  Calling API: $apiUrl" -ForegroundColor Gray
                    
                    try {
                        $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
                        Write-Host "  [OK] Response: $($response.StatusCode) - $($response.Content)" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
                        $failCount++
                    }
                }
                else {
                    Write-Host "  [FAIL] Could not get IP address" -ForegroundColor Red
                    $failCount++
                }
                Write-Host ''
            }
            
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host ''
            
            Wait-UserInput
        }
        '4' {
            # Environment Pistachio
            Write-Host ''
            Write-Host 'Executing: environment.type=pistachio on all devices...' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            
            $successCount = 0
            $failCount = 0
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing device: $serial" -ForegroundColor Cyan
                
                # Get IP address
                $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                $ipString = $ipOutput -join "`n"
                
                if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    $ipAddress = $Matches[1]
                    Write-Host "  IP: $ipAddress" -ForegroundColor White
                    
                    # Call Open Brush API
                    $apiUrl = "http://" + $ipAddress + ":40074/api/v1?environment.type=pistachio"
                    Write-Host "  Calling API: $apiUrl" -ForegroundColor Gray
                    
                    try {
                        $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
                        Write-Host "  [OK] Response: $($response.StatusCode) - $($response.Content)" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
                        $failCount++
                    }
                }
                else {
                    Write-Host "  [FAIL] Could not get IP address" -ForegroundColor Red
                    $failCount++
                }
                Write-Host ''
            }
            
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host ''
            
            Wait-UserInput
        }
        '5' {
            # Environment Passthrough
            Write-Host ''
            Write-Host 'Executing: environment.type=passtrough on all devices...' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            
            $successCount = 0
            $failCount = 0
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing device: $serial" -ForegroundColor Cyan
                
                # Get IP address
                $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                $ipString = $ipOutput -join "`n"
                
                if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    $ipAddress = $Matches[1]
                    Write-Host "  IP: $ipAddress" -ForegroundColor White
                    
                    # Call Open Brush API
                    $apiUrl = "http://" + $ipAddress + ":40074/api/v1?environment.type=passtrough"
                    Write-Host "  Calling API: $apiUrl" -ForegroundColor Gray
                    
                    try {
                        $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
                        Write-Host "  [OK] Response: $($response.StatusCode) - $($response.Content)" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
                        $failCount++
                    }
                }
                else {
                    Write-Host "  [FAIL] Could not get IP address" -ForegroundColor Red
                    $failCount++
                }
                Write-Host ''
            }
            
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host ''
            
            Wait-UserInput
        }
        '6' {
            # Custom Command
            Write-Host ''
            Write-Host 'Enter custom command (e.g. environment.type=pistachio): ' -NoNewline -ForegroundColor Yellow
            $customCmd = Read-Host
            
            if ($customCmd) {
                Write-Host ''
                Write-Host "Executing: $customCmd on all devices..." -ForegroundColor Yellow
                Write-Host '=====================================================================' -ForegroundColor DarkGray
                Write-Host ''
                
                $successCount = 0
                $failCount = 0
                
                foreach ($serial in $SelectedDevices) {
                    Write-Host "Processing device: $serial" -ForegroundColor Cyan
                    
                    # Get IP address
                    $ipOutput = & "$ScriptDir\adb.exe" -s $serial shell ip addr show wlan0 2>&1
                    $ipString = $ipOutput -join "`n"
                    
                    if ($ipString -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                        $ipAddress = $Matches[1]
                        Write-Host "  IP: $ipAddress" -ForegroundColor White
                        
                        # Call Open Brush API
                        $apiUrl = "http://" + $ipAddress + ":40074/api/v1?" + $customCmd
                        Write-Host "  Calling API: $apiUrl" -ForegroundColor Gray
                        
                        try {
                            $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
                            Write-Host "  [OK] Response: $($response.StatusCode) - $($response.Content)" -ForegroundColor Green
                            $successCount++
                        }
                        catch {
                            Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
                            $failCount++
                        }
                    }
                    else {
                        Write-Host "  [FAIL] Could not get IP address" -ForegroundColor Red
                        $failCount++
                    }
                    Write-Host ''
                }
                
                Write-Host '=====================================================================' -ForegroundColor DarkGray
                Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
                Write-Host ''
            }
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-OpenBrushMenu -SelectedDevices $SelectedDevices
}

function Show-ShowtimeVRMenu {
    param([array]$SelectedDevices)
    
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Magenta
    Write-Host '                        SHOWTIME VR                                  ' -ForegroundColor Magenta
    Write-Host '=====================================================================' -ForegroundColor Magenta
    Write-Host ''
    Write-Host "Selected devices: $($SelectedDevices.Count)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Send Config.txt (personalized for each headset)' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # Send personalized config.txt to each device
            Write-Host ''
            Write-Host 'Sending personalized config.txt to devices...' -ForegroundColor Yellow
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host ''
            
            # Check if template file exists
            $templatePath = Join-Path $ScriptDir 'ShowtimeVR\config.txt'
            if (-not (Test-Path $templatePath)) {
                Write-Host "ERROR: Template file not found at: $templatePath" -ForegroundColor Red
                Write-Host 'Please create the template file first.' -ForegroundColor Yellow
                Wait-UserInput
                Show-ShowtimeVRMenu -SelectedDevices $SelectedDevices
                return
            }
            
            # Read template content
            $templateContent = Get-Content $templatePath -Raw
            
            # Create temp directory for personalized configs
            $tempDir = Join-Path $env:TEMP "ShowtimeVR_$([DateTime]::Now.ToString('yyyyMMdd_HHmmss'))"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $successCount = 0
            $failCount = 0
            
            foreach ($serial in $SelectedDevices) {
                Write-Host "Processing device: $serial" -ForegroundColor Cyan
                
                # Get device info from inventory
                $deviceInfo = $null
                if ($script:DeviceConfig -and $script:DeviceConfig.devices) {
                    $deviceInfo = $script:DeviceConfig.devices | Where-Object { $_.serial -eq $serial }
                }
                
                if (-not $deviceInfo) {
                    Write-Host "  WARNING: Device not found in inventory. Skipping..." -ForegroundColor Yellow
                    $failCount++
                    continue
                }
                
                # Get alias and customNumber
                $deviceAlias = if ($deviceInfo.alias) { $deviceInfo.alias } else { "Unknown" }
                $deviceNumber = if ($deviceInfo.customNumber) { $deviceInfo.customNumber } else { "0" }
                
                Write-Host "  Alias: $deviceAlias" -ForegroundColor White
                Write-Host "  Number: $deviceNumber" -ForegroundColor White
                
                # Create personalized config
                $personalizedConfig = $templateContent -split "`r?`n"
                
                # Modify only the name and nr lines, preserve everything else
                for ($i = 0; $i -lt $personalizedConfig.Count; $i++) {
                    $line = $personalizedConfig[$i]
                    
                    # Check if line starts with "name" (with or without spaces)
                    if ($line -match '^\s*name\s*=') {
                        $personalizedConfig[$i] = "name = $deviceAlias"
                    }
                    # Check if line starts with "nr" (with or without spaces)
                    elseif ($line -match '^\s*nr\s*=') {
                        $personalizedConfig[$i] = "nr = $deviceNumber"
                    }
                    # All other lines remain unchanged
                }
                
                # Save personalized config to temp file
                $tempConfigPath = Join-Path $tempDir "$serial-config.txt"
                $personalizedConfig -join "`n" | Out-File -FilePath $tempConfigPath -Encoding UTF8 -NoNewline
                
                # Create directory on device
                & "$ScriptDir\adb.exe" -s $serial shell mkdir -p '/sdcard/Showtime VR' 2>&1 | Out-Null
                
                # Push config file to device
                $result = & "$ScriptDir\adb.exe" -s $serial push $tempConfigPath '/sdcard/Showtime VR/config.txt' 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] Config sent successfully!" -ForegroundColor Green
                    $successCount++
                }
                else {
                    Write-Host "  [FAIL] Error sending config" -ForegroundColor Red
                    Write-Host "  Error: $result" -ForegroundColor DarkRed
                    $failCount++
                }
                
                Write-Host ''
            }
            
            # Cleanup temp directory
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            # Summary
            Write-Host '=====================================================================' -ForegroundColor DarkGray
            Write-Host "Summary: $successCount succeeded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host ''
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-ShowtimeVRMenu -SelectedDevices $SelectedDevices
}

function Show-InventoryManagementMenu {
    Clear-Host
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                    INVENTORY MANAGEMENT                             ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  [1] View complete inventory' -ForegroundColor White
    Write-Host '  [2] Register/Update device information' -ForegroundColor White
    Write-Host '  [3] Assign custom numbers to devices' -ForegroundColor White
    Write-Host '  [4] Edit device alias' -ForegroundColor White
    Write-Host '  [5] Add/Edit device notes' -ForegroundColor White
    Write-Host '  [6] Auto-scan and update inventory' -ForegroundColor White
    Write-Host '  [7] Remove device from inventory' -ForegroundColor White
    Write-Host '  [8] Export inventory to file' -ForegroundColor White
    Write-Host '  [9] Import inventory from file' -ForegroundColor White
    Write-Host ''
    Write-Host '  [0] Back to main menu' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Select option: ' -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # View complete inventory
            Clear-Host
            Write-Host ''
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host '                      DEVICE INVENTORY                               ' -ForegroundColor Cyan
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host ''
            
            if ($script:DeviceConfig.devices.Count -eq 0) {
                Write-Host 'No devices registered in inventory.' -ForegroundColor Yellow
                Write-Host 'Use option [6] to auto-scan connected devices.' -ForegroundColor Gray
            }
            else {
                Write-Host "Total devices in inventory: $($script:DeviceConfig.devices.Count)" -ForegroundColor Green
                Write-Host ''
                Write-Host '--------------------------------------------------------------------' -ForegroundColor DarkGray
                
                foreach ($device in $script:DeviceConfig.devices) {
                    Write-Host ''
                    
                    # Custom Number
                    if ($device.customNumber) {
                        Write-Host "  Device #$($device.customNumber)" -ForegroundColor Yellow -NoNewline
                        Write-Host " - " -NoNewline
                    }
                    
                    # Alias
                    if ($device.alias) {
                        Write-Host "$($device.alias)" -ForegroundColor Cyan
                    }
                    else {
                        Write-Host "(No alias)" -ForegroundColor DarkGray
                    }
                    
                    # Serial
                    Write-Host "    Serial: $($device.serial)" -ForegroundColor White
                    
                    # Model
                    if ($device.model) {
                        Write-Host "    Model: $($device.model)" -ForegroundColor White
                    }
                    
                    # Notes
                    if ($device.notes) {
                        Write-Host "    Notes: $($device.notes)" -ForegroundColor Gray
                    }
                    
                    # Dates
                    if ($device.firstSeen) {
                        Write-Host "    First seen: $($device.firstSeen)" -ForegroundColor DarkGray
                    }
                    Write-Host "    Last seen: $($device.lastSeen)" -ForegroundColor DarkGray
                    
                    Write-Host '  ------------------------------------------------------------------' -ForegroundColor DarkGray
                }
            }
            
            Write-Host ''
            Wait-UserInput
        }
        '2' {
            # Register/Update device information
            Clear-Host
            Write-Host ''
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host '                   REGISTER/UPDATE DEVICE                            ' -ForegroundColor Cyan
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host ''
            
            # Get current connected devices
            $connectedDevices = Refresh-Devices
            
            if ($connectedDevices.Count -eq 0) {
                Write-Host 'No devices connected!' -ForegroundColor Red
                Wait-UserInput
                Show-InventoryManagementMenu
                return
            }
            
            # Show devices
            Write-Host 'Connected devices:' -ForegroundColor Yellow
            Write-Host ''
            for ($i = 0; $i -lt $connectedDevices.Count; $i++) {
                $device = $connectedDevices[$i]
                Write-Host "  [$($i + 1)] $($device.Model) - $($device.Serial)" -ForegroundColor White
            }
            Write-Host ''
            Write-Host '  [0] Cancel' -ForegroundColor Red
            Write-Host ''
            Write-Host 'Select device to register/update: ' -NoNewline -ForegroundColor Yellow
            $deviceChoice = Read-Host
            
            if ($deviceChoice -eq '0' -or $deviceChoice -eq '') {
                Show-InventoryManagementMenu
                return
            }
            
            $deviceIndex = [int]$deviceChoice - 1
            if ($deviceIndex -ge 0 -and $deviceIndex -lt $connectedDevices.Count) {
                $selectedDevice = $connectedDevices[$deviceIndex]
                
                Write-Host ''
                Write-Host "Registering: $($selectedDevice.Model) - $($selectedDevice.Serial)" -ForegroundColor Cyan
                Write-Host ''
                
                # Get existing info
                $existingDevice = $script:DeviceConfig.devices | Where-Object { $_.serial -eq $selectedDevice.Serial }
                
                # Alias
                Write-Host 'Enter device alias (e.g., Quest-VR-01): ' -NoNewline -ForegroundColor Yellow
                if ($existingDevice -and $existingDevice.alias) {
                    Write-Host "[Current: $($existingDevice.alias)]" -ForegroundColor Gray
                    Write-Host 'New alias (or press Enter to keep current): ' -NoNewline -ForegroundColor Yellow
                }
                $alias = Read-Host
                if (-not $alias -and $existingDevice) {
                    $alias = $existingDevice.alias
                }
                
                # Custom Number
                Write-Host 'Enter custom number (e.g., 1, 2, 3...): ' -NoNewline -ForegroundColor Yellow
                if ($existingDevice -and $existingDevice.customNumber) {
                    Write-Host "[Current: $($existingDevice.customNumber)]" -ForegroundColor Gray
                    Write-Host 'New number (or press Enter to keep current): ' -NoNewline -ForegroundColor Yellow
                }
                $customNumber = Read-Host
                if (-not $customNumber -and $existingDevice) {
                    $customNumber = $existingDevice.customNumber
                }
                
                # Notes
                Write-Host 'Enter notes (optional): ' -NoNewline -ForegroundColor Yellow
                if ($existingDevice -and $existingDevice.notes) {
                    Write-Host "[Current: $($existingDevice.notes)]" -ForegroundColor Gray
                    Write-Host 'New notes (or press Enter to keep current): ' -NoNewline -ForegroundColor Yellow
                }
                $notes = Read-Host
                if (-not $notes -and $existingDevice) {
                    $notes = $existingDevice.notes
                }
                
                # Update device
                Update-DeviceAlias -Serial $selectedDevice.Serial -Alias $alias -CustomNumber $customNumber -Model $selectedDevice.Model -Notes $notes
                
                Write-Host ''
                Write-Host 'Device registered successfully!' -ForegroundColor Green
                Write-Host ''
            }
            else {
                Write-Host 'Invalid selection!' -ForegroundColor Red
            }
            
            Wait-UserInput
        }
        '3' {
            # Assign custom numbers
            Clear-Host
            Write-Host ''
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host '                  ASSIGN CUSTOM NUMBERS                              ' -ForegroundColor Cyan
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host ''
            
            if ($script:DeviceConfig.devices.Count -eq 0) {
                Write-Host 'No devices in inventory. Register devices first!' -ForegroundColor Yellow
                Wait-UserInput
                Show-InventoryManagementMenu
                return
            }
            
            Write-Host 'Current devices:' -ForegroundColor Yellow
            Write-Host ''
            
            $devicesArray = @($script:DeviceConfig.devices)
            for ($i = 0; $i -lt $devicesArray.Count; $i++) {
                $device = $devicesArray[$i]
                $displayName = if ($device.alias) { $device.alias } else { $device.serial }
                $currentNum = if ($device.customNumber) { "#$($device.customNumber)" } else { "(no number)" }
                Write-Host "  [$($i + 1)] $displayName $currentNum" -ForegroundColor White
            }
            
            Write-Host ''
            Write-Host '  [0] Done' -ForegroundColor Green
            Write-Host ''
            Write-Host 'Select device to assign number (or 0 to finish): ' -NoNewline -ForegroundColor Yellow
            $deviceChoice = Read-Host
            
            if ($deviceChoice -eq '0' -or $deviceChoice -eq '') {
                Show-InventoryManagementMenu
                return
            }
            
            $deviceIndex = [int]$deviceChoice - 1
            if ($deviceIndex -ge 0 -and $deviceIndex -lt $devicesArray.Count) {
                $device = $devicesArray[$deviceIndex]
                
                Write-Host "Enter custom number for $($device.alias): " -NoNewline -ForegroundColor Yellow
                $customNumber = Read-Host
                
                if ($customNumber) {
                    Update-DeviceAlias -Serial $device.serial -Alias $device.alias -CustomNumber $customNumber -Model $device.model -Notes $device.notes
                    Write-Host "Number assigned successfully!" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
            }
            
            # Loop back to allow assigning more numbers
            Show-InventoryManagementMenu
        }
        '4' {
            # Edit device alias
            Clear-Host
            Write-Host ''
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host '                     EDIT DEVICE ALIAS                               ' -ForegroundColor Cyan
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host ''
            
            if ($script:DeviceConfig.devices.Count -eq 0) {
                Write-Host 'No devices in inventory!' -ForegroundColor Yellow
                Wait-UserInput
                Show-InventoryManagementMenu
                return
            }
            
            $devicesArray = @($script:DeviceConfig.devices)
            for ($i = 0; $i -lt $devicesArray.Count; $i++) {
                $device = $devicesArray[$i]
                Write-Host "  [$($i + 1)] $($device.alias) ($($device.serial))" -ForegroundColor White
            }
            
            Write-Host ''
            Write-Host '  [0] Cancel' -ForegroundColor Red
            Write-Host ''
            Write-Host 'Select device: ' -NoNewline -ForegroundColor Yellow
            $deviceChoice = Read-Host
            
            if ($deviceChoice -eq '0' -or $deviceChoice -eq '') {
                Show-InventoryManagementMenu
                return
            }
            
            $deviceIndex = [int]$deviceChoice - 1
            if ($deviceIndex -ge 0 -and $deviceIndex -lt $devicesArray.Count) {
                $device = $devicesArray[$deviceIndex]
                
                Write-Host "Current alias: $($device.alias)" -ForegroundColor Gray
                Write-Host 'Enter new alias: ' -NoNewline -ForegroundColor Yellow
                $newAlias = Read-Host
                
                if ($newAlias) {
                    Update-DeviceAlias -Serial $device.serial -Alias $newAlias -CustomNumber $device.customNumber -Model $device.model -Notes $device.notes
                    Write-Host 'Alias updated successfully!' -ForegroundColor Green
                }
            }
            
            Wait-UserInput
        }
        '5' {
            # Add/Edit notes
            Clear-Host
            Write-Host ''
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host '                    EDIT DEVICE NOTES                                ' -ForegroundColor Cyan
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host ''
            
            if ($script:DeviceConfig.devices.Count -eq 0) {
                Write-Host 'No devices in inventory!' -ForegroundColor Yellow
                Wait-UserInput
                Show-InventoryManagementMenu
                return
            }
            
            $devicesArray = @($script:DeviceConfig.devices)
            for ($i = 0; $i -lt $devicesArray.Count; $i++) {
                $device = $devicesArray[$i]
                $notePreview = if ($device.notes) { "- $($device.notes.Substring(0, [Math]::Min(30, $device.notes.Length)))..." } else { "" }
                Write-Host "  [$($i + 1)] $($device.alias) $notePreview" -ForegroundColor White
            }
            
            Write-Host ''
            Write-Host '  [0] Cancel' -ForegroundColor Red
            Write-Host ''
            Write-Host 'Select device: ' -NoNewline -ForegroundColor Yellow
            $deviceChoice = Read-Host
            
            if ($deviceChoice -eq '0' -or $deviceChoice -eq '') {
                Show-InventoryManagementMenu
                return
            }
            
            $deviceIndex = [int]$deviceChoice - 1
            if ($deviceIndex -ge 0 -and $deviceIndex -lt $devicesArray.Count) {
                $device = $devicesArray[$deviceIndex]
                
                if ($device.notes) {
                    Write-Host "Current notes: $($device.notes)" -ForegroundColor Gray
                }
                Write-Host 'Enter notes: ' -NoNewline -ForegroundColor Yellow
                $newNotes = Read-Host
                
                if ($newNotes) {
                    Update-DeviceAlias -Serial $device.serial -Alias $device.alias -CustomNumber $device.customNumber -Model $device.model -Notes $newNotes
                    Write-Host 'Notes updated successfully!' -ForegroundColor Green
                }
            }
            
            Wait-UserInput
        }
        '6' {
            # Auto-scan and update inventory
            Clear-Host
            Write-Host ''
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host '                   AUTO-SCAN INVENTORY                               ' -ForegroundColor Cyan
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host ''
            
            Write-Host 'Scanning for connected devices...' -ForegroundColor Yellow
            $connectedDevices = Refresh-Devices
            
            Write-Host "Found $($connectedDevices.Count) connected device(s)" -ForegroundColor Green
            Write-Host ''
            
            $newDevices = 0
            $updatedDevices = 0
            
            foreach ($device in $connectedDevices) {
                $existingDevice = $script:DeviceConfig.devices | Where-Object { $_.serial -eq $device.Serial }
                
                if ($existingDevice) {
                    # Update last seen
                    $existingDevice.lastSeen = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    if (-not $existingDevice.model) {
                        $existingDevice.model = $device.Model
                    }
                    $updatedDevices++
                    Write-Host "  [UPDATED] $($device.Serial) - $($device.Model)" -ForegroundColor Cyan
                }
                else {
                    # Add new device with auto-generated alias
                    $autoAlias = "$($device.Model)-$($device.Serial.Substring($device.Serial.Length - 6))"
                    Update-DeviceAlias -Serial $device.Serial -Alias $autoAlias -Model $device.Model
                    $newDevices++
                    Write-Host "  [NEW] $($device.Serial) - $($device.Model)" -ForegroundColor Green
                    Write-Host "        Auto-assigned alias: $autoAlias" -ForegroundColor Gray
                }
            }
            
            Save-Configuration
            
            Write-Host ''
            Write-Host '--------------------------------------------------------------------' -ForegroundColor DarkGray
            Write-Host "New devices added: $newDevices" -ForegroundColor Green
            Write-Host "Existing devices updated: $updatedDevices" -ForegroundColor Cyan
            Write-Host "Total devices in inventory: $($script:DeviceConfig.devices.Count)" -ForegroundColor Yellow
            Write-Host ''
            Write-Host 'Note: You can customize aliases and assign numbers using options 2-3' -ForegroundColor Gray
            
            Wait-UserInput
        }
        '7' {
            # Remove device from inventory
            Clear-Host
            Write-Host ''
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host '                   REMOVE DEVICE FROM INVENTORY                      ' -ForegroundColor Cyan
            Write-Host '=====================================================================' -ForegroundColor Cyan
            Write-Host ''
            
            if ($script:DeviceConfig.devices.Count -eq 0) {
                Write-Host 'No devices in inventory!' -ForegroundColor Yellow
                Wait-UserInput
                Show-InventoryManagementMenu
                return
            }
            
            $devicesArray = @($script:DeviceConfig.devices)
            for ($i = 0; $i -lt $devicesArray.Count; $i++) {
                $device = $devicesArray[$i]
                Write-Host "  [$($i + 1)] $($device.alias) ($($device.serial))" -ForegroundColor White
            }
            
            Write-Host ''
            Write-Host '  [0] Cancel' -ForegroundColor Red
            Write-Host ''
            Write-Host 'Select device to remove: ' -NoNewline -ForegroundColor Yellow
            $deviceChoice = Read-Host
            
            if ($deviceChoice -eq '0' -or $deviceChoice -eq '') {
                Show-InventoryManagementMenu
                return
            }
            
            $deviceIndex = [int]$deviceChoice - 1
            if ($deviceIndex -ge 0 -and $deviceIndex -lt $devicesArray.Count) {
                $device = $devicesArray[$deviceIndex]
                
                if (Show-ConfirmationDialog -Message "Remove device '$($device.alias)' from inventory?") {
                    $script:DeviceConfig.devices = @($script:DeviceConfig.devices | Where-Object { $_.serial -ne $device.serial })
                    Save-Configuration
                    Write-Host 'Device removed from inventory!' -ForegroundColor Green
                }
            }
            
            Wait-UserInput
        }
        '8' {
            # Export inventory
            Write-Host ''
            Write-Host 'Exporting inventory...' -ForegroundColor Yellow
            
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            $exportPath = Join-Path $ScriptDir "Inventory_Export_$timestamp.json"
            
            $script:DeviceConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $exportPath -Encoding UTF8
            
            Write-Host "Inventory exported to: $exportPath" -ForegroundColor Green
            Wait-UserInput
        }
        '9' {
            # Import inventory
            Write-Host ''
            Write-Host 'Enter path to inventory file: ' -NoNewline -ForegroundColor Yellow
            $importPath = Read-Host
            
            if (Test-Path $importPath) {
                try {
                    $importedConfig = Get-Content $importPath -Raw | ConvertFrom-Json
                    
                    if (Show-ConfirmationDialog -Message "This will merge imported devices with current inventory. Continue?") {
                        foreach ($importedDevice in $importedConfig.devices) {
                            $existingDevice = $script:DeviceConfig.devices | Where-Object { $_.serial -eq $importedDevice.serial }
                            
                            if (-not $existingDevice) {
                                $script:DeviceConfig.devices += $importedDevice
                            }
                        }
                        
                        Save-Configuration
                        Write-Host 'Inventory imported successfully!' -ForegroundColor Green
                    }
                }
                catch {
                    Write-Host "Error importing inventory: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host 'File not found!' -ForegroundColor Red
            }
            
            Wait-UserInput
        }
        '0' { return }
    }
    
    Show-InventoryManagementMenu
}

# Main program loop
function Start-QuasMultiDevice {
    Clear-Host
    
    # Show header
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host '                                                                     ' -ForegroundColor Cyan
    Write-Host '              QUAS MULTI-DEVICE MANAGER v1.0                         ' -ForegroundColor Cyan
    Write-Host '              Managing Multiple Quest Devices                        ' -ForegroundColor Cyan
    Write-Host '                                                                     ' -ForegroundColor Cyan
    Write-Host '=====================================================================' -ForegroundColor Cyan
    Write-Host ''
    
    # Load configuration
    Load-Configuration
    
    # Main loop
    $continue = $true
    while ($continue) {
        # Refresh devices
        $script:AllDevices = Refresh-Devices
        
        if ($script:AllDevices.Count -eq 0) {
            Write-Host 'No devices detected!' -ForegroundColor Red
            Write-Host ''
            Write-Host 'Options:' -ForegroundColor Yellow
            Write-Host '  [R] Restart ADB and retry' -ForegroundColor White
            Write-Host '  [Q] Quit' -ForegroundColor White
            Write-Host ''
            Write-Host 'Choice: ' -NoNewline -ForegroundColor Yellow
            $choice = Read-Host
            
            if ($choice -eq 'R' -or $choice -eq 'r') {
                Restart-AdbServer
                continue
            }
            else {
                break
            }
        }
        
        # Select devices
        $script:SelectedDevices = Show-DeviceSelectionMenu -Devices $script:AllDevices -AllowMultiple -DeviceConfig $script:DeviceConfig
        
        if ($script:SelectedDevices.Count -eq 0) {
            Write-Host 'No devices selected. Exiting...' -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            break
        }
        
        # Show command menu
        $categoryChoice = Show-CommandCategoryMenu
        
        switch ($categoryChoice) {
            '1' { Show-ScreenshotMediaMenu -SelectedDevices $script:SelectedDevices }
            '2' { Show-AppManagementMenu -SelectedDevices $script:SelectedDevices }
            '4' { Show-SystemInfoMenu -SelectedDevices $script:SelectedDevices }
            '5' { Show-DeviceSettingsMenu -SelectedDevices $script:SelectedDevices }
            '6' { Show-StreamingConnectivityMenu -SelectedDevices $script:SelectedDevices }
            '7' { Show-TextInputMenu -SelectedDevices $script:SelectedDevices }
            '8' { Show-AdvancedToolsMenu -SelectedDevices $script:SelectedDevices }
            'O' { 
                Show-OpenBrushMenu -SelectedDevices $script:SelectedDevices
            }
            'o' { 
                Show-OpenBrushMenu -SelectedDevices $script:SelectedDevices
            }
            'S' { 
                Show-ShowtimeVRMenu -SelectedDevices $script:SelectedDevices
            }
            's' { 
                Show-ShowtimeVRMenu -SelectedDevices $script:SelectedDevices
            }
            'D' { 
                Show-InventoryManagementMenu
            }
            'd' { 
                Show-InventoryManagementMenu
            }
            '0' { 
                $continue = $false
            }
            default {
                Write-Host 'Feature coming soon...' -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
    
    Write-Host ''
    Write-Host 'Thank you for using Quas Multi-Device Manager!' -ForegroundColor Green
    Write-Host ''
}

# Start the application
Start-QuasMultiDevice
