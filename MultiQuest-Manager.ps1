# MultiQuest Manager - Batch ADB Manager for Multiple Quest Devices
# Version 1.0.0 - Inspired by Quest ADB Scripts by Varset
# Created for managing multiple Meta Quest headsets simultaneously

param(
    [switch]$AutoDetect = $true
)

# Colors
$script:ColorTitle = "Cyan"
$script:ColorSuccess = "Green"
$script:ColorWarning = "Yellow"
$script:ColorError = "Red"
$script:ColorInfo = "White"

# Global variables
$script:ConnectedDevices = @()
$script:Version = "1.0.0"

function Show-Banner {
    Clear-Host
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $ColorTitle
    Write-Host "           MultiQuest Manager v$Version" -ForegroundColor $ColorTitle
    Write-Host "    Batch ADB Manager for Multiple Meta Quest Devices" -ForegroundColor $ColorTitle
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $ColorTitle
    Write-Host ""
}

function Get-ConnectedQuests {
    Write-Host "[*] Detecting connected Quest devices..." -ForegroundColor $ColorInfo

    $adbOutput = & adb devices 2>&1
    $devices = @()

    foreach ($line in $adbOutput) {
        if ($line -match '^([A-Z0-9]+)\s+device$') {
            $deviceId = $matches[1]

            # Get device model
            $model = & adb -s $deviceId shell getprop ro.product.model 2>$null
            $brand = & adb -s $deviceId shell getprop ro.product.brand 2>$null
            $androidVersion = & adb -s $deviceId shell getprop ro.build.version.release 2>$null

            $device = [PSCustomObject]@{
                ID = $deviceId
                Model = $model.Trim()
                Brand = $brand.Trim()
                Android = $androidVersion.Trim()
                Connection = "USB"
            }

            $devices += $device
        }
    }

    $script:ConnectedDevices = $devices

    if ($devices.Count -eq 0) {
        Write-Host "[!] No Quest devices detected!" -ForegroundColor $ColorError
        Write-Host "[i] Please connect your Quest device(s) via USB and enable USB debugging" -ForegroundColor $ColorWarning
    } else {
        Write-Host "[✓] Found $($devices.Count) Quest device(s):" -ForegroundColor $ColorSuccess
        $i = 1
        foreach ($dev in $devices) {
            Write-Host "    [$i] $($dev.Brand) $($dev.Model) - ID: $($dev.ID) - Android $($dev.Android)" -ForegroundColor $ColorInfo
            $i++
        }
    }

    Write-Host ""
    return $devices
}

function Show-MainMenu {
    Write-Host "══════════════════ MAIN MENU ══════════════════" -ForegroundColor $ColorTitle
    Write-Host ""
    Write-Host " [1]  📱 Device Management" -ForegroundColor $ColorInfo
    Write-Host " [2]  📦 App Management (Batch Install/Uninstall)" -ForegroundColor $ColorInfo
    Write-Host " [3]  📁 File Operations (Batch Transfer)" -ForegroundColor $ColorInfo
    Write-Host " [4]  🔧 System Settings (Apply to All)" -ForegroundColor $ColorInfo
    Write-Host " [5]  📸 Screenshot/Screen Record" -ForegroundColor $ColorInfo
    Write-Host " [6]  🔐 Certificate Management" -ForegroundColor $ColorInfo
    Write-Host " [7]  🔄 Reboot Devices" -ForegroundColor $ColorInfo
    Write-Host " [8]  ℹ️  Device Information" -ForegroundColor $ColorInfo
    Write-Host " [9]  🔍 Refresh Device List" -ForegroundColor $ColorInfo
    Write-Host " [0]  ❌ Exit" -ForegroundColor $ColorError
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor $ColorTitle
    Write-Host ""

    $choice = Read-Host "Select option"
    return $choice
}

