import 'package:shared_preferences/shared_preferences.dart';
import '../models/wifi_config.dart';

/// Persists and loads [WifiConfig] using [SharedPreferences].
///
/// Keys are kept as private constants so they are never mistyped elsewhere.
/// All public methods are async and null-safe.
class WifiConfigService {
  static const _keySSID = 'wifi_ssid';
  static const _keyPassword = 'wifi_password';

  /// Saves [config] to SharedPreferences.
  /// Both fields are written atomically (back-to-back awaits on the same
  /// prefs instance) to avoid a partial-save state.
  Future<void> save(WifiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySSID, config.ssid);
    await prefs.setString(_keyPassword, config.password);
  }

  /// Loads the previously saved [WifiConfig].
  /// Returns a config with empty strings when nothing has been saved yet.
  Future<WifiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WifiConfig(
      ssid: prefs.getString(_keySSID) ?? '',
      password: prefs.getString(_keyPassword) ?? '',
    );
  }

  /// Clears all saved WiFi credentials.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySSID);
    await prefs.remove(_keyPassword);
  }
}
