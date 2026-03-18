# Quas Multi-Device Manager

## Descripción

Versión mejorada de Quas que permite gestionar **múltiples visores Meta Quest conectados por USB simultáneamente**. Puedes enviar comandos a uno, varios o todos los dispositivos conectados.

## Características Principales

✅ **Detección automática de dispositivos** - Detecta todos los visores Quest conectados por USB  
✅ **Selección flexible** - Elige uno, varios o todos los dispositivos para cada operación  
✅ **Ejecución paralela** - Los comandos se ejecutan simultáneamente en múltiples dispositivos  
✅ **Logging detallado** - Todos los comandos y respuestas se registran en archivos de log  
✅ **Interfaz de consola interactiva** - Visualiza claramente los comandos enviados y las respuestas  
✅ **Alias de dispositivos** - Asigna nombres personalizados a tus visores  
✅ **Configuración persistente** - Guarda preferencias y alias de dispositivos

## Requisitos

- Windows 10/11
- PowerShell 5.1 o superior
- ADB drivers instalados (incluidos en Quas original)
- Meta Quest headsets conectados por USB con modo desarrollador habilitado

## Instalación

1. Descarga o clona el repositorio en tu carpeta de Quas existente
2. Los archivos nuevos se integrarán con tu instalación actual de Quas
3. No requiere instalación adicional

## Uso Rápido

### Opción 1: Ejecutar directamente
```powershell
cd c:\appz\Quas\Quas-main
.\Quas-MultiDevice.ps1
```

### Opción 2: Desde el menú principal de Quas (próximamente)
```
Ejecuta quas_v5.2.0.eng.cmd y selecciona la opción [MD] Multi-Device Management
```

## Estructura de Archivos

```
Quas-main/
├── Quas-MultiDevice.ps1          # Script principal
├── Modules/
│   ├── DeviceManager.psm1        # Gestión y detección de dispositivos
│   ├── CommandExecutor.psm1     # Ejecución de comandos y logging
│   └── UIComponents.psm1         # Componentes de interfaz de usuario
├── Config/
│   └── devices.json              # Configuración de dispositivos y preferencias
└── Logs/
    └── quas-multi-YYYY-MM-DD.log # Logs diarios de operaciones
```

## Funcionalidades Implementadas (v1.0)

### 📸 Screenshot & Media Management
- Crear screenshots individuales en todos los dispositivos
- Crear series de screenshots con intervalos configurables
- Copiar screenshots/videos/media desde los visores al PC
- Enviar archivos desde el PC a los visores

### 📱 Application Management
- Instalar APKs en múltiples dispositivos simultáneamente
- Desinstalar aplicaciones
- Listar aplicaciones instaladas
- Limpiar datos y caché de aplicaciones
- Iniciar/detener aplicaciones
- Habilitar/deshabilitar aplicaciones

### ℹ️ System Information
- Ver información detallada de cada dispositivo
- Consultar estado de batería
- Ver información de almacenamiento
- Obtener dirección IP
- Exportar propiedades del sistema
- Guardar información en archivos JSON

## Logging y Debugging

Todos los comandos ejecutados se registran automáticamente en:
```
Logs/quas-multi-YYYY-MM-DD.log
```

Formato del log:
```
[2025-11-25 10:30:45] [COMMAND] [1WMHH123456] Executing: Create screenshot
[2025-11-25 10:30:45] [INFO] [1WMHH123456] Command: adb -s 1WMHH123456 shell screencap...
[2025-11-25 10:30:46] [RESPONSE] [1WMHH123456] Output: ...
[2025-11-25 10:30:46] [SUCCESS] [1WMHH123456] Command completed successfully
```

Niveles de log:
- **INFO**: Información general
- **COMMAND**: Comandos ejecutados
- **RESPONSE**: Respuestas de los dispositivos
- **SUCCESS**: Operaciones exitosas
- **WARNING**: Advertencias
- **ERROR**: Errores

## Configuración

El archivo `Config/devices.json` almacena:

```json
{
  "devices": [
    {
      "serial": "1WMHH123456",
      "alias": "Quest 2 - Sala",
      "lastSeen": "2025-11-25 10:00:00"
    },
    {
      "serial": "1WMHH789012",
      "alias": "Quest 3 - Oficina",
      "lastSeen": "2025-11-25 10:00:00"
    }
  ],
  "preferences": {
    "defaultExecutionMode": "parallel",
    "maxParallelJobs": 5,
    "commandTimeout": 300,
    "autoRefreshDevices": true
  }
}
```

## Ejemplos de Uso

### Ejemplo 1: Tomar screenshots en 3 visores simultáneamente
1. Inicia `Quas-MultiDevice.ps1`
2. Selecciona "A" para todos los dispositivos
3. Selecciona opción [1] Screenshot & Media Management
4. Selecciona [1] Create Screenshot (single)
5. ✓ Screenshot creado en los 3 dispositivos en paralelo

### Ejemplo 2: Instalar un APK en visores específicos
1. Inicia `Quas-MultiDevice.ps1`
2. Selecciona los dispositivos "1,3" (primero y tercero)
3. Selecciona opción [2] Application Management
4. Selecciona [1] Install APK from PC
5. Ingresa la ruta del APK
6. ✓ APK instalado en los dispositivos seleccionados

### Ejemplo 3: Ver información de batería de todos los visores
1. Inicia `Quas-MultiDevice.ps1`
2. Selecciona "A" para todos
3. Selecciona opción [4] System Information
4. Selecciona [2] Show battery status
5. ✓ Información de batería mostrada para cada dispositivo

## Próximas Características (v2.0)

🔜 **Backup & Restore** - Backup y restauración de datos de aplicaciones  
🔜 **Device Settings** - Gestión de Wi-Fi, fecha/hora, configuraciones  
🔜 **Streaming** - Streaming de video simultáneo de múltiples dispositivos  
🔜 **Text Input** - Enviar texto a todos los dispositivos  
🔜 **Advanced Tools** - Shell personalizado, comandos custom  
🔜 **Interfaz Gráfica** - GUI con Windows Forms para facilitar el uso  
🔜 **Integración con Quas original** - Acceso directo desde el menú principal

## Solución de Problemas

### No se detectan dispositivos
1. Verifica que los visores estén conectados por USB
2. Asegúrate de que el modo desarrollador está habilitado
3. Confirma que los drivers ADB están instalados
4. Ejecuta "Restart ADB and retry" desde el menú

### Errores de permisos
- Ejecuta PowerShell como Administrador
- Verifica que la política de ejecución permite scripts:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Los comandos fallan en algunos dispositivos
- Revisa los logs en `Logs/quas-multi-YYYY-MM-DD.log`
- Verifica la conectividad de cada dispositivo individual
- Asegúrate de que los dispositivos no estén en modo sleep

## Contribuciones

Este proyecto es una mejora del [Quas original de Varsett](https://github.com/Varsett/Quas). 

## Contacto

Para reportar bugs o sugerir mejoras, crea un issue en el repositorio.

## Licencia

Este proyecto hereda la licencia del proyecto original Quas.

---

**Versión:** 1.0.0  
**Fecha:** 25 de Noviembre de 2025  
**Basado en:** Quas v5.2.0 por Varsett
