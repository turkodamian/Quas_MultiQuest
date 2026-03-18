# CommandExecutor.psm1
# Module for executing ADB commands across multiple devices

$script:AdbPath = Join-Path $PSScriptRoot "..\adb.exe"
$script:LogPath = Join-Path $PSScriptRoot "..\Logs"

# Ensure log directory exists
if (-not (Test-Path $script:LogPath)) {
    New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
}

<#
.SYNOPSIS
    Writes a log entry to both console and log file
.PARAMETER Message
    Message to log
.PARAMETER Level
    Log level (INFO, SUCCESS, WARNING, ERROR, COMMAND)
.PARAMETER DeviceSerial
    Optional device serial for device-specific logs
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'COMMAND', 'RESPONSE')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory=$false)]
        [string]$DeviceSerial = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $deviceTag = if ($DeviceSerial) { "[$DeviceSerial]" } else { "" }
    $logEntry = "[$timestamp] [$Level] $deviceTag $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'COMMAND' { 'Cyan' }
        'RESPONSE' { 'Gray' }
        default { 'White' }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    
    # Write to log file
    $logFile = Join-Path $script:LogPath "quas-multi-$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

<#
.SYNOPSIS
    Executes an ADB command on a single device
.PARAMETER Serial
    Device serial number
.PARAMETER Command
    ADB command to execute (without 'adb -s serial' prefix)
.PARAMETER Description
    Human-readable description of the command
.OUTPUTS
    PSCustomObject with Serial, Success, Output, Error properties
#>
function Invoke-SingleAdbCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Serial,
        
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = ""
    )
    
    try {
        $desc = if ($Description) { $Description } else { $Command }
        Write-Log -Message "Executing: $desc" -Level COMMAND -DeviceSerial $Serial
        Write-Log -Message "Command: adb -s $Serial $Command" -Level INFO -DeviceSerial $Serial
        
        # Execute command
        $output = ""
        $errorOutput = ""
        
        # Use StartProcess for better output capture
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:AdbPath
        $psi.Arguments = "-s $Serial $Command"
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $outputBuilder = New-Object System.Text.StringBuilder
        $errorBuilder = New-Object System.Text.StringBuilder
        
        $outputEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
            if ($EventArgs.Data) {
                $Event.MessageData.AppendLine($EventArgs.Data)
            }
        } -MessageData $outputBuilder
        
        $errorEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
            if ($EventArgs.Data) {
                $Event.MessageData.AppendLine($EventArgs.Data)
            }
        } -MessageData $errorBuilder
        
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        $process.WaitForExit()
        
        Unregister-Event -SourceIdentifier $outputEvent.Name
        Unregister-Event -SourceIdentifier $errorEvent.Name
        
        $output = $outputBuilder.ToString()
        $errorOutput = $errorBuilder.ToString()
        $exitCode = $process.ExitCode
        
        $success = ($exitCode -eq 0)
        
        # Log output
        if ($output) {
            $outputLines = $output -split "`n" | Where-Object { $_ -match '\S' }
            foreach ($line in $outputLines) {
                Write-Log -Message "Output: $line" -Level RESPONSE -DeviceSerial $Serial
            }
        }
        
        if ($errorOutput -and -not $success) {
            Write-Log -Message "Error: $errorOutput" -Level ERROR -DeviceSerial $Serial
        }
        
        if ($success) {
            Write-Log -Message "Command completed successfully" -Level SUCCESS -DeviceSerial $Serial
        } else {
            Write-Log -Message "Command failed with exit code $exitCode" -Level ERROR -DeviceSerial $Serial
        }
        
        return [PSCustomObject]@{
            Serial = $Serial
            Success = $success
            ExitCode = $exitCode
            Output = $output
            Error = $errorOutput
            Command = $Command
            Description = $desc
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Log -Message "Exception executing command: $_" -Level ERROR -DeviceSerial $Serial
        return [PSCustomObject]@{
            Serial = $Serial
            Success = $false
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
            Command = $Command
            Description = $Description
            Timestamp = Get-Date
        }
    }
}

<#
.SYNOPSIS
    Executes an ADB command on multiple devices in parallel
.PARAMETER Devices
    Array of device serials
.PARAMETER Command
    ADB command to execute
.PARAMETER Description
    Human-readable description
.PARAMETER MaxParallel
    Maximum number of parallel jobs (default: 5)
.OUTPUTS
    Array of result objects
