# Configurar Certificate Pinning

## Paso 1: Obtener el certificado del servidor

Para obtener el SHA256 fingerprint del certificado SSL de tu servidor:

### Opción A: Usando OpenSSL (Recomendado)

```powershell
# Conectar al servidor y obtener el certificado
openssl s_client -servername www.liceojacintodelaconcha.com -connect www.liceojacintodelaconcha.com:443 < /dev/null | openssl x509 -fingerprint -sha256 -noout

# O en una sola línea para Windows:
echo | openssl s_client -servername www.liceojacintodelaconcha.com -connect www.liceojacintodelaconcha.com:443 2>&1 | openssl x509 -fingerprint -sha256 -noout
```

### Opción B: Usando un navegador

1. Abre https://www.liceojacintodelaconcha.com en Chrome/Edge
2. Haz clic en el candado → Detalles del certificado
3. Busca el SHA-256 Fingerprint
4. Copia el valor (ej: `A1:B2:C3:...`)

### Opción C: Usando un sitio web

Visita: https://www.ssllabs.com/ssltest/analyze.html?d=www.liceojacintodelaconcha.com

## Paso 2: Configurar el fingerprint

1. Obtén el SHA256 fingerprint del paso 1
2. Edita `lib/network_service.dart`
3. Reemplaza `'TU_SHA256_FINGERPRINT_AQUI'` con el fingerprint real
4. Formato: `'A1:B2:C3:D4:...'` (con dos puntos entre cada byte)

## Paso 3: Verificar

Ejecuta la app y verifica que:
- ✅ Las peticiones al servidor funcionan correctamente
- ✅ Si cambias el fingerprint por uno incorrecto, las peticiones fallan
- ✅ Esto confirma que el certificate pinning está funcionando

## ⚠️ IMPORTANTE

- **Renovación de certificados**: Cuando renueves el certificado SSL del servidor, deberás actualizar la app con el nuevo fingerprint
- **Múltiples certificados**: Si usas CDN o balanceadores de carga, puede que necesites múltiples fingerprints
- **Actualizaciones**: Planifica actualizaciones de la app antes de que expire el certificado

## Ejemplo de fingerprint

```dart
'3E:B0:F9:F8:49:A0:D4:8F:13:5F:F0:87:5B:44:91:2A:1E:E8:F6:2A:49:B6:8E:3D:7C:8A:9F:2F:31:4F:6A:C1'
```
