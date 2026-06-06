import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';

typedef OnMessageReceived = void Function(MessageModel message);

// ── Terminal logger ───────────────────────────────────────────────────────────

void _log(String tag, String msg) {
  final t = DateTime.now();
  final time =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  // ignore: avoid_print
  print('[$time] $tag $msg');
}

// ── Shared notifier ───────────────────────────────────────────────────────────

/// Holds the last seen ESP32 IP address.
/// Updated on every incoming POST so DashboardScreen can show it live
/// via ValueListenableBuilder without any extra state-management library.
final esp32IpNotifier = ValueNotifier<String?>( null);

// ─────────────────────────────────────────────────────────────────────────────

class HttpServerService {
  static const int port = 3000;

  HttpServer? _server;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start(OnMessageReceived onMessageReceived) async {
    if (_isRunning) return;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _isRunning = true;

    _log('🟢 SERVER', 'Started — listening on 0.0.0.0:$port');
    _log('🟢 SERVER', 'ESP32 Captive Portal → Target IP   = <this phone IP>');
    _log('🟢 SERVER', 'ESP32 Captive Portal → Target Port = $port');
    _log('🟢 SERVER', 'Waiting for ESP32 to connect...');

    _server!.listen(
      (HttpRequest req) => _handleRequest(req, onMessageReceived),
      onError: (e) => _log('❌ SERVER', 'Socket error: $e'),
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    esp32IpNotifier.value = null;
    _log('🔴 SERVER', 'Stopped — port $port released');
  }

  Future<void> _handleRequest(
    HttpRequest request,
    OnMessageReceived onMessageReceived,
  ) async {
    final from = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final method = request.method;
    final path = request.uri.path;

    // Track ESP32 IP — update notifier so UI shows it immediately
    if (esp32IpNotifier.value != from) {
      esp32IpNotifier.value = from;
      _log('📍 ESP32 IP', 'New device seen: $from');
    }

    _log('📡 REQUEST', '$method $path  ← from $from');

    request.response.headers.add('Access-Control-Allow-Origin', '*');

    if (method == 'POST' && path == '/') {
      await _handlePost(request, onMessageReceived, from);
    } else if (method == 'OPTIONS') {
      _log('🔄 PREFLIGHT', 'CORS preflight from $from — responded 200');
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } else {
      _log('⚠️  UNKNOWN', '$method $path from $from — responded 404');
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      await request.response.close();
    }
  }

  Future<void> _handlePost(
    HttpRequest request,
    OnMessageReceived onMessageReceived,
    String from,
  ) async {
    try {
      final bodyBytes = await request.fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );
      final body = utf8.decode(bodyBytes).trim();

      if (body.isEmpty) {
        _log('⚠️  EMPTY', 'Empty body from $from — responded 400');
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Body cannot be empty');
        await request.response.close();
        return;
      }

      _log('✅ MESSAGE', 'From $from → "$body"');

      onMessageReceived(MessageModel(
        text: body,
        receivedAt: DateTime.now(),
        source: 'ESP32',
        senderIp: from,
      ));

      _log('↩️  REPLY  ', 'HTTP 200 OK → $from');
      request.response
        ..statusCode = HttpStatus.ok
        ..write('OK');
    } catch (e) {
      _log('❌ ERROR  ', 'Exception: $e');
      request.response.statusCode = HttpStatus.internalServerError;
    } finally {
      await request.response.close();
    }
  }
}
