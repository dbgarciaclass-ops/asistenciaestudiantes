/// Validador de entrada para prevenir ataques de inyección
class InputValidator {
  // Longitudes máximas para prevenir ataques de memoria
  static const int maxEmailLength = 254;
  static const int maxPasswordLength = 128;
  static const int maxGeneralTextLength = 1000;
  
  /// Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    
    // Prevenir inputs extremadamente largos
    if (value.length > maxEmailLength) {
      return 'Email demasiado largo';
    }
    
    // Regex seguro para email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }
    
    // Verificar caracteres peligrosos
    if (_containsDangerousChars(value)) {
      return 'Email contiene caracteres no permitidos';
    }
    
    return null;
  }
  
  /// Validar password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    
    // Prevenir inputs extremadamente largos
    if (value.length > maxPasswordLength) {
      return 'Contraseña demasiado larga';
    }
    
    // Verificar longitud mínima
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    
    return null;
  }
  
  /// Validar password seguro (con requisitos adicionales)
  static String? validateSecurePassword(String? value) {
    final basicValidation = validatePassword(value);
    if (basicValidation != null) {
      return basicValidation;
    }
    
    // Verificar mayúsculas
    if (!_hasUpperCase(value!)) {
      return 'La contraseña debe tener al menos una mayúscula';
    }
    
    // Verificar minúsculas
    if (!_hasLowerCase(value)) {
      return 'La contraseña debe tener al menos una minúscula';
    }
    
    // Verificar números
    if (!_hasDigit(value)) {
      return 'La contraseña debe tener al menos un número';
    }
    
    return null;
  }
  
  /// Validar texto general
  static String? validateText(String? value, {String fieldName = 'Campo'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    // Prevenir inputs extremadamente largos
    if (value.length > maxGeneralTextLength) {
      return '$fieldName demasiado largo';
    }
    
    // Verificar caracteres peligrosos básicos
    if (_containsDangerousChars(value)) {
      return '$fieldName contiene caracteres no permitidos';
    }
    
    return null;
  }
  
  /// Validar texto alfanumérico (nombres, códigos, etc.)
  static String? validateAlphanumeric(String? value, {String fieldName = 'Campo'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    // Prevenir inputs extremadamente largos
    if (value.length > maxGeneralTextLength) {
      return '$fieldName demasiado largo';
    }
    
    // Solo letras, números, espacios y guiones
    final alphanumericRegex = RegExp(r'^[a-zA-Z0-9\s\-áéíóúÁÉÍÓÚñÑ]+$');
    
    if (!alphanumericRegex.hasMatch(value)) {
      return '$fieldName solo puede contener letras, números y espacios';
    }
    
    return null;
  }
  
  /// Validar número
  static String? validateNumber(String? value, {String fieldName = 'Campo'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return '$fieldName debe ser un número válido';
    }
    
    return null;
  }
  
  /// Validar URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL es requerida';
    }
    
    // Prevenir inputs extremadamente largos
    if (value.length > maxGeneralTextLength) {
      return 'URL demasiado larga';
    }
    
    // Regex básico para URL
    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)$',
    );
    
    if (!urlRegex.hasMatch(value)) {
      return 'URL inválida';
    }
    
    return null;
  }
  
  /// Sanitizar input removiendo caracteres peligrosos
  static String sanitize(String value) {
    // Remover caracteres nulos y de control
    String sanitized = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    // Remover caracteres HTML peligrosos
    sanitized = sanitized
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
    
    // Limitar longitud
    if (sanitized.length > maxGeneralTextLength) {
      sanitized = sanitized.substring(0, maxGeneralTextLength);
    }
    
    return sanitized.trim();
  }

  /// Verificar si contiene caracteres peligrosos
  static bool _containsDangerousChars(String value) {
    // Caracteres de control y potencialmente peligrosos
    final dangerousChars = RegExp(r'[\x00-\x1F\x7F<>;]');
    return dangerousChars.hasMatch(value);
  }

  /// Verificar si tiene mayúsculas
  static bool _hasUpperCase(String value) => value.contains(RegExp(r'[A-Z]'));

  /// Verificar si tiene minúsculas
  static bool _hasLowerCase(String value) => value.contains(RegExp(r'[a-z]'));

  /// Verificar si tiene dígitos
  static bool _hasDigit(String value) => value.contains(RegExp(r'[0-9]'));
}
