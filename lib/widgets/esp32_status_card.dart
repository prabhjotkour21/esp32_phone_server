import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows whether an ESP32 has connected since the server was started.
///
/// [esp32Ip] is null  → "Not connected yet"
/// [esp32Ip] has value → shows IP with green indicator
///
/// Driven by [esp32IpNotifier] via ValueListenableBuilder in DashboardScreen,
/// so it rebuilds the instant the first POST arrives from the ESP32.
class Esp32StatusCard extends StatelessWidget {
  final String? esp32Ip;
  final bool serverRunning;

  const Esp32StatusCard({
    super.key,
    required this.esp32Ip,
    required this.serverRunning,
  });

  void _copyIp(BuildContext context, String ip) {
    Clipboard.setData(ClipboardData(text: ip));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ESP32 IP copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = esp32Ip != null;

    // Color scheme based on connection state
    final borderColor =
        connected ? Colors.green.shade300 : Colors.grey.shade300;
    final bgColor =
        connected ? Colors.green.shade50 : Colors.grey.shade50;
    final dotColor =
        connected ? Colors.green : (serverRunning ? Colors.orange : Colors.grey);
    final titleColor =
        connected ? Colors.green.shade800 : Colors.grey.shade700;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Animated pulsing dot
            _PulseDot(color: dotColor, active: connected),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected ? 'ESP32 Connected' : 'ESP32 Not Connected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    connected
                        ? 'Last seen from IP: $esp32Ip'
                        : serverRunning
                            ? 'Server is running — waiting for ESP32...'
                            : 'Start the server first',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontFamily: connected ? 'monospace' : null,
                    ),
                  ),
                ],
              ),
            ),

            // Copy IP button — only when connected
            if (connected)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy ESP32 IP',
                onPressed: () => _copyIp(context, esp32Ip!),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small colored dot that scales up/down when [active] is true,
/// giving a subtle "live" pulse effect using AnimatedContainer.
class _PulseDot extends StatefulWidget {
  final Color color;
  final bool active;

  const _PulseDot({required this.color, required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
