import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/iot_provider.dart';
import '../widgets/history_chart.dart';
import '../widgets/valve_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final iot = Provider.of<IotProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("IoT Home Monitor"),
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4FC3F7)),
            onPressed: () => iot.fetchData(),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => iot.fetchData(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Estado en Tiempo Real"),
              const SizedBox(height: 16),
              _buildSensorGrid(iot),
              const SizedBox(height: 32),
              _buildSectionTitle("Histórico 24h"),
              const SizedBox(height: 16),
              HistoryChart(history: iot.history),
              const SizedBox(height: 32),
              _buildSectionTitle("Voltaje de Baterías"),
              const SizedBox(height: 16),
              _buildBatteryCard("Batería 1 (Principal)", iot.currentData?.voltajeBat ?? 0, const Color(0xFF4CAF50)),
              const SizedBox(height: 12),
              _buildBatteryCard("Batería 2 (Auxiliar)", iot.currentData?.voltajeBat2 ?? 0, const Color(0xFFFDD835)),
              const SizedBox(height: 32),
              _buildSectionTitle("Control de Válvulas"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: ValveButton(id: 1, iot: iot)),
                  const SizedBox(width: 16),
                  Expanded(child: ValveButton(id: 2, iot: iot)),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  Widget _buildSensorGrid(IotProvider iot) {
    final data = iot.currentData;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _SensorCard(label: "Exterior", value: data?.exterior, color: const Color(0xFF4FC3F7), icon: Icons.wb_sunny_outlined),
        _SensorCard(label: "Interior", value: data?.interior, color: const Color(0xFFFF9800), icon: Icons.home_outlined),
        _SensorCard(label: "Depósito", value: data?.deposito, color: const Color(0xFFF44336), icon: Icons.water_drop_outlined),
        _SensorCard(label: "Ambiente 2", value: data?.ambiente2, color: const Color(0xFF4CAF50), icon: Icons.thermostat_outlined),
      ],
    );
  }

  Widget _buildBatteryCard(String label, double voltage, Color accentColor) {
    double progress = ((voltage - 11) / (14 - 11)).clamp(0.0, 1.0);
    Color statusColor = voltage < 11.5 ? Colors.redAccent : (voltage < 12.2 ? Colors.orangeAccent : accentColor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Text("${voltage.toStringAsFixed(2)} V", style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress, 
              minHeight: 8, 
              backgroundColor: Colors.white10, 
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  final IconData icon;

  const _SensorCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1B1B1B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Icon(icon, color: color.withOpacity(0.5), size: 18),
            ],
          ),
          Text("${value?.toStringAsFixed(1) ?? '--'}°C", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
