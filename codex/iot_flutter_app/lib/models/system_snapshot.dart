import 'sensor_data.dart';

class SystemSnapshot {
  const SystemSnapshot({
    required this.sensorData,
    required this.rele6,
    required this.rele7,
  });

  final SensorData sensorData;
  final String rele6;
  final String rele7;

  factory SystemSnapshot.fromJson(Map<String, dynamic> json) {
    return SystemSnapshot(
      sensorData: SensorData.fromJson(
        Map<String, dynamic>.from(json['sensores'] as Map),
      ),
      rele6: json['rele6']?.toString() ?? 'Desconocido',
      rele7: json['rele7']?.toString() ?? 'Desconocido',
    );
  }
}
