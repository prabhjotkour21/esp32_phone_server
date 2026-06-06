import 'dart:io';

/// Simple terminal logger (shared across services)
void logInfo(String tag, String msg) {
  final t = DateTime.now();
  final time =
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:${t.second.toString().padLeft(2,'0')}';
  // ignore: avoid_print
  print('[$time] $tag $msg');
}

/// Fetches network information about the current device.
/// Uses dart:io — no external packages needed.
class NetworkService {
  /// Returns the first non-loopback IPv4 address found on any network
  /// interface, or null if the device is not connected to a network.
  ///
  /// How it works:
  /// 1. [NetworkInterface.list] returns all network adapters (WiFi, Ethernet, etc.)
  /// 2. We filter out loopback (127.0.0.1) since that is not reachable by ESP32
  /// 3. We pick the first IPv4 address (InternetAddressType.IPv4)
  ///
  /// On Android/iOS this will return the WiFi IP when connected to WiFi.
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            logInfo('📶 NETWORK', 'Phone IP detected: ${addr.address}  (interface: ${interface.name})');
            return addr.address;
          }
        }
      }
      logInfo('⚠️  NETWORK', 'No WiFi IP found — is the phone connected to WiFi?');
      return null;
    } catch (e) {
      logInfo('❌ NETWORK', 'Error fetching IP: $e');
      return null;
    }
  }
}
