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
$script:Version = "1.3.0"
$script:DeviceInventoryPath = Join-Path $PSScriptRoot "quest_inventory.csv"
$script:DeviceInventory = @{}

function Show-Banner {
    Clear-Host
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $ColorTitle
    Write-Host "           MultiQuest Manager v$Version" -ForegroundColor $ColorTitle
    Write-Host "    Batch ADB Manager for Multiple Meta Quest Devices" -ForegroundColor $ColorTitle
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $ColorTitle
    Write-Host ""
}

function Load-DeviceInventory {
    $script:DeviceInventory = @{}

    if (Test-Path $script:DeviceInventoryPath) {
        try {
            $csv = Import-Csv $script:DeviceInventoryPath
            foreach ($row in $csv) {
                if ($row.SerialNumber -and $row.SerialNumber -ne "") {
                    $script:DeviceInventory[$row.SerialNumber] = $row.LabelNumber
                }
            }
            Write-Host "[✓] Loaded device inventory: $($script:DeviceInventory.Count) devices" -ForegroundColor $ColorSuccess
        } catch {
            Write-Host "[!] Error loading inventory: $($_.Exception.Message)" -ForegroundColor $ColorError
        }
    }
}

function Get-DeviceLabel {
    param([string]$SerialNumber)

    if ($script:DeviceInventory.ContainsKey($SerialNumber)) {
        return $script:DeviceInventory[$SerialNumber]
    }
    return "---"
}

function Get-DeviceDisplayName {
    param($Device)

    $label = Get-DeviceLabel -SerialNumber $Device.ID
    if ($label -ne "---") {
        return "#$label - $($Device.Model) ($($Device.ID))"
    }
    return "$($Device.Model) ($($Device.ID))"
}

