
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'auth_service.dart';
import 'network_service.dart';
import 'input_validator.dart';
import 'update_service.dart';
import 'app_theme.dart';

// URL de API por entorno.
// - Debug: backend local para pruebas seguras sin tocar producciÃ³n.
// - Release: backend de producciÃ³n.
// Se puede sobrescribir con: --dart-define=API_URL=...
const String _prodApiUrl = 'https://www.liceojacintodelaconcha.com/api';
const String _devApiUrl = 'http://127.0.0.1:8000/api';
const String _apiUrlFromEnv = String.fromEnvironment('API_URL', defaultValue: '');
final String apiUrl = _apiUrlFromEnv.isNotEmpty
  ? _apiUrlFromEnv
  : (kReleaseMode ? _prodApiUrl : _devApiUrl);
const Duration requestTimeout = Duration(seconds: 20);

// Helper para logging seguro solo en modo debug
void debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class ApiService {
  /// Obtener headers con autenticaciÃ³n
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await SecureAuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(requestTimeout);
      // Removido: logs de respuesta con datos sensibles
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Guardar token y datos de usuario de forma segura
        final token = data['token'] ?? data['access_token'] ?? '';
        if (token.isNotEmpty) {
          await SecureAuthService.saveAuthData(
            token: token,
            user: data['user'],
          );
        }
        
        return {
          'success': true,
          'user': data['user'],
          'token': token,
        };
      } else {
        // Intenta extraer mensaje de error del backend
        try {
          final data = json.decode(response.body);
          if (data is Map && data.containsKey('message')) {
            return {'success': false, 'message': data['message'].toString()};
          }
        } catch (_) {}
        return {'success': false, 'message': 'Error ${response.statusCode}'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Tiempo de espera agotado. Verifica tu conexion.'};
    } catch (e) {
      debugLog('Login error: $e');
      return {'success': false, 'message': 'Error de conexiÃ³n'};
    }
  }

  static Future<List<dynamic>> obtenerAulas(int docenteId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$apiUrl/aulas?docente_id=$docenteId'),
        headers: headers,
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return _normalizeAulasResponse(json.decode(response.body));
      }
      debugLog('Error obtener aulas: ${response.statusCode}');
    } catch (e) {
      debugLog('Error de conexiÃ³n al obtener aulas');
    }
    return [];
  }

  static Future<List<dynamic>> obtenerAulasParaCoordinador(String role) async {
    final normalizedRole = role == 'admin' ? 'admin' : 'coordinador';

    try {
      final headers = await _getAuthHeaders();
      final candidateUris = [
        Uri.parse('$apiUrl/aulas-materias?role=$normalizedRole'),
        Uri.parse('$apiUrl/aulas?role=$normalizedRole&include_materias=1'),
        Uri.parse('$apiUrl/aulas?role=$normalizedRole'),
      ];

      for (final uri in candidateUris) {
        final response = await http.get(
          uri,
          headers: headers,
        ).timeout(requestTimeout);

        if (response.statusCode != 200) {
          debugLog('Endpoint ${uri.path}?${uri.query} respondiÃ³ ${response.statusCode}');
          continue;
        }

        final aulas = _normalizeAulasResponse(json.decode(response.body));
        if (aulas.isEmpty) {
          continue;
        }

        final hasCombinedData = _containsMateriaData(aulas);
        debugLog(
          'Aulas normalizadas para $normalizedRole desde ${uri.path}: '
          'hasCombinedData=$hasCombinedData first=${aulas.first}',
        );

        if (hasCombinedData || uri == candidateUris.last) {
          return aulas;
        }
      }
    } catch (e) {
      debugLog('Error de conexiÃ³n al obtener aulas para $normalizedRole: $e');
    }
    return [];
  }

  static bool _containsMateriaData(List<dynamic> aulas) {
    return aulas.any((item) {
      if (item is! Map) {
        return false;
      }

      final materiaNombre = _extractMateriaNombre(Map<String, dynamic>.from(item.cast<dynamic, dynamic>()));
      return materiaNombre != null && materiaNombre.isNotEmpty;
    });
  }

  static List<dynamic> _normalizeAulasResponse(dynamic rawData) {
    if (rawData is! List) {
      return [];
    }

    return rawData.map<dynamic>(_normalizeAulaData).toList();
  }

  static dynamic _normalizeAulaData(dynamic item) {
    if (item is! Map) {
      return item;
    }

    final aula = Map<String, dynamic>.from(item.cast<dynamic, dynamic>());
    final aulaNombre = _extractAulaNombre(aula);
    final materiaNombre = _extractMateriaNombre(aula);

    if ((aula['aula_nombre'] == null || aula['aula_nombre'].toString().isEmpty) &&
        aulaNombre != null) {
      aula['aula_nombre'] = aulaNombre;
    }

    if ((aula['materia_nombre'] == null || aula['materia_nombre'].toString().isEmpty) &&
        materiaNombre != null) {
      aula['materia_nombre'] = materiaNombre;
    }

    if ((aula['nombre_completo'] == null || aula['nombre_completo'].toString().isEmpty) &&
        aulaNombre != null &&
        materiaNombre != null) {
      aula['nombre_completo'] = '$aulaNombre - $materiaNombre';
    }

    return aula;
  }

  static String? _extractAulaNombre(Map<String, dynamic> aula) {
    return _firstNonEmptyString([
      aula['aula_nombre'],
      aula['nombre_aula'],
      aula['aula'],
      aula['nombre'],
      _extractNestedName(aula['aula']),
    ]);
  }

  static String? _extractMateriaNombre(Map<String, dynamic> aula) {
    final nestedMaterias = _joinNestedNames(aula['materias']) ?? _joinNestedNames(aula['asignaturas']);

    return _firstNonEmptyString([
      aula['materia_nombre'],
      aula['nombre_materia'],
      aula['asignatura_nombre'],
      aula['materia'],
      aula['asignatura'],
      aula['subject_name'],
      _extractNestedName(aula['materia']),
      _extractNestedName(aula['asignatura']),
      nestedMaterias,
    ]);
  }

  static String? _extractNestedName(dynamic value) {
    if (value is Map) {
      return _firstNonEmptyString([
        value['nombre'],
        value['name'],
        value['descripcion'],
      ]);
    }

    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static String? _joinNestedNames(dynamic value) {
    if (value is! List) {
      return null;
    }

    final names = value
        .map(_extractNestedName)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return null;
    }

    return names.join(', ');
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> obtenerResumenAsistencia(int aulaId, String fecha, int sesion, {int? materiaId}) async {
    try {
      final headers = await _getAuthHeaders();
      final materiaParam = materiaId != null ? '&materia_id=$materiaId' : '';
      final response = await http.get(
        Uri.parse('$apiUrl/aulas/resumen-asistencia?aula_id=$aulaId&fecha=$fecha&sesion=$sesion$materiaParam'),
        headers: headers,
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      debugLog('Error obtener resumen: ${response.statusCode}');
      return {};
    } catch (e) {
      debugLog('Error de conexiÃ³n al obtener resumen');
      return {};
    }
  }

  static Future<List<dynamic>> obtenerEstudiantes(int aulaId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$apiUrl/aulas/$aulaId/estudiantes'),
        headers: headers,
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      debugLog('Error obtener estudiantes: ${response.statusCode}');
    } catch (e) {
      debugLog('Error de conexiÃ³n al obtener estudiantes');
    }
    return [];
  }

  static Future<bool> registrarAsistencia(int estudianteId, String estado, String fecha, int sesion) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$apiUrl/asistencias'),
        headers: headers,
        body: json.encode({
          'estudiante_id': estudianteId,
          'estado': estado.toLowerCase(),
          'fecha': fecha,
          'sesion': sesion,
        }),
      ).timeout(requestTimeout);
      return response.statusCode == 201;
    } catch (e) {
      debugLog('Error al guardar asistencia');
      return false;
    }
  }

  static Future<Map<String, dynamic>> registrarAsistenciasBatch(
    List<Map<String, dynamic>> asistencias,
    String fecha,
    int sesion, {
    required int materiaId,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$apiUrl/asistencias/batch'),
        headers: headers,
        body: json.encode({
          'fecha': fecha,
          'sesion': sesion,
          'materia_id': materiaId,
          'asistencias': asistencias,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Asistencias guardadas exitosamente',
        };
      }

      String message = 'Error al guardar asistencias (${response.statusCode})';
      try {
        final data = json.decode(response.body);
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        } else if (data is Map && data['errors'] != null) {
          message = 'Error de validacion en los datos enviados';
        }
      } catch (_) {}

      debugLog('Error batch asistencia: ${response.statusCode} - ${response.body}');
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      debugLog('Error al guardar asistencias batch: $e');
      return {
        'success': false,
        'message': 'Error de conexion al guardar asistencias',
      };
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar certificate pinning (opcional pero recomendado)
  await SecureNetworkService.initialize();
  
  runApp(const AsistenciaEstudiantesApp());
}

