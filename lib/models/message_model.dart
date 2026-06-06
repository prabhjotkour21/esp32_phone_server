/// Represents a single message received from the ESP32 device (or simulated).
class MessageModel {
  final String text;
  final DateTime receivedAt;
  final String source; // 'ESP32' or 'Simulated'

  const MessageModel({
    required this.text,
    required this.receivedAt,
    required this.source,
  });

  /// Returns a formatted timestamp string for display in the UI.
  String get formattedTime {
    final h = receivedAt.hour.toString().padLeft(2, '0');
    final m = receivedAt.minute.toString().padLeft(2, '0');
    final s = receivedAt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