function Invoke-BatchCommand {
    param(
        [string]$Description,
        [scriptblock]$Command,
        [array]$Devices = $script:ConnectedDevices,
        [switch]$Parallel
    )

    Write-Host ""
    Write-Host "[*] $Description..." -ForegroundColor $ColorInfo
    Write-Host "────────────────────────────────────────────────" -ForegroundColor $ColorTitle

    if ($Devices.Count -eq 0) {
        Write-Host "[!] No devices selected!" -ForegroundColor $ColorError
        return
    }

    $results = @()

    if ($Parallel) {
        # Execute in parallel
        $jobs = @()
        foreach ($device in $Devices) {
            $jobs += Start-Job -ScriptBlock {
                param($dev, $cmd)
                $deviceId = $dev.ID
                & $cmd $dev
            } -ArgumentList $device, $Command
        }

        # Wait for all jobs
        $jobs | Wait-Job | ForEach-Object {
            $result = Receive-Job $_
            $results += $result
            Remove-Job $_
        }
    } else {
        # Execute sequentially
        foreach ($device in $Devices) {
            Write-Host "[→] Processing: $($device.Model) ($($device.ID))" -ForegroundColor $ColorWarning
            try {
                $result = & $Command $device
                Write-Host "[✓] Success: $($device.Model)" -ForegroundColor $ColorSuccess
                $results += $result
            } catch {
                Write-Host "[✗] Failed: $($device.Model) - $($_.Exception.Message)" -ForegroundColor $ColorError
            }
            Write-Host ""
        }
    }

    Write-Host "────────────────────────────────────────────────" -ForegroundColor $ColorTitle
    Write-Host "[✓] Batch operation completed!" -ForegroundColor $ColorSuccess
    Write-Host ""

    return $results
}

function Menu-AppManagement {
    while ($true) {
        Show-Banner
        Write-Host "════════════ APP MANAGEMENT (BATCH) ═══════════" -ForegroundColor $ColorTitle
        Write-Host ""
        Write-Host " [1]  Install APK to all devices" -ForegroundColor $ColorInfo
        Write-Host " [2]  Uninstall app from all devices" -ForegroundColor $ColorInfo
        Write-Host " [3]  List installed apps" -ForegroundColor $ColorInfo
        Write-Host " [4]  Backup app data (all devices)" -ForegroundColor $ColorInfo
        Write-Host " [5]  Restore app data (all devices)" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                $apkPath = Read-Host "Enter APK path"
                if (Test-Path $apkPath) {
                    Invoke-BatchCommand -Description "Installing APK to all devices" -Command {
                        param($dev)
                        & adb -s $dev.ID install -r "$apkPath"
                    }
                } else {
                    Write-Host "[!] APK file not found!" -ForegroundColor $ColorError
                }
                Pause
            }
            "2" {
                $packageName = Read-Host "Enter package name (e.g., com.example.app)"
                Invoke-BatchCommand -Description "Uninstalling app from all devices" -Command {
                    param($dev)
                    & adb -s $dev.ID uninstall "$packageName"
                }
                Pause
            }
            "3" {
                Invoke-BatchCommand -Description "Listing installed apps" -Command {
                    param($dev)
                    Write-Host "`nInstalled packages on $($dev.Model):" -ForegroundColor $ColorInfo
                    & adb -s $dev.ID shell pm list packages | Select-Object -First 20
                    Write-Host "(Showing first 20 packages...)" -ForegroundColor $ColorWarning
                }
                Pause
            }
            "0" { return }
        }
    }
}

