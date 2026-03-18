# QUAS MULTI-DEVICE - DEVICE SETTINGS MENU

## Menu Principal - Opcion 5: Device Settings

```
=====================================================================
                       DEVICE SETTINGS                               
=====================================================================

Selected devices: X

  [1] Configure Wi-Fi (enable/disable)
  [2] Set screen brightness
  [3] Set volume level
  [4] Set date and time
  [5] Enable/Disable Developer mode
  [6] Set screen timeout
  [7] Reboot devices
  [8] Reboot to recovery
  [9] Show current settings

  [0] Back to main menu

Select option:
```

## Submenus

### Opcion 1: Wi-Fi Configuration

```
Wi-Fi Configuration:
  [1] Enable Wi-Fi
  [2] Disable Wi-Fi
  [3] Show Wi-Fi status

Select:
```

### Opcion 5: Developer Mode

```
Developer Mode:
  [1] Enable USB debugging
  [2] Disable USB debugging
  [3] Show developer options status

Select:
```

## Opciones Interactivas

### Opcion 2: Set screen brightness
```
Enter brightness level (0-255):
```

### Opcion 3: Set volume level
```
Enter volume level (0-15):
```

### Opcion 6: Set screen timeout
```
Enter screen timeout in milliseconds (e.g., 60000 = 1 min, 300000 = 5 min):
```

## Ejemplo de Salida - Opcion 9 (Show current settings)

```
Retrieving current settings...

========================================
Device: 2G0YC1ZF7G070P
========================================
Brightness: 128
Screen Timeout: 300000 ms (300 seconds)
Wi-Fi: Wi-Fi is enabled
Developer Mode: ENABLED

========================================
Device: 2G0YC1ZF7W0SLT
========================================
Brightness: 150
Screen Timeout: 600000 ms (600 seconds)
Wi-Fi: Wi-Fi is enabled
Developer Mode: DISABLED
```

## Confirmaciones

### Opcion 7: Reboot devices
```
Reboot 2 device(s)?
Confirm [Y/n]:
```

### Opcion 8: Reboot to recovery
```
Reboot 2 device(s) to recovery mode?
Confirm [Y/n]:
```

## Resumen de Ejecucion (Ejemplo)

```
====================================================================
                       EXECUTION SUMMARY                            
====================================================================

Total Devices: 2
Successful: 2
Failed: 0

Device Details:

  [OK]  2G0YC1ZF7G070P - Set brightness to 200
  [OK]  2G0YC1ZF7W0SLT - Set brightness to 200

```

## Valores Recomendados

### Brightness (Brillo)
- **Minimo**: 10-20 (muy oscuro, para uso nocturno)
- **Medio**: 100-150 (uso normal interior)
- **Alto**: 200-255 (uso exterior o luz brillante)

### Volume (Volumen)
- **Silencio**: 0
- **Bajo**: 3-5
- **Medio**: 7-10
- **Alto**: 12-15

### Screen Timeout (Tiempo antes de apagar pantalla)
- **30 segundos**: 30000
- **1 minuto**: 60000
- **2 minutos**: 120000
- **5 minutos**: 300000
- **10 minutos**: 600000
- **30 minutos**: 1800000

## Notas de Uso

1. **Wi-Fi**: Desactivar Wi-Fi puede ahorrar bateria pero perdera conectividad de red
2. **Brightness**: Valores muy bajos pueden dificultar la visualizacion
3. **Volume**: El volumen afecta solo audio de medios (stream 3)
4. **Date/Time**: Se sincroniza automaticamente con la hora del PC
5. **Developer Mode**: Necesario para depuracion y funciones avanzadas
6. **Reboot**: Las operaciones de reinicio cierran todas las apps activas
7. **Recovery Mode**: Solo usar si necesita realizar tareas de mantenimiento avanzado

## Comandos ADB Equivalentes

Para referencia, estos son los comandos ADB directos:

```bash
# Wi-Fi
adb shell svc wifi enable
adb shell svc wifi disable

# Brillo
adb shell settings put system screen_brightness 150

# Volumen
adb shell media volume --show --stream 3 --set 10

# Fecha/Hora
adb shell date 112510302025.45

# Developer mode
adb shell settings put global adb_enabled 1

# Screen timeout
adb shell settings put system screen_off_timeout 300000

# Reboot
adb reboot
adb reboot recovery
```

---
Documentacion actualizada: 2025-11-25
