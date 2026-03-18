# Nueva Funcionalidad: Comandos de Entorno Open Brush

## Descripción
Se han añadido dos nuevos comandos al menú de Open Brush para controlar el tipo de entorno visual.

## Nuevos Comandos

### [4] Environment Pistachio
- **Comando:** `environment.type=pistachio`
- **URL:** `http://{IP}:40074/api/v1?environment.type=pistachio`
- **Función:** Cambia el entorno a un fondo sólido (Pistachio).

### [5] Environment Passthrough
- **Comando:** `environment.type=passtrough`
- **URL:** `http://{IP}:40074/api/v1?environment.type=passtrough`
- **Función:** Activa el modo Passthrough (cámaras) para ver el entorno real.

## Ubicación
Main Menu > [O] Open Brush > Opciones [4] y [5]

## Archivos Modificados
- `Quas-MultiDevice.ps1`: Actualizado menú y lógica de switch
- `OPEN-BRUSH-API.md`: Documentación actualizada
- `test-openbrush-api.ps1`: Script de prueba actualizado

## Notas
- Se utiliza concatenación explícita de strings para construir las URLs correctamente.
- Se respeta la ortografía "passtrough" solicitada para el parámetro de la API.
