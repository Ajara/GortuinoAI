import 'package:flutter/material.dart';

import '../models/sensor_data.dart';

class SensorCards extends StatelessWidget {
  final SensorData? latest;

  const SensorCards({super.key, required this.latest});

  @override
  Widget build(BuildContext context) {
    final data = latest;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SensorCard(
          label: 'Exterior',
          value: data?.exterior,
          unit: '°C',
          color: const Color(0xFF4FC3F7),
        ),
        _SensorCard(
          label: 'Interior',
          value: data?.interior,
          unit: '°C',
          color: const Color(0xFFFF9800),
        ),
        _SensorCard(
          label: 'Depósito',
          value: data?.deposito,
          unit: '°C',
          color: const Color(0xFFF44336),
        ),
        _SensorCard(
          label: 'Ambiente 2',
          value: data?.ambiente2,
          unit: '°C',
          color: const Color(0xFF4CAF50),
        ),
        _SensorCard(
          label: 'Batería',
          value: data?.voltajeBat,
          unit: 'V',
          color: Colors.lightGreenAccent,
        ),
        _SensorCard(
          label: 'Batería 2',
          value: data?.voltajeBat2,
          unit: 'V',
          color: const Color(0xFFFDD835),
        ),
      ],
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final Color color;

  const _SensorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 22,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE0E0E0),
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    value != null ? value!.toStringAsFixed(1) : '--',
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

