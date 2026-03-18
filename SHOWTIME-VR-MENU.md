# MENÚ SHOWTIME VR - Documentación

## Descripción
El menú **[S] Showtime VR** permite enviar archivos de configuración personalizados a cada visor desde un archivo template.

## Ubicación
- Menú Principal > **[S] Showtime VR**
- Color: Magenta

## Funcionalidades

### [1] Send Config.txt (personalized for each headset)

**Propósito:** Generar y enviar un archivo `config.txt` personalizado a cada visor basado en su información de inventario.

**Flujo de trabajo:**
1. El script lee el archivo template desde `\ShowtimeVR\config.txt`
2. Para cada dispositivo seleccionado:
   - Recupera `alias` y `customNumber` desde `devices.json`
   - Modifica la primera línea del template (variable `name`) con el `alias` del dispositivo
   - Modifica la segunda línea del template (variable `nr`) con el `customNumber` del dispositivo
   - Guarda el archivo personalizado en una carpeta temporal
   - Crea la carpeta `/sdcard/Showtime VR` en el dispositivo (si no existe)
   - Copia el archivo personalizado al dispositivo como `/sdcard/Showtime VR/config.txt`
3. Muestra un resumen de éxito/fallo

**Archivo Template (ShowtimeVR\config.txt):**
```
name=VisorTemplate
nr=0
version=1.0
mode=default
```

**Ejemplo de resultado:**
Si el dispositivo tiene:
- `alias`: "asd"
- `customNumber`: "99"

El archivo generado será:
```
name=asd
nr=99
version=1.0
mode=default
```

**Ubicación en dispositivo:** `/sdcard/Showtime VR/config.txt`

## Requerimientos
- Los dispositivos deben estar registrados en el inventario (`devices.json`)
- Cada dispositivo debe tener al menos un `alias` asignado
- El archivo template debe existir en `c:\appz\Quas\Quas-main\ShowtimeVR\config.txt`

## Casos de uso
- Configurar la aplicación Showtime VR en múltiples visores con información única para cada uno
- Asignar números de visor automáticamente desde el inventario
- Mantener la sincronización entre la configuración física (inventario) y la configuración de la app

## Mensajes de error
- `ERROR: Template file not found`: El archivo `ShowtimeVR\config.txt` no existe
- `WARNING: Device not found in inventory. Skipping...`: El dispositivo no está registrado en `devices.json`
- `[FAIL] Error sending config`: Falló el push del archivo al dispositivo

## Notas técnicas
- Se usa un directorio temporal en `%TEMP%` para almacenar los archivos personalizados
- El directorio temporal se limpia automáticamente después de enviar los archivos
- Los archivos se codifican en UTF-8
- Se crean las carpetas necesarias en el dispositivo si no existen
