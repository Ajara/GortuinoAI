import 'package:flutter/material.dart';

class BatteryGauge extends StatelessWidget {
  final double? voltaje;

  const BatteryGauge({super.key, required this.voltaje});

  @override
  Widget build(BuildContext context) {
    final v = voltaje ?? 0;
    const minV = 11.0;
    const maxV = 14.0;
    final clamped = v.clamp(minV, maxV);
    final percent = ((clamped - minV) / (maxV - minV)).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batería',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: voltaje == null ? 0 : percent,
              minHeight: 10,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.6
                    ? Colors.greenAccent
                    : percent > 0.3
                        ? Colors.orangeAccent
                        : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  voltaje != null ? '${voltaje!.toStringAsFixed(2)} V' : '-- V',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Text(
                  '11V - 14V',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

