# SISTEMA DE INVENTARIO - GUIA COMPLETA

## Resumen
Sistema completo de gestion de inventario para dispositivos VR que permite:
- Asignar numeros personalizados a cada visor
- Crear alias amigables
- Mantener notas sobre cada dispositivo
- Auto-escaneo que preserva datos previos
- Exportar/importar inventarios

## Acceso al Sistema
**Menu principal > [D] Device Management > INVENTORY MANAGEMENT**

## Opciones del Menu

### [1] View Complete Inventory
Muestra un listado completo de todos los dispositivos registrados con toda su informacion:

```
====================================================================
                      DEVICE INVENTORY                               
====================================================================

Total devices in inventory: 2

--------------------------------------------------------------------

  Device #1 - Quest-Sala-A
    Serial: 2G0YC1ZF7G070P
    Model: Quest_3
    Notes: Visor principal - sala de reuniones
    First seen: 2025-11-25 12:00:00
    Last seen: 2025-11-25 12:15:00
  ------------------------------------------------------------------

  Device #2 - Quest-Desarrollo
    Serial: 2G0YC1ZF7W0SLT
    Model: Quest_3
    Notes: Visor de desarrollo - equipo tecnico
    First seen: 2025-11-25 12:00:00
    Last seen: 2025-11-25 12:15:00
  ------------------------------------------------------------------
```

**Informacion mostrada:**
- Custom Number (numero personalizado)
- Alias (nombre amigable)
- Serial (numero de serie del dispositivo)
- Model (modelo del dispositivo)
- Notes (notas personalizadas)
- First seen (primera vez detectado)
- Last seen (ultima vez detectado)

---

### [2] Register/Update Device Information
Registra un nuevo dispositivo o actualiza la informacion de uno existente.

**Proceso:**
1. Muestra lista de dispositivos conectados
2. Seleccionar dispositivo
3. Ingresar/actualizar:
   - Alias (ej: "Quest-VR-01", "Sala-Principal", "Dev-Team")
   - Custom Number (ej: 1, 2, 3, etc.)
   - Notes (ej: "Visor de pruebas", "Sala de conferencias")

**Caracteristicas:**
- Si el dispositivo ya existe, muestra valores actuales
- Presionar Enter sin escribir mantiene el valor actual
- Actualiza automaticamente el modelo y fecha

**Ejemplo:**
```
Registering: Quest_3 - 2G0YC1ZF7G070P

Enter device alias (e.g., Quest-VR-01): Quest-Principal
Enter custom number (e.g., 1, 2, 3...): 1
Enter notes (optional): Visor principal de la oficina

Device registered successfully!
```

---

### [3] Assign Custom Numbers to Devices
Asigna rapidamente numeros personalizados a multiples dispositivos.

**Proceso:**
1. Muestra lista de dispositivos con sus numeros actuales
2. Seleccionar dispositivo
3. Ingresar numero personalizado
4. Repite para asignar mas numeros
5. [0] para finalizar

**Beneficios:**
- Proceso rapido para asignar numeros secuenciales
- Ver numeros actuales de todos los dispositivos
- Permite reorganizar numeracion facilmente

**Ejemplo:**
```
Current devices:

  [1] Quest-Development (no number)
  [2] Quest-Testing #5
  [3] Quest-Production (no number)

  [0] Done

Select device to assign number (or 0 to finish): 1
Enter custom number for Quest-Development: 10
Number assigned successfully!
```

---

### [4] Edit Device Alias
Cambia el alias (nombre) de un dispositivo existente.

**Proceso:**
1. Lista todos los dispositivos con sus alias actuales
2. Seleccionar dispositivo a editar
3. Ingresar nuevo alias
4. Confirmar cambio

**Uso recomendado:**
- Renombrar dispositivos cuando cambian de ubicacion
- Corregir errores de escritura
- Actualizar nomenclatura

---

### [5] Add/Edit Device Notes
Agrega o edita notas sobre un dispositivo especifico.

**Proceso:**
1. Lista dispositivos con preview de notas actuales
2. Seleccionar dispositivo
3. Ingresar nuevas notas (reemplaza las anteriores)

**Ideas para notas:**
- Ubicacion fisica: "Sala de conferencias 3er piso"
- Estado: "Requiere actualizacion de firmware"
- Responsable: "Asignado a equipo de desarrollo"
- Problemas: "Bateria con bajo rendimiento"
- Historia: "Comprado en enero 2024"

