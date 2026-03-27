import 'package:flutter/material.dart';

class ConnectionHeader extends StatelessWidget {
  const ConnectionHeader({
    super.key,
    required this.serverIp,
    required this.isConnected,
  });

  final String serverIp;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planta hidráulica principal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConnected
                        ? 'Conectado a $serverIp'
                        : 'Sin conexión con $serverIp',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
