# Example-UseCases.ps1
# Practical examples of using Quas Multi-Device Manager

<#
.SYNOPSIS
    Ejemplos de uso común del Quas Multi-Device Manager
    
.DESCRIPTION
    Este script muestra ejemplos prácticos de cómo usar las funciones principales
    del sistema multi-dispositivo. Puedes copiar y adaptar estos ejemplos.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import modules
Import-Module (Join-Path $ScriptDir "Modules\DeviceManager.psm1") -Force
Import-Module (Join-Path $ScriptDir "Modules\CommandExecutor.psm1") -Force

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "          EJEMPLOS DE USO - Quas Multi-Device" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Ejemplo 1: Detectar todos los dispositivos y mostrar información
Write-Host "EJEMPLO 1: Detectar dispositivos" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$devices = Get-AdbDevices

if ($devices.Count -eq 0) {
    Write-Host "No hay dispositivos conectados." -ForegroundColor Red
    exit
}

Write-Host "Dispositivos encontrados: $($devices.Count)" -ForegroundColor Green
foreach ($device in $devices) {
    Write-Host "  • $($device.Serial) - $($device.Model)" -ForegroundColor White
}
Write-Host ""

# Ejemplo 2: Tomar screenshot en todos los dispositivos
Write-Host "EJEMPLO 2: Screenshot en todos los dispositivos" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$command = "shell screencap -p /sdcard/screenshot_$timestamp.png"
Write-Host "Comando a ejecutar: adb $command" -ForegroundColor Cyan
Write-Host ""

# Simular ejecución (comentar para ejecutar realmente)
Write-Host "[SIMULACIÓN] Se ejecutaría en $($devices.Count) dispositivo(s)" -ForegroundColor Gray

# Descomentar las siguientes líneas para ejecutar realmente:
# $results = Invoke-ParallelAdbCommand -Devices $devices -Command $command -Description "Create screenshot"
# Show-ResultsSummary -Results $results

Write-Host ""

# Ejemplo 3: Obtener información de batería de todos los dispositivos
Write-Host "EJEMPLO 3: Información de batería" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

foreach ($device in $devices) {
    $info = Get-DeviceInfo -Serial $device.Serial
    if ($info -and $info.BatteryLevel) {
        Write-Host "  $($device.Serial): " -NoNewline
        
        $batteryNum = [int]($info.BatteryLevel -replace '%', '')
        $color = if ($batteryNum -ge 50) { "Green" } elseif ($batteryNum -ge 20) { "Yellow" } else { "Red" }
        Write-Host "$($info.BatteryLevel)" -ForegroundColor $color
    }
}
Write-Host ""

# Ejemplo 4: Ejecutar comando personalizado
Write-Host "EJEMPLO 4: Comando personalizado (obtener dirección IP)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$command = "shell ip addr show wlan0"
Write-Host "Comando: adb $command" -ForegroundColor Cyan
Write-Host ""
Write-Host "[SIMULACIÓN] Resultado esperado:" -ForegroundColor Gray

foreach ($device in $devices) {
    $info = Get-DeviceInfo -Serial $device.Serial
    if ($info -and $info.IPAddress) {
        Write-Host "  $($device.Serial): $($info.IPAddress)" -ForegroundColor White
    }
}
Write-Host ""

# Ejemplo 5: Instalar APK en dispositivos seleccionados
Write-Host "EJEMPLO 5: Instalación de APK (simulado)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$apkPath = "C:\Downloads\MiApp.apk"
Write-Host "APK: $apkPath" -ForegroundColor Cyan
Write-Host "Dispositivos seleccionados: Primeros 2" -ForegroundColor Cyan
Write-Host ""

$selectedDevices = $devices | Select-Object -First 2
foreach ($device in $selectedDevices) {
    Write-Host "  [SIMULACIÓN] Instalando en $($device.Serial)..." -ForegroundColor Gray
}