function Menu-FileOperations {
    while ($true) {
        Show-Banner
        Write-Host "═══════════ FILE OPERATIONS (BATCH) ═══════════" -ForegroundColor $ColorTitle
        Write-Host ""
        Write-Host " [1]  Push file to all devices" -ForegroundColor $ColorInfo
        Write-Host " [2]  Pull file from all devices" -ForegroundColor $ColorInfo
        Write-Host " [3]  Delete file from all devices" -ForegroundColor $ColorInfo
        Write-Host " [4]  List files" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                $localPath = Read-Host "Enter local file path"
                $remotePath = Read-Host "Enter remote path (e.g., /sdcard/Download/)"

                if (Test-Path $localPath) {
                    Invoke-BatchCommand -Description "Pushing file to all devices" -Command {
                        param($dev)
                        & adb -s $dev.ID push "$localPath" "$remotePath"
                    }
                } else {
                    Write-Host "[!] File not found!" -ForegroundColor $ColorError
                }
                Pause
            }
            "2" {
                $remotePath = Read-Host "Enter remote file path"
                $localFolder = Read-Host "Enter local folder to save files"

                if (!(Test-Path $localFolder)) {
                    New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
                }

                Invoke-BatchCommand -Description "Pulling file from all devices" -Command {
                    param($dev)
                    $outputPath = Join-Path $localFolder "$($dev.ID)_$(Split-Path $remotePath -Leaf)"
                    & adb -s $dev.ID pull "$remotePath" "$outputPath"
                }
                Pause
            }
            "3" {
                $remotePath = Read-Host "Enter remote file path to delete"
                $confirm = Read-Host "Are you sure? (yes/no)"

                if ($confirm -eq "yes") {
                    Invoke-BatchCommand -Description "Deleting file from all devices" -Command {
                        param($dev)
                        & adb -s $dev.ID shell rm -f "$remotePath"
                    }
                }
                Pause
            }
            "4" {
                $remotePath = Read-Host "Enter remote path (e.g., /sdcard/Download/)"
                Invoke-BatchCommand -Description "Listing files" -Command {
                    param($dev)
                    Write-Host "`nFiles on $($dev.Model):" -ForegroundColor $ColorInfo
                    & adb -s $dev.ID shell "ls -lah $remotePath"
                }
                Pause
            }
            "0" { return }
        }
    }
}

function Menu-CertificateManagement {
    while ($true) {
        Show-Banner
        Write-Host "═══════════ CERTIFICATE MANAGEMENT ════════════" -ForegroundColor $ColorTitle
        Write-Host ""
        Write-Host " [1]  Push certificate to all devices" -ForegroundColor $ColorInfo
        Write-Host " [2]  Open certificate installer (all devices)" -ForegroundColor $ColorInfo
        Write-Host " [3]  View installed certificates" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                $certPath = Read-Host "Enter certificate path (.p12, .pfx, .crt, .pem)"
                if (Test-Path $certPath) {
                    Invoke-BatchCommand -Description "Pushing certificate to all devices" -Command {
                        param($dev)
                        & adb -s $dev.ID push "$certPath" "/sdcard/Download/"
                    }
                } else {
                    Write-Host "[!] Certificate file not found!" -ForegroundColor $ColorError
                }
                Pause
            }
            "2" {
                Invoke-BatchCommand -Description "Opening certificate installer" -Command {
                    param($dev)
                    & adb -s $dev.ID shell am start -n com.android.certinstaller/.CertInstallerMain
                }
                Write-Host "`n[i] Check your Quest headsets to complete installation" -ForegroundColor $ColorWarning
                Pause
            }
            "3" {
                Invoke-BatchCommand -Description "Viewing installed certificates" -Command {
                    param($dev)
                    & adb -s $dev.ID shell am start -n "com.android.settings/.Settings\`$TrustedCredentialsSettingsActivity"
                }
                Write-Host "`n[i] Check your Quest headsets to view certificates" -ForegroundColor $ColorWarning
                Pause
            }
            "0" { return }
        }
    }
}