#>
function Invoke-ParallelAdbCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Devices,
        
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "",
        
        [Parameter(Mandatory=$false)]
        [int]$MaxParallel = 5
    )
    
    Write-Log -Message "Starting parallel execution on $($Devices.Count) device(s)" -Level INFO
    Write-Log -Message "Command: $Command" -Level INFO
    
    $results = @()
    $jobs = @()
    
    # Create script block for parallel execution
    $scriptBlock = {
        param($AdbPath, $Serial, $Command, $Description, $LogPath)
        
        # Import logging function in job context
        function Write-JobLog {
            param($Message, $Level, $Serial, $LogPath)
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [$Level] [$Serial] $Message"
            $logFile = Join-Path $LogPath "quas-multi-$(Get-Date -Format 'yyyy-MM-dd').log"
            Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
        }
        
        try {
            Write-JobLog -Message "Executing: $Command" -Level "COMMAND" -Serial $Serial -LogPath $LogPath
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $AdbPath
            $psi.Arguments = "-s $Serial $Command"
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            $process.Start() | Out-Null
            
            $output = $process.StandardOutput.ReadToEnd()
            $errorOutput = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            
            $success = ($exitCode -eq 0)
            
            Write-JobLog -Message "Command completed with exit code: $exitCode" -Level $(if($success){"SUCCESS"}else{"ERROR"}) -Serial $Serial -LogPath $LogPath
            
            return [PSCustomObject]@{
                Serial = $Serial
                Success = $success
                ExitCode = $exitCode
                Output = $output
                Error = $errorOutput
                Command = $Command
                Description = $Description
                Timestamp = Get-Date
            }
        }
        catch {
            Write-JobLog -Message "Exception: $_" -Level "ERROR" -Serial $Serial -LogPath $LogPath
            return [PSCustomObject]@{
                Serial = $Serial
                Success = $false
                ExitCode = -1
                Output = ""
                Error = $_.Exception.Message
                Command = $Command
                Description = $Description
                Timestamp = Get-Date
            }
        }
    }
    
    # Start jobs
    foreach ($device in $Devices) {
        $serial = if ($device -is [string]) { $device } else { $device.Serial }
        
        while ((Get-Job -State Running).Count -ge $MaxParallel) {
            Start-Sleep -Milliseconds 100
        }
        
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $script:AdbPath, $serial, $Command, $Description, $script:LogPath
        $jobs += $job
    }
    
    # Wait for all jobs to complete with progress
    $total = $jobs.Count
    $completed = 0
    
    Write-Host ""
    Write-Host "Progress: " -NoNewline
    
    while ($jobs | Where-Object { $_.State -eq 'Running' }) {
        $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
        $percent = [math]::Round(($completed / $total) * 100)
        Write-Host "`rProgress: $completed/$total ($percent%)  " -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "`rProgress: $total/$total (100%)  " -ForegroundColor Green
    Write-Host ""
    
    # Collect results
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job
        $results += $result
        Remove-Job -Job $job
    }
    
    # Summary
    $successCount = ($results | Where-Object { $_.Success }).Count
    $failCount = $results.Count - $successCount
    
    Write-Log -Message "Parallel execution completed: $successCount succeeded, $failCount failed" -Level INFO
    
    return $results
}

<#
.SYNOPSIS
    Exports command results to a file
.PARAMETER Results
    Array of result objects
.PARAMETER Format
    Output format (JSON, CSV, TXT)
#>
function Export-CommandResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Results,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('JSON', 'CSV', 'TXT')]
        [string]$Format = 'TXT'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $filename = "results_$timestamp.$($Format.ToLower())"
    $filepath = Join-Path $script:LogPath $filename
    
    switch ($Format) {
        'JSON' {
            $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $filepath -Encoding UTF8
        }
        'CSV' {
            $Results | Export-Csv -Path $filepath -NoTypeInformation -Encoding UTF8
        }
        'TXT' {
            $output = @()
            $output += "=" * 80
            $output += "Command Execution Results - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            $output += "=" * 80
            $output += ""
            
            foreach ($result in $Results) {
                $output += "-" * 80
                $output += "Device: $($result.Serial)"
                $output += "Command: $($result.Command)"
                $output += "Description: $($result.Description)"
                $output += "Status: $(if($result.Success){'SUCCESS'}else{'FAILED'})"
                $output += "Exit Code: $($result.ExitCode)"
                $output += "Timestamp: $($result.Timestamp)"
                $output += ""
                $output += "Output:"
                $output += $result.Output
                if ($result.Error) {
                    $output += ""
                    $output += "Error:"
                    $output += $result.Error
                }
                $output += ""
            }
            
            $output += "=" * 80
            
            $output | Out-File -FilePath $filepath -Encoding UTF8
        }
    }
    
    Write-Log -Message "Results exported to: $filepath" -Level SUCCESS
    return $filepath
}

# Export module functions
Export-ModuleMember -Function @(
    'Write-Log',
    'Invoke-SingleAdbCommand',
    'Invoke-ParallelAdbCommand',
    'Export-CommandResults'
)
