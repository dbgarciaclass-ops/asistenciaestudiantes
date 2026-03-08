
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

// URL de API para builds de distribución.
const String apiUrl = 'https://www.liceojacintodelaconcha.com/api';
const Duration requestTimeout = Duration(seconds: 20);

// Helper para logging seguro solo en modo debug
void debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class ApiService {
  /// Obtener headers con autenticación
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
      return {'success': false, 'message': 'Error de conexión'};
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
        return json.decode(response.body);
      }
      debugLog('Error obtener aulas: ${response.statusCode}');
    } catch (e) {
      debugLog('Error de conexión al obtener aulas');
    }
    return [];
  }

  static Future<List<dynamic>> obtenerAulasParaCoordinador() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$apiUrl/aulas?role=coordinador'),
        headers: headers,
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      debugLog('Error obtener aulas: ${response.statusCode}');
    } catch (e) {
      debugLog('Error de conexión al obtener aulas');
    }
    return [];
  }

  static Future<Map<String, dynamic>> obtenerResumenAsistencia(int aulaId, String fecha, int sesion) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$apiUrl/aulas/resumen-asistencia?aula_id=$aulaId&fecha=$fecha&sesion=$sesion'),
        headers: headers,
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      debugLog('Error obtener resumen: ${response.statusCode}');
      return {};
    } catch (e) {
      debugLog('Error de conexión al obtener resumen');
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
      debugLog('Error de conexión al obtener estudiantes');
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

  static Future<bool> registrarAsistenciasBatch(List<Map<String, dynamic>> asistencias, String fecha, int sesion) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$apiUrl/asistencias/batch'),
        headers: headers,
        body: json.encode({
          'fecha': fecha,
          'sesion': sesion,
          'asistencias': asistencias,
        }),
      ).timeout(requestTimeout);
      return response.statusCode == 201;
    } catch (e) {
      debugLog('Error al guardar asistencias batch');
      return false;
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

    /// Verificar si hay sesión activa y redirigir automáticamente
    Future<void> _checkAutoLogin() async {
      final isLoggedIn = await SecureAuthService.isLoggedIn();
      if (!isLoggedIn || !mounted) return;

      final userData = await SecureAuthService.getUserData();
      if (userData == null || !mounted) return;

      final role = userData['role'];
      
      // Redirigir según el rol
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
                    // Logo y título
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          // Círculo con logo institucional
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
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
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Iniciar Sesión',
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
                                hintText: 'Correo electrónico',
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
                                hintText: 'Contraseña',
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
                                      // Validación robusta de entrada
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
                                              builder: (context) => ResumenAsistenciaScreen(userName: user['name']),
                                            ),
                                          );
                                        } else {
                                          setState(() => error = 'Rol no soportado en esta aplicación');
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
                                      'Iniciar Sesión',
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
                  tooltip: 'Cerrar sesión',
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
                                        color: AppTheme.accentColor.withOpacity(0.1),
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
                                            '¡Bienvenido!',
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

                              // Selección de aula
                              AppTheme.buildSectionHeader(
                                title: 'Aula',
                                icon: Icons.meeting_room_rounded,
                              ),
                              const SizedBox(height: 12),
                              AppTheme.buildCard(
                                padding: const EdgeInsets.all(4),
                                child: DropdownButtonFormField(
                                  value: aulaSeleccionada,
                                  items: aulas.map<DropdownMenuItem>((aula) {
                                    return DropdownMenuItem(
                                      value: aula,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.class_rounded,
                                              color: AppTheme.primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            aula['nombre'] ?? aula.toString(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
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

                              // Selección de fecha
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
                                            color: AppTheme.accentColor.withOpacity(0.1),
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

                              // Selección de sesión
                              AppTheme.buildSectionHeader(
                                title: 'Sesión de Clase',
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
                                                      color: Colors.black.withOpacity(0.05),
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

                              // Botón continuar
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
      final data = await ApiService.obtenerEstudiantes(widget.aula['id']);
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
      
      // Preparar todas las asistencias para enviar en lote
      final asistenciasList = estudiantes.map((estudiante) {
        final estado = asistencias[estudiante['id']] ?? 'Presente';
        return {
          'estudiante_id': estudiante['id'],
          'estado': estado.toLowerCase(),
        };
      }).toList();

      // Enviar todas las asistencias en una sola petición
      final exito = await ApiService.registrarAsistenciasBatch(
        asistenciasList,
        widget.fecha.toLocal().toString().split(' ')[0],
        widget.sesion,
      );

      setState(() {
        guardando = false;
        mensaje = exito ? 'Asistencias guardadas exitosamente' : 'Error al guardar asistencias';
      });
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(widget.aula['nombre'] ?? 'Asistencia'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'Información',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Información'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Aula:', widget.aula['nombre'] ?? 'N/A'),
                        _buildInfoRow('Fecha:', _formatFecha(widget.fecha)),
                        _buildInfoRow('Sesión:', 'Sesión ${widget.sesion}'),
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
              tooltip: 'Cerrar sesión',
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
                  // Header con información
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
                              color: Colors.white.withOpacity(0.2),
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
                  
                  // Área fija inferior
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                                    ? AppTheme.successColor.withOpacity(0.1)
                                    : AppTheme.errorColor.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.05),
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
                    color: AppTheme.primaryColor.withOpacity(0.1),
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
                                color: color.withOpacity(0.3),
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
    const ResumenAsistenciaScreen({super.key, required this.userName});

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

    @override
    void initState() {
      super.initState();
      cargarAulas();
    }

    Future<void> cargarAulas() async {
      final data = await ApiService.obtenerAulasParaCoordinador();
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
      final resultado = await ApiService.obtenerResumenAsistencia(
        aulaSeleccionada['id'],
        format,
        sesion,
      );

      setState(() {
        resumenAsistencia = resultado;
        consultando = false;
      });
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Resumen de Asistencia'),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Cerrar sesión',
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
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido, ${widget.userName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filtros',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField(
                                value: aulaSeleccionada,
                                items: aulas
                                    .map<DropdownMenuItem>((aula) => DropdownMenuItem(
                                          value: aula,
                                          child: Text(aula['nombre'] ?? aula.toString()),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => aulaSeleccionada = value);
                                },
                                decoration: const InputDecoration(labelText: 'Aula'),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Fecha: ${fecha.toLocal().toString().split(' ')[0]}'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: fecha,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() => fecha = picked);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: sesion,
                                items: sesiones
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text('Sesión $s'),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) setState(() => sesion = value);
                                },
                                decoration: const InputDecoration(labelText: 'Sesión de clase'),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: consultando ? null : obtenerResumen,
                                  child: consultando
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Ver Resumen'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (resumenAsistencia != null) ...[
                        _construirResumenStats(resumenAsistencia!),
                        const SizedBox(height: 24),
                        _construirListaEstudiantes(resumenAsistencia!),
                      ],
                    ],
                  ),
                ),
              ),
      );
    }

    Widget _construirResumenStats(Map<String, dynamic> resumen) {
      final stats = resumen['estadisticas'] ?? {};
      return Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estadísticas de Asistencia',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
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
              Text(
                'Total de Estudiantes: ${stats['total'] ?? 0}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    Widget _estatCard(String label, int value, Color color) {
      return Card(
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
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
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget _construirListaEstudiantes(Map<String, dynamic> resumen) {
      final estudiantes = resumen['estudiantes'] as List? ?? [];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalles de Estudiantes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (estudiantes.isEmpty)
                const Text('No hay estudiantes registrados',
                    style: TextStyle(color: Colors.grey))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: estudiantes.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final est = estudiantes[index];
                    final estado = est['estado'] ?? 'no registrada';
                    Color colorEstado = Colors.grey;
                    if (estado == 'presente') colorEstado = Colors.green;
                    if (estado == 'ausente') colorEstado = Colors.red;
                    if (estado == 'tardanza') colorEstado = Colors.orange;
                    if (estado == 'justificada') colorEstado = Colors.blue;
                    if (estado == 'retirado') colorEstado = Colors.purple;

                    return ListTile(
                      title: Text(est['nombre_completo'] ?? 'Sin nombre'),
                      trailing: Chip(
                        label: Text(estado),
                        backgroundColor: colorEstado.withOpacity(0.2),
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
  }
