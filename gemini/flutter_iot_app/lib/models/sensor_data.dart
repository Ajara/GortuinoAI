class SensorData {
  final double exterior;
  final double interior;
  final double deposito;
  final double ambiente2;
  final double voltajeBat;
  final double voltajeBat2;
  final DateTime timestamp;

  SensorData({
    required this.exterior,
    required this.interior,
    required this.deposito,
    required this.ambiente2,
    required this.voltajeBat,
    required this.voltajeBat2,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      exterior: (json['Exterior'] ?? 0.0).toDouble(),
      interior: (json['Interior'] ?? 0.0).toDouble(),
      deposito: (json['Deposito'] ?? 0.0).toDouble(),
      ambiente2: (json['Ambiente2'] ?? 0.0).toDouble(),
      voltajeBat: (json['VoltajeBateria'] ?? 0.0).toDouble(),
      voltajeBat2: (json['VoltajeBateria2'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
