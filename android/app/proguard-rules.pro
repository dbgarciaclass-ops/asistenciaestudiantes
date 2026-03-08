# Reglas ProGuard para Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Mantener clases de reflexión
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Reglas para http package
-keep class dart.** { *; }
-keep class com.google.gson.** { *; }

# No ofuscar nombres de archivos y números de línea (útil para debugging)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
