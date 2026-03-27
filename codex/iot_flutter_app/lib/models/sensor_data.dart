class SensorData {
  const SensorData({
    required this.exterior,
    required this.interior,
    required this.deposito,
    required this.ambiente2,
    required this.voltajeBat,
    required this.voltajeBat2,
    required this.createdAt,
  });

  final double? exterior;
  final double? interior;
  final double? deposito;
  final double? ambiente2;
  final double? voltajeBat;
  final double? voltajeBat2;
  final DateTime createdAt;

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      exterior: _asDouble(json['exterior']),
      interior: _asDouble(json['interior']),
      deposito: _asDouble(json['deposito']),
      ambiente2: _asDouble(json['ambiente2']),
      voltajeBat: _asDouble(json['voltaje_bat'] ?? json['voltaje_bateria']),
      voltajeBat2: _asDouble(json['voltaje_bat_2']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}
