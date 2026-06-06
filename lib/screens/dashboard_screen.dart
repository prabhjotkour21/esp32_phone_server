import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../models/wifi_config.dart';
import '../screens/wifi_config_screen.dart';
import '../services/http_server_service.dart';
import '../services/network_service.dart';
import '../widgets/status_card.dart';
import '../widgets/esp32_status_card.dart';

/// DashboardScreen
///
/// The main screen of the app. Responsibilities:
///   1. Display the phone's local IP address and server port.
///   2. Start / stop the HTTP server.
///   3. Show received messages and a running log.
///   4. Display the currently saved WiFi config (SSID + password status).
///   5. Provide a settings icon that opens [WiFiConfigScreen].
///
/// STATE MANAGEMENT:
///   Plain setState() for server/message state.
///   [wifiConfigNotifier] (ValueNotifier) drives the WiFi card so it updates
///   the moment the user saves credentials on the WiFi Config tab.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Services ───────────────────────────────────────────────────────────────
  final _serverService = HttpServerService();

  // ── State ──────────────────────────────────────────────────────────────────
  String _localIp = 'Fetching…';
  bool _serverRunning = false;
  String? _errorMessage;
  MessageModel? _lastMessage;
  final List<MessageModel> _messageLog = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchIpAddress();
  }

  @override
  void dispose() {
    _serverService.stop();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _fetchIpAddress() async {
    final ip = await NetworkService.getLocalIpAddress();
    if (mounted) {
      setState(() => _localIp = ip ?? 'Not connected to WiFi');
    }
  }

  void _onMessageReceived(MessageModel message) {
    setState(() {
      _lastMessage = message;
      _messageLog.insert(0, message);
    });
  }

  Future<void> _startServer() async {
    setState(() => _errorMessage = null);
    try {
      await _serverService.start(_onMessageReceived);
      setState(() => _serverRunning = true);
    } on SocketException catch (e) {
      final msg = 'Socket error: ${e.message} (port ${HttpServerService.port})';
      // ignore: avoid_print
      print('[ERROR] $msg');
      setState(() => _errorMessage = msg);
    } on Exception catch (e) {
      // ignore: avoid_print
      print('[ERROR] Failed to start server: $e');
      setState(() => _errorMessage = 'Failed to start server: $e');
    }
  }

  Future<void> _stopServer() async {
    await _serverService.stop();
    setState(() => _serverRunning = false);
  }

  void _simulateMessage() {
    _onMessageReceived(MessageModel(
      text: 'Hello from simulated ESP32! 🤖',
      receivedAt: DateTime.now(),
      source: 'Simulated',
    ));
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

  /// Opens [WiFiConfigScreen] as a push route (from the settings icon).
  /// Using push instead of switching the bottom-nav tab keeps it accessible
  /// from the AppBar regardless of which tab is active.
  void _openWifiConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WiFiConfigScreen()),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Phone Server'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_messageLog.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear message log',
              onPressed: _clearLog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh IP address',
            onPressed: _fetchIpAddress,
          ),
          // ── Settings / WiFi Config shortcut ──────────────────────────────
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'WiFi Configuration',
            onPressed: _openWifiConfig,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Server status card ─────────────────────────────────────────
          StatusCard(isRunning: _serverRunning),
          const SizedBox(height: 12),

          // ── WiFi Config summary card ─────────────────────────────────
          ValueListenableBuilder<WifiConfig>(
            valueListenable: wifiConfigNotifier,
            builder: (_, config, __) => _WifiConfigCard(
              config: config,
              onEdit: _openWifiConfig,
            ),
          ),
          const SizedBox(height: 12),

          // ── ESP32 live connection status ──────────────────────────────
          ValueListenableBuilder<String?>(
            valueListenable: esp32IpNotifier,
            builder: (_, ip, __) => Esp32StatusCard(
              esp32Ip: ip,
              serverRunning: _serverRunning,
            ),
          ),
          const SizedBox(height: 12),

          // ── Network info ───────────────────────────────────────────────
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
                  onCopy: () => _copyToClipboard('${HttpServerService.port}'),
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.link,
                  label: 'Endpoint',
                  value: 'POST /',
                  onCopy: _localIp.contains('.')
                      ? () => _copyToClipboard(
                          'http://$_localIp:${HttpServerService.port}/')
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Error message ──────────────────────────────────────────────
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

          // ── Server controls ────────────────────────────────────────────
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

          // ── Last received message ──────────────────────────────────────
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

          // ── Message log ────────────────────────────────────────────────
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
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _messageLog.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _MessageTile(message: _messageLog[i]),
                  ),
          ),
          const SizedBox(height: 24),

          // ── ESP32 quick reference ──────────────────────────────────────
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
                      'http.begin("http://$_localIp:${HttpServerService.port}/");\n'
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── WiFi Config Card ──────────────────────────────────────────────────────────

/// Shows the currently saved WiFi credentials on the Dashboard.
/// Rebuilds automatically via [ValueListenableBuilder] whenever the user
/// saves new credentials on the WiFi Config screen.
class _WifiConfigCard extends StatelessWidget {
  final WifiConfig config;
  final VoidCallback onEdit;

  const _WifiConfigCard({required this.config, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final configured = config.isComplete;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: configured ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  configured ? Icons.wifi : Icons.wifi_off,
                  size: 18,
                  color: configured
                      ? Colors.green.shade600
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'WiFi Configuration',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(configured ? 'Edit' : 'Configure'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (configured) ...[
              _ConfigRow(
                icon: Icons.wifi,
                label: 'SSID',
                value: config.ssid,
              ),
              const SizedBox(height: 4),
              _ConfigRow(
                icon: Icons.lock_outline,
                label: 'Password',
                value: config.hasPassword ? 'Configured ✓' : 'Not set',
                valueColor:
                    config.hasPassword ? Colors.green.shade700 : Colors.red,
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'No WiFi credentials configured yet.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.orange.shade800),
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

class _ConfigRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ConfigRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reusable section widgets ──────────────────────────────────────────────────

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
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

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
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
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

class _MessageTile extends StatelessWidget {
  final MessageModel message;
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isSimulated ? Colors.orange.shade100 : Colors.green.shade100,
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
                Text(message.text, style: const TextStyle(fontSize: 14)),
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
