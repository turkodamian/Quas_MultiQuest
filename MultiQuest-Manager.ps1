# MultiQuest Manager - Batch ADB Manager for Multiple Quest Devices
# Version 1.2.0 - Based on Quest ADB Scripts by Varset v5.2.0
# Created for managing multiple Meta Quest headsets simultaneously
# Uses the same proven ADB commands from QUAS

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
$script:Version = "1.2.0"

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

function Select-TargetDevices {
    param(
        [string]$OperationName
    )

    if ($script:ConnectedDevices.Count -eq 0) {
        Write-Host "[!] No devices connected!" -ForegroundColor $ColorError
        return @()
    }

    if ($script:ConnectedDevices.Count -eq 1) {
        # Only one device, use it automatically
        Write-Host "[i] Auto-selected: $($script:ConnectedDevices[0].Model) ($($script:ConnectedDevices[0].ID))" -ForegroundColor $ColorInfo
        return $script:ConnectedDevices
    }

    # Multiple devices, ask user
    Write-Host ""
    Write-Host "════════════ SELECT TARGET DEVICES ════════════" -ForegroundColor $ColorTitle
    Write-Host ""
    Write-Host "Operation: $OperationName" -ForegroundColor $ColorWarning
    Write-Host ""
    Write-Host "Connected devices:" -ForegroundColor $ColorInfo

    for ($i = 0; $i -lt $script:ConnectedDevices.Count; $i++) {
        $dev = $script:ConnectedDevices[$i]
        Write-Host "  [$($i+1)] $($dev.Brand) $($dev.Model) - $($dev.ID)" -ForegroundColor $ColorInfo
    }

    Write-Host ""
    Write-Host "  [A] Apply to ALL devices" -ForegroundColor $ColorSuccess
    Write-Host "  [0] Cancel" -ForegroundColor $ColorError
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor $ColorTitle
    Write-Host ""

    $choice = Read-Host "Select device(s) (1-$($script:ConnectedDevices.Count), A for all, or comma-separated like 1,3)"

    if ($choice -eq "0") {
        return @()
    }

    if ($choice -eq "A" -or $choice -eq "a") {
        Write-Host "[i] Selected: ALL devices ($($script:ConnectedDevices.Count))" -ForegroundColor $ColorSuccess
        return $script:ConnectedDevices
    }

    # Parse comma-separated list
    $selectedDevices = @()
    $indices = $choice -split ',' | ForEach-Object { $_.Trim() }

    foreach ($index in $indices) {
        if ($index -match '^\d+$') {
            $idx = [int]$index - 1
            if ($idx -ge 0 -and $idx -lt $script:ConnectedDevices.Count) {
                $selectedDevices += $script:ConnectedDevices[$idx]
            }
        }
    }

    if ($selectedDevices.Count -eq 0) {
        Write-Host "[!] No valid devices selected!" -ForegroundColor $ColorError
        return @()
    }

    Write-Host "[i] Selected $($selectedDevices.Count) device(s)" -ForegroundColor $ColorSuccess
    return $selectedDevices
}

