
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// URL de API para builds de distribución.
const String apiUrl = 'https://www.liceojacintodelaconcha.com/api';
const Duration requestTimeout = Duration(seconds: 20);

class ApiService {
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
      print('Login response: ${response.statusCode}');
      print('Login body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('User data: ${data['user']}');
        return {
          'success': true,
          'user': data['user'],
        };
      } else {
        // Intenta extraer mensaje de error del backend
        try {
          final data = json.decode(response.body);
          if (data is Map && data.containsKey('message')) {
            return {'success': false, 'message': data['message'].toString()};
          }
        } catch (_) {}
        return {'success': false, 'message': 'Error ${response.statusCode}: ${response.body}'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Tiempo de espera agotado. Verifica tu conexion.'};
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  static Future<List<dynamic>> obtenerAulas(int docenteId) async {
    try {
      print('Obteniendo aulas para docente_id: $docenteId');
      final response = await http.get(
        Uri.parse('$apiUrl/aulas?docente_id=$docenteId'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);
      print('Respuesta aulas: ${response.statusCode}');
      print('Body: ${response.body}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Error obtener aulas: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error de conexión al obtener aulas: $e');
    }
    return [];
  }

  static Future<List<dynamic>> obtenerAulasParaCoordinador() async {
    try {
      print('Obteniendo todas las aulas para coordinador');
      final response = await http.get(
        Uri.parse('$apiUrl/aulas?role=coordinador'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);
      print('Respuesta aulas coordinador: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Error obtener aulas: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error de conexión al obtener aulas: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> obtenerResumenAsistencia(int aulaId, String fecha, int sesion) async {
    try {
      print('Obteniendo resumen de asistencia para aula_id: $aulaId, fecha: $fecha, sesion: $sesion');
      final response = await http.get(
        Uri.parse('$apiUrl/aulas/resumen-asistencia?aula_id=$aulaId&fecha=$fecha&sesion=$sesion'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);
      print('Respuesta resumen: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Error obtener resumen: ${response.statusCode} - ${response.body}');
      return {};
    } catch (e) {
      print('Error de conexión al obtener resumen: $e');
      return {};
    }
  }

  static Future<List<dynamic>> obtenerEstudiantes(int aulaId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/aulas/$aulaId/estudiantes'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Error obtener estudiantes: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error de conexión al obtener estudiantes: $e');
    }
    return [];
  }

  static Future<bool> registrarAsistencia(int estudianteId, String estado, String fecha, int sesion) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/asistencias'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'estudiante_id': estudianteId,
          'estado': estado.toLowerCase(),
          'fecha': fecha,
          'sesion': sesion,
        }),
      ).timeout(requestTimeout);
      print('Respuesta asistencia: ${response.statusCode} - ${response.body}');
      return response.statusCode == 201;
    } catch (e) {
      print('Error al guardar asistencia: $e');
      return false;
    }
  }

  static Future<bool> registrarAsistenciasBatch(List<Map<String, dynamic>> asistencias, String fecha, int sesion) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/asistencias/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'fecha': fecha,
          'sesion': sesion,
          'asistencias': asistencias,
        }),
      ).timeout(requestTimeout);
      print('Respuesta batch: ${response.statusCode} - ${response.body}');
      return response.statusCode == 201;
    } catch (e) {
      print('Error al guardar asistencias batch: $e');
      return false;
    }
  }
}

void main() {
  runApp(const AsistenciaEstudiantesApp());
}

class AsistenciaEstudiantesApp extends StatelessWidget {
  const AsistenciaEstudiantesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistencia Estudiantes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
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
                                      final email = usuarioController.text.trim().toLowerCase();
                                      if (email.isEmpty || passwordController.text.isEmpty) {
                                        setState(() {
                                          error = 'Por favor completa todos los campos';
                                        });
                                        return;
                                      }

                                      setState(() {
                                        cargando = true;
                                        error = null;
                                      });

                                      final loginResult = await ApiService.login(
                                        email,
                                        passwordController.text,
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

  class _SelectAulaFechaScreenState extends State<SelectAulaFechaScreen> {
    List aulas = [];
    dynamic aulaSeleccionada;
    DateTime fecha = DateTime.now();
    int sesion = 1;
    final List<int> sesiones = List.generate(8, (i) => i + 1);
    bool cargando = true;

    @override
    void initState() {
      super.initState();
      print('SelectAulaFechaScreen iniciado con docente_id: ${widget.docenteId}');
      cargarAulas();
    }

    Future<void> cargarAulas() async {
      print('Cargando aulas para docente_id: ${widget.docenteId}');
      final data = await ApiService.obtenerAulas(widget.docenteId);
      print('Aulas recibidas: ${data.length}');
      setState(() {
        aulas = data;
        cargando = false;
        if (aulas.isNotEmpty) {
          aulaSeleccionada = aulas[0];
        }
      });
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seleccionar Aula y Fecha'),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Cerrar sesión',
              onPressed: () {
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
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (aulas.isEmpty)
                      const Text('No hay aulas disponibles. Contacte al administrador.', style: TextStyle(color: Colors.red)),
                    if (aulas.isNotEmpty)
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
                    ElevatedButton(
                      child: const Text('Continuar'),
                      onPressed: (aulas.isEmpty || aulaSeleccionada == null)
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AsistenciaScreen(
                                    aula: aulaSeleccionada,
                                    fecha: fecha,
                                    sesion: sesion,
                                  ),
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
        appBar: AppBar(
          title: const Text('Registrar Asistencia'),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Cerrar sesión',
              onPressed: () {
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
                  if (estudiantes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No hay estudiantes en esta aula.', style: TextStyle(color: Colors.red)),
                    ),
                  if (estudiantes.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: estudiantes.length,
                        itemBuilder: (context, index) {
                          final estudiante = estudiantes[index];
                          return AsistenciaItem(
                            nombre: estudiante['nombre'] ?? estudiante['nombre_completo'] ?? estudiante.toString(),
                            onChanged: (estado) {
                              setState(() {
                                asistencias[estudiante['id']] = estado;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  // Área fija en la parte inferior para mensaje y botón
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mensaje != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                              margin: const EdgeInsets.only(bottom: 12.0),
                              decoration: BoxDecoration(
                                color: mensaje!.contains('exitosamente') 
                                    ? Colors.green.withOpacity(0.1) 
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: mensaje!.contains('exitosamente') 
                                      ? Colors.green 
                                      : Colors.red,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                mensaje!, 
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: mensaje!.contains('exitosamente') 
                                      ? Colors.green.shade700 
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          guardando
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: estudiantes.isEmpty ? null : guardarAsistencias,
                                    child: const Text(
                                      'Guardar Asistencias',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
    final estados = [
      'Presente',
      'Ausente',
      'Tardanza',
      'Justificada',
      'Retirado',
    ];

    @override
    Widget build(BuildContext context) {
      return ListTile(
        title: Text(widget.nombre),
        trailing: DropdownButton<String>(
          value: estado,
          items: estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) {
            setState(() {
              estado = value!;
            });
            if (widget.onChanged != null) {
              widget.onChanged!(estado);
            }
          },
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
              onPressed: () {
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
