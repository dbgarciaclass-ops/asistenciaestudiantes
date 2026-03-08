# 🚀 Guía de Despliegue a Producción

Esta guía te ayudará a compilar y desplegar la aplicación web en tu servidor de producción.

---

## 📋 Pre-requisitos

Antes de compilar para producción:

### 1. **Completar Configuraciones de Seguridad**

✅ **Generar Keystore para Android** (si vas a distribuir APK)
```bash
keytool -genkey -v -keystore android/keystore/asistenciaestudiantes.jks -keyalg RSA -keysize 2048 -validity 10000 -alias asistenciaestudiantes
```

✅ **Configurar SSL Certificate Pinning**
```dart
// En lib/network_service.dart, reemplaza:
static const String _certificateFingerprint = 'TU_SHA256_FINGERPRINT_AQUI';

// Por el fingerprint real de tu certificado SSL:
static const String _certificateFingerprint = 'AA:BB:CC:DD:...';
```

✅ **Configurar API Base URL**
```dart
// En lib/main.dart, verifica que apunte a producción:
static const String baseUrl = 'https://www.liceojacintodelaconcha.com/api';
```

✅ **Configurar Backend Endpoint para Actualizaciones**
Crea en tu Laravel el endpoint `/api/app-version` (ver SISTEMA_ACTUALIZACIONES.md)

---

## 🌐 Compilar para WEB (PWA)

### Paso 1: Limpiar Build Anterior
```powershell
flutter clean
flutter pub get
```

### Paso 2: Compilar Build Optimizado
```powershell
flutter build web --release --web-renderer html
```

**Parámetros importantes:**
- `--release`: Modo producción (código optimizado y minificado)
- `--web-renderer html`: Mejor compatibilidad (alternativa: `canvaskit` para mejor rendimiento)
- `--base-href /`: Si la app estará en un subdirectorio, especificar la ruta (ej: `/asistencia/`)

**Ejemplo con subdirectorio:**
```powershell
flutter build web --release --web-renderer html --base-href /asistencia/
```

### Paso 3: Verificar Build Compilado
El build estará en: `build/web/`

Archivos generados:
```
build/web/
├── assets/
├── canvaskit/
├── icons/
├── favicon.png
├── flutter.js
├── flutter_bootstrap.js
├── index.html
├── main.dart.js
├── manifest.json
└── version.json
```

---

## 📤 Subir a Producción

### Opción A: Servidor Apache

#### 1. Subir archivos via FTP/SFTP
Sube todo el contenido de `build/web/` a tu servidor:
```
/var/www/html/asistencia/
```

#### 2. Configurar .htaccess
Crea `build/web/.htaccess`:

```apache
<IfModule mod_rewrite.c>
  RewriteEngine On
  
  # No rewrite para archivos existentes
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  
  # Redirigir todo a index.html (SPA routing)
  RewriteRule ^ index.html [L]
</IfModule>

# Habilitar HTTPS
<IfModule mod_rewrite.c>
  RewriteCond %{HTTPS} off
  RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</IfModule>

# Headers de seguridad
<IfModule mod_headers.c>
  Header set X-Content-Type-Options "nosniff"
  Header set X-Frame-Options "SAMEORIGIN"
  Header set X-XSS-Protection "1; mode=block"
  Header set Referrer-Policy "strict-origin-when-cross-origin"
</IfModule>

# Cache para recursos estáticos
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/svg+xml "access plus 1 year"
  ExpiresByType application/javascript "access plus 1 year"
  ExpiresByType text/css "access plus 1 year"
  ExpiresByType font/woff2 "access plus 1 year"
</IfModule>

# Comprimir archivos
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json
</IfModule>
```

Sube el `.htaccess` junto con los archivos web.

#### 3. Verificar Permisos
```bash
chmod -R 755 /var/www/html/asistencia/
```

---

### Opción B: Servidor Nginx

#### 1. Subir archivos
Sube `build/web/` a `/var/www/asistencia/`

