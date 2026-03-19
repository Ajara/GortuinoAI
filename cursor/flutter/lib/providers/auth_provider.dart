import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'jwt_token';
  static const _keyServerIp = 'server_ip';
  static const _keySetupDone = 'setup_done';

  bool _isInitializing = true;
  bool _isAuthenticated = false;
  String? _token;
  String? _serverIp;
  bool _setupDone = false;

  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get serverIp => _serverIp;
  bool get setupDone => _setupDone;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIp = prefs.getString(_keyServerIp);
    _setupDone = prefs.getBool(_keySetupDone) ?? false;
    _token = await _storage.read(key: _keyToken);
    _isAuthenticated = _token != null && _serverIp != null;
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _saveServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerIp, ip);
    _serverIp = ip;
  }

  Future<void> _setSetupDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySetupDone, value);
    _setupDone = value;
    notifyListeners();
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
    _token = token;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _token = null;
    await _storage.delete(key: _keyToken);
    notifyListeners();
  }

  Uri _buildUri(String path) {
    final ip = _serverIp ?? '127.0.0.1';
    return Uri.parse('http://$ip$path');
  }

  Future<void> setup({
    required String username,
    required String password,
    required String serverIp,
  }) async {
    await _saveServerIp(serverIp);

    final response = await http.post(
      _buildUri('/setup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'mqtt_broker_ip': serverIp,
      }),
    );

    if (response.statusCode == 200) {
      await _setSetupDone(true);
      return;
    }

    if (response.statusCode == 403) {
      // Setup ya fue hecho previamente, lo marcamos y no lo tratamos como error
      await _setSetupDone(true);
      return;
    }

    throw Exception('Error en setup: ${response.body}');
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _buildUri('/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 401) {
      throw Exception('Login incorrecto');
    }
    if (response.statusCode != 200) {
      throw Exception('Error en login: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null) {
      throw Exception('Token no recibido');
    }

    await _saveToken(token);
    _isAuthenticated = true;
    notifyListeners();
  }
}

