import 'package:flutter/material.dart';
import '../providers/iot_provider.dart';

class ValveButton extends StatelessWidget {
  final int id;
  final IotProvider iot;

  const ValveButton({super.key, required this.id, required this.iot});

  @override
  Widget build(BuildContext context) {
    final bool isActive = iot.activeValveId == id;
    final bool isDisabled = iot.isValveLoading && !isActive;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFFFF9800) : const Color(0xFF263238),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isActive ? 8 : 2,
      ),
      onPressed: isDisabled || isActive ? null : () => _handlePress(context),
      child: isActive 
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text("${iot.valveCountdown}s", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          )
        : Text("VÁLVULA $id", style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _handlePress(BuildContext context) async {
    try {
      await iot.activateValve(id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al activar válvula $id: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
