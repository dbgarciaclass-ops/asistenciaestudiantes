# 🚀 Pasos Finales Antes de Publicar

## ✅ Lo que ya está completo

- [x] Eliminación de logs sensibles
- [x] Configuración de firma de producción
- [x] Almacenamiento seguro implementado
- [x] SSL certificate pinning configurado
- [x] Validación de entrada robusta
- [x] Ofuscación de código habilitada
- [x] Dependencias instaladas

---

## ⚠️ Configuraciones Manuales Requeridas

### 1️⃣ Generar Keystore de Producción (15 minutos)

**¿Por qué?** Para firmar la app con claves seguras propias.

**Pasos:**

```powershell
# 1. Crear directorio para keystore
New-Item -ItemType Directory -Force -Path "android\keystore"

# 2. Generar keystore
keytool -genkey -v -keystore android\keystore\asistenciaestudiantes.jks -keyalg RSA -keysize 2048 -validity 10000 -alias asistenciaestudiantes
```

Cuando te pida información:
- **Contraseña del keystore:** [Usa una contraseña fuerte y guárdala]
- **Nombre:** Liceo Jacinto de la Concha
- **Unidad organizativa:** IT / Sistemas
- **Organización:** Liceo Jacinto de la Concha
- **Ciudad/Provincia/País:** [Tu ubicación]

```powershell
# 3. Copiar archivo de configuración
Copy-Item android\key.properties.example android\key.properties

# 4. Editar android\key.properties y reemplazar:
# - Reemplaza TU_PASSWORD_AQUI con la contraseña que usaste
```

**⚠️ MUY IMPORTANTE:** 
- Haz backup del archivo `.jks` y la contraseña
- NO lo subas al repositorio (ya está en .gitignore)
- Si pierdes el keystore, NO podrás actualizar la app en Play Store

---

### 2️⃣ Configurar SSL Certificate Pinning (10 minutos)

**¿Por qué?** Para proteger contra ataques Man-in-the-Middle.

**Opción A - PowerShell (Recomendado):**

```powershell
# Obtener el SHA256 fingerprint del certificado
$cert = (New-Object System.Net.WebClient).DownloadString("https://www.liceojacintodelaconcha.com")
# O usa OpenSSL si lo tienes instalado:
echo | openssl s_client -servername www.liceojacintodelaconcha.com -connect www.liceojacintodelaconcha.com:443 2>&1 | openssl x509 -fingerprint -sha256 -noout
```

**Opción B - Navegador:**
1. Abre https://www.liceojacintodelaconcha.com en Chrome
2. Click en el candado 🔒 → Detalles del certificado
3. Copia el SHA-256 Fingerprint
4. Formato: `A1:B2:C3:D4:...` (con dos puntos)

**Aplicar configuración:**

1. Abre `lib/network_service.dart`
2. Busca la línea:
   ```dart
   static const String _certificateFingerprint = 'TU_SHA256_FINGERPRINT_AQUI';
   ```
3. Reemplaza con tu fingerprint:
   ```dart
   static const String _certificateFingerprint = '3E:B0:F9:F8:49:A0:D4:8F:13:5F:F0:87:5B:44:91:2A:1E:E8:F6:2A:49:B6:8E:3D:7C:8A:9F:2F:31:4F:6A:C1';
   ```

---

### 3️⃣ Verificar API Backend (5 minutos)

**Asegúrate de que tu API Laravel:**

- ✅ Retorna un token JWT en el endpoint `/api/login`:
  ```json
  {
    "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "user": {
      "id": 1,
      "name": "Juan Pérez",
      "email": "juan@example.com",
      "role": "docente",
      "docente_id": 5
    }
  }
  ```

- ✅ Los endpoints protegidos validan el token Bearer:
  ```php
  // En tu middleware o controlador
  if (!auth()->check()) {
      return response()->json(['message' => 'Unauthorized'], 401);
  }
  ```

- ✅ CORS configurado correctamente
- ✅ HTTPS habilitado en producción

---

## 🧪 Testing (30 minutos)

### Pruebas en Desarrollo

```powershell
# 1. Limpiar builds anteriores
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Ejecutar en modo debug
flutter run
```

**Verificar:**
- ✅ Login funciona
- ✅ Auto-login funciona (cierra y abre la app)
- ✅ Logout funciona
- ✅ Todas las pantallas cargan correctamente
- ✅ No hay errores en la consola

### Pruebas en Release

```powershell
# Build de release
flutter build apk --release

# Instalar en dispositivo
flutter install --release
```

**Verificar:**
- ✅ App funciona igual que en debug
- ✅ No aparecen logs de producción
- ✅ Tamaño del APK es razonable (~15-30 MB)

---

## 📦 Build Final de Producción

```powershell
# Android APK
flutter build apk --release

# Android App Bundle (recomendado para Play Store)
flutter build appbundle --release

# Ubicación de los archivos:
# APK: build/app/outputs/flutter-apk/app-release.apk
# Bundle: build/app/outputs/bundle/release/app-release.aab
```

---

## 📱 Publicar en Google Play Store

1. **Preparar cuenta de Google Play Console**
   - Crea tu cuenta de desarrollador ($25 USD una vez)
   - https://play.google.com/console

2. **Crear nueva aplicación**
   - Nombre: Asistencia Estudiantes
   - Idioma predeterminado: Español
   - Tipo: Aplicación o juego

3. **Subir el archivo**
   - Usa `app-release.aab` (recomendado)
   - O `app-release.apk`

4. **Completar información:**
   - Descripción de la app
   - Screenshots (mínimo 2, requiere capturas de pantalla)
   - Icono (512x512 px)
   - Política de privacidad
   - Clasificación de contenido

5. **Revisar y publicar**

---

## 📋 Checklist Final

Antes de publicar, verifica:

### Seguridad
- [ ] Keystore de producción generado
- [ ] `key.properties` configurado
- [ ] Backup del keystore guardado de forma segura
- [ ] SSL certificate pinning configurado
- [ ] API backend retorna tokens JWT
- [ ] No hay datos sensibles en logs

### Funcionalidad
- [ ] Login funciona
- [ ] Auto-login funciona
- [ ] Logout funciona
- [ ] Todas las pantallas cargan
- [ ] Registro de asistencia funciona
- [ ] Consulta de resumen funciona

### Build
- [ ] `flutter clean` ejecutado
- [ ] Build de release exitoso
- [ ] App instalada y probada en dispositivo real
- [ ] Tamaño del APK/AAB razonable
- [ ] No hay advertencias críticas

### Documentación
- [ ] README.md actualizado
- [ ] Versión incrementada en pubspec.yaml
- [ ] Changelog documentado

---

## 🆘 Solución de Problemas

### Error: "Signing config not found"
- Verifica que `android/key.properties` existe
- Verifica que las rutas son correctas
- Verifica que las contraseñas coinciden

### Error: "Certificate pinning failed"
- Verifica que el fingerprint es correcto
- Usa HTTPS en la URL del servidor
- Temporalmente comenta el código de pinning para debugging

### App no inicia sesión
- Verifica que el backend retorna un token
- Revisa los logs del servidor Laravel
- Verifica CORS en el backend

---

## 📞 Recursos de Ayuda

- **Flutter Docs:** https://flutter.dev/docs
- **Google Play Console:** https://support.google.com/googleplay/android-developer
- **SSL Labs (verificar certificado):** https://www.ssllabs.com/ssltest/

---

**¡Tu app está lista para producción! 🎉**

Sigue estos pasos en orden y tendrás tu app publicada de forma segura.
