import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio para gestión segura de autenticación y tokens
class SecureAuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Keys para el almacenamiento seguro
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyDocenteId = 'docente_id';

  /// Guardar token y datos de usuario de forma segura
  static Future<void> saveAuthData({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserId, value: user['id'].toString());
    await _storage.write(key: _keyUserName, value: user['name'] ?? '');
    await _storage.write(key: _keyUserEmail, value: user['email'] ?? '');
    await _storage.write(key: _keyUserRole, value: user['role'] ?? '');
    
    if (user['docente_id'] != null) {
      await _storage.write(key: _keyDocenteId, value: user['docente_id'].toString());
    }
  }

  /// Obtener token guardado
  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  /// Obtener datos del usuario guardado
  static Future<Map<String, dynamic>?> getUserData() async {
    final token = await getToken();
    if (token == null) return null;

    final userId = await _storage.read(key: _keyUserId);
    if (userId == null) return null;

    final userName = await _storage.read(key: _keyUserName);
    final userEmail = await _storage.read(key: _keyUserEmail);
    final userRole = await _storage.read(key: _keyUserRole);
    final docenteId = await _storage.read(key: _keyDocenteId);

    return {
      'id': int.tryParse(userId),
      'name': userName,
      'email': userEmail,
      'role': userRole,
      'docente_id': docenteId != null ? int.tryParse(docenteId) : null,
      'token': token,
    };
  }

  /// Verificar si hay sesión activa
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Cerrar sesión (eliminar todos los datos)
  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  /// Limpiar solo el token (útil cuando expira)
  static Future<void> clearToken() async {
    await _storage.delete(key: _keyToken);
  }
}