---

### [6] Auto-scan and Update Inventory
**FUNCION PRINCIPAL - MAS IMPORTANTE**

Escanea automaticamente todos los dispositivos conectados y actualiza el inventario:

**Caracteristicas clave:**
- ✅ **Preserva datos existentes**: Mantiene alias, numeros y notas
- ✅ **Detecta nuevos dispositivos**: Los agrega automaticamente
- ✅ **Actualiza fechas**: Actualiza "last seen" de dispositivos existentes
- ✅ **Auto-alias**: Genera alias automaticos para nuevos dispositivos
- ✅ **No elimina datos**: Nunca borra dispositivos del inventario

**Salida ejemplo:**
```
Scanning for connected devices...
Found 3 connected device(s)

  [UPDATED] 2G0YC1ZF7G070P - Quest_3
  [UPDATED] 2G0YC1ZF7W0SLT - Quest_3
  [NEW] 2G0YC1ZF8A123BC - Quest_3
        Auto-assigned alias: Quest_3-8A123BC

--------------------------------------------------------------------
New devices added: 1
Existing devices updated: 2
Total devices in inventory: 3

Note: You can customize aliases and assign numbers using options 2-3
```

**Uso recomendado:**
- Ejecutar al inicio de cada sesion de trabajo
- Cuando se conectan nuevos dispositivos
- Para actualizar el timestamp de "last seen"
- Antes de exportar el inventario

---

### [7] Remove Device from Inventory
Elimina un dispositivo del inventario (con confirmacion).

**Proceso:**
1. Lista todos los dispositivos
2. Seleccionar dispositivo a eliminar
3. Confirmar eliminacion
4. Dispositivo removido del inventario

**Uso:**
- Dispositivo vendido o dado de baja
- Dispositivo roto permanentemente
- Limpiar inventario de dispositivos antiguos

**Nota:** Esta accion NO se puede deshacer (a menos que tengas un backup)

---

### [8] Export Inventory to File
Exporta todo el inventario a un archivo JSON con timestamp.

**Caracteristicas:**
- Formato: `Inventory_Export_YYYY-MM-DD_HHmmss.json`
- Ubicacion: Carpeta del script
- Incluye toda la configuracion (dispositivos + preferencias)
- Compatible para importacion posterior

**Uso recomendado:**
- Backup antes de hacer cambios importantes
- Compartir inventario entre instalaciones
- Mantener historial de dispositivos
- Documentacion de equipos

**Ejemplo de archivo generado:**
```
Inventory_Export_2025-11-25_121530.json
```

---

### [9] Import Inventory from File
Importa dispositivos desde un archivo JSON exportado previamente.

**Proceso:**
1. Solicita ruta del archivo
2. Valida el archivo
3. Muestra confirmacion
4. Fusiona dispositivos (no duplica)

**Caracteristicas:**
- Solo agrega dispositivos nuevos (no duplica)
- Mantiene dispositivos existentes
- Merge inteligente por numero de serie

**Uso:**
- Restaurar backup
- Combinar inventarios de diferentes instalaciones
- Recuperar datos perdidos

---

### [0] Back to Main Menu
Regresa al menu principal de categorias.

---

## Estructura de Datos (JSON)

```json
{
  "devices": [
    {
      "serial": "2G0YC1ZF7G070P",
      "alias": "Quest-Principal",
      "customNumber": "1",
      "model": "Quest_3",
      "notes": "Visor principal de oficina",
      "lastSeen": "2025-11-25 12:15:30",
      "firstSeen": "2025-11-25 10:00:00"
    },
    {
      "serial": "2G0YC1ZF7W0SLT",
      "alias": "Quest-Desarrollo",
      "customNumber": "2",
      "model": "Quest_3",
      "notes": "Equipo de desarrollo",
      "lastSeen": "2025-11-25 12:15:30",
      "firstSeen": "2025-11-25 10:05:00"
    }
  ],
  "preferences": {
    "defaultExecutionMode": "parallel",
    "maxParallelJobs": 5,
    "commandTimeout": 300,
    "autoRefreshDevices": true
  },
  "lastUpdated": "2025-11-25 12:15:30"
}
```

---

## Flujo de Trabajo Recomendado

