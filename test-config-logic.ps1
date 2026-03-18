# Test script to verify config modification logic
$templatePath = "c:\appz\Quas\Quas-main\ShowtimeVR\config.txt"
$templateContent = Get-Content $templatePath -Raw

$deviceAlias = "TEST-VISOR"
$deviceNumber = "42"

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

# Save to test file
$testFile = "c:\appz\Quas\Quas-main\ShowtimeVR\config-TEST.txt"
$personalizedConfig -join "`n" | Out-File -FilePath $testFile -Encoding UTF8 -NoNewline

Write-Host "Test file created: $testFile" -ForegroundColor Green
Write-Host ""
Write-Host "Content:" -ForegroundColor Yellow
Get-Content $testFile
