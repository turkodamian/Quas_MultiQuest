# QUICK START GUIDE - Quas Multi-Device Manager

## Inicio Rápido (5 minutos)

### Paso 1: Preparar los Dispositivos
1. Conecta tus visores Quest por USB al PC
2. Asegúrate de que el modo desarrollador está habilitado en cada visor
3. Acepta la autorización de USB debugging en cada visor

### Paso 2: Verificar Detección
Abre PowerShell en la carpeta de Quas y ejecuta:
```powershell
.\Test-MultiDevice.ps1
```

Deberías ver algo como:
```
Found 2 device(s):
─────────────────────────────────────────────────────────────
Serial:      1WMHH123456
Status:      device
Model:       Quest 2
Battery:     85%
─────────────────────────────────────────────────────────────
```

### Paso 3: Iniciar el Manager
```powershell
.\Quas-MultiDevice.ps1
```

### Paso 4: Seleccionar Dispositivos
Verás un menú como este:
```
Connected Devices:

  [1] Quest 2 - Serial: 1WMHH123456
      Product: hollywood | Status: device

  [2] Quest 3 - Serial: 1WMHH789012
      Product: eureka | Status: device

  [A] All devices
  [0] Cancel / Go back

Select a device [1-2], A for all, or 0 to cancel:
```

Opciones:
- Escribe `1` para seleccionar solo el primer dispositivo
- Escribe `1,2` para seleccionar ambos dispositivos
- Escribe `A` para seleccionar todos los dispositivos automáticamente

### Paso 5: Ejecutar Comandos

#### Ejemplo 1: Tomar Screenshot en Todos los Visores
1. Selecciona `A` (todos los dispositivos)
2. Elige `[1] Screenshot & Media Management`
3. Elige `[1] Create Screenshot (single)`
4. ✓ Screenshot creado en todos los dispositivos

#### Ejemplo 2: Instalar APK en Visores Específicos
1. Selecciona `1,3` (dispositivos 1 y 3)
2. Elige `[2] Application Management`
3. Elige `[1] Install APK from PC`
4. Ingresa la ruta: `C:\Downloads\MiApp.apk`
5. ✓ APK instalado en los dispositivos seleccionados

#### Ejemplo 3: Ver Info de Sistema
1. Selecciona `A` (todos)
2. Elige `[4] System Information`
3. Elige `[1] Show device info`
4. ✓ Información mostrada para cada dispositivo

## Comandos Disponibles

### 📸 Screenshots y Media (Opción 1)
- **[1]** Screenshot individual
- **[2]** Serie de screenshots con delay
- **[3]** Copiar screenshots al PC
- **[4]** Copiar videos al PC
- **[5]** Copiar todo el media al PC
- **[6]** Enviar archivo a los visores

### 📱 Gestión de Apps (Opción 2)
- **[1]** Instalar APK
- **[2]** Desinstalar app
- **[3]** Listar apps instaladas
- **[4]** Limpiar datos/caché
- **[5]** Detener app
- **[6]** Iniciar app
- **[7]** Habilitar app
- **[8]** Deshabilitar app

### ℹ️ Información del Sistema (Opción 4)
- **[1]** Info del dispositivo (modelo, Android, etc.)
- **[2]** Estado de batería
- **[3]** Info de almacenamiento
- **[4]** Dirección IP
- **[5]** Todas las propiedades (getprop)
- **[6]** Exportar info a archivo

## Logging

Todos los comandos se registran automáticamente en:
```
Logs\quas-multi-2025-11-25.log
```

Puedes abrir este archivo en cualquier momento para ver:
- Qué comandos se ejecutaron
- En qué dispositivos
- Qué respuestas se recibieron
- Si hubo errores

## Consejos Útiles

### Asignar Nombres a tus Dispositivos
Por ahora los dispositivos se identifican por el serial número. En una futura versión podrás asignar nombres como "Quest 2 - Sala" o "Quest 3 - Oficina".

### Ejecución Paralela
Cuando seleccionas múltiples dispositivos, los comandos se ejecutan **en paralelo** (simultáneamente). Verás una barra de progreso:
```
Progress: 2/3 (66%)
```

### Logs Detallados
Si algo falla, revisa el archivo de log. Cada comando muestra:
- El comando exacto enviado
- La respuesta completa del dispositivo
- Cualquier error que ocurrió

### Solución Rápida de Problemas

**"No devices detected!"**
1. Ejecuta `.\adb.exe devices` para verificar
2. Si ves "unauthorized", acepta el diálogo en el visor
3. Si no funciona, intenta "Restart ADB and retry" en el menú

**"Command failed on some devices"**
1. Revisa el log para ver el error específico
2. Verifica que el dispositivo sigue conectado
3. Intenta ejecutar el comando solo en ese dispositivo para debuggear

**Errores de permisos en PowerShell**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Próximos Pasos

Una vez que te familiarices con las funciones básicas:
1. Explora las otras categorías de comandos
2. Revisa los logs para entender mejor cómo funciona
3. Consulta el README-MultiDevice.md para documentación completa

## Soporte

Si encuentras bugs o tienes sugerencias:
- Revisa primero los logs en `Logs/`
- Abre un issue en el repositorio con:
  - Descripción del problema
  - Contenido relevante del log
  - Número de dispositivos conectados

---

**¡Listo!** Ahora puedes gestionar múltiples visores Quest simultáneamente 🚀
