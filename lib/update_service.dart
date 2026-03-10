import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Servicio para verificar actualizaciones de la app
class UpdateService {
  static const String _updateCheckUrl = 'https://www.liceojacintodelaconcha.com/api/app-version';

  static Future<String> getInstalledVersionLabel() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
  
  /// Verificar si hay actualizaciones disponibles
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      // Obtener versión actual de la app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      
      // Consultar versión más reciente del servidor
      final response = await http.get(
        Uri.parse(_updateCheckUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String?;
        final latestBuildNumber = _parseBuildNumber(data['build_number']);
        final downloadUrl = data['download_url'] as String?;
        final isForced = data['force_update'] as bool? ?? false;
        final releaseNotes = data['release_notes'] as String?;
        
        if (latestVersion == null || latestBuildNumber == null) {
          return null;
        }
        
        if (_isRemoteVersionNewer(
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          latestVersion: latestVersion,
          latestBuildNumber: latestBuildNumber,
        )) {
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            currentBuildNumber: currentBuildNumber,
            latestBuildNumber: latestBuildNumber,
            downloadUrl: downloadUrl ?? '',
            isForced: isForced,
            releaseNotes: releaseNotes,
          );
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error al verificar actualizaciones: $e');
      return null;
    }
  }

  static int? _parseBuildNumber(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool _isRemoteVersionNewer({
    required String currentVersion,
    required int currentBuildNumber,
    required String latestVersion,
    required int latestBuildNumber,
  }) {
    if (latestBuildNumber != currentBuildNumber) {
      return latestBuildNumber > currentBuildNumber;
    }

    return _compareVersions(latestVersion, currentVersion) > 0;
  }

  static int _compareVersions(String left, String right) {
    final leftParts = _extractVersionNumbers(left);
    final rightParts = _extractVersionNumbers(right);
    final maxLength = leftParts.length > rightParts.length ? leftParts.length : rightParts.length;

    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;

      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return 0;
  }

  static List<int> _extractVersionNumbers(String version) {
    return RegExp(r'\d+')
        .allMatches(version)
        .map((match) => int.tryParse(match.group(0) ?? '0') ?? 0)
        .toList();
  }
  
  /// Mostrar diálogo de actualización disponible
  static void showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForced,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => !updateInfo.isForced,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: updateInfo.isForced ? Colors.red.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    updateInfo.isForced ? Icons.warning_rounded : Icons.system_update_rounded,
                    color: updateInfo.isForced ? Colors.red.shade700 : Colors.blue.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    updateInfo.isForced 
                        ? '¡Actualización Requerida!' 
                        : 'Actualización Disponible',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Versión Actual',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              updateInfo.currentVersionLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward, color: Colors.grey),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Nueva Versión',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              updateInfo.latestVersionLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (updateInfo.releaseNotes != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Novedades:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updateInfo.releaseNotes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  if (updateInfo.isForced) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Esta actualización es obligatoria para continuar usando la app.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!updateInfo.isForced)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Más tarde'),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (updateInfo.downloadUrl.isNotEmpty) {
                    final uri = Uri.parse(updateInfo.downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                  if (!updateInfo.isForced && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Actualizar Ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Información de actualización disponible
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final int currentBuildNumber;
  final int latestBuildNumber;
  final String downloadUrl;
  final bool isForced;
  final String? releaseNotes;

  String get currentVersionLabel => '$currentVersion+$currentBuildNumber';
  String get latestVersionLabel => '$latestVersion+$latestBuildNumber';

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.currentBuildNumber,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.isForced,
    this.releaseNotes,
  });
}
