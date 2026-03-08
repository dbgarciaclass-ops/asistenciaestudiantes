# Generar Keystore de Producción

## ⚠️ IMPORTANTE: Hacer esto ANTES de publicar la app

## Paso 1: Generar el Keystore

Ejecuta este comando en PowerShell desde la raíz del proyecto:

```powershell
# Crear directorio para el keystore
New-Item -ItemType Directory -Force -Path "android\keystore"

# Generar el keystore (requiere Java/Android Studio instalado)
keytool -genkey -v -keystore android\keystore\asistenciaestudiantes.jks -keyalg RSA -keysize 2048 -validity 10000 -alias asistenciaestudiantes
```

## Paso 2: Información requerida

El comando te pedirá:
- **Contraseña del keystore**: Usa una contraseña segura (mínimo 12 caracteres)
- **Contraseña de la key**: Usa la misma contraseña (más simple)
- **Nombre y apellido**: Liceo Jacinto de la Concha
- **Unidad organizativa**: Departamento IT
- **Organización**: Liceo Jacinto de la Concha
- **Ciudad**: Tu ciudad
- **Provincia**: Tu provincia
- **Código de país**: EC (o el tuyo)

## Paso 3: Crear key.properties

Copia el archivo `key.properties.example` a `key.properties`:

```powershell
Copy-Item android\key.properties.example android\key.properties
```

Edita `android\key.properties` y reemplaza:
- `TU_PASSWORD_AQUI` con la contraseña que usaste

## Paso 4: Verificar

- ✅ Archivo `android\keystore\asistenciaestudiantes.jks` generado
- ✅ Archivo `android\key.properties` configurado
- ✅ Archivo `.gitignore` actualizado (no subir estos archivos)

## ⚠️ GUARDAR BACKUP SEGURO

**MUY IMPORTANTE:**
1. Haz backup del archivo `.jks` y las contraseñas
2. Guárdalos en un lugar seguro (NO en el repositorio)
3. Si pierdes el keystore, NO podrás actualizar la app en Google Play

## Verificar firma

Para verificar que el keystore fue creado correctamente:

```powershell
keytool -list -v -keystore android\keystore\asistenciaestudiantes.jks -alias asistenciaestudiantes
```