# Para instalar realmente, usar:
# foreach ($device in $selectedDevices) {
#     $result = Invoke-SingleAdbCommand -Serial $device.Serial -Command "install -r `"$apkPath`"" -Description "Install APK"
#     if ($result.Success) {
#         Write-Host "✓ Instalado en $($device.Serial)" -ForegroundColor Green
#     } else {
#         Write-Host "✗ Error en $($device.Serial)" -ForegroundColor Red
#     }
# }

Write-Host ""

# Ejemplo 6: Copiar screenshots desde los dispositivos
Write-Host "EJEMPLO 6: Copiar screenshots al PC" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$destBase = Join-Path $ScriptDir "Screenshots"
Write-Host "Destino base: $destBase" -ForegroundColor Cyan
Write-Host ""

foreach ($device in $devices) {
    $destDir = Join-Path $destBase "$($device.Serial)\$(Get-Date -Format 'yyyy-MM-dd')"
    Write-Host "  [SIMULACIÓN] Copiando desde $($device.Serial) a:" -ForegroundColor Gray
    Write-Host "    $destDir" -ForegroundColor DarkGray
}

# Para ejecutar realmente:
# foreach ($device in $devices) {
#     $destDir = Join-Path $destBase "$($device.Serial)\$(Get-Date -Format 'yyyy-MM-dd')"
#     New-Item -ItemType Directory -Path $destDir -Force | Out-Null
#     & "$ScriptDir\adb.exe" -s $device.Serial pull /sdcard/DCIM/Screenshots $destDir
#     Write-Host "✓ Copiado desde $($device.Serial)" -ForegroundColor Green
# }

Write-Host ""

# Ejemplo 7: Reiniciar aplicación en todos los dispositivos
Write-Host "EJEMPLO 7: Reiniciar aplicación (simulado)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$package = "com.oculus.vrshell"
Write-Host "Paquete: $package" -ForegroundColor Cyan
Write-Host ""

# Paso 1: Detener la app
Write-Host "Paso 1: Detener aplicación en todos los dispositivos" -ForegroundColor Yellow
$stopCommand = "shell am force-stop $package"
Write-Host "  Comando: adb $stopCommand" -ForegroundColor Gray
Write-Host ""

# Paso 2: Esperar
Write-Host "Paso 2: Esperar 2 segundos..." -ForegroundColor Yellow
Write-Host ""

# Paso 3: Iniciar la app
Write-Host "Paso 3: Iniciar aplicación" -ForegroundColor Yellow
$startCommand = "shell monkey -p $package 1"
Write-Host "  Comando: adb $startCommand" -ForegroundColor Gray

# Para ejecutar realmente:
# $results = Invoke-ParallelAdbCommand -Devices $devices -Command $stopCommand -Description "Stop $package"
# Start-Sleep -Seconds 2
# $results = Invoke-ParallelAdbCommand -Devices $devices -Command $startCommand -Description "Start $package"

Write-Host ""

# Resumen final
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "RESUMEN DE EJEMPLOS:" -ForegroundColor Green
Write-Host "  1. ✓ Detección de dispositivos" -ForegroundColor White
Write-Host "  2. ✓ Screenshots en paralelo" -ForegroundColor White
Write-Host "  3. ✓ Info de batería" -ForegroundColor White
Write-Host "  4. ✓ Comandos personalizados" -ForegroundColor White
Write-Host "  5. ✓ Instalación de APK" -ForegroundColor White
Write-Host "  6. ✓ Copia de archivos" -ForegroundColor White
Write-Host "  7. ✓ Reinicio de apps" -ForegroundColor White
Write-Host ""
Write-Host "NOTA: Los ejemplos están en modo SIMULACIÓN" -ForegroundColor Yellow
Write-Host "      Descomenta el código para ejecutar realmente" -ForegroundColor Yellow
Write-Host ""
Write-Host "Para usar el sistema completo, ejecuta:" -ForegroundColor Cyan
Write-Host "  .\Quas-MultiDevice.ps1" -ForegroundColor White
Write-Host ""
