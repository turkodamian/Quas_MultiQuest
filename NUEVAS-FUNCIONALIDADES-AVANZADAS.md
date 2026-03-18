# NUEVAS FUNCIONALIDADES AVANZADAS (MENUS 6, 7, 8)

## Resumen de Implementación

Se han agregado tres nuevos módulos completos al sistema `Quas-MultiDevice.ps1`:

### 1. [6] Streaming & Connectivity
Herramientas para gestión de red y visualización remota.

| Opción | Función | Descripción |
|--------|---------|-------------|
| **[1] Start screen streaming** | `scrcpy` | Inicia transmisión de pantalla (requiere scrcpy instalado). |
| **[2] Enable ADB over Wi-Fi** | `adb tcpip 5555` | Habilita modo inalámbrico en el puerto 5555. Muestra la IP del dispositivo. |
| **[3] Disable ADB over Wi-Fi** | `adb usb` | Retorna los dispositivos a modo USB. |
| **[4] Show IP addresses** | `ip addr` | Muestra rápidamente las IPs de todos los dispositivos conectados. |
| **[5] Connect to device via Wi-Fi** | `adb connect` | Permite conectar manualmente a una IP específica. |
| **[6] Disconnect Wi-Fi ADB** | `adb disconnect` | Desconecta sesiones inalámbricas activas. |
| **[7] Port forwarding setup** | `adb forward` | Configura reenvío de puertos (útil para debugging remoto). |

### 2. [7] Text Input
Automatización de entrada de texto y eventos.

| Opción | Función | Descripción |
|--------|---------|-------------|
| **[1] Send text to devices** | `input text` | Envía cadenas de texto a todos los dispositivos (útil para URLs, passwords). |
| **[2] Send keyevent** | `input keyevent` | Envía códigos de tecla específicos (Android KeyCodes). |
| **[3] Send special characters** | `input text` | Envío rápido de símbolos comunes (@, ., /, etc). |
| **[4] Tap at coordinates** | `input tap` | Simula un toque en coordenadas X,Y específicas. |
| **[5] Swipe gesture** | `input swipe` | Simula deslizamiento desde A hasta B con duración controlada. |
| **[6] Common keycodes** | Menú rápido | Acceso directo a teclas comunes: HOME, BACK, ENTER, VOLUME, etc. |

### 3. [8] Advanced Tools
Herramientas de sistema y depuración profunda.

| Opción | Función | Descripción |
|--------|---------|-------------|
| **[1] Interactive shell** | `adb shell` | Abre una terminal interactiva directa con un dispositivo seleccionado. |
| **[2] Execute custom shell command** | `adb shell <cmd>` | Ejecuta un comando shell en **todos** los dispositivos simultáneamente. |
| **[3] View logcat (live)** | `adb logcat` | Muestra logs en tiempo real de un dispositivo. |
| **[4] Save logcat to file** | `adb logcat -d` | Guarda los logs actuales de **todos** los dispositivos en archivos timestamped en `Logs/`. |
| **[5] Clear logcat buffer** | `logcat -c` | Limpia el buffer de logs en todos los dispositivos. |
| **[6] Get detailed device info** | `getprop` | Reporte completo: Modelo, Android Ver, SDK, Build ID, Resolución, Densidad. |
| **[7] List running processes** | `ps` | Muestra los primeros 20 procesos activos en cada dispositivo. |
| **[8] Kill process by name** | `am force-stop` | Detiene forzosamente una aplicación/paquete en todos los dispositivos. |
| **[9] Execute custom ADB command** | `adb <cmd>` | Ejecuta cualquier comando ADB arbitrario en paralelo. |

---

## Guía de Uso Rápido

### Escenario: Configuración de Laboratorio Inalámbrico
1. Conectar dispositivos por USB.
2. Ir a **[6] Streaming & Connectivity**.
3. Seleccionar **[2] Enable ADB over Wi-Fi**.
4. Anotar las IPs mostradas.
5. Desconectar cables USB.
6. Usar **[5] Connect to device via Wi-Fi** para reconectar sin cables.

### Escenario: Testing de Formulario en Múltiples Dispositivos
1. Abrir app en todos los visores.
2. Ir a **[7] Text Input**.
3. Seleccionar **[1] Send text** para llenar campos de usuario.
4. Usar **[6] Common keycodes** > **ENTER** para avanzar.
5. Usar **[1] Send text** para llenar password.

### Escenario: Depuración de Error
1. Reproducir error en los dispositivos.
2. Ir a **[8] Advanced Tools**.
3. Seleccionar **[4] Save logcat to file**.
4. Revisar la carpeta `Logs/YYYY-MM-DD_HHmmss/` creada automáticamente con los reportes de cada visor.

---

## Estado del Sistema
✅ **Script:** `Quas-MultiDevice.ps1` actualizado y funcional.
✅ **Pruebas:** Todos los menús cargan y ejecutan comandos correctamente.
✅ **Integración:** Menús conectados al flujo principal (opciones 6, 7, 8).
