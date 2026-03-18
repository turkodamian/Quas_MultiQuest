# MENÚ OPEN BRUSH - Documentación

## Descripción
El menú **[O] Open Brush** permite controlar la aplicación Open Brush que está ejecutándose en los visores VR mediante comandos HTTP a su API REST.

## Ubicación
- Menú Principal > **[O] Open Brush**
- Color: Verde

## Requisitos Previos
1. **Open Brush debe estar ejecutándose** en los visores
2. Los dispositivos deben tener **Wi-Fi habilitado** y conectado
3. La **API HTTP de Open Brush** debe estar habilitada (puerto 40074)

## Funcionalidades

### [1] Save New - Save current sketch with new filename

**Propósito:** Guarda el sketch actual con un nuevo nombre de archivo.

**API Call:** `GET http://{IP_VISOR}:40074/api/v1?save.new`

**Comportamiento:**
- Guarda el dibujo actual
- Genera un nuevo nombre de archivo automáticamente
- No sobrescribe archivos existentes

**Ejemplo de salida:**
```
Processing device: 2G0YC1ZF7G070P
  IP: 192.168.12.33
  Calling API: http://192.168.12.33:40074/api/v1?save.new
  [OK] Response: 200 - {"success": true}
```

---

### [2] Export Current - Export current sketch

**Propósito:** Exporta el sketch actual en el formato configurado (USD, FBX, GLB, etc.).

**API Call:** `GET http://{IP_VISOR}:40074/api/v1?export.current`

**Comportamiento:**
- Exporta el dibujo actual
- Usa el formato de exportación predeterminado de Open Brush
- Guarda en la carpeta de exportaciones del visor

**Ejemplo de salida:**
```
Processing device: 2G0YC1ZF7W0SLT
  IP: 192.168.12.45
  Calling API: http://192.168.12.45:40074/api/v1?export.current
  [OK] Response: 200 - {"success": true, "file": "export_001.usd"}
```

---

### [3] New - Create new blank sketch

**Propósito:** Crea un nuevo sketch en blanco (limpia el canvas actual).

**API Call:** `GET http://{IP_VISOR}:40074/api/v1?new`

**Comportamiento:**
- Borra el dibujo actual
- Crea un canvas nuevo y vacío
- **ADVERTENCIA:** Perderás el trabajo no guardado

**Ejemplo de salida:**
```
Processing device: 2G0YC1ZF7Y06MH
  IP: 192.168.12.52
  Calling API: http://192.168.12.52:40074/api/v1?new
  [OK] Response: 200 - {"success": true}
```

  [OK] Response: 200 - {"success": true}
```

---

### [4] Environment Pistachio

**Propósito:** Cambia el entorno de Open Brush a "Pistachio" (fondo sólido).

**API Call:** `GET http://{IP_VISOR}:40074/api/v1?environment.type=pistachio`

**Comportamiento:**
- Cambia instantáneamente el entorno visual
- Útil para presentaciones o capturas limpias

**Ejemplo de salida:**
```
Processing device: 2G0YC1ZF7Y06MH
  IP: 192.168.12.52
  Calling API: http://192.168.12.52:40074/api/v1?environment.type=pistachio
  [OK] Response: 200 - {"success": true}
```

---

### [5] Environment Passthrough

**Propósito:** Cambia el entorno de Open Brush a "Passthrough" (realidad mixta).

**API Call:** `GET http://{IP_VISOR}:40074/api/v1?environment.type=passtrough`

**Comportamiento:**
- Activa las cámaras del visor para ver el mundo real
- Permite dibujar sobre el entorno físico

**Ejemplo de salida:**
```
Processing device: 2G0YC1ZF7Y06MH
  IP: 192.168.12.52
  Calling API: http://192.168.12.52:40074/api/v1?environment.type=passtrough
  [OK] Response: 200 - {"success": true}
```

  [OK] Response: 200 - {"success": true}
```

---

### [6] Custom Command

**Propósito:** Ejecutar cualquier comando de la API de Open Brush escribiendo solo el parámetro.

**API Call:** `GET http://{IP_VISOR}:40074/api/v1?{COMANDO_USUARIO}`