function Menu-DeviceManagement {
    while ($true) {
        Show-Banner
        Write-Host "══════════════ DEVICE MANAGEMENT ══════════════" -ForegroundColor $ColorTitle
        Write-Host ""
        Write-Host " [1]  Connect device via Wi-Fi (wireless ADB)" -ForegroundColor $ColorInfo
        Write-Host " [2]  Disconnect wireless device" -ForegroundColor $ColorInfo
        Write-Host " [3]  Enable/Disable USB debugging" -ForegroundColor $ColorInfo
        Write-Host " [4]  Check ADB authorization" -ForegroundColor $ColorInfo
        Write-Host " [5]  Restart ADB server" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                Write-Host ""
                Write-Host "[*] Wireless ADB Setup" -ForegroundColor $ColorInfo
                Write-Host "────────────────────────────────────────────────" -ForegroundColor $ColorTitle

                Invoke-BatchCommand -Description "Enabling wireless ADB on all devices" -Command {
                    param($dev)
                    # Enable TCP/IP mode on port 5555
                    & adb -s $dev.ID tcpip 5555
                    Start-Sleep -Seconds 2

                    # Get device IP
                    $ip = & adb -s $dev.ID shell ip addr show wlan0 | Select-String "inet " | ForEach-Object {
                        $_.ToString().Trim().Split()[1].Split('/')[0]
                    }

                    Write-Host "[i] Device IP: $ip - You can now connect via: adb connect $ip`:5555" -ForegroundColor $ColorInfo
                }

                Write-Host ""
                Write-Host "[i] To connect wirelessly, disconnect USB and run:" -ForegroundColor $ColorWarning
                Write-Host "    adb connect <DEVICE_IP>:5555" -ForegroundColor $ColorInfo
                Pause
            }
            "2" {
                $ip = Read-Host "Enter device IP address to disconnect"
                & adb disconnect "$ip`:5555"
                Write-Host "[✓] Disconnected from $ip" -ForegroundColor $ColorSuccess
                Pause
            }
            "3" {
                Write-Host ""
                Write-Host "[i] USB Debugging settings opened on all devices" -ForegroundColor $ColorInfo
                Write-Host "[i] Check your Quest headsets to toggle USB debugging" -ForegroundColor $ColorWarning

                Invoke-BatchCommand -Description "Opening developer settings" -Command {
                    param($dev)
                    & adb -s $dev.ID shell am start -n com.android.settings/.Settings
                }
                Pause
            }
            "4" {
                Write-Host ""
                & adb devices -l
                Write-Host ""
                Write-Host "[i] Devices with 'unauthorized' need to accept USB debugging prompt" -ForegroundColor $ColorWarning
                Pause
            }
            "5" {
                Write-Host ""
                Write-Host "[*] Restarting ADB server..." -ForegroundColor $ColorInfo
                & adb kill-server
                Start-Sleep -Seconds 1
                & adb start-server
                Write-Host "[✓] ADB server restarted" -ForegroundColor $ColorSuccess
                Pause
            }
            "0" { return }
        }
    }
}

function Menu-SystemSettings {
    while ($true) {
        Show-Banner
        Write-Host "════════════ SYSTEM SETTINGS (BATCH) ═════════" -ForegroundColor $ColorTitle
        Write-Host ""
        Write-Host " [1]  Set screen brightness" -ForegroundColor $ColorInfo
        Write-Host " [2]  Set volume level" -ForegroundColor $ColorInfo
        Write-Host " [3]  Enable/Disable Wi-Fi" -ForegroundColor $ColorInfo
        Write-Host " [4]  Set time zone" -ForegroundColor $ColorInfo
        Write-Host " [5]  Clear app cache (all apps)" -ForegroundColor $ColorInfo
        Write-Host " [6]  Grant app permissions" -ForegroundColor $ColorInfo
        Write-Host " [7]  Set developer options" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                $brightness = Read-Host "Enter brightness level (0-255)"
                if ($brightness -match '^\d+$' -and [int]$brightness -ge 0 -and [int]$brightness -le 255) {
                    Invoke-BatchCommand -Description "Setting brightness to $brightness" -Command {
                        param($dev)
                        & adb -s $dev.ID shell settings put system screen_brightness $brightness
                    }
                } else {
                    Write-Host "[!] Invalid brightness value!" -ForegroundColor $ColorError
                }
                Pause
            }
            "2" {
                $volume = Read-Host "Enter volume level (0-15)"
                if ($volume -match '^\d+$' -and [int]$volume -ge 0 -and [int]$volume -le 15) {
                    Invoke-BatchCommand -Description "Setting volume to $volume" -Command {
                        param($dev)
                        & adb -s $dev.ID shell media volume --set $volume
                    }
                } else {
                    Write-Host "[!] Invalid volume value!" -ForegroundColor $ColorError
                }
                Pause
            }
            "3" {
                Write-Host ""
                Write-Host " [1] Enable Wi-Fi"
                Write-Host " [2] Disable Wi-Fi"
                $wifiChoice = Read-Host "Select option"

                $enable = if ($wifiChoice -eq "1") { "enable" } else { "disable" }

                Invoke-BatchCommand -Description "$enable Wi-Fi on all devices" -Command {
                    param($dev)
                    & adb -s $dev.ID shell svc wifi $enable
                }
                Pause
            }
            "4" {
                $timezone = Read-Host "Enter timezone (e.g., America/New_York, Europe/Madrid)"
                Invoke-BatchCommand -Description "Setting timezone to $timezone" -Command {
                    param($dev)
                    & adb -s $dev.ID shell setprop persist.sys.timezone $timezone
                }
                Pause
            }
            "5" {
                $confirm = Read-Host "Clear cache for all apps on all devices? (yes/no)"
                if ($confirm -eq "yes") {
                    Invoke-BatchCommand -Description "Clearing app cache" -Command {
                        param($dev)
                        # Get list of packages and clear cache
                        $packages = & adb -s $dev.ID shell pm list packages | ForEach-Object { $_.Replace("package:", "") }
                        foreach ($pkg in $packages) {
                            & adb -s $dev.ID shell pm clear $pkg 2>$null
                        }
                    }
                }
                Pause
            }
            "6" {
                $package = Read-Host "Enter package name (e.g., com.example.app)"
                $permission = Read-Host "Enter permission (e.g., android.permission.CAMERA)"

                Invoke-BatchCommand -Description "Granting $permission to $package" -Command {
                    param($dev)
                    & adb -s $dev.ID shell pm grant $package $permission
                }
                Pause
            }
            "7" {
                Invoke-BatchCommand -Description "Opening developer options" -Command {
                    param($dev)
                    & adb -s $dev.ID shell am start -n com.android.settings/.Settings
                }
                Write-Host "`n[i] Check your Quest headsets to modify developer options" -ForegroundColor $ColorWarning
                Pause
            }
            "0" { return }
        }
    }
}

