# Distribución iOS - AsistenciaEstudiantes

## Requisitos previos

### 1. Cuenta Apple Developer ($99/año)
- Registro: https://developer.apple.com/programs/
- Necesario para publicar en TestFlight y App Store

### 2. Crear App en App Store Connect

1. Ve a https://appstoreconnect.apple.com
2. Click en "Apps" → "+" → "Nueva App"
3. Completa:
   - **Nombre:** Asistencia Estudiantes
   - **Idioma principal:** Español
   - **Bundle ID:** com.liceojacinto.asistenciaestudiantes (crear nuevo)
   - **SKU:** asistencia-estudiantes-001
   - **Acceso de usuario:** Full Access

### 3. Configurar Codemagic con Apple

#### A. Generar API Key de App Store Connect

1. En App Store Connect: **Usuarios y acceso** → **Claves API**
2. Click "+" para crear nueva clave
3. Datos:
   - **Nombre:** Codemagic CI
   - **Acceso:** Desarrollador
4. Descargar el archivo `.p8` (guárdalo, solo se descarga una vez)
5. Copiar:
   - **Key ID** (ej: `ABC123DEF4`)
   - **Issuer ID** (ej: `12345678-1234-1234-1234-123456789012`)

#### B. Configurar en Codemagic

1. Ve a https://codemagic.io/apps
2. Selecciona tu app `asistenciaestudiantes`
3. **Environment variables**:
   - `APP_STORE_CONNECT_PRIVATE_KEY`: pega el contenido del archivo `.p8`
   - `APP_STORE_CONNECT_KEY_IDENTIFIER`: pega el Key ID
   - `APP_STORE_CONNECT_ISSUER_ID`: pega el Issuer ID
   - Marca todas como "Secure"

#### C. Configurar certificados

1. En Codemagic → **Code signing identities**
2. **iOS certificates**:
   - Click "Add certificate"
   - Selecciona "Automatic" (Codemagic lo genera)
   - O sube tu certificado de distribución manual

3. **Provisioning profiles**:
   - Click "Add profile"
   - Selecciona "Automatic" (recomendado)

#### D. Actualizar Team ID

1. En https://developer.apple.com → **Membership** → copiar **Team ID**
2. Editar archivo `ios/ExportOptions.plist`:
   ```xml
   <key>teamID</key>
   <string>TU_TEAM_ID_AQUI</string>
   ```

## Proceso de publicación

### Compilación automática

Cada `git push` a `main`:
1. Codemagic compila el `.ipa` firmado
2. Sube automáticamente a TestFlight
3. Notifica por email cuando esté listo

### Distribución manual (si prefieres)

```bash
# Compilar localmente (requiere Mac + Xcode)
flutter build ipa --release

# El archivo estará en:
# build/ios/ipa/asistenciaestudiantes.ipa

# Subir manualmente con Transporter app (Mac)
```

## TestFlight - Distribución Beta

### 1. Probar internamente

1. En App Store Connect → tu app → **TestFlight**
2. **Grupo de prueba interno**:
   - Agregar usuarios (hasta 100)
   - Usuarios deben ser parte del equipo de App Store Connect

### 2. Probar externamente (profesores/usuarios finales)

1. En TestFlight → **Grupos de prueba externos**
2. Click "+" para crear grupo:
   - **Nombre:** Liceo Jacinto Beta
   - **Agregar probadores:** emails de profesores
3. **Información de prueba**:
   - Descripción de qué probar
   - Email de contacto
   - Política de privacidad URL (opcional)
4. **Enviar a revisión de Apple** (primera vez, 24-48h)

### 3. Instalación para usuarios

Los probadores reciben email con instrucciones:
1. Descargar **TestFlight** desde App Store
2. Tocar enlace de invitación en el email
3. Instalar "Asistencia Estudiantes"

**Link de invitación público** (opcional):
- En TestFlight → Grupo externo → "Habilitar link público"
- Copiar link y compartir (ej: en la web del liceo)

## Publicar en App Store (producción)

Cuando esté lista para todos:

1. En App Store Connect → tu app → **App Store**
2. **Versión 1.0**:
   - Capturas de pantalla (iPhone 6.7" requerido)
   - Descripción de la app
   - Palabras clave
   - URL de soporte
   - Política de privacidad URL
3. **Información de revisión**:
   - Credenciales de prueba (usuario/contraseña para probar)
   - Notas para el revisor
4. Click **Enviar a revisión**
5. Esperar aprobación (3-7 días promedio)

## Alternativa: Distribución Ad-hoc (sin TestFlight)

Si NO quieres cuenta de $99/año:

**Limitaciones:**
- Solo funciona en **hasta 100 dispositivos** registrados manualmente
- Cada iPhone debe registrar su UDID
- Más complejo de gestionar

**Proceso:**
1. Recopilar UDID de cada iPhone (Settings → General → About)
2. Registrar en https://developer.apple.com → Devices
3. Crear provisioning profile Ad-hoc con esos dispositivos
4. Compilar con ese profile
5. Distribuir `.ipa` + profile vía email/web
6. Usuarios instalan con Apple Configurator 2 (Mac) o herramientas de terceros

**NO recomendado para escuelas** (mejor usar TestFlight).

## Actualizar la app

Proceso automático:
1. Hacer cambios en el código
2. Actualizar versión en `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # 1.0.1 = version, +2 = build number
   ```
3. `git commit` y `git push`
4. Codemagic compila y sube a TestFlight automáticamente
5. En App Store Connect → aprobar nueva build para probadores

## Troubleshooting

### Error: "No signing certificate"
- Configurar certificados en Codemagic → Code signing identities

### Error: "Bundle ID mismatch"
- Verificar que `com.liceojacinto.asistenciaestudiantes` esté en:
  - `ios/Runner/Info.plist`
  - App Store Connect
  - Codemagic configuración

### Build en Codemagic pero no aparece en TestFlight
- Revisar logs: puede estar en revisión de Apple (primera build)
- Verificar que `submit_to_testflight: true` esté en `codemagic.yaml`

### Usuarios no reciben invitación de TestFlight
- Verificar email correcto en App Store Connect
- Revisar carpeta spam
- Reenviar invitación desde TestFlight

## Soporte

- Documentación Codemagic: https://docs.codemagic.io/flutter-publishing/
- Apple Developer: https://developer.apple.com/support/
- TestFlight: https://developer.apple.com/testflight/
