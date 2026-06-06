import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wifi_config.dart';
import '../services/wifi_config_service.dart';
import '../services/network_service.dart';
import '../services/http_server_service.dart';

/// Shared notifier — seeded at startup, updated on every save.
final wifiConfigNotifier = ValueNotifier<WifiConfig>(
  const WifiConfig(ssid: '', password: ''),
);

Future<void> loadSavedWifiConfig() async {
  final config = await WifiConfigService().load();
  wifiConfigNotifier.value = config;
}

// ─────────────────────────────────────────────────────────────────────────────

class WiFiConfigScreen extends StatefulWidget {
  const WiFiConfigScreen({super.key});

  @override
  State<WiFiConfigScreen> createState() => _WiFiConfigScreenState();
}

class _WiFiConfigScreenState extends State<WiFiConfigScreen> {
  final _service = WifiConfigService();
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSaving = false;
  bool _savedOnce = false;
  String _phoneIp = 'Fetching...';

  @override
  void initState() {
    super.initState();
    final current = wifiConfigNotifier.value;
    _ssidController.text = current.ssid;
    _passwordController.text = current.password;
    if (current.isComplete) _savedOnce = true;
    _loadPhoneIp();
  }

  Future<void> _loadPhoneIp() async {
    final ip = await NetworkService.getLocalIpAddress();
    if (mounted) setState(() => _phoneIp = ip ?? 'Not connected to WiFi');
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final config = WifiConfig(
      ssid: _ssidController.text.trim(),
      password: _passwordController.text,
    );
    await _service.save(config);
    wifiConfigNotifier.value = config;

    if (mounted) {
      setState(() {
        _isSaving = false;
        _savedOnce = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WiFi credentials saved ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear credentials?'),
        content: const Text(
            'This will remove the saved SSID and password from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _service.clear();
    wifiConfigNotifier.value = const WifiConfig(ssid: '', password: '');
    if (mounted) {
      _ssidController.clear();
      _passwordController.clear();
      setState(() => _savedOnce = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Credentials cleared')));
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_savedOnce)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear saved credentials',
              onPressed: _clear,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Info banner ──────────────────────────────────────────────
              _InfoBanner(
                icon: Icons.info_outline,
                color: Colors.blue,
                text: 'Enter the WiFi credentials your ESP32 will use.\n'
                    'These are stored on this device for reference when '
                    'setting up the ESP32 via its Captive Portal.',
              ),
              const SizedBox(height: 24),

              // ── SSID ─────────────────────────────────────────────────────
              TextFormField(
                controller: _ssidController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'WiFi SSID',
                  hintText: 'e.g. MyHomeNetwork',
                  prefixIcon: Icon(Icons.wifi),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'SSID cannot be empty'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Password ─────────────────────────────────────────────────
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'WiFi Password',
                  hintText: 'Enter password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Password cannot be empty'
                    : null,
              ),
              const SizedBox(height: 28),

              // ── Save button ───────────────────────────────────────────────
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving…' : 'Save Credentials'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 24),

              // ── ESP32 Captive Portal helper ───────────────────────────────
              // Shows Phone IP + Port with copy buttons so user can paste
              // directly into the ESP32C3_Auto_AP captive portal fields.
              _CaptivePortalHelper(
                phoneIp: _phoneIp,
                port: HttpServerService.port,
                onCopy: _copyToClipboard,
              ),

              // ── Saved credentials summary ─────────────────────────────────
              if (_savedOnce) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                _SavedSummary(
                  ssid: wifiConfigNotifier.value.ssid,
                  passwordLength: wifiConfigNotifier.value.password.length,
                ),
                const SizedBox(height: 20),
                _InfoBanner(
                  icon: Icons.code,
                  color: Colors.orange,
                  text: 'ESP32 firmware reference:\n\n'
                      'const char* ssid     = "${wifiConfigNotifier.value.ssid}";\n'
                      'const char* password = "YOUR_PASSWORD";',
                  monospace: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Captive Portal Helper ─────────────────────────────────────────────────────

/// Card that shows the phone IP and server port with one-tap copy buttons.
/// The user opens ESP32's hotspot (ESP32C3_Auto_AP), goes to the captive
/// portal, and pastes these two values into "Target Server IP" and
/// "Target Server Port" fields.
class _CaptivePortalHelper extends StatelessWidget {
  final String phoneIp;
  final int port;
  final void Function(String value, String label) onCopy;

  const _CaptivePortalHelper({
    required this.phoneIp,
    required this.port,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final hasIp = phoneIp.contains('.');

    return Container(
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.router, size: 18, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              Text(
                'ESP32 Captive Portal Values',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.purple.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Connect phone to "ESP32C3_Auto_AP" hotspot → open browser → '
            'paste these values in the portal form.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),

          // ── Target Server IP row ──────────────────────────────────────
          _PortalRow(
            label: 'Target Server IP',
            value: hasIp ? phoneIp : 'Connect to WiFi first',
            canCopy: hasIp,
            onCopy: () => onCopy(phoneIp, 'Phone IP'),
          ),
          const SizedBox(height: 10),

          // ── Target Server Port row ────────────────────────────────────
          _PortalRow(
            label: 'Target Server Port',
            value: '$port',
            canCopy: true,
            onCopy: () => onCopy('$port', 'Port'),
          ),
        ],
      ),
    );
  }
}

class _PortalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool canCopy;
  final VoidCallback onCopy;

  const _PortalRow({
    required this.label,
    required this.value,
    required this.canCopy,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: canCopy ? Colors.purple.shade900 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        if (canCopy)
          ElevatedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade100,
              foregroundColor: Colors.purple.shade900,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
      ],
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final MaterialColor color;
  final String text;
  final bool monospace;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontFamily: monospace ? 'monospace' : null,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedSummary extends StatelessWidget {
  final String ssid;
  final int passwordLength;

  const _SavedSummary({required this.ssid, required this.passwordLength});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved Credentials',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _LabelValue(label: 'SSID', value: ssid),
        const SizedBox(height: 6),
        _LabelValue(
          label: 'Password',
          value: passwordLength > 0
              ? '●' * passwordLength.clamp(0, 12)
              : '(not set)',
        ),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ),
      ],
    );
  }
}
