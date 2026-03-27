import 'package:flutter/material.dart';

class BatteryGauge extends StatelessWidget {
  const BatteryGauge({super.key, required this.voltage});

  final double? voltage;

  @override
  Widget build(BuildContext context) {
    final normalized = voltage == null
        ? 0.0
        : ((voltage! - 11.0) / 3.0).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batería', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              minHeight: 12,
              value: normalized,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                normalized > 0.66
                    ? const Color(0xFF4CAF50)
                    : normalized > 0.33
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFF44336),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              voltage == null
                  ? 'Sin lectura'
                  : '${voltage!.toStringAsFixed(2)} V  |  rango 11V - 14V',
            ),
          ],
        ),
      ),
    );
  }
}
