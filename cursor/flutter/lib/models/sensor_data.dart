class SensorData {
  final double exterior;
  final double interior;
  final double deposito;
  final double ambiente2;
  final double voltajeBat;
  final double voltajeBat2;
  final DateTime createdAt;

  SensorData({
    required this.exterior,
    required this.interior,
    required this.deposito,
    required this.ambiente2,
    required this.voltajeBat,
    required this.voltajeBat2,
    required this.createdAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      exterior: (json['Exterior'] ?? json['temp_exterior'] ?? 0).toDouble(),
      interior: (json['Interior'] ?? json['temp_interior'] ?? 0).toDouble(),
      deposito: (json['Deposito'] ?? json['temp_deposito'] ?? 0).toDouble(),
      ambiente2:
          (json['Ambiente2'] ?? json['temp_ambiente2'] ?? 0).toDouble(),
      voltajeBat: (json['VoltajeBat'] ??
              json['bateria_v'] ??
              json['Voltaje_Bat'] ??
              0)
          .toDouble(),
      voltajeBat2: (json['VoltajeBat2'] ??
              json['voltaje_bat_2'] ??
              json['Voltaje_Bat_2'] ??
              0)
          .toDouble(),
      createdAt: DateTime.tryParse(
            json['CreatedAt'] ?? json['created_at'] ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