function Menu-Screenshot {
    while ($true) {
        Show-Banner
        Write-Host "═══════ SCREENSHOT / SCREEN RECORD (BATCH) ════" -ForegroundColor $ColorTitle
        Write-Host ""
        Write-Host " [1]  Take screenshot (all devices)" -ForegroundColor $ColorInfo
        Write-Host " [2]  Start screen recording (all devices)" -ForegroundColor $ColorInfo
        Write-Host " [3]  Stop screen recording (all devices)" -ForegroundColor $ColorInfo
        Write-Host " [4]  Pull screenshots/recordings" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

                Invoke-BatchCommand -Description "Taking screenshots" -Command {
                    param($dev)
                    $filename = "screenshot_$timestamp.png"
                    & adb -s $dev.ID shell screencap -p /sdcard/Download/$filename
                    Write-Host "[i] Screenshot saved: /sdcard/Download/$filename" -ForegroundColor $ColorInfo
                }

                Write-Host ""
                $pull = Read-Host "Pull screenshots to PC? (yes/no)"
                if ($pull -eq "yes") {
                    $localFolder = ".\Screenshots_$timestamp"
                    New-Item -ItemType Directory -Path $localFolder -Force | Out-Null

                    Invoke-BatchCommand -Description "Pulling screenshots" -Command {
                        param($dev)
                        $filename = "screenshot_$timestamp.png"
                        $outputPath = Join-Path $localFolder "$($dev.ID)_$filename"
                        & adb -s $dev.ID pull /sdcard/Download/$filename $outputPath
                    }

                    Write-Host "[✓] Screenshots saved to: $localFolder" -ForegroundColor $ColorSuccess
                }
                Pause
            }
            "2" {
                $duration = Read-Host "Enter recording duration in seconds (max 180)"
                if ($duration -match '^\d+$' -and [int]$duration -gt 0 -and [int]$duration -le 180) {
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

                    Write-Host ""
                    Write-Host "[*] Starting screen recording on all devices..." -ForegroundColor $ColorInfo
                    Write-Host "[*] Recording will run for $duration seconds" -ForegroundColor $ColorWarning
                    Write-Host ""

                    Invoke-BatchCommand -Description "Starting screen recording" -Command {
                        param($dev)
                        $filename = "recording_$timestamp.mp4"
                        Start-Process -FilePath "adb" -ArgumentList "-s", $dev.ID, "shell", "screenrecord", "--time-limit", $duration, "/sdcard/Download/$filename" -NoNewWindow
                    } -Parallel

                    Write-Host "[i] Recordings in progress..." -ForegroundColor $ColorInfo
                    Write-Host "[i] Use option 3 to stop early or wait $duration seconds" -ForegroundColor $ColorInfo
                } else {
                    Write-Host "[!] Invalid duration!" -ForegroundColor $ColorError
                }
                Pause
            }
            "3" {
                Invoke-BatchCommand -Description "Stopping screen recording" -Command {
                    param($dev)
                    # Kill screenrecord process
                    & adb -s $dev.ID shell pkill -SIGINT screenrecord
                }

                Write-Host "[✓] Recordings stopped" -ForegroundColor $ColorSuccess
                Write-Host "[i] Use option 4 to pull recordings" -ForegroundColor $ColorInfo
                Pause
            }
            "4" {
                $localFolder = Read-Host "Enter local folder to save files"

                if (!(Test-Path $localFolder)) {
                    New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
                }

                Invoke-BatchCommand -Description "Pulling media files" -Command {
                    param($dev)
                    # Create device-specific subfolder
                    $deviceFolder = Join-Path $localFolder $dev.ID
                    New-Item -ItemType Directory -Path $deviceFolder -Force | Out-Null

                    # Pull all screenshots and recordings
                    & adb -s $dev.ID pull /sdcard/Download/ $deviceFolder
                }

                Write-Host "[✓] Files saved to: $localFolder" -ForegroundColor $ColorSuccess
                Pause
            }
            "0" { return }
        }
    }
}

