# Fix: Open Brush API URL Construction

## Problema
Las URLs de la API no estaban incluyendo la IP del visor.

### Salida con Error:
```
Calling API: http:///api/v1?new
[FAIL] Error: Cannot bind parameter 'Uri'. Cannot convert value "http:///api/v1?new" to type "System.Uri"
```

### Causa Raíz
PowerShell no interpola correctamente variables cuando hay un `:` seguido de números inmediatamente después.

**Código problemático:**
```powershell
$apiUrl = "http://$ipAddress:40074/api/v1?new"
# PowerShell interpreta $ipAddress:40074 como el nombre de una variable
# Resultado: http:///api/v1?new ❌
```

PowerShell confunde `$ipAddress:40074` pensando que `:40074` es parte del nombre de la variable.

## Solución
Usar concatenación explícita en lugar de interpolación de strings.

**Código corregido:**
```powershell
$apiUrl = "http://" + $ipAddress + ":40074/api/v1?new"
# Resultado: http://192.168.12.33:40074/api/v1?new ✅
```

## Archivos Modificados
- `Quas-MultiDevice.ps1` - 3 ubicaciones (líneas 1749, 1793, 1836)
- `test-openbrush-api.ps1` - Array de endpoints

## Verificación

### Prueba Simple:
```powershell
$ip = "192.168.12.33"
$url1 = "http://$ip:40074/test"     
$url2 = "http://" + $ip + ":40074/test"

Write-Host $url1  # http:///test ❌
Write-Host $url2  # http://192.168.12.33:40074/test ✅
```

### Resultado Actual:
```
Processing device: 2G0YC1ZF7G070P
  IP: 192.168.12.33
  Calling API: http://192.168.12.33:40074/api/v1?new ✅
```

## Lección Aprendida
En PowerShell, cuando necesitas incluir un número de puerto (`:XXXX`) después de una variable, **siempre usa concatenación explícita** para evitar problemas de parsing:

```powershell
# ✅ CORRECTO
"http://" + $variable + ":puerto"

# ❌ INCORRECTO  
"http://$variable:puerto"
```

## Estado
✅ **CORREGIDO** - URLs ahora se construyen correctamente con IP y puerto 40074
