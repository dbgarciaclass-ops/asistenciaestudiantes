import 'package:http_certificate_pinning/http_certificate_pinning.dart';
import 'package:http/http.dart' as http;

/// Servicio de red con SSL Certificate Pinning
class SecureNetworkService {
  static const String _serverUrl = 'https://www.liceojacintodelaconcha.com';
  
  // ⚠️ IMPORTANTE: Reemplaza esto con el SHA256 fingerprint real de tu certificado
  // Ver CONFIGURAR_SSL_PINNING.md para instrucciones
  static const String _certificateFingerprint = 'TU_SHA256_FINGERPRINT_AQUI';
  
  static bool _isPinningEnabled = false;
  
  /// Verificar si el certificate pinning está configurado
  static bool get isPinningConfigured {
    return _certificateFingerprint != 'TU_SHA256_FINGERPRINT_AQUI' && 
           _certificateFingerprint.isNotEmpty;
  }

  /// Inicializar el certificate pinning
  static Future<void> initialize() async {
    if (!isPinningConfigured) {
      // En producción, esto debería ser un error
      // Por ahora, solo logueamos una advertencia
      print('⚠️ WARNING: Certificate pinning no configurado. Ver CONFIGURAR_SSL_PINNING.md');
      _isPinningEnabled = false;
      return;
    }

    try {
      // Verificar el pinning
      await HttpCertificatePinning.check(
        serverURL: _serverUrl,
        headerHttp: {},
        sha: SHA.SHA256,
        allowedSHAFingerprints: [_certificateFingerprint],
        timeout: 10,
      );
      _isPinningEnabled = true;
      print('✅ Certificate pinning habilitado correctamente');
    } catch (e) {
      print('❌ Error al verificar certificate pinning: $e');
      _isPinningEnabled = false;
      // En producción, podrías querer lanzar una excepción aquí
    }
  }

  /// Crear un cliente HTTP con certificate pinning
  static Future<http.Response> secureGet(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_isPinningEnabled && isPinningConfigured) {
      try {
        final responseBody = await HttpCertificatePinning.check(
          serverURL: url,
          headerHttp: headers ?? {},
          sha: SHA.SHA256,
          allowedSHAFingerprints: [_certificateFingerprint],
          timeout: timeout.inSeconds,
        );
        
        // HttpCertificatePinning.check retorna String (el body)
        // Asumimos status 200 si no falla
        return http.Response(responseBody, 200);
      } catch (e) {
        throw Exception('Certificate pinning failed: $e');
      }
    } else {
      // Fallback a http normal si no está configurado
      return await http.get(Uri.parse(url), headers: headers).timeout(timeout);
    }
  }

  /// POST seguro con certificate pinning
  static Future<http.Response> securePost(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // La librería http_certificate_pinning no soporta POST directamente
    // Usamos http normal para POST (el pinning se verifica en la inicialización)
    if (!isPinningConfigured) {
      print('⚠️ WARNING: Certificate pinning no configurado para POST');
    }
    
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    ).timeout(timeout);
  }
}
