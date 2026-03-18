# GUIA RAPIDA - NUEVAS FUNCIONES

## Menu de Seleccion Mejorado

### Como se ve ahora:

```
====================================================================
                    DEVICE SELECTION MENU                           
====================================================================

Connected Devices:

  [1] Visor #1 - Quest-Sala-Conferencias-A
      Serial: 2G0YC1ZF7G070P | Product: eureka | Status: device
      Note: Visor principal - sala de conferencias piso 3

  [2] Visor #10 - Quest-Desarrollo-Backend
      Serial: 2G0YC1ZF7W0SLT | Product: eureka | Status: device
      Note: Equipo desarrollo. Asignado a Juan Perez

  [A] All devices
  [0] Cancel / Go back

Enter device numbers separated by commas (e.g., 1,3,4) or 'A' for all:
```

**Ventaja:** Ya sabes exactamente cual visor es cual!

---

## Conectar a Wi-Fi Personalizado

### Acceso: Menu Device Settings > [2]

### Paso a paso:

1. Seleccionar visores (ej: A para todos)
2. Menu principal > [5] Device Settings
3. Presionar [2] - Connect to custom Wi-Fi network
4. Ingresar SSID (nombre de la red)
5. Ingresar password (oculto con *****)
6. ¡Listo! Todos conectados

### Ejemplo:

```
Enter Wi-Fi Network Name (SSID): OficinaVR-5G
Enter Wi-Fi Password: ********

Connecting to Wi-Fi network: OficinaVR-5G

Connecting device 2G0YC1ZF7G070P...
  Connected successfully
Connecting device 2G0YC1ZF7W0SLT...
  Connected successfully
```

### Cuando usar:
- Cambiar de ubicacion/oficina
- Nueva red Wi-Fi en la empresa
- Conectar multiples visores rapidamente

---

## Stand By (Dormir Visores)

### Acceso: Menu Device Settings > [8]

### Que hace:
Pone los visores en modo reposo (pantalla apagada, bajo consumo)

### Uso:
```
Menu: 5 > 8

Putting devices into stand by mode (sleep)...

[OK]  2G0YC1ZF7G070P - Stand by mode
[OK]  2G0YC1ZF7W0SLT - Stand by mode

Devices should now be in stand by mode (screen off)
```

### Cuando usar:
- Fin del dia de trabajo
- Pausas largas
- Ahorrar bateria
- Guardar visores organizadamente

---

## Wake Up (Despertar Visores)

### Acceso: Menu Device Settings > [9]

### Que hace:
Despierta los visores del modo stand by (enciende pantallas)

### Uso:
```
Menu: 5 > 9

Waking up devices from stand by...

[OK]  2G0YC1ZF7G070P - Wake up
[OK]  2G0YC1ZF7W0SLT - Wake up

Devices should now be awake (screen on)
```

### Cuando usar:
- Inicio del dia
- Preparar visores para sesion
- Despertar multiples visores simultaneamente

---

## Passthrough (Camara Real)

### Acceso: Menu Device Settings > [A]

### Submenu:
```
Passthrough Control:
  [1] Enable Passthrough        - Activar camara
  [2] Disable Passthrough       - Desactivar camara
  [3] Toggle Passthrough        - Alternar

Select:
```

### Opciones:

#### [1] Enable Passthrough
Activa la camara para ver mundo real
```
Enabling passthrough...

[OK]  2G0YC1ZF7G070P - Enable Passthrough
[OK]  2G0YC1ZF7W0SLT - Enable Passthrough
```

#### [2] Disable Passthrough
Vuelve a VR completo
```
Disabling passthrough...

[OK]  2G0YC1ZF7G070P - Disable Passthrough
[OK]  2G0YC1ZF7W0SLT - Disable Passthrough
```

#### [3] Toggle Passthrough
Alterna entre modos (requiere confirmacion manual)
```
Toggling passthrough...
Sent HOME button command (double-tap HOME manually to toggle)
```

### Cuando usar:
- **Enable**: Desarrollo/debugging necesita ver entorno
- **Disable**: Volver a immersion completa
- **Toggle**: Cambiar rapidamente (con interaccion manual)

---

## Workflows Comunes

### Workflow 1: Conectar visores nuevos a Wi-Fi

```
1. Conectar visores via USB
2. Abrir Quas-MultiDevice.ps1
3. [A] Seleccionar todos
4. [5] Device Settings
5. [2] Connect to custom Wi-Fi
6. Ingresar: SSID + Password
7. ✓ Todos conectados!
```

**Tiempo:** ~1 minuto para multiples visores

---

### Workflow 2: Fin de jornada

```
1. Quas-MultiDevice.ps1
2. [A] Todos los visores
3. [5] Device Settings
4. [8] Stand by mode
5. ✓ Visores en reposo
6. Guardar fisicamente
```

