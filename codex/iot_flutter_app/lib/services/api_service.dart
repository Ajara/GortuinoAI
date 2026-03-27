import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';
import '../models/system_snapshot.dart';
import 'app_logger.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({required StorageService storageService})
      : _storageService = storageService;

  final StorageService _storageService;

  Future<void> setup({
    required String serverIp,
    required String username,
    required String password,
    required String mqttBrokerIp,
    required int mqttPort,
    required bool mqttSecure,
    required String mqttCa,
    required String mqttUsername,
    required String mqttPassword,
  }) async {
    AppLogger.info('POST /setup -> $serverIp', name: 'API');
    final response = await _post(
      serverIp: serverIp,
      path: '/setup',
      body: {
        'username': username,
        'password': password,
        'mqtt_broker_ip': mqttBrokerIp,
        'mqtt_port': mqttPort,
        'mqtt_secure': mqttSecure,
        'mqtt_ca': mqttCa,
        'mqtt_username': mqttUsername,
        'mqtt_password': mqttPassword,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        'POST /setup fallo con status ${response.statusCode}',
        name: 'API',
      );
      throw _toApiException(response);
    }
    AppLogger.info('POST /setup completado OK', name: 'API');
  }

  Future<String> login({
    required String serverIp,
    required String username,
    required String password,
  }) async {
    AppLogger.info('POST /login -> $serverIp', name: 'API');
    final response = await _post(
      serverIp: serverIp,
      path: '/login',
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        'POST /login fallo con status ${response.statusCode}',
        name: 'API',
      );
      throw _toApiException(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final token = json['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('El backend no devolvió un JWT válido.');
    }

    await _storageService.saveServerIp(serverIp);
    await _storageService.saveToken(token);
    AppLogger.info('POST /login devolvio JWT', name: 'API');
    return token;
  }

  Future<SystemSnapshot> fetchActual({
    required String serverIp,
    required String token,
  }) async {
    AppLogger.info('GET /api/actual', name: 'API');
    final response = await _get(
      serverIp: serverIp,
      path: '/api/actual',
      token: token,
    );

    if (response.statusCode == 401) {
      throw ApiException('La sesión ha expirado.', statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        'GET /api/actual fallo con status ${response.statusCode}',
        name: 'API',
      );
      throw _toApiException(response);
    }

    return SystemSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SensorData>> fetchHistorico({
    required String serverIp,
    required String token,
  }) async {
    AppLogger.info('GET /api/historico', name: 'API');
    final response = await _get(
      serverIp: serverIp,
      path: '/api/historico',
      token: token,
    );

    if (response.statusCode == 401) {
      throw ApiException('La sesión ha expirado.', statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        'GET /api/historico fallo con status ${response.statusCode}',
        name: 'API',
      );
      throw _toApiException(response);
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => SensorData.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> activateValve({
    required String serverIp,
    required String token,
    required int valveId,
  }) async {
    AppLogger.info('POST /api/valvula/$valveId', name: 'API');
    final response = await _post(
      serverIp: serverIp,
      path: '/api/valvula/$valveId',
      token: token,
      body: const {},
    );

    if (response.statusCode == 401) {
      throw ApiException('La sesión ha expirado.', statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        'POST /api/valvula/$valveId fallo con status ${response.statusCode}',
        name: 'API',
      );
      throw _toApiException(response);
    }
    AppLogger.info('POST /api/valvula/$valveId aceptado', name: 'API');
  }

  Future<void> requestLiveSensors({
    required String serverIp,
    required String token,
  }) async {
    AppLogger.info('POST /api/sensores/live', name: 'API');
    final response = await _post(
      serverIp: serverIp,
      path: '/api/sensores/live',
      token: token,
      body: const {},
    );

    if (response.statusCode == 401) {
      throw ApiException('La sesión ha expirado.', statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        'POST /api/sensores/live fallo con status ${response.statusCode}',
        name: 'API',
      );
      throw _toApiException(response);
    }
    AppLogger.info('POST /api/sensores/live aceptado', name: 'API');
  }

  Future<http.Response> _get({
    required String serverIp,
    required String path,
    String? token,
  }) async {
    final uri = _buildUri(serverIp, path);
    try {
      return await http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      AppLogger.error(
        'GET ${uri.toString()} fallo',
        name: 'API',
        error: error,
        stackTrace: stackTrace,
      );
      throw ApiException('No se pudo conectar con el servidor.');
    }
  }

  Future<http.Response> _post({
    required String serverIp,
    required String path,
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final uri = _buildUri(serverIp, path);
    try {
      return await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      AppLogger.error(
        'POST ${uri.toString()} fallo',
        name: 'API',
        error: error,
        stackTrace: stackTrace,
      );
      throw ApiException('No se pudo conectar con el servidor.');
    }
  }

  Uri _buildUri(String serverIp, String path) {
    final sanitized = serverIp.trim().replaceAll(RegExp(r'^https?://'), '');
    return Uri.parse('http://$sanitized:8080$path');
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  ApiException _toApiException(http.Response response) {
    String message = 'Error inesperado del servidor.';
    if (response.body.isNotEmpty) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        message = json['error']?.toString() ?? message;
      } catch (_) {
        message = response.body;
      }
    }
    return ApiException(message, statusCode: response.statusCode);
  }
}
