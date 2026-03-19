import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';
import 'auth_provider.dart';

class DataProvider extends ChangeNotifier {
  AuthProvider? _auth;

  SensorData? _latest;
  List<SensorData> _history = [];
  bool _isLoading = false;
  String? _error;

  bool _valve1Busy = false;
  bool _valve2Busy = false;
  int _valve1SecondsLeft = 0;
  int _valve2SecondsLeft = 0;

  Timer? _pollTimer;
  Timer? _valveTimer;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
  }

  SensorData? get latest => _latest;
  List<SensorData> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get valve1Busy => _valve1Busy;
  bool get valve2Busy => _valve2Busy;
  int get valve1SecondsLeft => _valve1SecondsLeft;
  int get valve2SecondsLeft => _valve2SecondsLeft;

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      fetchActual();
    });
    fetchActual();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Uri _buildUri(String path) {
    final ip = _auth?.serverIp ?? '127.0.0.1';
    return Uri.parse('http://$ip$path');
  }

  Map<String, String> _headers() {
    final token = _auth?.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> fetchActual() async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        _buildUri('/api/actual'),
        headers: _headers(),
      );
      if (response.statusCode == 401) {
        await _auth?.logout();
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final sensores = data['sensores'] as Map<String, dynamic>? ?? {};
      _latest = SensorData.fromJson(sensores);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchActualOnline() async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        _buildUri('/api/actual/online'),
        headers: _headers(),
      );
      if (response.statusCode == 401) {
        await _auth?.logout();
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final sensores = data['sensores'] as Map<String, dynamic>? ?? {};
      _latest = SensorData.fromJson(sensores);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchHistorico() async {
    _error = null;
    try {
      final response = await http.get(
        _buildUri('/api/historico'),
        headers: _headers(),
      );
      if (response.statusCode == 401) {
        await _auth?.logout();
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}');
      }
      final list = jsonDecode(response.body) as List<dynamic>;
      _history = list
          .map((e) => SensorData.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> triggerValve(int id) async {
    _error = null;
    if (id == 1 && _valve1Busy) return;
    if (id == 2 && _valve2Busy) return;

    try {
      final response = await http.post(
        _buildUri('/api/valvula/$id'),
        headers: _headers(),
      );
      if (response.statusCode == 401) {
        await _auth?.logout();
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}');
      }

      _startValveCountdown(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _startValveCountdown(int id) {
    _valveTimer?.cancel();
    _valve1Busy = id == 1;
    _valve2Busy = id == 2;
    _valve1SecondsLeft = id == 1 ? 30 : 0;
    _valve2SecondsLeft = id == 2 ? 30 : 0;
    notifyListeners();

    _valveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (id == 1) {
        _valve1SecondsLeft--;
        if (_valve1SecondsLeft <= 0) {
          _valve1Busy = false;
          timer.cancel();
        }
      } else {
        _valve2SecondsLeft--;
        if (_valve2SecondsLeft <= 0) {
          _valve2Busy = false;
          timer.cancel();
        }
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _valveTimer?.cancel();
    super.dispose();
  }
}