**Beneficio:** Bateria preservada, arranged organizadamente

---

### Workflow 3: Inicio de jornada

```
1. Quas-MultiDevice.ps1
2. [A] Todos los visores
3. [5] Device Settings
4. [9] Wake up
5. ✓ Visores listos para usar
```

**Beneficio:** Todos despiertan simultaneamente

---

### Workflow 4: Desarrollo con Passthrough

```
1. Quas-MultiDevice.ps1
2. Seleccionar visor de desarrollo
3. [5] Device Settings
4. [A] Passthrough Control
5. [1] Enable Passthrough
6. ✓ Visor con camara activa
7. ...desarrollar/debuggear...
8. [2] Disable Passthrough
9. ✓ Volver a VR normal
```

---

## Comandos Rapidos (Cheat Sheet)

| Accion                    | Ruta Menu  | Input         |
|---------------------------|------------|---------------|
| Ver inventario en seleccion | Automatico | -             |
| Conectar a Wi-Fi          | 5 > 2      | SSID, Pass    |
| Dormir visores            | 5 > 8      | -             |
| Despertar visores         | 5 > 9      | -             |
| Enable passthrough        | 5 > A > 1  | -             |
| Disable passthrough       | 5 > A > 2  | -             |
| Reboot visores            | 5 > B      | Confirmar     |
| Ver settings actuales     | 5 > C      | -             |

---

## Tips y Trucos

### Tip 1: Identificacion Rapida
Asigna numeros secuenciales a tus visores:
- Sala A: Visor #1, #2, #3
- Sala B: Visor #11, #12, #13
- Desarrollo: Visor #100, #101, #102

### Tip 2: Notas Utiles
Agrega notas descriptivas:
- "Requiere actualizacion firmware"
- "Bateria de bajo rendimiento"
- "Asignado a Juan Perez"
- "Solo para demos clientes"

### Tip 3: Wi-Fi Automatizado
Crea script batch para conectar visores:
```powershell
# ConnectOfficeWiFi.bat
.\Quas-MultiDevice.ps1
# Seleccionar A
# Menu 5 > 2
# SSID: OfficeNetwork
# Pass: YourPassword
```

### Tip 4: Power Management
Al final del dia:
```
Stand by (8) > Desconectar USB > Guardar
```

Al inicio del dia:
```
Conectar USB > Wake up (9) > Listo
```

---

## Solución de Problemas

### Problema: Wi-Fi no conecta

**Soluciones:**
1. Verificar SSID correcto (case-sensitive)
2. Verificar password correcto
3. Asegurar red es WPA2
4. Verificar visor en rango de Wi-Fi
5. Algunos visores requieren confirmacion manual

### Problema: Stand by no funciona

**Soluciones:**
1. Verificar visores esten en modo normal (no VR activo)
2. Algunos apps pueden prevenir sleep
3. Cerrar apps antes de stand by

### Problema: Passthrough no activa

**Soluciones:**
1. Passthrough es especifico de Quest/Oculus
2. Verificar dispositivo soporta passthrough
3. Opcion [3] requiere interaccion manual (double-tap HOME)
4. Usar [1] o [2] para control programatico

---

## Preguntas Frecuentes

**Q: El numero de visor se muestra en seleccion?**  
R: Si, si has asignado customNumber en el inventario.

**Q: Puedo conectar a Wi-Fi sin password?**  
R: La funcion actual requiere password. Para redes abiertas, usa opcion [1] (enable Wi-Fi).

**Q: Stand by apaga completamente el visor?**  
R: No, solo pone en modo reposo (screen off, low power). Para apagar completamente, usa el boton fisico.

**Q: Passthrough funciona en todos los visores?**  
R: No, es especifico de Quest/Oculus. Otros visores VR pueden no soportarlo.

**Q: Las notas tienen limite de caracteres?**  
R: En el inventario no, pero en seleccion se muestran solo primeros 50 caracteres.

**Q: Puedo ver el password Wi-Fi despues de ingresarlo?**  
R: No, por seguridad no se muestra ni se guarda.

---

## Atajos de Teclado (Futuro)

Version actual usa menu interactivo.  
Posibles mejoras futuras:
- Parametros de linea de comando
- Scripts automatizados
- API REST

---

## Recursos Adicionales

- **MEJORAS-IMPLEMENTADAS.md** - Documentacion tecnica completa
- **GUIA-INVENTARIO.md** - Sistema de inventario
- **DEVICE-SETTINGS-GUIDE.md** - Guia de Device Settings
- **README-MultiDevice.md** - Documentacion general

---

**Version:** 1.1.0  
**Fecha:** 2025-11-25  
**Estado:** Produccion  
