import 'package:flutter/material.dart';

class ValveButtons extends StatelessWidget {
  final bool valve1Busy;
  final bool valve2Busy;
  final int valve1SecondsLeft;
  final int valve2SecondsLeft;
  final VoidCallback onValve1;
  final VoidCallback onValve2;

  const ValveButtons({
    super.key,
    required this.valve1Busy,
    required this.valve2Busy,
    required this.valve1SecondsLeft,
    required this.valve2SecondsLeft,
    required this.onValve1,
    required this.onValve2,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = valve1Busy || valve2Busy;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: (disabled && !valve1Busy) ? null : onValve1,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: Text(
              valve1Busy
                  ? 'Válvula 1 (${valve1SecondsLeft}s)'
                  : 'Válvula 1',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: (disabled && !valve2Busy) ? null : onValve2,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFFF44336),
            ),
            child: Text(
              valve2Busy
                  ? 'Válvula 2 (${valve2SecondsLeft}s)'
                  : 'Válvula 2',
            ),
          ),
        ),
      ],
    );
  }
}

