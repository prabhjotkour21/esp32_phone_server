/// Represents a single message received from the ESP32 device (or simulated).
class MessageModel {
  final String text;
  final DateTime receivedAt;
  final String source;    // 'ESP32' or 'Simulated'
  final String? senderIp; // ESP32's IP address — null for simulated messages

  const MessageModel({
    required this.text,
    required this.receivedAt,
    required this.source,
    this.senderIp,
  });

  String get formattedTime {
    final h = receivedAt.hour.toString().padLeft(2, '0');
    final m = receivedAt.minute.toString().padLeft(2, '0');
    final s = receivedAt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