#### 2. Configurar Nginx
Edita tu configuración de sitio:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name www.liceojacintodelaconcha.com;
    
    # Redirigir a HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.liceojacintodelaconcha.com;

    # Certificados SSL
    ssl_certificate /etc/ssl/certs/tu_certificado.crt;
    ssl_certificate_key /etc/ssl/private/tu_clave.key;

    # Configuración SSL segura
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root /var/www/asistencia;
    index index.html;

    # Headers de seguridad
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # SPA routing - redirigir todo a index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Comprimir respuestas
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

#### 3. Reiniciar Nginx
```bash
sudo nginx -t  # Probar configuración
sudo systemctl reload nginx
```

---

### Opción C: Hosting Compartido (cPanel)

1. **Accede a cPanel → File Manager**
2. **Navega a public_html/** (o subdirectorio)
3. **Sube todos los archivos de build/web/**
4. **Crea .htaccess** con la configuración de Apache mostrada arriba
5. **Verifica que SSL esté habilitado** en cPanel

---

## 🔍 Verificar PWA Funcionando

### 1. Abrir en Navegador
Visita: `https://www.liceojacintodelaconcha.com`

### 2. Verificar con Chrome DevTools

#### Abrir DevTools (F12)

**A. Verificar Manifest**
1. Ve a **Application** (pestaña)
2. En el menú izquierdo: **Manifest**
3. Deberías ver:
   - ✅ Name: "Asistencia Estudiantes - Liceo Jacinto de la Concha"
   - ✅ Short name: "Asistencia"
   - ✅ Start URL: "/"
   - ✅ Theme color: #2a5298
   - ✅ Iconos: 192x192 y 512x512

**B. Verificar Service Worker**
1. En **Application → Service Workers**
2. Debería aparecer el service worker de Flutter
3. Estado: **Activated and is running**

**C. Lighthouse Audit (Importante)**
1. En DevTools: **Lighthouse** (pestaña)
2. Selecciona:
   - ✅ Progressive Web App
   - ✅ Performance
   - ✅ Accessibility
   - ✅ Best Practices
   - ✅ SEO
3. Click **Analyze page load**
4. **Objetivo:** PWA score de 90+ puntos

**D. Verificar HTTPS**
1. En la barra de URL debe aparecer el candado 🔒
2. Click en el candado → **Connection is secure**
3. Certificado debe estar válido

---

## 📱 Instalar como PWA

### En Móvil (Android - Chrome)

1. Abre `https://www.liceojacintodelaconcha.com` en Chrome
2. Aparecerá banner: **"Agregar Asistencia a la pantalla de inicio"**
3. O bien: Menú (⋮) → **Instalar aplicación**
4. Click **Instalar**
5. La app aparecerá en el cajón de aplicaciones

### En Móvil (iOS - Safari)

1. Abre la URL en Safari
2. Click en botón **Compartir** (cuadrado con flecha)
3. Scroll y selecciona **"Añadir a pantalla de inicio"**
4. Confirma

### En Desktop (Chrome/Edge)

1. Abre la URL
2. En la barra de navegación: icono **+** (Instalar)
3. O bien: Menú → **Instalar Asistencia...**
4. Click **Instalar**
5. Se abre como aplicación independiente

---

## 🧪 Testing de Producción

### Checklist de Verificación

#### Funcionalidad
- [ ] Login funciona correctamente
- [ ] Auto-login al recargar página
- [ ] Selección de aula y fecha
- [ ] Registro de asistencia se guarda
- [ ] Logout funciona
- [ ] Notificación de actualización aparece (si configuraste endpoint)

#### PWA
- [ ] Se puede instalar como app
- [ ] Funciona sin conexión (carga última versión en caché)
- [ ] Iconos correctos en pantalla de inicio
- [ ] Splash screen aparece al abrir (color azul institucional)
- [ ] Barra de estado tiene color theme (#2a5298)

#### Seguridad
- [ ] HTTPS habilitado (candado verde)
- [ ] Certificado SSL válido
- [ ] Warning de SSL pinning aparece en consola (si no está configurado)
- [ ] Headers de seguridad presentes (verificar en Network tab)

#### Performance
- [ ] Carga inicial < 3 segundos
- [ ] Animaciones fluidas
- [ ] Sin errores en consola
- [ ] Lighthouse PWA score > 90

---

## 🔧 Comandos Útiles de Mantenimiento

### Actualizar Aplicación

1. **Hacer cambios en código**
2. **Incrementar versión** en `pubspec.yaml`:
```yaml
version: 1.0.1+2  # 1.0.1 = version name, 2 = build number
```

3. **Compilar nuevo build**:
```powershell
flutter build web --release --web-renderer html
```

4. **Subir archivos a servidor** (reemplazar `build/web/`)

5. **Limpiar caché del navegador** o esperar que service worker actualice automáticamente

### Verificar Build Localmente Antes de Subir

```powershell
# Instalar servidor HTTP simple
dart pub global activate dhttpd

# Servir build web
dhttpd --path build/web --port 8080

# Abrir en navegador:
# http://localhost:8080
```

---

## 📊 Monitoreo Post-Despliegue

### Logs del Servidor

**Apache:**
```bash
tail -f /var/log/apache2/access.log
tail -f /var/log/apache2/error.log
```

**Nginx:**
```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Analytics (Opcional)

Agregar Google Analytics en `web/index.html` antes de `</head>`:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=TU-ID-AQUI"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'TU-ID-AQUI');
</script>
```

---

## 🐛 Troubleshooting Común

### Problema: App no se puede instalar como PWA

**Solución:**
- Verificar que `manifest.json` esté accesible: `https://tudominio.com/manifest.json`
- Verificar HTTPS habilitado
- Verificar que existan los iconos en `icons/`
- Revisar consola del navegador (F12) para errores

### Problema: Rutas no funcionan (404 en refresh)

**Solución:**
- Verificar `.htaccess` (Apache) o configuración Nginx
- El servidor debe redirigir todas las rutas a `index.html`

### Problema: Assets no cargan (imágenes, fuentes)

**Solución:**
- Verificar rutas en `pubspec.yaml`
- Verificar permisos de archivos (755)
- Limpiar caché del navegador (Ctrl+Shift+R)

### Problema: Service Worker bloqueado por política CORS

**Solución:**
- Verificar headers CORS en servidor
- Service worker debe estar en mismo origen que la app

### Problema: "Certificate pinning no configurado" en consola

**Solución:**
- Esto es solo un warning
- Configura el fingerprint en `lib/network_service.dart`
- O déjalo así para desarrollo (usar fallback HTTP normal)

---

## 📱 Compilar APK para Android (Opcional)

Si también quieres distribuir como APK nativo:

```powershell
# Build APK
flutter build apk --release

# Build App Bundle (para Google Play)
flutter build appbundle --release

# APK resultante en:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## ✅ Checklist Final Pre-Producción

- [ ] SSL Certificate configurado y válido
- [ ] API Base URL apunta a producción
- [ ] SSL Pinning fingerprint configurado (o comentado para desarrollo)
- [ ] Endpoint `/api/app-version` configurado en backend
- [ ] Version number incrementado en `pubspec.yaml`
- [ ] Build compilado sin errores: `flutter build web --release`
- [ ] `.htaccess` o configuración Nginx lista
- [ ] Archivos subidos a servidor
- [ ] HTTPS funciona (candado verde)
- [ ] PWA instalable en móvil y desktop
- [ ] Login funciona correctamente
- [ ] Lighthouse audit score > 90
- [ ] Testing completo realizado

---

## 🎉 ¡Listo para Producción!

Tu aplicación ahora está:
- ✅ Optimizada y minificada
- ✅ Servida via HTTPS
- ✅ Instalable como PWA
- ✅ Con caché offline
- ✅ Segura con validación de entrada
- ✅ Lista para tráfico real

**URL de Acceso:**
- Web: `https://www.liceojacintodelaconcha.com`
- PWA instalada: Desde pantalla de inicio del dispositivo

---

## 📞 Soporte

Si encuentras problemas durante el despliegue:

1. **Revisar logs del servidor** (Apache/Nginx)
2. **Revisar consola del navegador** (F12)
3. **Verificar configuración HTTPS**
4. **Asegurar que backend Laravel esté funcionando**

---

**Fecha de Última Actualización:** Marzo 2026
**Versión de Flutter:** 3.11.0
**Versión de la App:** 1.0.0+1