class AsistenciaEstudiantesApp extends StatelessWidget {
  const AsistenciaEstudiantesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistencia Estudiantes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryColor,
          primary: AppTheme.primaryColor,
          secondary: AppTheme.accentColor,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.cardRadius,
          ),
          color: AppTheme.cardBackground,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.buttonRadius,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: AppTheme.inputRadius,
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppTheme.inputRadius,
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.inputRadius,
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
    final usuarioController = TextEditingController();
    final passwordController = TextEditingController();
    bool cargando = false;
    bool mostrarPassword = false;
    String? error;

    @override
    void initState() {
      super.initState();
      _checkAutoLogin();
    }

    /// Verificar si hay sesiÃ³n activa y redirigir automÃ¡ticamente
    Future<void> _checkAutoLogin() async {
      final isLoggedIn = await SecureAuthService.isLoggedIn();
      if (!isLoggedIn || !mounted) return;

      final userData = await SecureAuthService.getUserData();
      if (userData == null || !mounted) return;

      final role = userData['role'];
      
      // Redirigir segÃºn el rol
      if (role == 'docente' && userData['docente_id'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SelectAulaFechaScreen(
              docenteId: userData['docente_id'],
            ),
          ),
        );
      } else if (role == 'coordinador' || role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResumenAsistenciaScreen(
              userName: userData['name'] ?? 'Usuario',
              userRole: role,
            ),
          ),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1e3c72),  // Azul oscuro
                Color(0xFF2a5298),  // Azul medio
                Color(0xFF7aa8d8),  // Azul claro
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo y tÃ­tulo
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          // CÃ­rculo con logo institucional
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/logo.jpeg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Asistencia Estudiantes',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Liceo Jacinto de la Concha',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFb3d9ff),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Formulario
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Iniciar SesiÃ³n',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e3c72),
                            ),
                          ),
                          const SizedBox(height: 25),

                          // Email input
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFf5f7fa),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFe0e0e0),
                              ),
                            ),
                            child: TextField(
                              controller: usuarioController,
                              decoration: InputDecoration(
                                hintText: 'Correo electrÃ³nico',
                                hintStyle: const TextStyle(color: Color(0xFF999999)),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF2a5298),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 15,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enableSuggestions: false,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Password input
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFf5f7fa),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFe0e0e0),
                              ),
                            ),
                            child: TextField(
                              controller: passwordController,
                              obscureText: !mostrarPassword,
                              decoration: InputDecoration(
                                hintText: 'ContraseÃ±a',
                                hintStyle: const TextStyle(color: Color(0xFF999999)),
                                prefixIcon: const Icon(
                                  Icons.lock_outlined,
                                  color: Color(0xFF2a5298),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    mostrarPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF2a5298),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      mostrarPassword = !mostrarPassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 15,
                                ),
                              ),
                              autocorrect: false,
                              enableSuggestions: false,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Error message
                          if (error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFffe0e0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFff6b6b)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFff6b6b),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      error!,
                                      style: const TextStyle(
                                        color: Color(0xFFc92a2a),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: cargando
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2a5298),
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: () async {
                                      // ValidaciÃ³n robusta de entrada
                                      final emailError = InputValidator.validateEmail(usuarioController.text);
                                      if (emailError != null) {
                                        setState(() {
                                          error = emailError;
                                        });
                                        return;
                                      }

                                      final passwordError = InputValidator.validatePassword(passwordController.text);
                                      if (passwordError != null) {
                                        setState(() {
                                          error = passwordError;
                                        });
                                        return;
                                      }

                                      setState(() {
                                        cargando = true;
                                        error = null;
                                      });

                                      // Sanitizar entrada antes de enviar
                                      final email = InputValidator.sanitize(usuarioController.text).toLowerCase();
                                      final password = passwordController.text;  // No sanitizar password

                                      final loginResult = await ApiService.login(
                                        email,
                                        password,
                                      );
                                      setState(() => cargando = false);

                                      if (loginResult['success'] == true) {
                                        final user = loginResult['user'];
                                        final role = user['role'];
                                        
                                        if (role == 'docente') {
                                          final docenteIdRaw = user['docente_id'];
                                          final docenteId = docenteIdRaw is int ? docenteIdRaw : int.parse(docenteIdRaw.toString());
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SelectAulaFechaScreen(docenteId: docenteId),
                                            ),
                                          );
                                        } else if (role == 'coordinador' || role == 'admin') {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ResumenAsistenciaScreen(
                                                userName: user['name'],
                                                userRole: role,
                                              ),
                                            ),
                                          );
                                        } else {
                                          setState(() => error = 'Rol no soportado en esta aplicaciÃ³n');
                                        }
                                      } else {
                                        setState(() => error = loginResult['message']);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2a5298),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 5,
                                    ),
                                    child: const Text(
                                      'Iniciar SesiÃ³n',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  class SelectAulaFechaScreen extends StatefulWidget {
    final int docenteId;
    const SelectAulaFechaScreen({super.key, required this.docenteId});

    @override
    State<SelectAulaFechaScreen> createState() => _SelectAulaFechaScreenState();
  }

  class _SelectAulaFechaScreenState extends State<SelectAulaFechaScreen> with SingleTickerProviderStateMixin {
    List aulas = [];
    dynamic aulaSeleccionada;
    DateTime fecha = DateTime.now();
    int sesion = 1;
    final List<int> sesiones = List.generate(8, (i) => i + 1);
    bool cargando = true;
    late AnimationController _animationController;

    @override
    void initState() {
      super.initState();
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      cargarAulas();
      _checkForUpdates();
    }

    @override
    void dispose() {
      _animationController.dispose();
      super.dispose();
    }

    Future<void> _checkForUpdates() async {
      // Esperar un poco para no interferir con la carga inicial
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      
      final updateInfo = await UpdateService.checkForUpdates();
      if (updateInfo != null && mounted) {
        UpdateService.showUpdateDialog(context, updateInfo);
      }
    }

    Future<void> cargarAulas() async {
      final data = await ApiService.obtenerAulas(widget.docenteId);
      
      setState(() {
        aulas = data;
        cargando = false;
        if (aulas.isNotEmpty) {
          aulaSeleccionada = aulas[0];
        }
      });
      _animationController.forward();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Registro de Asistencia',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded),
                  tooltip: 'Cerrar sesiÃ³n',
                  onPressed: () async {
                    await SecureAuthService.logout();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: cargando
                  ? const SizedBox(
                      height: 400,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _animationController.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _animationController.value)),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.paddingMedium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (aulas.isEmpty)
                              AppTheme.buildCard(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No hay aulas disponibles',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Contacte al administrador',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // Tarjeta de bienvenida
                              AppTheme.buildCard(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: AppTheme.accentColor,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Â¡Bienvenido!',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Selecciona los detalles para continuar',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // SelecciÃ³n de aula y materia
                              AppTheme.buildSectionHeader(
                                title: 'Aula y Materia',
                                icon: Icons.menu_book_rounded,
                              ),
                              const SizedBox(height: 12),
                              AppTheme.buildCard(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButtonFormField(
                                  initialValue: aulaSeleccionada,
                                  items: aulas.map<DropdownMenuItem>((aula) {
                                    // Soporte para formato nuevo (con materia) y antiguo (solo aula)
                                    String nombreCompleto = '';
                                    
                                    // Intenta usar nombre_completo del backend primero
                                    if (aula['nombre_completo'] != null && aula['nombre_completo'].toString().isNotEmpty) {
                                      nombreCompleto = aula['nombre_completo'].toString();
                                    }
                                    // Si tiene materia_nombre, construir localmente
                                    else if (aula['materia_nombre'] != null && aula['materia_nombre'].toString().isNotEmpty) {
                                      final aulaNom = aula['aula_nombre']?.toString() ?? aula['nombre']?.toString() ?? 'Aula';
                                      final materiaNom = aula['materia_nombre'].toString();
                                      nombreCompleto = '$aulaNom - $materiaNom';
                                    }
                                    // Fallback: solo nombre del aula
                                    else {
                                      nombreCompleto = aula['nombre']?.toString() ?? aula['aula_nombre']?.toString() ?? 'Seleccionar aula';
                                    }
                                    
                                    final tieneMateria = aula['materia_nombre'] != null || aula['nombre_completo'] != null;
                                    
                                    return DropdownMenuItem(
                                      value: aula,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              tieneMateria ? Icons.school_rounded : Icons.class_rounded,
                                              color: AppTheme.primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              nombreCompleto,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => aulaSeleccionada = value);
                                  },
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // SelecciÃ³n de fecha
                              AppTheme.buildSectionHeader(
                                title: 'Fecha',
                                icon: Icons.calendar_today_rounded,
                              ),
                              const SizedBox(height: 12),
                              AppTheme.buildCard(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: fecha,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.light(
                                              primary: AppTheme.primaryColor,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() => fecha = picked);
                                    }
                                  },
                                  borderRadius: AppTheme.cardRadius,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.event_rounded,
                                            color: AppTheme.accentColor,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Fecha seleccionada',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatFecha(fecha),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.edit_calendar_rounded,
                                          color: AppTheme.textHint,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // SelecciÃ³n de sesiÃ³n
                              AppTheme.buildSectionHeader(
                                title: 'SesiÃ³n de Clase',
                                icon: Icons.schedule_rounded,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 70,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: sesiones.length,
                                  itemBuilder: (context, index) {
                                    final s = sesiones[index];
                                    final isSelected = s == sesion;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: InkWell(
                                        onTap: () => setState(() => sesion = s),
                                        borderRadius: BorderRadius.circular(12),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 70,
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? AppTheme.primaryGradient
                                                : null,
                                            color: isSelected
                                                ? null
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                            boxShadow: isSelected
                                                ? AppTheme.buttonShadow
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.timer_rounded,
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppTheme.primaryColor,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$s',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppTheme.primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),

                              // BotÃ³n continuar
                              AppTheme.buildPrimaryButton(
                                text: 'Continuar al Registro',
                                icon: Icons.arrow_forward_rounded,
                                width: double.infinity,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          AsistenciaScreen(
                                        aula: aulaSeleccionada,
                                        fecha: fecha,
                                        sesion: sesion,
                                      ),
                                      transitionsBuilder:
                                          (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end)
                                            .chain(CurveTween(curve: curve));
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    String _formatFecha(DateTime fecha) {
      const meses = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];
      return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
    }
  }

  class AsistenciaScreen extends StatefulWidget {
    final dynamic aula;
    final DateTime fecha;
    final int sesion;
    const AsistenciaScreen({super.key, required this.aula, required this.fecha, required this.sesion});

    @override
    State<AsistenciaScreen> createState() => _AsistenciaScreenState();
  }

  class _AsistenciaScreenState extends State<AsistenciaScreen> {
    List estudiantes = [];
    Map<int, String> asistencias = {};
    bool cargando = true;
    bool guardando = false;
    String? mensaje;

    @override
    void initState() {
      super.initState();
      cargarEstudiantes();
    }

    Future<void> cargarEstudiantes() async {
      // Soporte para formato nuevo (aula_id) y antiguo (id)
      final aulaId = widget.aula['aula_id'] ?? widget.aula['id'];
      final data = await ApiService.obtenerEstudiantes(aulaId);
      setState(() {
        estudiantes = data;
        cargando = false;
      });
    }

    Future<void> guardarAsistencias() async {
      setState(() {
        guardando = true;
        mensaje = null;
      });

      final materiaIdRaw = widget.aula['materia_id'];
      final materiaId = materiaIdRaw is int ? materiaIdRaw : int.tryParse('${materiaIdRaw ?? ''}');
      if (materiaId == null) {
        setState(() {
          guardando = false;
          mensaje = 'No se pudo identificar la materia. Vuelve a seleccionar Aula y Materia.';
        });
        return;
      }
      
      // Preparar todas las asistencias para enviar en lote
      final asistenciasList = estudiantes.map((estudiante) {
        final estado = asistencias[estudiante['id']] ?? 'Presente';
        return {
          'estudiante_id': estudiante['id'],
          'estado': estado.toLowerCase(),
        };
      }).toList();

      // Enviar todas las asistencias en una sola peticiÃ³n
      final resultado = await ApiService.registrarAsistenciasBatch(
        asistenciasList,
        widget.fecha.toLocal().toString().split(' ')[0],
        widget.sesion,
        materiaId: materiaId,
      );

      setState(() {
        guardando = false;
        mensaje = resultado['message']?.toString() ??
            (resultado['success'] == true
                ? 'Asistencias guardadas exitosamente'
                : 'Error al guardar asistencias');
      });
    }

    @override
    Widget build(BuildContext context) {
      // Obtener nombre apropiado para mostrar
      final nombreDisplay = widget.aula['nombre_completo'] ?? 
                           (widget.aula['materia_nombre'] != null 
                             ? '${widget.aula['aula_nombre'] ?? widget.aula['nombre']} - ${widget.aula['materia_nombre']}' 
                             : widget.aula['nombre']);
      
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(nombreDisplay ?? 'Asistencia'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'InformaciÃ³n',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('InformaciÃ³n'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Aula:', widget.aula['aula_nombre'] ?? widget.aula['nombre'] ?? 'N/A'),
                        if (widget.aula['materia_nombre'] != null)
                          _buildInfoRow('Materia:', widget.aula['materia_nombre']),
                        _buildInfoRow('Fecha:', _formatFecha(widget.fecha)),
                        _buildInfoRow('SesiÃ³n:', 'SesiÃ³n ${widget.sesion}'),
                        _buildInfoRow('Estudiantes:', '${estudiantes.length}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              tooltip: 'Cerrar sesiÃ³n',
              onPressed: () async {
                await SecureAuthService.logout();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header con informaciÃ³n
                  Container(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total de Estudiantes',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${estudiantes.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.people_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (estudiantes.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay estudiantes en esta aula',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.paddingMedium),
                        itemCount: estudiantes.length,
                        itemBuilder: (context, index) {
                          final estudiante = estudiantes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AsistenciaItem(
                              nombre: estudiante['nombre'] ?? 
                                      estudiante['nombre_completo'] ?? 
                                      estudiante.toString(),
                              onChanged: (estado) {
                                setState(() {
                                  asistencias[estudiante['id']] = estado;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // Ãrea fija inferior
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mensaje != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: mensaje!.contains('exitosamente')
                                    ? AppTheme.successColor.withValues(alpha: 0.1)
                                    : AppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: mensaje!.contains('exitosamente')
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    mensaje!.contains('exitosamente')
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    color: mensaje!.contains('exitosamente')
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      mensaje!,
                                      style: TextStyle(
                                        color: mensaje!.contains('exitosamente')
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          AppTheme.buildPrimaryButton(
                            text: guardando ? 'Guardando...' : 'Guardar Asistencias',
                            icon: Icons.save_rounded,
                            width: double.infinity,
                            isLoading: guardando,
                            onPressed: estudiantes.isEmpty ? () {} : guardarAsistencias,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      );
    }

    Widget _buildInfoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    String _formatFecha(DateTime fecha) {
      const meses = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];
      return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
    }
  }

  class AsistenciaItem extends StatefulWidget {
    final String nombre;
    final void Function(String estado)? onChanged;
    const AsistenciaItem({super.key, required this.nombre, this.onChanged});

    @override
    State<AsistenciaItem> createState() => _AsistenciaItemState();
  }

  class _AsistenciaItemState extends State<AsistenciaItem> {
    String estado = 'Presente';
    final Map<String, Map<String, dynamic>> estadosConfig = {
      'Presente': {
        'color': AppTheme.successColor,
        'icon': Icons.check_circle_rounded,
      },
      'Ausente': {
        'color': AppTheme.errorColor,
        'icon': Icons.cancel_rounded,
      },
      'Tardanza': {
        'color': AppTheme.warningColor,
        'icon': Icons.access_time_rounded,
      },
      'Justificada': {
        'color': Colors.blue,
        'icon': Icons.description_rounded,
      },
      'Retirado': {
        'color': Colors.purple,
        'icon': Icons.exit_to_app_rounded,
      },
    };

    @override
    Widget build(BuildContext context) {
      return AppTheme.buildCard(
        padding: const EdgeInsets.all(12),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: estadosConfig.entries.map((entry) {
                final isSelected = estado == entry.key;
                final color = entry.value['color'] as Color;
                final icon = entry.value['icon'] as IconData;
                
                return InkWell(
                  onTap: () {
                    setState(() {
                      estado = entry.key;
                    });
                    if (widget.onChanged != null) {
                      widget.onChanged!(entry.key);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isSelected ? Colors.white : color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }
  }

  // ==================== Nueva Pantalla para Coordinadores ====================

  class ResumenAsistenciaScreen extends StatefulWidget {
    final String userName;
    final String userRole;

    const ResumenAsistenciaScreen({
      super.key,
      required this.userName,
      required this.userRole,
    });

    @override
    State<ResumenAsistenciaScreen> createState() => _ResumenAsistenciaScreenState();
  }

  class _ResumenAsistenciaScreenState extends State<ResumenAsistenciaScreen> {
    List aulas = [];
    dynamic aulaSeleccionada;
    DateTime fecha = DateTime.now();
    int sesion = 1;
    final List<int> sesiones = List.generate(8, (i) => i + 1);
    bool cargando = true;
    bool consultando = false;
    Map<String, dynamic>? resumenAsistencia;
    String appVersionLabel = '';

    @override
    void initState() {
      super.initState();
      cargarAulas();
      _cargarVersionInstalada();
      _checkForUpdates();
    }

    Future<void> _cargarVersionInstalada() async {
      final installedVersion = await UpdateService.getInstalledVersionLabel();
      if (!mounted) return;

      setState(() {
        appVersionLabel = installedVersion;
      });
    }

    Future<void> _checkForUpdates() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final updateInfo = await UpdateService.checkForUpdates();
      if (updateInfo != null && mounted) {
        UpdateService.showUpdateDialog(context, updateInfo);
      }
    }

    Future<void> cargarAulas() async {
      final data = await ApiService.obtenerAulasParaCoordinador(widget.userRole);
      setState(() {
        aulas = data;
        cargando = false;
        if (aulas.isNotEmpty) {
          aulaSeleccionada = aulas[0];
        }
      });
    }

    Future<void> obtenerResumen() async {
      if (aulaSeleccionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un aula')),
        );
        return;
      }

      setState(() => consultando = true);

      final format = fecha.toIso8601String().split('T')[0];
      final aulaIdRaw = aulaSeleccionada['aula_id'] ?? aulaSeleccionada['id'];
      final aulaId = aulaIdRaw is int ? aulaIdRaw : int.tryParse('$aulaIdRaw');
      if (aulaId == null) {
        setState(() => consultando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo identificar el aula seleccionada')),
        );
        return;
      }

      final materiaIdRaw = aulaSeleccionada?['materia_id'];
      final materiaId = materiaIdRaw == null
          ? null
          : (materiaIdRaw is int ? materiaIdRaw : int.tryParse('$materiaIdRaw'));

      final resultado = await ApiService.obtenerResumenAsistencia(
        aulaId,
        format,
        sesion,
        materiaId: materiaId,
      );

      setState(() {
        resumenAsistencia = resultado;
        consultando = false;
      });
    }

    @override
    Widget build(BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final statsColumns = screenWidth >= 900 ? 3 : 2;

      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Resumen de Asistencia',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded),
                  tooltip: 'Cerrar sesiÃ³n',
                  onPressed: () async {
                    await SecureAuthService.logout();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: cargando
                  ? const SizedBox(
                      height: 420,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(AppTheme.paddingMedium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTheme.buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.insights_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bienvenido, ${widget.userName}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Consulta la asistencia por aula, fecha y sesiÃ³n.',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    AppTheme.buildBadge(
                                      text: _formatRole(widget.userRole),
                                      color: AppTheme.primaryColor,
                                      icon: Icons.verified_user_rounded,
                                    ),
                                    if (appVersionLabel.isNotEmpty)
                                      AppTheme.buildBadge(
                                        text: appVersionLabel,
                                        color: AppTheme.accentColor,
                                        icon: Icons.system_update_alt_rounded,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppTheme.buildSectionHeader(
                            title: 'Filtros de consulta',
                            subtitle: 'Selecciona el grupo y la sesiÃ³n que deseas revisar.',
                            icon: Icons.tune_rounded,
                          ),
                          const SizedBox(height: 12),
                          AppTheme.buildCard(
                            child: Column(
                              children: [
                                DropdownButtonFormField(
                                  initialValue: aulaSeleccionada,
                                  items: aulas
                                      .map<DropdownMenuItem>((aula) => DropdownMenuItem(
                                            value: aula,
                                            child: Text(_buildAulaDisplayName(aula)),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      aulaSeleccionada = value;
                                      resumenAsistencia = null;
                                    });
                                  },
                                  decoration: _buildInputDecoration(
                                    label: 'Aula y materia',
                                    icon: Icons.menu_book_rounded,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: fecha,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.light(
                                              primary: AppTheme.primaryColor,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() => fecha = picked);
                                    }
                                  },
                                  borderRadius: AppTheme.cardRadius,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Fecha seleccionada',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatFecha(fecha),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.edit_calendar_rounded,
                                          color: AppTheme.textHint,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  initialValue: sesion,
                                  items: sesiones
                                      .map((sessionValue) => DropdownMenuItem(
                                            value: sessionValue,
                                            child: Text('SesiÃ³n $sessionValue'),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => sesion = value);
                                    }
                                  },
                                  decoration: _buildInputDecoration(
                                    label: 'SesiÃ³n de clase',
                                    icon: Icons.schedule_rounded,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AppTheme.buildPrimaryButton(
                                  text: 'Ver resumen',
                                  icon: Icons.analytics_rounded,
                                  width: double.infinity,
                                  isLoading: consultando,
                                  onPressed: obtenerResumen,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (resumenAsistencia != null) ...[
                            _construirResumenStats(resumenAsistencia!, statsColumns),
                            const SizedBox(height: 24),
                            _construirListaEstudiantes(resumenAsistencia!),
                          ] else
                            AppTheme.buildCard(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.fact_check_outlined,
                                    size: 54,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Aun no has consultado un resumen',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Aplica los filtros y presiona "Ver resumen" para cargar la asistencia.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      );
    }

    String _buildAulaDisplayName(dynamic aula) {
      if (aula['nombre_completo'] != null && aula['nombre_completo'].toString().isNotEmpty) {
        return aula['nombre_completo'].toString();
      }

      if (aula['materia_nombre'] != null && aula['materia_nombre'].toString().isNotEmpty) {
        final aulaNom = aula['aula_nombre']?.toString() ?? aula['nombre']?.toString() ?? 'Aula';
        final materiaNom = aula['materia_nombre'].toString();
        return '$aulaNom - $materiaNom';
      }

      return aula['nombre']?.toString() ?? aula['aula_nombre']?.toString() ?? 'Seleccionar';
    }

    String _formatRole(String role) {
      if (role == 'admin') {
        return 'Administrador';
      }
      if (role == 'coordinador') {
        return 'Coordinador';
      }
      return role;
    }

    String _formatFecha(DateTime value) {
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    Widget _construirResumenStats(Map<String, dynamic> resumen, int crossAxisCount) {
      final stats = resumen['estadisticas'] ?? {};
      return AppTheme.buildCard(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTheme.buildSectionHeader(
                title: 'EstadÃ­sticas de Asistencia',
                subtitle: 'Vista consolidada del grupo seleccionado.',
                icon: Icons.bar_chart_rounded,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _estatCard('Presentes', stats['presentes'] ?? 0, Colors.green),
                  _estatCard('Ausentes', stats['ausentes'] ?? 0, Colors.red),
                  _estatCard('Tardanzas', stats['tardanzas'] ?? 0, Colors.orange),
                  _estatCard('Justificadas', stats['justificadas'] ?? 0, Colors.blue),
                  _estatCard('Retirados', stats['retirados'] ?? 0, Colors.purple),
                  _estatCard('No Registrados', stats['no_registrados'] ?? 0, Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total de Estudiantes: ${stats['total'] ?? 0}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _estatCard(String label, int value, Color color) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(top: BorderSide(color: color, width: 4)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _construirListaEstudiantes(Map<String, dynamic> resumen) {
      final estudiantes = resumen['estudiantes'] as List? ?? [];
      return AppTheme.buildCard(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTheme.buildSectionHeader(
                title: 'Detalles de Estudiantes',
                subtitle: 'Estado individual para la sesiÃ³n consultada.',
                icon: Icons.groups_rounded,
              ),
              const SizedBox(height: 12),
              if (estudiantes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No hay estudiantes registrados',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: estudiantes.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final est = estudiantes[index];
                    final estado = est['estado'] ?? 'no registrada';
                    final colorEstado = _estadoColor(estado.toString());

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: colorEstado.withValues(alpha: 0.15),
                        child: Icon(Icons.person_rounded, color: colorEstado),
                      ),
                      title: Text(est['nombre_completo'] ?? 'Sin nombre'),
                      subtitle: Text(
                        est['matricula']?.toString() ?? 'Sin matricula',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      trailing: Chip(
                        label: Text(_capitalizeEstado(estado.toString())),
                        backgroundColor: colorEstado.withValues(alpha: 0.2),
                        labelStyle: TextStyle(color: colorEstado),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    Color _estadoColor(String estado) {
      switch (estado.toLowerCase()) {
        case 'presente':
          return Colors.green;
        case 'ausente':
          return Colors.red;
        case 'tardanza':
          return Colors.orange;
        case 'justificada':
          return Colors.blue;
        case 'retirado':
          return Colors.purple;
        default:
          return Colors.grey;
      }
    }

    String _capitalizeEstado(String estado) {
      if (estado.isEmpty) {
        return estado;
      }
      return estado[0].toUpperCase() + estado.substring(1);
    }
  }

