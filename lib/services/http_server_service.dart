import 'dart:io';
import 'dart:convert';
import '../models/message_model.dart';

/// Callback type invoked whenever a new message arrives at POST /send-text.
typedef OnMessageReceived = void Function(MessageModel message);

/// Manages the lifecycle of the local HTTP server running inside the app.
///
/// How it works:
/// - [HttpServer.bind] binds to all network interfaces (0.0.0.0) on [port].
///   This means the phone listens on every network adapter, including WiFi,
///   so the ESP32 on the same LAN can reach it.
/// - For every incoming [HttpRequest] we check the method and path, read the
///   body, create a [MessageModel] and fire [onMessageReceived].
/// - The server runs as an async loop; we keep a reference to cancel it on stop.
class HttpServerService {
  static const int port = 3000;

  HttpServer? _server;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Starts the HTTP server and registers the [onMessageReceived] callback.
  /// Throws a [SocketException] if the port is already in use.
  Future<void> start(OnMessageReceived onMessageReceived) async {
    if (_isRunning) return;

    // Bind to all interfaces so both WiFi and USB-tethered connections work.
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _isRunning = true;

    // Listen for requests without await so the UI is not blocked.
    _server!.listen(
      (HttpRequest request) => _handleRequest(request, onMessageReceived),
      onError: (_) {}, // Silently ignore socket-level errors
      cancelOnError: false,
    );
  }

  /// Stops the server and frees the port.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  /// Routes incoming requests to the correct handler.
  Future<void> _handleRequest(
    HttpRequest request,
    OnMessageReceived onMessageReceived,
  ) async {
    // Add CORS headers so browser-based test tools (e.g. Postman web) work.
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    if (request.method == 'POST' && request.uri.path == '/send-text') {
      await _handleSendText(request, onMessageReceived);
    } else if (request.method == 'OPTIONS') {
      // Preflight request — respond OK
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } else {
      // Any other route returns 404
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      await request.response.close();
    }
  }

  /// Handles POST /send-text
  ///
  /// The ESP32 sends a plain text body, e.g.:
  ///   POST http://192.168.1.x:3000/send-text
  ///   Content-Type: text/plain
  ///   Body: Hello from ESP32!
  ///
  /// We read the body, validate it is not empty, create a [MessageModel]
  /// and invoke [onMessageReceived] so the UI can update via setState.
  Future<void> _handleSendText(
    HttpRequest request,
    OnMessageReceived onMessageReceived,
  ) async {
    try {
      // Collect all body bytes and decode as UTF-8 string
      final bodyBytes = await request.fold<List<int>>(
        [],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes).trim();

      if (body.isEmpty) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Body cannot be empty');
        await request.response.close();
        return;
      }

      // Build the message and notify the UI
      final message = MessageModel(
        text: body,
        receivedAt: DateTime.now(),
        source: 'ESP32',
      );
      onMessageReceived(message);

      // Acknowledge the ESP32
      request.response
        ..statusCode = HttpStatus.ok
        ..write('OK');
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
    } finally {
      await request.response.close();
    }
  }
}
