import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

class ApiService {
  Future<String> get _baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    // Para Flutter Web (Chrome), usa localhost
    return prefs.getString('server_ip') ?? 'http://localhost:8080';
  }

  Future<SensorData> getActualStatus() async {
    final url = await _baseUrl;
    final response = await http.get(Uri.parse('$url/api/actual'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return SensorData.fromJson(data['sensores']);
    } else {
      throw Exception('Fallo al cargar estado actual');
    }
  }

  Future<List<SensorData>> getHistory() async {
    final url = await _baseUrl;
    final response = await http.get(Uri.parse('$url/api/historico'));
    
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => SensorData.fromJson(data)).toList();
    } else {
      throw Exception('Fallo al cargar histórico');
    }
  }

  Future<void> controlValve(int id) async {
    final url = await _baseUrl;
    final response = await http.post(Uri.parse('$url/api/valvula/$id'));
    
    if (response.statusCode != 200) {
      throw Exception('Error al controlar válvula $id');
    }
  }
}
