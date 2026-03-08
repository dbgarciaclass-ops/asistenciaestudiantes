# Sistema de Notificación de Actualizaciones

## 📱 Funcionalidad Implementada en Flutter

La app ahora verifica automáticamente si hay actualizaciones disponibles cuando el usuario inicia sesión.

### Características:
- ✅ Verificación automática de versiones
- ✅ Diálogo visual moderno informando de actualizaciones
- ✅ Comparación de versiones usando build numbers
- ✅ Soporte para actualizaciones opcionales y obligatorias
- ✅ Notas de la versión (release notes)
- ✅ Enlace directo para descargar la actualización

---

## 🔧 Configuración del Backend Laravel

Para que funcione el sistema de actualizaciones, necesitas agregar un endpoint en tu API Laravel:

### 1. Crear el Endpoint

Agrega esta ruta en `routes/api.php`:

```php
Route::get('/app-version', function (Request $request) {
    return response()->json([
        'version' => '1.1.0',  // Versión más reciente disponible
        'build_number' => 2,   // Número de build (debe incrementarse con cada versión)
        'download_url' => 'https://www.liceojacintodelaconcha.com/downloads/asistencia-estudiantes.apk',
        'force_update' => false,  // true = actualización obligatoria, false = opcional
        'release_notes' => 'Mejoras en la interfaz de usuario y corrección de errores de seguridad.',
    ]);
});
```

### 2. O Crear un Controlador (Recomendado)

Crea un controlador para gestionar las versiones:

```bash
php artisan make:controller AppVersionController
```

En `app/Http/Controllers/AppVersionController.php`:

```php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class AppVersionController extends Controller
{
    public function getLatestVersion(Request $request)
    {
        // Podrías almacenar esto en una tabla de la base de datos
        // o en un archivo de configuración
        
        $platform = $request->input('platform', 'android'); // android o ios
        
        $versions = [
            'android' => [
                'version' => '1.1.0',
                'build_number' => 2,
                'download_url' => 'https://www.liceojacintodelaconcha.com/downloads/asistencia-estudiantes.apk',
                'force_update' => false,
                'release_notes' => "✨ Mejoras:\n- Interfaz modernizada\n- Mejoras de seguridad\n- Corrección de errores menores",
                'min_supported_version' => '1.0.0',
            ],
            'ios' => [
                'version' => '1.1.0',
                'build_number' => 2,
                'download_url' => 'https://apps.apple.com/app/...',
                'force_update' => false,
                'release_notes' => "✨ Mejoras:\n- Interfaz modernizada\n- Mejoras de seguridad\n- Corrección de errores menores",
                'min_supported_version' => '1.0.0',
            ],
        ];
        
        return response()->json($versions[$platform] ?? $versions['android']);
    }
}
```

Luego en `routes/api.php`:

```php
use App\Http\Controllers\AppVersionController;

Route::get('/app-version', [AppVersionController::class, 'getLatestVersion']);
```

### 3. Versión Avanzada con Base de Datos

Crear una tabla para gestionar versiones:

```bash
php artisan make:migration create_app_versions_table
```

En la migración:

```php
public function up()
{
    Schema::create('app_versions', function (Blueprint $table) {
        $table->id();
        $table->string('version');
        $table->integer('build_number');
        $table->enum('platform', ['android', 'ios', 'both'])->default('both');
        $table->text('download_url');
        $table->boolean('force_update')->default(false);
        $table->text('release_notes')->nullable();
        $table->string('min_supported_version')->nullable();
        $table->boolean('is_active')->default(true);
        $table->timestamps();
    });
}
```

Crear el modelo:

```bash
php artisan make:model AppVersion
```