function Menu-DeviceInformation {
    Show-Banner
    Write-Host "═══════════════ DEVICE INFORMATION ════════════" -ForegroundColor $ColorTitle
    Write-Host ""

    foreach ($device in $script:ConnectedDevices) {
        Write-Host "┌─────────────────────────────────────────────┐" -ForegroundColor $ColorTitle
        Write-Host "│ Device: $($device.Model) ($($device.ID))" -ForegroundColor $ColorInfo
        Write-Host "├─────────────────────────────────────────────┤" -ForegroundColor $ColorTitle

        $battery = & adb -s $device.ID shell dumpsys battery | Select-String "level"
        $ipAddress = & adb -s $device.ID shell ip addr show wlan0 | Select-String "inet " | ForEach-Object { $_.ToString().Trim().Split()[1] }
        $storage = & adb -s $device.ID shell df /data | Select-Object -Last 1

        Write-Host "│ Brand: $($device.Brand)" -ForegroundColor $ColorInfo
        Write-Host "│ Android: $($device.Android)" -ForegroundColor $ColorInfo
        Write-Host "│ Battery: $battery" -ForegroundColor $ColorInfo
        Write-Host "│ IP Address: $ipAddress" -ForegroundColor $ColorInfo
        Write-Host "│ Storage: $storage" -ForegroundColor $ColorInfo
        Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor $ColorTitle
        Write-Host ""
    }

    Pause
}

# Main Program
Show-Banner

if ($AutoDetect) {
    Get-ConnectedQuests
}

while ($true) {
    Show-Banner
    Write-Host "[i] Connected devices: $($script:ConnectedDevices.Count)" -ForegroundColor $ColorInfo
    Write-Host ""

    $choice = Show-MainMenu

    switch ($choice) {
        "1" {
            Menu-DeviceManagement
        }
        "2" {
            Menu-AppManagement
        }
        "3" {
            Menu-FileOperations
        }
        "4" {
            Menu-SystemSettings
        }
        "5" {
            Menu-Screenshot
        }
        "6" {
            Menu-CertificateManagement
        }
        "7" {
            # Reboot
            $confirm = Read-Host "Reboot all devices? (yes/no)"
            if ($confirm -eq "yes") {
                Invoke-BatchCommand -Description "Rebooting all devices" -Command {
                    param($dev)
                    & adb -s $dev.ID reboot
                }
            }
            Pause
        }
        "8" {
            Menu-DeviceInformation
        }
        "9" {
            Get-ConnectedQuests
            Pause
        }
        "0" {
            Write-Host "`n[✓] Goodbye!" -ForegroundColor $ColorSuccess
            exit
        }
    }
}
