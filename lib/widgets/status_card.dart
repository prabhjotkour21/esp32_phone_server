import 'package:flutter/material.dart';

/// A small card widget that shows the server status (Running / Stopped)
/// with a coloured indicator dot.
class StatusCard extends StatelessWidget {
  final bool isRunning;

  const StatusCard({super.key, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? Colors.green : Colors.red;
    final label = isRunning ? 'Running' : 'Stopped';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Coloured indicator dot
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                // Pulsing glow effect when running
                boxShadow: isRunning
                    ? [BoxShadow(color: color.withAlpha(120), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Server Status: ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
