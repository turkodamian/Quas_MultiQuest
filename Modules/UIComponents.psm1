# UIComponents.psm1
# Module for console-based user interface components

<#
.SYNOPSIS
    Shows a table of devices with selection options
.PARAMETER Devices
    Array of device objects
.PARAMETER AllowMultiple
    Allow selecting multiple devices
.OUTPUTS
    Array of selected device serials
#>
function Show-DeviceSelectionMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices,
        
        [Parameter(Mandatory = $false)]
        [switch]$AllowMultiple,
        
        [Parameter(Mandatory = $false)]
        [object]$DeviceConfig
    )
    
    if ($Devices.Count -eq 0) {
        Write-Host ""
        Write-Host "No devices detected!" -ForegroundColor Red
        Write-Host "Please ensure devices are connected and ADB drivers are installed." -ForegroundColor Yellow
        Write-Host ""
        return @()
    }
    
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                    DEVICE SELECTION MENU                           " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    # --- NEW LOGIC: Map devices to Selection IDs ---
    $deviceMap = @{} # Key: SelectionID (int), Value: Device Object
    $usedIds = @{}   # To track used IDs
    $pendingDevices = @()
    
    # Step 1: Assign devices with CustomNumber from inventory
    foreach ($device in $Devices) {
        $assigned = $false
        if ($DeviceConfig -and $DeviceConfig.devices) {
            $inventoryDevice = $DeviceConfig.devices | Where-Object { $_.serial -eq $device.Serial }
            if ($inventoryDevice -and $inventoryDevice.customNumber) {
                $id = [int]$inventoryDevice.customNumber
                if (-not $usedIds.ContainsKey($id)) {
                    $deviceMap[$id] = $device
                    $usedIds[$id] = $true
                    $assigned = $true
                }
            }
        }
        if (-not $assigned) {
            $pendingDevices += $device
        }
    }
    
    # Step 2: Assign remaining devices to first available IDs
    $nextId = 1
    foreach ($device in $pendingDevices) {
        while ($usedIds.ContainsKey($nextId)) {
            $nextId++
        }
        $deviceMap[$nextId] = $device
        $usedIds[$nextId] = $true
    }
    
    # --- DISPLAY MENU ---
    
    # Sort IDs for display
    $sortedIds = $deviceMap.Keys | Sort-Object
    
    foreach ($id in $sortedIds) {
        $device = $deviceMap[$id]
        
        # Load inventory info again for display
        $customNumber = ''
        $inventoryAlias = ''
        $inventoryNotes = ''
        
        if ($DeviceConfig -and $DeviceConfig.devices) {
            $inventoryDevice = $DeviceConfig.devices | Where-Object { $_.serial -eq $device.Serial }
            if ($inventoryDevice) {
                $customNumber = $inventoryDevice.customNumber
                $inventoryAlias = $inventoryDevice.alias
                $inventoryNotes = $inventoryDevice.notes
            }
        }
        
        # Build display name
        $displayName = ''
        if ($customNumber) {
            $displayName = "Visor #$customNumber"
            if ($inventoryAlias) { $displayName += " - $inventoryAlias" }
        }
        elseif ($inventoryAlias) {
            $displayName = "$inventoryAlias ($($device.Model))"
        }
        elseif ($device.Alias) {
            $displayName = "$($device.Alias) ($($device.Model))"
        }
        else {
            $displayName = "$($device.Model)"
        }
        
        Write-Host "  [$id] " -NoNewline -ForegroundColor Yellow
        Write-Host "$displayName" -ForegroundColor White
        Write-Host "      Serial: $($device.Serial)" -NoNewline -ForegroundColor Gray
        
        if ($device.Product) { Write-Host " | Product: $($device.Product)" -NoNewline -ForegroundColor DarkGray }
        if ($device.Status) { Write-Host " | Status: $($device.Status)" -ForegroundColor DarkGray } else { Write-Host "" }
        
        if ($inventoryNotes) {
            $notePreview = if ($inventoryNotes.Length -gt 50) { $inventoryNotes.Substring(0, 50) + "..." } else { $inventoryNotes }
            Write-Host "      Note: $notePreview" -ForegroundColor DarkCyan
        }
        Write-Host ""
    }
    
    Write-Host "  [A] " -NoNewline -ForegroundColor Cyan
    Write-Host "All devices" -ForegroundColor White
    Write-Host "  [0] " -NoNewline -ForegroundColor Red
    Write-Host "Cancel / Go back" -ForegroundColor White
    Write-Host ""
    
    # Get selection
    if ($AllowMultiple) {
        Write-Host "Enter device numbers separated by commas (e.g., 1,3,4) or 'A' for all: " -NoNewline -ForegroundColor Yellow
    }
    else {
        Write-Host "Select a device number, A for all, or 0 to cancel: " -NoNewline -ForegroundColor Yellow
    }
    
    $selection = Read-Host
    
    if ($selection -eq "0" -or $selection -eq "") { return @() }
    
    if ($selection -eq "A" -or $selection -eq "a") {
        return $Devices | ForEach-Object { $_.Serial }
    }
    
    # Parse selection using the map
    $selected = @()
    $numbers = $selection -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($num in $numbers) {
        if ($num -match '^\d+$') {
            $id = [int]$num
            if ($deviceMap.ContainsKey($id)) {
                $selected += $deviceMap[$id].Serial
            }
            else {
                Write-Host "Warning: Device #$id not found in list." -ForegroundColor Red
            }
        }
    }
    
    return $selected
}

