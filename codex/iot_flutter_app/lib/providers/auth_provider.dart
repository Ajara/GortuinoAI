import 'package:flutter/foundation.dart';

import '../services/app_logger.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required StorageService storageService,
    required ApiService apiService,
  })  : _storageService = storageService,
        _apiService = apiService;

  final StorageService _storageService;
  final ApiService _apiService;

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _serverIp;
  String? _token;
  String? _errorMessage;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _serverIp != null && _token != null;
  bool get isFirstSetup => _serverIp == null || _serverIp!.isEmpty;
  String? get serverIp => _serverIp;
  String? get token => _token;

  Future<void> bootstrap() async {
    _serverIp = await _storageService.readServerIp();
    _token = await _storageService.readToken();
    AppLogger.info(
      'Bootstrap auth: ip=${_serverIp ?? "-"} token=${_token != null ? "presente" : "ausente"}',
      name: 'AUTH',
    );
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> submitCredentials({
    required String serverIp,
    required String username,
    required String password,
    String mqttBrokerIp = '',
    int mqttPort = 1883,
    bool mqttSecure = false,
    String mqttCa = '',
    String mqttUsername = '',
    String mqttPassword = '',
  }) async {
    _setLoading(true);
    AppLogger.info(
      'Submit credentials: firstSetup=$isFirstSetup server=$serverIp user=$username',
      name: 'AUTH',
    );
    try {
      if (isFirstSetup) {
        AppLogger.info('Lanzando setup inicial', name: 'AUTH');
        try {
          await _apiService.setup(
            serverIp: serverIp,
            username: username,
            password: password,
            mqttBrokerIp: mqttBrokerIp,
            mqttPort: mqttPort,
            mqttSecure: mqttSecure,
            mqttCa: mqttCa,
            mqttUsername: mqttUsername,
            mqttPassword: mqttPassword,
          );
        } on ApiException catch (error) {
          if (error.statusCode == 403) {
            AppLogger.info(
              'Setup ya realizado en backend. Continuando con login.',
              name: 'AUTH',
            );
          } else {
            rethrow;
          }
        }
      }

      _token = await _apiService.login(
        serverIp: serverIp,
        username: username,
        password: password,
      );
      _serverIp = serverIp;
      _errorMessage = null;
      AppLogger.info('Autenticacion completada', name: 'AUTH');
    } on ApiException catch (error) {
      _errorMessage = error.message;
      AppLogger.warning('Error de autenticacion: ${error.message}', name: 'AUTH');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout({bool clearServerIp = false}) async {
    AppLogger.info('Logout solicitado. clearServerIp=$clearServerIp', name: 'AUTH');
    _token = null;
    if (clearServerIp) {
      _serverIp = null;
      await _storageService.clearSession();
    } else {
      await _storageService.clearToken();
    }
    notifyListeners();
  }

  String? consumeError() {
    final error = _errorMessage;
    _errorMessage = null;
    return error;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
