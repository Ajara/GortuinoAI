import 'package:flutter/material.dart';

class ConnectionHeader extends StatelessWidget {
  const ConnectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.router, color: Color(0xFF4FC3F7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tamavans IoT',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Conectado',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.greenAccent,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