<#
.SYNOPSIS
    Displays a summary table of command results
.PARAMETER Results
    Array of result objects
#>
function Show-ResultsSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )
    
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                       EXECUTION SUMMARY                            " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $successCount = ($Results | Where-Object { $_.Success }).Count
    $failCount = $Results.Count - $successCount
    
    Write-Host "Total Devices: " -NoNewline
    Write-Host $Results.Count -ForegroundColor White
    
    Write-Host "Successful: " -NoNewline
    Write-Host $successCount -ForegroundColor Green
    
    Write-Host "Failed: " -NoNewline
    Write-Host $failCount -ForegroundColor $(if ($failCount -gt 0) { "Red" }else { "Green" })
    
    Write-Host ""
    Write-Host "Device Details:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($result in $Results) {
        $statusChar = if ($result.Success) { "[OK]" } else { "[FAIL]" }
        $statusColor = if ($result.Success) { "Green" } else { "Red" }
        
        Write-Host "  $statusChar " -NoNewline -ForegroundColor $statusColor
        Write-Host "$($result.Serial)" -NoNewline -ForegroundColor White
        Write-Host " - " -NoNewline
        Write-Host "$($result.Description)" -ForegroundColor Gray
        
        if (-not $result.Success -and $result.Error) {
            Write-Host "    Error: $($result.Error)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
}

<#
.SYNOPSIS
    Shows a menu with command categories
.OUTPUTS
    Selected category code
#>
function Show-CommandCategoryMenu {
    [CmdletBinding()]
    param()
    
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "             QUAS MULTI-DEVICE - COMMAND CATEGORIES                " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Screenshot & Media Management" -ForegroundColor White
    Write-Host "      Create screenshots, copy media files from/to devices" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [2] Application Management" -ForegroundColor White
    Write-Host "      Install, uninstall, manage apps on devices" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [3] Backup & Restore" -ForegroundColor White
    Write-Host "      Backup app data, restore from backups" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [4] System Information" -ForegroundColor White
    Write-Host "      View device info, battery, storage, etc." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [5] Device Settings" -ForegroundColor White
    Write-Host "      Wi-Fi, date/time, display settings" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [6] Streaming & Connectivity" -ForegroundColor White
    Write-Host "      Screen streaming, ADB over Wi-Fi" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [7] Text Input" -ForegroundColor White
    Write-Host "      Send text to all selected devices" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [8] Advanced Tools" -ForegroundColor White
    Write-Host "      Shell access, custom commands, logs" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [O] Open Brush" -ForegroundColor Green
    Write-Host "      Control Open Brush app via HTTP API" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [S] Showtime VR" -ForegroundColor Magenta
    Write-Host "      Send personalized config files to VR headsets" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [D] Device Management" -ForegroundColor Yellow
    Write-Host "      Manage device aliases, restart ADB, refresh devices" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [0] Exit to Main Quas Menu" -ForegroundColor Red
    Write-Host ""
    Write-Host "Select category: " -NoNewline -ForegroundColor Yellow
    
    $choice = Read-Host
    return $choice
}

<#
.SYNOPSIS
    Shows a confirmation dialog
.PARAMETER Message
    Message to display
.PARAMETER DefaultYes
    Default to Yes if user just presses Enter
.OUTPUTS
    Boolean indicating user's choice
#>
function Show-ConfirmationDialog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [switch]$DefaultYes
    )
    
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    
    $prompt = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    Write-Host "Confirm $prompt : " -NoNewline -ForegroundColor Yellow
    
    $response = Read-Host
    
    if ($response -eq "") {
        return $DefaultYes.IsPresent
    }
    
    return $response -match '^[Yy]'
}

<#
.SYNOPSIS
    Pauses and waits for user input
#>
function Wait-UserInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "Press any key to continue..."
    )
    
    Write-Host ""
    Write-Host $Message -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

<#
.SYNOPSIS
    Shows device status table with real-time information
.PARAMETER Devices
    Array of device serials or device objects
#>
function Show-DeviceStatusTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices
    )
    
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                        DEVICE STATUS                              " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Table header
    $header = "{0,-20} {1,-15} {2,-12} {3,-10} {4,-15}" -f "Serial", "Model", "Battery", "Status", "IP Address"
    Write-Host $header -ForegroundColor Yellow
    Write-Host ("-" * 80) -ForegroundColor DarkGray
    
    foreach ($device in $Devices) {
        $serial = if ($device -is [string]) { $device } else { $device.Serial }
        
        # This would require Get-DeviceInfo from DeviceManager module
        # For now, show basic info
        $row = "{0,-20} {1,-15} {2,-12} {3,-10} {4,-15}" -f $serial, "Quest", "N/A", "Connected", "N/A"
        Write-Host $row -ForegroundColor White
    }
    
    Write-Host ""
}

# Export module functions
Export-ModuleMember -Function @(
    'Show-DeviceSelectionMenu',
    'Show-ResultsSummary',
    'Show-CommandCategoryMenu',
    'Show-ConfirmationDialog',
    'Wait-UserInput',
    'Show-DeviceStatusTable'
)
