import 'package:flutter/material.dart';

class ValveButton extends StatelessWidget {
  const ValveButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.isDisabled,
    required this.remainingSeconds,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final bool isDisabled;
  final int remainingSeconds;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isDisabled || isActive ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: isActive ? const Color(0xFFFF9800) : null,
      ),
      child: isActive
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('$label · ${remainingSeconds}s'),
              ],
            )
          : Text(label),
    );
  }
}