### Primera vez (Setup inicial):
1. Conectar todos los dispositivos via USB
2. Abrir Quas-MultiDevice.ps1
3. Menu principal > [D] Device Management
4. **[6] Auto-scan and update inventory** (detecta todos)
5. **[2] Register/Update device information** (asignar alias y numeros a cada uno)
6. **[1] View complete inventory** (verificar)
7. **[8] Export inventory to file** (backup inicial)

### Uso diario:
1. Conectar dispositivos
2. Menu principal > [D] Device Management
3. **[6] Auto-scan** (actualiza last seen)
4. Proceder con operaciones normales usando alias/numeros

### Cuando llega un nuevo dispositivo:
1. Conectar el nuevo dispositivo
2. **[6] Auto-scan** (lo detecta automaticamente)
3. **[2] Register/Update** (personalizar alias/numero)
4. **[8] Export** (actualizar backup)

### Mantenimiento:
- Ejecutar **[6] Auto-scan** semanalmente
- **[8] Export** mensualmente para backup
- **[5] Add notes** para documentar cambios/problemas
- **[1] View inventory** para auditorias

---

## Ventajas del Sistema

### 1. **No se pierden datos**
- El auto-scan NUNCA elimina dispositivos
- Solo agrega nuevos y actualiza timestamps
- Todos los alias, numeros y notas se preservan

### 2. **Identificacion amigable**
En lugar de: `2G0YC1ZF7G070P`
Usar: `Quest-Principal` o `Visor #1`

### 3. **Historial completo**
- Primera vez visto
- Ultima vez visto
- Modelo detectado automaticamente

### 4. **Portable y respaldable**
- Exportar/importar en segundos
- Formato JSON legible
- Compatible entre instalaciones

### 5. **Integracion con el resto del sistema**
- Los alias aparecen en el menu de seleccion de dispositivos
- Los numeros personalizados facilitan la referencia
- Las notas ayudan a documentar problemas

---

## Casos de Uso

### Empresa con multiples visores
```
Device #1 - Sala-Conferencias-A
Device #2 - Sala-Conferencias-B
Device #3 - Demo-Clientes
Device #4 - Desarrollo-Backend
Device #5 - Desarrollo-Frontend
Device #6 - Testing-QA
```

### Estudio de desarrollo
```
Device #DEV1 - Lead-Developer
Device #DEV2 - Junior-Dev
Device #TEST1 - QA-Testing
Device #PROD1 - Production-Build
```

### Centro educativo
```
Device #1 - Aula-101
Device #2 - Aula-102
Device #3 - Laboratorio-VR
Device #4 - Biblioteca
Device #5 - Profesor-Principal
```

---

## Archivos Relacionados

- **devices.json**: Archivo principal de inventario
- **Inventory_Export_*.json**: Backups exportados
- **Quas-MultiDevice.ps1**: Script principal
- **Config/devices.json**: Ubicacion del archivo de configuracion

---

## Preguntas Frecuentes

**Q: Que pasa si elimino devices.json?**
A: Se crea uno nuevo vacio. Puedes recuperar desde un Export o usar Auto-scan.

**Q: Puedo tener dos dispositivos con el mismo numero?**
A: Si, el sistema lo permite (aunque no es recomendado).

**Q: Los datos se guardan automaticamente?**
A: Si, cada cambio llama a Save-Configuration automaticamente.

**Q: Se pueden buscar dispositivos por alias?**
A: Si, en el menu de seleccion de dispositivos se muestran los alias.

**Q: Que pasa con dispositivos que ya no se conectan?**
A: Permanecen en el inventario. Puedes eliminarlos con opcion [7].

**Q: El auto-scan detecta dispositivos por Wi-Fi?**
A: Si, detecta cualquier dispositivo visible via ADB (USB o Wi-Fi).

---

## Resumen de Comandos Rapidos

| Accion | Opcion | Rapido |
|--------|--------|--------|
| Ver todos los dispositivos | [1] | Consulta |
| Registrar nuevo visor | [2] | Setup |
| Asignar numeros | [3] | Organizacion |
| Cambiar nombre | [4] | Edicion |
| Agregar notas | [5] | Documentacion |
| **Actualizar inventario** | **[6]** | **PRINCIPAL** |
| Eliminar dispositivo | [7] | Limpieza |
| Hacer backup | [8] | Seguridad |
| Restaurar backup | [9] | Recuperacion |

---

Creado: 2025-11-25
Version: 1.0.0  
Estado: IMPLEMENTADO Y PROBADO ✅