function Show-MainMenu {
    Write-Host "══════════════════ MAIN MENU ══════════════════" -ForegroundColor $ColorTitle
    Write-Host ""
    Write-Host " [1]  Device Management" -ForegroundColor $ColorInfo
    Write-Host " [2]  App Management (Install/Uninstall)" -ForegroundColor $ColorInfo
    Write-Host " [3]  File Operations (Transfer)" -ForegroundColor $ColorInfo
    Write-Host " [4]  System Settings" -ForegroundColor $ColorInfo
    Write-Host " [5]  Screenshot/Screen Record" -ForegroundColor $ColorInfo
    Write-Host " [6]  Certificate Management" -ForegroundColor $ColorInfo
    Write-Host " [7]  Reboot Devices" -ForegroundColor $ColorInfo
    Write-Host " [8]  Device Information" -ForegroundColor $ColorInfo
    Write-Host " [9]  Refresh Device List" -ForegroundColor $ColorInfo
    Write-Host " [0]  Exit" -ForegroundColor $ColorError
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
                    $targetDevices = Select-TargetDevices -OperationName "Install APK: $(Split-Path $apkPath -Leaf)"
                    if ($targetDevices.Count -gt 0) {
                        Invoke-BatchCommand -Description "Installing APK" -Devices $targetDevices -Command {
                            param($dev)
                            # Using QUAS method: install -r -g --no-streaming
                            # -r = replace existing application
                            # -g = grant all runtime permissions
                            # --no-streaming = disable streaming install
                            & adb -s $dev.ID install -r -g --no-streaming "$apkPath"
                        }
                    }
                } else {
                    Write-Host "[!] APK file not found!" -ForegroundColor $ColorError
                }
                Pause
            }
            "2" {
                $packageName = Read-Host "Enter package name (e.g., com.example.app)"
                $targetDevices = Select-TargetDevices -OperationName "Uninstall: $packageName"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Uninstalling app" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID uninstall "$packageName"
                    }
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
                    $targetDevices = Select-TargetDevices -OperationName "Push: $(Split-Path $localPath -Leaf) -> $remotePath"
                    if ($targetDevices.Count -gt 0) {
                        Invoke-BatchCommand -Description "Pushing file" -Devices $targetDevices -Command {
                            param($dev)
                            & adb -s $dev.ID push "$localPath" "$remotePath"
                        }
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

                $targetDevices = Select-TargetDevices -OperationName "Pull: $remotePath"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Pulling file from devices" -Devices $targetDevices -Command {
                        param($dev)
                        $outputPath = Join-Path $localFolder "$($dev.ID)_$(Split-Path $remotePath -Leaf)"
                        & adb -s $dev.ID pull "$remotePath" "$outputPath"
                    }
                }
                Pause
            }
            "3" {
                $remotePath = Read-Host "Enter remote file path to delete"
                $confirm = Read-Host "Are you sure? (yes/no)"

                if ($confirm -eq "yes") {
                    $targetDevices = Select-TargetDevices -OperationName "Delete: $remotePath"
                    if ($targetDevices.Count -gt 0) {
                        Invoke-BatchCommand -Description "Deleting file from devices" -Devices $targetDevices -Command {
                            param($dev)
                            & adb -s $dev.ID shell rm -f "$remotePath"
                        }
                    }
                }
                Pause
            }
            "4" {
                $remotePath = Read-Host "Enter remote path (e.g., /sdcard/Download/)"
                $targetDevices = Select-TargetDevices -OperationName "List files: $remotePath"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Listing files" -Devices $targetDevices -Command {
                        param($dev)
                        Write-Host "`nFiles on $($dev.Model):" -ForegroundColor $ColorInfo
                        & adb -s $dev.ID shell "ls -lah $remotePath"
                    }
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
                    $targetDevices = Select-TargetDevices -OperationName "Push Certificate: $(Split-Path $certPath -Leaf)"
                    if ($targetDevices.Count -gt 0) {
                        Invoke-BatchCommand -Description "Pushing certificate" -Devices $targetDevices -Command {
                            param($dev)
                            & adb -s $dev.ID push "$certPath" "/sdcard/Download/"
                        }
                    }
                } else {
                    Write-Host "[!] Certificate file not found!" -ForegroundColor $ColorError
                }
                Pause
            }
            "2" {
                $targetDevices = Select-TargetDevices -OperationName "Open Certificate Installer"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Opening certificate installer" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID shell am start -n com.android.certinstaller/.CertInstallerMain
                    }
                    Write-Host "`n[i] Check your Quest headsets to complete installation" -ForegroundColor $ColorWarning
                }
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

                $targetDevices = Select-TargetDevices -OperationName "Enable Wireless ADB"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Enabling wireless ADB" -Devices $targetDevices -Command {
                        param($dev)
                        # Using QUAS method: tcpip 5555
                        & adb -s $dev.ID tcpip 5555
                        Start-Sleep -Seconds 2

                        # Get device IP address
                        $ip = & adb -s $dev.ID shell ip addr show wlan0 | Select-String "inet " | ForEach-Object {
                            $_.ToString().Trim().Split()[1].Split('/')[0]
                        }

                        if ($ip) {
                            Write-Host "[✓] Device: $($dev.Model) - IP: $ip" -ForegroundColor $ColorSuccess
                            Write-Host "[i] To connect wirelessly: adb connect $ip`:5555" -ForegroundColor $ColorInfo
                        } else {
                            Write-Host "[!] Could not determine IP for $($dev.Model)" -ForegroundColor $ColorWarning
                        }
                    }

                    Write-Host ""
                    Write-Host "[i] To connect wirelessly, disconnect USB and run:" -ForegroundColor $ColorWarning
                    Write-Host "    adb connect <DEVICE_IP>:5555" -ForegroundColor $ColorInfo
                }
                Pause
            }
            "2" {
                $ip = Read-Host "Enter device IP address to disconnect"
                & adb disconnect "$ip`:5555"
                Write-Host "[✓] Disconnected from $ip" -ForegroundColor $ColorSuccess
                Pause
            }
            "3" {
                $targetDevices = Select-TargetDevices -OperationName "Open USB Debugging Settings"
                if ($targetDevices.Count -gt 0) {
                    Write-Host ""
                    Write-Host "[i] USB Debugging settings opened on selected devices" -ForegroundColor $ColorInfo
                    Write-Host "[i] Check your Quest headsets to toggle USB debugging" -ForegroundColor $ColorWarning

                    Invoke-BatchCommand -Description "Opening developer settings" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID shell am start -n com.android.settings/.Settings
                    }
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
                    $targetDevices = Select-TargetDevices -OperationName "Set Brightness: $brightness"
                    if ($targetDevices.Count -gt 0) {
                        Invoke-BatchCommand -Description "Setting brightness to $brightness" -Devices $targetDevices -Command {
                            param($dev)
                            & adb -s $dev.ID shell settings put system screen_brightness $brightness
                        }
                    }
                } else {
                    Write-Host "[!] Invalid brightness value!" -ForegroundColor $ColorError
                }
                Pause
            }
            "2" {
                $volume = Read-Host "Enter volume level (0-15)"
                if ($volume -match '^\d+$' -and [int]$volume -ge 0 -and [int]$volume -le 15) {
                    $targetDevices = Select-TargetDevices -OperationName "Set Volume: $volume"
                    if ($targetDevices.Count -gt 0) {
                        Invoke-BatchCommand -Description "Setting volume to $volume" -Devices $targetDevices -Command {
                            param($dev)
                            & adb -s $dev.ID shell media volume --set $volume
                        }
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
                $targetDevices = Select-TargetDevices -OperationName "$enable Wi-Fi"

                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "$enable Wi-Fi" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID shell svc wifi $enable
                    }
                }
                Pause
            }
            "4" {
                $timezone = Read-Host "Enter timezone (e.g., America/New_York, Europe/Madrid)"
                $targetDevices = Select-TargetDevices -OperationName "Set Timezone: $timezone"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Setting timezone to $timezone" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID shell setprop persist.sys.timezone $timezone
                    }
                }
                Pause
            }
            "5" {
                $confirm = Read-Host "Clear cache for all apps on selected devices? (yes/no)"
                if ($confirm -eq "yes") {
                    $targetDevices = Select-TargetDevices -OperationName "Clear App Cache"
                    if ($targetDevices.Count -gt 0) {
                        Invoke-BatchCommand -Description "Clearing app cache" -Devices $targetDevices -Command {
                            param($dev)
                            # Get list of packages and clear cache
                            $packages = & adb -s $dev.ID shell pm list packages | ForEach-Object { $_.Replace("package:", "") }
                            foreach ($pkg in $packages) {
                                & adb -s $dev.ID shell pm clear $pkg 2>$null
                            }
                        }
                    }
                }
                Pause
            }
            "6" {
                $package = Read-Host "Enter package name (e.g., com.example.app)"
                $permission = Read-Host "Enter permission (e.g., android.permission.CAMERA)"

                $targetDevices = Select-TargetDevices -OperationName "Grant Permission: $permission to $package"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Granting $permission to $package" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID shell pm grant $package $permission
                    }
                }
                Pause
            }
            "7" {
                $targetDevices = Select-TargetDevices -OperationName "Open Developer Options"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Opening developer options" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID shell am start -n com.android.settings/.Settings
                    }
                    Write-Host "`n[i] Check your Quest headsets to modify developer options" -ForegroundColor $ColorWarning
                }
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
        Write-Host " [4]  Copy Oculus screenshots/videos to PC" -ForegroundColor $ColorInfo
        Write-Host " [5]  Pull custom files from devices" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $targetDevices = Select-TargetDevices -OperationName "Take Screenshot"

                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Taking screenshots" -Devices $targetDevices -Command {
                        param($dev)
                        $filename = "screenshot_$timestamp.png"
                        # Using QUAS method: exec-out screencap (faster and more reliable)
                        & adb -s $dev.ID exec-out screencap -p > "$($dev.ID)_$filename"
                        Write-Host "[i] Screenshot saved: $($dev.ID)_$filename" -ForegroundColor $ColorInfo
                    }

                    Write-Host ""
                    Write-Host "[i] Screenshots are already saved in current directory" -ForegroundColor $ColorInfo
                    Write-Host "[i] Files named: [DEVICE_ID]_screenshot_*.png" -ForegroundColor $ColorInfo
                }
                Pause
            }
            "2" {
                $duration = Read-Host "Enter recording duration in seconds (max 180)"
                if ($duration -match '^\d+$' -and [int]$duration -gt 0 -and [int]$duration -le 180) {
                    $targetDevices = Select-TargetDevices -OperationName "Start Screen Recording ($duration seconds)"

                    if ($targetDevices.Count -gt 0) {
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

                        Write-Host ""
                        Write-Host "[*] Starting screen recording on selected devices..." -ForegroundColor $ColorInfo
                        Write-Host "[*] Recording will run for $duration seconds" -ForegroundColor $ColorWarning
                        Write-Host ""

                        Invoke-BatchCommand -Description "Starting screen recording" -Devices $targetDevices -Command {
                            param($dev)
                            $filename = "recording_$timestamp.mp4"
                            Start-Process -FilePath "adb" -ArgumentList "-s", $dev.ID, "shell", "screenrecord", "--time-limit", $duration, "/sdcard/Download/$filename" -NoNewWindow
                        } -Parallel

                        Write-Host "[i] Recordings in progress..." -ForegroundColor $ColorInfo
                        Write-Host "[i] Use option 3 to stop early or wait $duration seconds" -ForegroundColor $ColorInfo
                    }
                } else {
                    Write-Host "[!] Invalid duration!" -ForegroundColor $ColorError
                }
                Pause
            }
            "3" {
                $targetDevices = Select-TargetDevices -OperationName "Stop Screen Recording"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Stopping screen recording" -Devices $targetDevices -Command {
                        param($dev)
                        # Kill screenrecord process
                        & adb -s $dev.ID shell pkill -SIGINT screenrecord
                    }

                    Write-Host "[✓] Recordings stopped" -ForegroundColor $ColorSuccess
                    Write-Host "[i] Use option 4 to pull recordings" -ForegroundColor $ColorInfo
                }
                Pause
            }
            "4" {
                # Using QUAS method: Pull from /sdcard/Oculus/Screenshots and /sdcard/Oculus/Videoshots
                $targetDevices = Select-TargetDevices -OperationName "Copy Oculus Screenshots/Videos to PC"

                if ($targetDevices.Count -gt 0) {
                    $desktopPath = [Environment]::GetFolderPath("Desktop")
                    $questMediaPath = Join-Path $desktopPath "QuestMedia"

                    if (!(Test-Path $questMediaPath)) {
                        New-Item -ItemType Directory -Path $questMediaPath -Force | Out-Null
                    }

                    Invoke-BatchCommand -Description "Copying Oculus media to Desktop/QuestMedia" -Devices $targetDevices -Command {
                        param($dev)
                        $deviceFolder = Join-Path $questMediaPath $dev.ID
                        New-Item -ItemType Directory -Path $deviceFolder -Force | Out-Null

                        # Pull screenshots from Oculus folder (QUAS method)
                        & adb -s $dev.ID pull /sdcard/Oculus/Screenshots "$deviceFolder\Screenshots" 2>$null
                        # Pull videoshots from Oculus folder (QUAS method)
                        & adb -s $dev.ID pull /sdcard/Oculus/Videoshots "$deviceFolder\Videoshots" 2>$null

                        Write-Host "[i] Media from $($dev.Model) copied to $deviceFolder" -ForegroundColor $ColorInfo
                    }

                    Write-Host ""
                    Write-Host "[✓] All media saved to: $questMediaPath" -ForegroundColor $ColorSuccess
                    Write-Host "[i] Opening folder..." -ForegroundColor $ColorInfo
                    Start-Process $questMediaPath
                }
                Pause
            }
            "5" {
                $localFolder = Read-Host "Enter local folder to save files"

                if (!(Test-Path $localFolder)) {
                    New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
                }

                $targetDevices = Select-TargetDevices -OperationName "Pull Custom Files from Devices"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Pulling media files" -Devices $targetDevices -Command {
                        param($dev)
                        # Create device-specific subfolder
                        $deviceFolder = Join-Path $localFolder $dev.ID
                        New-Item -ItemType Directory -Path $deviceFolder -Force | Out-Null

                        # Pull all screenshots and recordings
                        & adb -s $dev.ID pull /sdcard/Download/ $deviceFolder
                    }

                    Write-Host "[✓] Files saved to: $localFolder" -ForegroundColor $ColorSuccess
                }
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
            $confirm = Read-Host "Reboot selected devices? (yes/no)"
            if ($confirm -eq "yes") {
                $targetDevices = Select-TargetDevices -OperationName "Reboot Devices"
                if ($targetDevices.Count -gt 0) {
                    Invoke-BatchCommand -Description "Rebooting devices" -Devices $targetDevices -Command {
                        param($dev)
                        & adb -s $dev.ID reboot
                    }
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
