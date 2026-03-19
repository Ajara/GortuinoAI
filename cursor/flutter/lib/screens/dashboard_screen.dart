import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';
import '../widgets/connection_header.dart';
import '../widgets/sensor_cards.dart';
import '../widgets/sensor_chart.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/valve_buttons.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final data = context.read<DataProvider>();
    data.startPolling();
    data.fetchHistorico();
  }

  Future<void> _refresh() async {
    final data = context.read<DataProvider>();
    await Future.wait([
      data.fetchActual(),
      data.fetchHistorico(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Consumer<DataProvider>(
              builder: (context, data, _) {
                if (data.error != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error de conexión: ${data.error}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const ConnectionHeader(),
                        TextButton.icon(
                          onPressed: data.isLoading
                              ? null
                              : () => data.fetchActualOnline(),
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          label: const Text(
                            'Actualizar',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SensorCards(latest: data.latest),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 260,
                      child: SensorChart(history: data.history),
                    ),
                    const SizedBox(height: 16),
                    BatteryGauge(voltaje: data.latest?.voltajeBat),
                    const SizedBox(height: 24),
                    ValveButtons(
                      valve1Busy: data.valve1Busy,
                      valve2Busy: data.valve2Busy,
                      valve1SecondsLeft: data.valve1SecondsLeft,
                      valve2SecondsLeft: data.valve2SecondsLeft,
                      onValve1: () => data.triggerValve(1),
                      onValve2: () => data.triggerValve(2),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

