import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/sensor_data.dart';

class SensorChart extends StatelessWidget {
  final List<SensorData> history;

  const SensorChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('Sin datos históricos'));
    }

    final minX = 0.0;
    final maxX = history.length.toDouble() - 1;

    List<FlSpot> spotsFor(double Function(SensorData) selector) {
      return List.generate(
        history.length,
        (i) => FlSpot(i.toDouble(), selector(history[i])),
      );
    }

    return LineChart(
      LineChartData(
        backgroundColor: Colors.transparent,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (maxX - minX) / 4,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= history.length) {
                  return const SizedBox.shrink();
                }
                final ts = history[index].createdAt;
                final label =
                    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                return Text(
                  label,
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            //tooltipBgColor: Colors.black87,
            getTooltipColor: (LineBarSpot touchedSpot) => Colors.black87,
            getTooltipItems: (spots) {
              if (spots.isEmpty) return [];
              final idx = spots.first.spotIndex;
              final d = history[idx];
              final ts = d.createdAt;
              final timeLabel =
                  '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
              return [
                LineTooltipItem(
                  'Hora: $timeLabel\n'
                  'Ext: ${d.exterior.toStringAsFixed(1)}°C\n'
                  'Int: ${d.interior.toStringAsFixed(1)}°C\n'
                  'Dep: ${d.deposito.toStringAsFixed(1)}°C\n'
                  'Amb2: ${d.ambiente2.toStringAsFixed(1)}°C',
                  const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ];
            },
          ),
        ),
        minX: minX,
        maxX: maxX,
        lineBarsData: [
          LineChartBarData(
            spots: spotsFor((d) => d.exterior),
            isCurved: true,
            color: const Color(0xFF4FC3F7),
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spotsFor((d) => d.interior),
            isCurved: true,
            color: const Color(0xFFFF9800),
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spotsFor((d) => d.deposito),
            isCurved: true,
            color: const Color(0xFFF44336),
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spotsFor((d) => d.ambiente2),
            isCurved: true,
            color: const Color(0xFF4CAF50),
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

