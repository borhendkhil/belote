import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'hub.dart';

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Middleware _cors() {
  return (inner) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await inner(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

/// Serveur HTTP/WebSocket prêt à l'emploi.
class BelloteServer {
  BelloteServer._(this.hub, this._server);

  final Hub hub;
  final HttpServer _server;

  InternetAddress get address => _server.address;
  int get port => _server.port;

  Uri get wsUri => Uri.parse('ws://127.0.0.1:$port/ws');

  static Future<BelloteServer> start({
    String host = '0.0.0.0',
    int port = 8080,
  }) async {
    final hub = Hub()..startCleanup();

    final wsHandler = webSocketHandler(
      (WebSocketChannel channel, String? protocol) {
        final connection = ClientConnection(hub, channel);
        connection.send({
          'type': 'hello',
          'version': 1,
          'serverTime': DateTime.now().millisecondsSinceEpoch,
        });
      },
      pingInterval: const Duration(seconds: 30),
    );

    Response httpHandler(Request request) {
      if (request.url.path == 'health') {
        return Response.ok(
          jsonEncode({
            'status': 'ok',
            'rooms': hub.rooms.length,
            'serverTime': DateTime.now().toIso8601String(),
          }),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return Response.ok(
        'Belote contrée tunisienne — serveur autoritaire\n'
        'WebSocket: /ws\n'
        'Santé: /health\n',
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }

    Future<Response> handler(Request request) async {
      if (request.url.path == 'ws') {
        return wsHandler(request);
      }
      return httpHandler(request);
    }

    final pipeline =
        const Pipeline().addMiddleware(_cors()).addHandler(handler);

    final server = await shelf_io.serve(pipeline, host, port);
    server.autoCompress = true;
    return BelloteServer._(hub, server);
  }

  Future<void> close() async {
    hub.stop();
    await _server.close(force: true);
  }
}
