# asistenciaestudiantes

## Versionado de la APK

La APK ahora debe manejarse con la versión declarada en `pubspec.yaml`.

Ejemplo actual:

```yaml
version: 1.1.0+2
```

- `1.1.0` es la versión visible para el usuario.
- `2` es el build number interno y debe incrementarse en cada APK nueva.

Para generar una nueva APK versionada:

```powershell
flutter build apk --release
```

Si necesitas forzar una versión puntual durante el build:

```powershell
flutter build apk --release --build-name=1.1.1 --build-number=3
```

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
