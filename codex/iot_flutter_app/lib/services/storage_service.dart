import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _serverIpKey = 'server_ip';
  static const _jwtKey = 'jwt_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveServerIp(String serverIp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIpKey, serverIp);
  }

  Future<String?> readServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverIpKey);
  }

  Future<void> saveToken(String token) {
    return _secureStorage.write(key: _jwtKey, value: token);
  }

  Future<String?> readToken() {
    return _secureStorage.read(key: _jwtKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverIpKey);
    await _secureStorage.delete(key: _jwtKey);
  }

  Future<void> clearToken() {
    return _secureStorage.delete(key: _jwtKey);
  }
}
