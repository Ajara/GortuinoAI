import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';

class HistoryChart extends StatelessWidget {
  final List<SensorData> history;

  const HistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox(height: 300, child: Center(child: Text("Cargando histórico...")));
    }

    return AspectRatio(
      aspectRatio: 1.70,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF1B1B1B),
        ),
        padding: const EdgeInsets.all(12),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => const FlLine(color: Colors.white10, strokeWidth: 1)),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: history.length > 5 ? (history.length / 5).toDouble() : 1,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= 0 && value.toInt() < history.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(DateFormat('HH:mm').format(history[value.toInt()].timestamp), style: const TextStyle(fontSize: 10, color: Colors.white60)),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
            lineBarsData: [
              _generateLineData(history, (d) => d.exterior, const Color(0xFF4FC3F7)),
              _generateLineData(history, (d) => d.interior, const Color(0xFFFF9800)),
              _generateLineData(history, (d) => d.deposito, const Color(0xFFF44336)),
              _generateLineData(history, (d) => d.ambiente2, const Color(0xFF4CAF50)),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.black87,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      "${spot.barIndex == 0 ? 'Ext' : spot.barIndex == 1 ? 'Int' : spot.barIndex == 2 ? 'Dep' : 'Amb'}: ${spot.y.toStringAsFixed(1)}°C",
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _generateLineData(List<SensorData> data, double Function(SensorData) field, Color color) {
    return LineChartBarData(
      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), field(e.value))).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }
}
