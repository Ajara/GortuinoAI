import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sensor_data.dart';

class TemperatureChart extends StatelessWidget {
  const TemperatureChart({super.key, required this.history});

  final List<SensorData> history;

  @override
  Widget build(BuildContext context) {
    final filteredHistory = history.where(_hasAnyTemperature).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historico 24h', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: filteredHistory.isEmpty
                  ? const Center(child: Text('Sin historico disponible'))
                  : LineChart(_buildChartData(filteredHistory)),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData(List<SensorData> filteredHistory) {
    final timeFormat = DateFormat('HH:mm');
    final lineBarsData = <LineChartBarData>[
      _line(filteredHistory, (e) => e.exterior, const Color(0xFF4FC3F7)),
      _line(filteredHistory, (e) => e.interior, const Color(0xFFFF9800)),
      _line(filteredHistory, (e) => e.deposito, const Color(0xFFF44336)),
      _line(filteredHistory, (e) => e.ambiente2, const Color(0xFF4CAF50)),
    ].where((line) => line.spots.isNotEmpty).toList();

    return LineChartData(
      minX: 0,
      maxX: (filteredHistory.length - 1).toDouble(),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (value, _) => Text(
              value.toStringAsFixed(0),
              style: const TextStyle(fontSize: 11, color: Color(0xFFE0E0E0)),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: filteredHistory.length < 6
                ? 1
                : (filteredHistory.length / 6).floorToDouble(),
            getTitlesWidget: (value, _) {
              final index = value.toInt();
              if (index < 0 || index >= filteredHistory.length) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  timeFormat.format(filteredHistory[index].createdAt.toLocal()),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFE0E0E0)),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            if (spots.isEmpty) {
              return [];
            }

            final index = spots.first.x.toInt();
            final sample = filteredHistory[index];
            final timeLabel = timeFormat.format(sample.createdAt.toLocal());

            return spots.map((spot) {
              final color = spot.bar.color ?? Colors.white;
              final value = spot.y.toStringAsFixed(2);
              final label = _seriesLabel(color);

              return LineTooltipItem(
                '$timeLabel\n$label: $value C',
                TextStyle(color: color, fontWeight: FontWeight.w600),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: lineBarsData,
    );
  }

  LineChartBarData _line(
    List<SensorData> values,
    double? Function(SensorData) selector,
    Color color,
  ) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      spots: [
        for (int i = 0; i < values.length; i++)
          if (selector(values[i]) != null) FlSpot(i.toDouble(), selector(values[i])!)
      ],
    );
  }

  bool _hasAnyTemperature(SensorData data) {
    return data.exterior != null ||
        data.interior != null ||
        data.deposito != null ||
        data.ambiente2 != null;
  }

  String _seriesLabel(Color color) {
    if (color.value == const Color(0xFF4FC3F7).value) {
      return 'Ext';
    }
    if (color.value == const Color(0xFFFF9800).value) {
      return 'Int';
    }
    if (color.value == const Color(0xFFF44336).value) {
      return 'Dep';
    }
    if (color.value == const Color(0xFF4CAF50).value) {
      return 'Amb2';
    }
    return 'Temp';
  }

  String _format(double? value) => value == null ? '--' : value.toStringAsFixed(2);
}