**Comportamiento:**
- El script construye la URL base automáticamente
- El usuario solo ingresa la parte del query string

**Ejemplo:**
- Input usuario: `brush.move.to=0,0,0`
- URL generada: `http://{IP}:40074/api/v1?brush.move.to=0,0,0`

**Ejemplo de salida:**
```
Enter custom command (e.g. environment.type=pistachio): brush.type=Icing

Processing device: 2G0YC1ZF7Y06MH
  IP: 192.168.12.52
  Calling API: http://192.168.12.52:40074/api/v1?brush.type=Icing
  [OK] Response: 200 - {"success": true}
```

---

## Flujo de Trabajo

Para cada comando, el script:

1. **Obtiene la IP** del visor ejecutando `adb shell ip addr show wlan0`
2. **Construye la URL** de la API: `http://{IP}:40074/api/v1?{comando}`
3. **Hace un HTTP GET** usando `Invoke-WebRequest` con timeout de 5 segundos
4. **Muestra el resultado:** código de respuesta HTTP y contenido
5. **Genera resumen:** cuenta de éxitos/fallos

## Manejo de Errores

### Error: Could not get IP address
- **Causa:** El visor no tiene Wi-Fi habilitado o no está conectado a una red
- **Solución:** Conectar el visor a Wi-Fi desde settings

### Error: Connection timed out
- **Causa:** Open Brush no está ejecutándose o la API HTTP no está habilitada
- **Solución:** 
  - Abrir Open Brush en el visor
  - Verificar que la API HTTP esté habilitada en settings de Open Brush

### Error: 404 Not Found
- **Causa:** La API no está disponible en ese endpoint
- **Solución:** Verificar la versión de Open Brush (requiere versión con API HTTP)

### Error: 500 Internal Server Error
- **Causa:** Error en Open Brush al procesar el comando
- **Solución:** Verificar que el comando sea válido para el estado actual de la app

## Casos de Uso

### 1. Guardar trabajo en múltiples visores simultáneamente
```
Escenario: Clase de arte VR con 10 estudiantes
1. Instructor avisa: "Guarden su trabajo"
2. Ejecuta [O] > [1] Save New
3. Todos los sketches se guardan automáticamente
```

### 2. Exportar obras de arte para exhibición
```
Escenario: Preparar exhibición digital
1. Los artistas terminan sus obras
2. Ejecuta [O] > [2] Export Current
3. Todas las obras se exportan en formato USD/FBX
4. Se copian desde los visores para la exhibición
```

### 3. Reiniciar sesión de práctica
```
Escenario: Práctica de dibujo con límite de tiempo
1. Timer termina
2. Ejecuta [O] > [3] New
3. Todos los canvas se limpian para la siguiente ronda
```

## Documentación de la API

Para más comandos disponibles, consulta la documentación oficial:
https://docs.openbrush.app/user-guide/open-brush-api/api-commands

## Notas Técnicas

- **Puerto:** 40074 (puerto predeterminado de la API de Open Brush)
- **Protocolo:** HTTP GET
- **Timeout:** 5 segundos
- **Sin autenticación:** La API es local y no requiere autenticación
- **Thread-safe:** Los comandos se ejecutan secuencialmente por dispositivo

## Ejemplos de Respuestas API

### Éxito:
```json
{
  "success": true,
  "message": "Sketch saved successfully",
  "filename": "untitled_2025-11-26_123045.tilt"
}
```

### Error:
```json
{
  "success": false,
  "error": "No active sketch to save"
}
```

## Troubleshooting

**P: El comando no hace nada**
R: Verifica que Open Brush esté en primer plano (activo) en el visor

**P: Obtengo error de conexión**
R: Asegúrate de que el visor y la PC estén en la misma red Wi-Fi

**P: La API está deshabilitada**
R: En Open Brush, ve a Settings > Labs > Enable HTTP API

**P: ¿Funciona con dispositivos USB?**
R: Sí, mientras tengan Wi-Fi conectado (se obtiene la IP por ADB)
