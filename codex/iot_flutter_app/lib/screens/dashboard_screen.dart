import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/system_provider.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/connection_header.dart';
import '../widgets/sensor_card.dart';
import '../widgets/temperature_chart.dart';
import '../widgets/valve_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SystemProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SystemProvider, AuthProvider>(
      builder: (context, system, auth, _) {
        final snapshot = system.snapshot;
        final sensors = snapshot?.sensorData;
        final error = system.consumeError();

        if (error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sistema IoT'),
            actions: [
              IconButton(
                onPressed: () => auth.logout(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: system.refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                ConnectionHeader(
                  serverIp: auth.serverIp ?? '-',
                  isConnected: system.isConnected,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: system.isLiveRefreshing
                        ? null
                        : () => system.requestLiveSensors(),
                    icon: system.isLiveRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt),
                    label: Text(
                      system.isLiveRefreshing
                          ? 'Solicitando lectura...'
                          : 'Pedir valores en caliente',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SensorCard(
                      title: 'Exterior',
                      value: sensors?.exterior,
                      unit: '°C',
                      color: const Color(0xFF4FC3F7),
                    ),
                    SensorCard(
                      title: 'Interior',
                      value: sensors?.interior,
                      unit: '°C',
                      color: const Color(0xFFFF9800),
                    ),
                    SensorCard(
                      title: 'Depósito',
                      value: sensors?.deposito,
                      unit: '°C',
                      color: const Color(0xFFF44336),
                    ),
                    SensorCard(
                      title: 'Ambiente 2',
                      value: sensors?.ambiente2,
                      unit: '°C',
                      color: const Color(0xFF4CAF50),
                    ),
                    SensorCard(
                      title: 'Voltaje batería',
                      value: sensors?.voltajeBat,
                      unit: 'V',
                      color: const Color(0xFFAB47BC),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BatteryGauge(voltage: sensors?.voltajeBat),
                const SizedBox(height: 16),
                TemperatureChart(history: system.history),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ValveButton(
                        label: 'Válvula 1',
                        isActive: system.activeValveId == 1,
                        isDisabled:
                            system.activeValveId != null && system.activeValveId != 1,
                        remainingSeconds: system.remainingSeconds,
                        onPressed: () => system.activateValve(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValveButton(
                        label: 'Válvula 2',
                        isActive: system.activeValveId == 2,
                        isDisabled:
                            system.activeValveId != null && system.activeValveId != 2,
                        remainingSeconds: system.remainingSeconds,
                        onPressed: () => system.activateValve(2),
                      ),
                    ),
                  ],
                ),
                if (system.isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