function Menu-DeviceInventory {
    while ($true) {
        Show-Banner
        Write-Host "═══════════════ DEVICE INVENTORY ══════════════" -ForegroundColor $ColorTitle
        Write-Host ""
        Write-Host " [1]  Create devices list (001-100)" -ForegroundColor $ColorInfo
        Write-Host " [2]  Update devices list (add new devices)" -ForegroundColor $ColorInfo
        Write-Host " [3]  View inventory" -ForegroundColor $ColorInfo
        Write-Host " [4]  Export inventory to Excel-compatible CSV" -ForegroundColor $ColorInfo
        Write-Host " [0]  Back to main menu" -ForegroundColor $ColorWarning
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                # Create new inventory
                Write-Host ""
                if (Test-Path $script:DeviceInventoryPath) {
                    Write-Host "[!] WARNING: quest_inventory.csv already exists!" -ForegroundColor $ColorWarning
                    $confirm = Read-Host "Overwrite existing inventory? (yes/no)"
                    if ($confirm -ne "yes") {
                        Write-Host "[i] Operation cancelled" -ForegroundColor $ColorInfo
                        Pause
                        continue
                    }
                }

                Write-Host "[*] Creating device inventory template (001-100)..." -ForegroundColor $ColorInfo

                # Create CSV rows as array
                $csvRows = @()
                $csvRows += "LabelNumber,SerialNumber,Model,Brand,Notes"

                for ($i = 1; $i -le 100; $i++) {
                    $labelNum = "{0:D3}" -f $i
                    $row = $labelNum + ",,,Quest,"
                    $csvRows += $row
                }

                # Save to file
                $csvRows -join "`n" | Out-File -FilePath $script:DeviceInventoryPath -Encoding UTF8 -NoNewline

                Write-Host "[✓] Inventory template created: $script:DeviceInventoryPath" -ForegroundColor $ColorSuccess
                Write-Host ""
                Write-Host "[i] Next steps:" -ForegroundColor $ColorInfo
                Write-Host "    1. Open quest_inventory.csv in Excel or Notepad" -ForegroundColor $ColorInfo
                Write-Host "    2. Fill in the SerialNumber column for each labeled device" -ForegroundColor $ColorInfo
                Write-Host "    3. Save the file" -ForegroundColor $ColorInfo
                Write-Host "    4. Use 'Update devices list' to add newly connected devices" -ForegroundColor $ColorInfo
                Write-Host ""
                Write-Host "[i] Opening CSV file..." -ForegroundColor $ColorInfo
                Start-Process $script:DeviceInventoryPath
                Pause
            }
            "2" {
                # Update inventory with new connected devices
                Write-Host ""
                if (!(Test-Path $script:DeviceInventoryPath)) {
                    Write-Host "[!] Inventory file not found. Please create it first (option 1)" -ForegroundColor $ColorError
                    Pause
                    continue
                }

                # Get connected devices
                if ($script:ConnectedDevices.Count -eq 0) {
                    Write-Host "[!] No devices connected! Connect devices first." -ForegroundColor $ColorError
                    Pause
                    continue
                }

                # Load current inventory
                Load-DeviceInventory

                Write-Host "[*] Checking for new devices..." -ForegroundColor $ColorInfo
                Write-Host ""

                $newDevices = @()
                foreach ($dev in $script:ConnectedDevices) {
                    if (-not $script:DeviceInventory.ContainsKey($dev.ID)) {
                        $newDevices += $dev
                        Write-Host "[+] New device found: $($dev.Model) - $($dev.ID)" -ForegroundColor $ColorSuccess
                    }
                }

                if ($newDevices.Count -eq 0) {
                    Write-Host "[i] No new devices to add. All connected devices are already in inventory." -ForegroundColor $ColorInfo
                    Pause
                    continue
                }

                Write-Host ""
                Write-Host "[*] Found $($newDevices.Count) new device(s)" -ForegroundColor $ColorInfo
                $confirm = Read-Host "Add these devices to inventory? (yes/no)"

                if ($confirm -eq "yes") {
                    # Read current CSV
                    $csvRows = Import-Csv $script:DeviceInventoryPath

                    # Find first empty row (no serial number)
                    $emptyRows = $csvRows | Where-Object { $_.SerialNumber -eq "" }

                    if ($emptyRows.Count -lt $newDevices.Count) {
                        Write-Host "[!] WARNING: Not enough empty rows in inventory!" -ForegroundColor $ColorWarning
                        Write-Host "[i] Available rows: $($emptyRows.Count), New devices: $($newDevices.Count)" -ForegroundColor $ColorWarning
                    }

                    # Add new devices to empty rows
                    $addedCount = 0
                    foreach ($dev in $newDevices) {
                        $emptyRow = $emptyRows | Where-Object { $_.SerialNumber -eq "" } | Select-Object -First 1

                        if ($emptyRow) {
                            $emptyRow.SerialNumber = $dev.ID
                            $emptyRow.Model = $dev.Model
                            $emptyRow.Brand = $dev.Brand
                            $addedCount++
                            Write-Host "[✓] Added: #$($emptyRow.LabelNumber) → $($dev.ID)" -ForegroundColor $ColorSuccess
                        }
                    }

                    # Save updated CSV
                    $csvRows | Export-Csv -Path $script:DeviceInventoryPath -NoTypeInformation -Encoding UTF8

                    Write-Host ""
                    Write-Host "[✓] Inventory updated: $addedCount device(s) added" -ForegroundColor $ColorSuccess
                    Write-Host "[i] Opening CSV file to verify..." -ForegroundColor $ColorInfo
                    Start-Process $script:DeviceInventoryPath

                    # Reload inventory
                    Load-DeviceInventory
                }

                Pause
            }
            "3" {
                # View inventory
                Show-Banner
                Write-Host "═══════════════════ DEVICE INVENTORY ══════════════════════" -ForegroundColor $ColorTitle
                Write-Host ""

                if (!(Test-Path $script:DeviceInventoryPath)) {
                    Write-Host "[!] Inventory file not found. Please create it first (option 1)" -ForegroundColor $ColorError
                    Pause
                    continue
                }

                Load-DeviceInventory

                $csv = Import-Csv $script:DeviceInventoryPath
                $registeredDevices = $csv | Where-Object { $_.SerialNumber -ne "" }

                Write-Host "Total registered devices: $($registeredDevices.Count) / 100" -ForegroundColor $ColorSuccess
                Write-Host ""
                Write-Host "┌────────┬──────────────────┬─────────────┬──────────────┐" -ForegroundColor $ColorTitle
                Write-Host "│ Label  │ Serial Number    │ Model       │ Status       │" -ForegroundColor $ColorTitle
                Write-Host "├────────┼──────────────────┼─────────────┼──────────────┤" -ForegroundColor $ColorTitle

                foreach ($device in $registeredDevices) {
                    $isConnected = $script:ConnectedDevices | Where-Object { $_.ID -eq $device.SerialNumber }
                    $status = if ($isConnected) { "CONNECTED" } else { "Offline" }
                    $statusColor = if ($isConnected) { $ColorSuccess } else { $ColorWarning }

                    $labelPadded = $device.LabelNumber.PadRight(6)
                    $serialPadded = $device.SerialNumber.PadRight(16)
                    $modelPadded = ($device.Model).PadRight(11)
                    $statusPadded = $status.PadRight(12)

                    Write-Host "│ $labelPadded │ $serialPadded │ $modelPadded │ " -NoNewline -ForegroundColor $ColorInfo
                    Write-Host "$statusPadded" -NoNewline -ForegroundColor $statusColor
                    Write-Host " │" -ForegroundColor $ColorInfo
                }

                Write-Host "└────────┴──────────────────┴─────────────┴──────────────┘" -ForegroundColor $ColorTitle
                Write-Host ""

                $emptySlots = 100 - $registeredDevices.Count
                Write-Host "[i] Empty label slots available: $emptySlots" -ForegroundColor $ColorInfo

                Pause
            }
            "4" {
                # Export inventory
                Write-Host ""
                if (!(Test-Path $script:DeviceInventoryPath)) {
                    Write-Host "[!] Inventory file not found. Please create it first (option 1)" -ForegroundColor $ColorError
                    Pause
                    continue
                }

                $exportPath = Join-Path $PSScriptRoot "quest_inventory_export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                Copy-Item -Path $script:DeviceInventoryPath -Destination $exportPath

                Write-Host "[✓] Inventory exported to: $exportPath" -ForegroundColor $ColorSuccess
                Write-Host "[i] Opening file..." -ForegroundColor $ColorInfo
                Start-Process $exportPath
                Pause
            }
            "0" { return }
        }
    }
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
            $displayName = Get-DeviceDisplayName -Device $dev
            Write-Host "    [$i] $displayName - Android $($dev.Android)" -ForegroundColor $ColorInfo
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
        $displayName = Get-DeviceDisplayName -Device $script:ConnectedDevices[0]
        Write-Host "[i] Auto-selected: $displayName" -ForegroundColor $ColorInfo
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
        $displayName = Get-DeviceDisplayName -Device $dev
        Write-Host "  [$($i+1)] $displayName" -ForegroundColor $ColorInfo
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
    Write-Host " [9]  Device Inventory (Label Management)" -ForegroundColor $ColorInfo
    Write-Host " [10] Refresh Device List" -ForegroundColor $ColorInfo
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
            $displayName = Get-DeviceDisplayName -Device $device
            Write-Host "[→] Processing: $displayName" -ForegroundColor $ColorWarning
            try {
                $result = & $Command $device
                $label = Get-DeviceLabel -SerialNumber $device.ID
                $successMsg = if ($label -ne "---") { "#$label - $($device.Model)" } else { $device.Model }
                Write-Host "[✓] Success: $successMsg" -ForegroundColor $ColorSuccess
                $results += $result
            } catch {
                $label = Get-DeviceLabel -SerialNumber $device.ID
                $errorMsg = if ($label -ne "---") { "#$label - $($device.Model)" } else { $device.Model }
                Write-Host "[✗] Failed: $errorMsg - $($_.Exception.Message)" -ForegroundColor $ColorError
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

# Load device inventory on startup
Load-DeviceInventory

if ($AutoDetect) {
    Get-ConnectedQuests
}

while ($true) {
    Show-Banner
    Write-Host "[i] Connected devices: $($script:ConnectedDevices.Count)" -ForegroundColor $ColorInfo
    if ($script:DeviceInventory.Count -gt 0) {
        Write-Host "[i] Registered devices in inventory: $($script:DeviceInventory.Count)" -ForegroundColor $ColorInfo
    }
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
            Menu-DeviceInventory
        }
        "10" {
            Get-ConnectedQuests
            Pause
        }
        "0" {
            Write-Host "`n[✓] Goodbye!" -ForegroundColor $ColorSuccess
            exit
        }
    }
}
