import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sensor_data.dart';
import '../models/system_snapshot.dart';
import '../services/app_logger.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class SystemProvider extends ChangeNotifier {
  SystemProvider({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  AuthProvider? _authProvider;
  SystemSnapshot? _snapshot;
  List<SensorData> _history = const [];
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  bool _isLoading = false;
  bool _isLiveRefreshing = false;
  bool _isConnected = false;
  String? _errorMessage;
  int? _activeValveId;
  int _remainingSeconds = 0;

  SystemSnapshot? get snapshot => _snapshot;
  List<SensorData> get history => _history;
  bool get isLoading => _isLoading;
  bool get isLiveRefreshing => _isLiveRefreshing;
  bool get isConnected => _isConnected;
  int? get activeValveId => _activeValveId;
  int get remainingSeconds => _remainingSeconds;

  void bindAuthProvider(AuthProvider auth) {
    final wasAuthenticated = _authProvider?.isAuthenticated ?? false;
    _authProvider = auth;

    if (auth.isAuthenticated && !wasAuthenticated) {
      AppLogger.info('Auth enlazada: iniciando refresh y polling', name: 'SYSTEM');
      unawaited(refreshAll());
      startPolling();
    } else if (!auth.isAuthenticated && wasAuthenticated) {
      AppLogger.info('Auth perdida: deteniendo polling', name: 'SYSTEM');
      stopPolling();
      _snapshot = null;
      _history = const [];
      _isConnected = false;
    }
  }

  Future<void> refreshAll() async {
    final auth = _authProvider;
    if (auth == null || !auth.isAuthenticated) {
      return;
    }

    _setLoading(true);
    AppLogger.info('Refresh completo solicitado', name: 'SYSTEM');
    try {
      _snapshot = await _apiService.fetchActual(
        serverIp: auth.serverIp!,
        token: auth.token!,
      );
      _history = await _apiService.fetchHistorico(
        serverIp: auth.serverIp!,
        token: auth.token!,
      );
      _isConnected = true;
      _errorMessage = null;
      AppLogger.info(
        'Refresh completo OK: historico=${_history.length} muestras',
        name: 'SYSTEM',
      );
    } on ApiException catch (error) {
      await _handleApiError(error, auth);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshActual() async {
    final auth = _authProvider;
    if (auth == null || !auth.isAuthenticated) {
      return;
    }

    try {
      AppLogger.info('Polling /api/actual', name: 'SYSTEM');
      _snapshot = await _apiService.fetchActual(
        serverIp: auth.serverIp!,
        token: auth.token!,
      );
      _isConnected = true;
      _errorMessage = null;
      AppLogger.info('Polling OK', name: 'SYSTEM');
      notifyListeners();
    } on ApiException catch (error) {
      await _handleApiError(error, auth);
    }
  }

  Future<void> activateValve(int valveId) async {
    final auth = _authProvider;
    if (auth == null || !auth.isAuthenticated || _activeValveId != null) {
      return;
    }

    try {
      AppLogger.info('Activando valvula $valveId', name: 'SYSTEM');
      await _apiService.activateValve(
        serverIp: auth.serverIp!,
        token: auth.token!,
        valveId: valveId,
      );

      _activeValveId = valveId;
      _remainingSeconds = 30;
      notifyListeners();

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds <= 1) {
          timer.cancel();
          AppLogger.info('Cuenta atras completada para valvula $valveId', name: 'SYSTEM');
          _activeValveId = null;
          _remainingSeconds = 0;
          notifyListeners();
          unawaited(refreshActual());
          return;
        }

        _remainingSeconds--;
        notifyListeners();
      });
    } on ApiException catch (error) {
      await _handleApiError(error, auth);
      rethrow;
    }
  }

  Future<void> requestLiveSensors() async {
    final auth = _authProvider;
    if (auth == null || !auth.isAuthenticated || _isLiveRefreshing) {
      return;
    }

    _isLiveRefreshing = true;
    notifyListeners();

    try {
      AppLogger.info('Solicitando lectura en caliente', name: 'SYSTEM');
      await _apiService.requestLiveSensors(
        serverIp: auth.serverIp!,
        token: auth.token!,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await refreshActual();
    } on ApiException catch (error) {
      await _handleApiError(error, auth);
      rethrow;
    } finally {
      _isLiveRefreshing = false;
      notifyListeners();
    }
  }

  void startPolling() {
    _pollingTimer?.cancel();
    AppLogger.info('Timer de polling iniciado cada 10s', name: 'SYSTEM');
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(refreshActual()),
    );
  }

  void stopPolling() {
    AppLogger.info('Timers detenidos', name: 'SYSTEM');
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
  }

  String? consumeError() {
    final error = _errorMessage;
    _errorMessage = null;
    return error;
  }

  Future<void> _handleApiError(ApiException error, AuthProvider auth) async {
    _isConnected = false;
    _errorMessage = error.message;
    AppLogger.warning(
      'Error de sistema: ${error.message} status=${error.statusCode ?? "-"}',
      name: 'SYSTEM',
    );
    if (error.statusCode == 401) {
      await auth.logout();
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
