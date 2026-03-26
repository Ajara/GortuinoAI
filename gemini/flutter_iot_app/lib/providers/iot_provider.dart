import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart';

class IotProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  SensorData? _currentData;
  List<SensorData> _history = [];
  bool _isValveLoading = false;
  int _valveCountdown = 0;
  int? _activeValveId;
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  SensorData? get currentData => _currentData;
  List<SensorData> get history => _history;
  bool get isValveLoading => _isValveLoading;
  int get valveCountdown => _valveCountdown;
  int? get activeValveId => _activeValveId;

  void startApp() {
    fetchData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetchData());
  }

  Future<void> fetchData() async {
    try {
      _currentData = await _api.getActualStatus();
      _history = await _api.getHistory();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  Future<void> activateValve(int id) async {
    if (_isValveLoading) return;

    try {
      await _api.controlValve(id);
      _isValveLoading = true;
      _activeValveId = id;
      _valveCountdown = 30;
      notifyListeners();

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_valveCountdown > 0) {
          _valveCountdown--;
          notifyListeners();
        } else {
          _isValveLoading = false;
          _activeValveId = null;
          timer.cancel();
          notifyListeners();
        }
      });
    } catch (e) {
      _isValveLoading = false;
      rethrow;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
