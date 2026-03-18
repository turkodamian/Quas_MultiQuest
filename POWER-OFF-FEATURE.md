# Nueva Funcionalidad: Apagar Dispositivos

## Descripción
Se ha añadido la opción **[D] Power Off devices** al menú de **Device Settings**.

## Ubicación
Main Menu > [5] Device Settings > **[D] Power Off devices**

## Funcionalidad
- Apaga completamente todos los dispositivos seleccionados.
- Utiliza el comando ADB: `adb shell reboot -p`
- Incluye diálogo de confirmación para evitar apagados accidentales.
- Ejecución en paralelo para máxima velocidad.

## Flujo de Uso
1. Seleccionar opción **[D]**.
2. Confirmar la acción: `POWER OFF X device(s)? (Y/N)`
3. Los dispositivos se apagarán inmediatamente.

## Archivos Modificados
- `Quas-MultiDevice.ps1`: Implementación de la opción [D]
- `DEVICE-SETTINGS-MENU.md`: Documentación actualizada

## Notas
- El comando `reboot -p` es el estándar para apagar dispositivos Android desde ADB.
- Es útil para apagar todos los visores al finalizar una sesión o jornada.