En `app/Models/AppVersion.php`:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AppVersion extends Model
{
    protected $fillable = [
        'version',
        'build_number',
        'platform',
        'download_url',
        'force_update',
        'release_notes',
        'min_supported_version',
        'is_active',
    ];

    protected $casts = [
        'force_update' => 'boolean',
        'is_active' => 'boolean',
    ];

    public static function getLatestForPlatform($platform = 'android')
    {
        return self::where('is_active', true)
            ->where(function($query) use ($platform) {
                $query->where('platform', $platform)
                      ->orWhere('platform', 'both');
            })
            ->orderBy('build_number', 'desc')
            ->first();
    }
}
```

Actualizar el controlador:

```php
public function getLatestVersion(Request $request)
{
    $platform = $request->input('platform', 'android');
    
    $version = AppVersion::getLatestForPlatform($platform);
    
    if (!$version) {
        return response()->json([
            'version' => '1.0.0',
            'build_number' => 1,
            'download_url' => '',
            'force_update' => false,
            'release_notes' => null,
        ]);
    }
    
    return response()->json([
        'version' => $version->version,
        'build_number' => $version->build_number,
        'download_url' => $version->download_url,
        'force_update' => $version->force_update,
        'release_notes' => $version->release_notes,
        'min_supported_version' => $version->min_supported_version,
    ]);
}
```

---

## 📦 Cómo Publicar una Nueva Versión

### 1. Actualizar versión en Flutter

En `pubspec.yaml`:

```yaml
version: 1.1.0+2
#        ^     ^
#        |     build number (debe incrementarse siempre)
#        versión legible
```

### 2. Generar el APK/AAB

```bash
flutter build apk --release
# o
flutter build appbundle --release
```

### 3. Subir el archivo a tu servidor

Sube el APK generado a tu servidor web:

```bash
# El archivo estará en:
# build/app/outputs/flutter-apk/app-release.apk

# Súbelo a:
# https://www.liceojacintodelaconcha.com/downloads/asistencia-estudiantes.apk
```

### 4. Actualizar el endpoint en Laravel

**Opción A - Archivo de configuración:**

Actualiza la respuesta del endpoint con la nueva versión.

**Opción B - Base de datos:**

```php
AppVersion::create([
    'version' => '1.1.0',
    'build_number' => 2,
    'platform' => 'android',
    'download_url' => 'https://www.liceojacintodelaconcha.com/downloads/asistencia-estudiantes-v1.1.0.apk',
    'force_update' => false, // Cambiar a true si es crítica
    'release_notes' => "✨ Mejoras:\n- Interfaz modernizada\n- Mejoras de seguridad\n- Corrección de errores",
    'is_active' => true,
]);
```

---

## 🎯 Tipos de Actualizaciones

### Actualización Opcional (`force_update: false`)
- El usuario puede cerrar el diálogo y seguir usando la app
- Bueno para mejoras menores o nuevas funcionalidades

### Actualización Obligatoria (`force_update: true`)
- El usuario NO puede cerrar el diálogo
- DEBE actualizar para usar la app
- Usar solo para:
  - Correcciones de seguridad críticas
  - Cambios incompatibles con versiones antiguas
  - Bugs críticos que impiden el uso de la app

---

## 💡 Ejemplo Completo de Respuesta del Endpoint

```json
{
  "version": "1.2.0",
  "build_number": 3,
  "download_url": "https://www.liceojacintodelaconcha.com/downloads/asistencia-estudiantes-v1.2.0.apk",
  "force_update": false,
  "release_notes": "🎉 Nueva versión disponible!\n\n✨ Novedades:\n• Interfaz modernizada y más intuitiva\n• Nuevas animaciones y transiciones\n• Sistema de notificaciones de actualizaciones\n\n🔒 Seguridad:\n• Almacenamiento seguro de credenciales\n• Certificado SSL Pinning\n• Validación mejorada de entradas\n\n🐛 Correcciones:\n• Corrección de errores menores\n• Mejoras de rendimiento",
  "min_supported_version": "1.0.0"
}
```

---

## 🧪 Probar el Sistema

### 1. En desarrollo

Cambia temporalmente el endpoint en `lib/update_service.dart` a:

```dart
static const String _updateCheckUrl = 'http://10.0.2.2:8000/api/app-version'; // Para emulador Android
// o
static const String _updateCheckUrl = 'http://localhost:8000/api/app-version'; // Para dispositivo físico
```

### 2. Simular actualización disponible

En tu endpoint Laravel, retorna un build_number mayor al que tienes en `pubspec.yaml`:

```php
'build_number' => 999, // Mucho mayor que el actual
```

### 3. Ejecutar la app

Inicia sesión y verás el diálogo de actualización.

---

## 📝 Checklist para Publicar Actualización

- [ ] Incrementar versión en `pubspec.yaml`
- [ ] Incrementar build_number en `pubspec.yaml`
- [ ] Hacer build de release (`flutter build apk --release`)
- [ ] Probar el APK en un dispositivo real
- [ ] Subir APK al servidor web
- [ ] Actualizar endpoint Laravel con nueva versión
- [ ] Decidir si es `force_update` o no
- [ ] Escribir release notes descriptivas
- [ ] Probar que el diálogo aparece correctamente
- [ ] Verificar que el enlace de descarga funciona

---

¡El sistema está listo! Los usuarios serán notificados automáticamente cuando haya actualizaciones disponibles. 🚀
