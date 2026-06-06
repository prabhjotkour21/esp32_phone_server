import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../services/http_server_service.dart';
import '../services/network_service.dart';
import '../widgets/status_card.dart';

/// DashboardScreen
///
/// The main screen of the app. It is responsible for:
///   1. Displaying the phone's local IP address and server port.
///   2. Starting / stopping the HTTP server.
///   3. Showing received messages and a running log.
///
/// STATE MANAGEMENT:
///   All state lives in [_DashboardScreenState] and is updated with
///   setState(). There is no Provider, Riverpod, or Bloc — just plain Flutter.
///
/// HOW THE SERVER CALLBACK REACHES THE UI:
///   [HttpServerService.start] accepts a callback [_onMessageReceived].
///   When the server's listen loop fires (background async), the callback
///   calls setState(), which schedules a rebuild on the main isolate.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  final _serverService = HttpServerService();

  // ── State fields ──────────────────────────────────────────────────────────
  String _localIp = 'Fetching...';
  bool _serverRunning = false;
  String? _errorMessage;

  /// The most recently received message (shown prominently at the top).
  MessageModel? _lastMessage;

  /// All messages received since the app was opened (newest first).
  final List<MessageModel> _messageLog = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchIpAddress();
  }

  @override
  void dispose() {
    // Always stop the server when the widget is removed to free the port.
    _serverService.stop();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _fetchIpAddress() async {
    final ip = await NetworkService.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _localIp = ip ?? 'Not connected to WiFi';
      });
    }
  }

  /// Called by the HTTP server (on the main isolate via setState) whenever
  /// a valid POST /send-text request arrives.
  void _onMessageReceived(MessageModel message) {
    // setState guarantees the UI rebuilds with the new message.
    setState(() {
      _lastMessage = message;
      _messageLog.insert(0, message); // newest first
    });
  }

  Future<void> _startServer() async {
    setState(() => _errorMessage = null);
    try {
      await _serverService.start(_onMessageReceived);
      setState(() => _serverRunning = true);
    } on Exception catch (e) {
      setState(() => _errorMessage = 'Failed to start server: $e');
    }
  }

  Future<void> _stopServer() async {
    await _serverService.stop();
    setState(() => _serverRunning = false);
  }

  /// Simulates a message from the ESP32 — useful for testing the UI
  /// without needing real hardware.
  void _simulateMessage() {
    _onMessageReceived(
      MessageModel(
        text: 'Hello from simulated ESP32! 🤖',
        receivedAt: DateTime.now(),
        source: 'Simulated',
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _clearLog() {
    setState(() {
      _messageLog.clear();
      _lastMessage = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Phone Server'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Clear log button
          if (_messageLog.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear message log',
              onPressed: _clearLog,
            ),
          // Refresh IP button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh IP address',
            onPressed: _fetchIpAddress,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status card ──────────────────────────────────────────────────
          StatusCard(isRunning: _serverRunning),
          const SizedBox(height: 12),

          // ── Network info ─────────────────────────────────────────────────
          _SectionCard(
            title: 'Network Info',
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.phone_android,
                  label: 'Phone IP',
                  value: _localIp,
                  onCopy: _localIp.contains('.')
                      ? () => _copyToClipboard(_localIp)
                      : null,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.router,
                  label: 'Server Port',
                  value: '${HttpServerService.port}',
                  onCopy: () =>
                      _copyToClipboard('${HttpServerService.port}'),
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.link,
                  label: 'Endpoint',
                  value: 'POST /send-text',
                  onCopy: _localIp.contains('.')
                      ? () => _copyToClipboard(
                          'http://$_localIp:${HttpServerService.port}/send-text')
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Error message ─────────────────────────────────────────────────
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
            ),

          // ── Server controls ───────────────────────────────────────────────
          _SectionCard(
            title: 'Server Controls',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _serverRunning ? null : _startServer,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _serverRunning ? _stopServer : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                // Testing helper button — simulates a message from the ESP32
                OutlinedButton.icon(
                  onPressed: _simulateMessage,
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Simulate ESP32 Message'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Last received message ─────────────────────────────────────────
          _SectionCard(
            title: 'Last Received Message',
            child: _lastMessage == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No messages yet.\nStart the server and send a POST request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : _MessageTile(message: _lastMessage!, highlight: true),
          ),
          const SizedBox(height: 12),

          // ── Message log ───────────────────────────────────────────────────
          _SectionCard(
            title: 'Message Log (${_messageLog.length})',
            child: _messageLog.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Log is empty.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    // Nested ListView inside a scrollable parent requires
                    // shrinkWrap + NeverScrollableScrollPhysics
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _messageLog.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) =>
                        _MessageTile(message: _messageLog[index]),
                  ),
          ),

          const SizedBox(height: 24),

          // ── Quick reference for ESP32 developers ─────────────────────────
          _SectionCard(
            title: 'ESP32 Quick Reference',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use this snippet in your ESP32 Arduino sketch:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'HTTPClient http;\n'
                      'http.begin("http://$_localIp:${HttpServerService.port}/send-text");\n'
                      'http.addHeader("Content-Type", "text/plain");\n'
                      'int code = http.POST("Hello from ESP32!");\n'
                      'http.end();',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

/// A card with a title and arbitrary child content.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// A row showing an icon, label, value, and optional copy button.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

/// Displays a single [MessageModel] in the log list.
class _MessageTile extends StatelessWidget {
  final MessageModel message;

  /// When true, renders with a slightly highlighted background (used for the
  /// "last message" section).
  final bool highlight;

  const _MessageTile({required this.message, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final isSimulated = message.source == 'Simulated';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: highlight ? Colors.blue.shade50 : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSimulated
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              message.source,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSimulated
                    ? Colors.orange.shade800
                    : Colors.green.shade800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  message.formattedTime,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
