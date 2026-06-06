/// Holds the WiFi credentials used by the ESP32.
///
/// This is a plain immutable data class — no JSON needed because
/// [WifiConfigService] stores each field individually in SharedPreferences.
class WifiConfig {
  final String ssid;
  final String password;

  const WifiConfig({
    required this.ssid,
    required this.password,
  });

  bool get hasPassword => password.isNotEmpty;

  /// Returns true when both fields are non-empty.
  bool get isComplete => ssid.isNotEmpty && password.isNotEmpty;

  WifiConfig copyWith({String? ssid, String? password}) => WifiConfig(
        ssid: ssid ?? this.ssid,
        password: password ?? this.password,
      );

  @override
  String toString() => 'WifiConfig(ssid: $ssid, hasPassword: $hasPassword)';
}
