import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bellote_engine/bellote_engine.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'room.dart';

/// Connexion cliente (un WebSocket).
class ClientConnection {
  ClientConnection(this.hub, this.channel) {
    _subscription = channel.stream.listen(
      _onData,
      onDone: _onDone,
      onError: (_) => _onDone(),
      cancelOnError: true,
    );
  }

  final Hub hub;
  final WebSocketChannel channel;
  StreamSubscription<dynamic>? _subscription;

  Room? room;
  int? seat;
  String? token;
  String? name;
  bool closed = false;
  DateTime lastActionAt = DateTime.fromMillisecondsSinceEpoch(0);

  void send(Map<String, dynamic> message) {
    if (closed) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (_) {
      close();
    }
  }

  void sendError(String code, {String? message, Object? details}) {
    send({
      'type': 'error',
      'code': code,
      if (message != null) 'message': message,
      if (details != null) 'details': details,
    });
  }

  void _onData(dynamic data) {
    if (closed) return;
    Object? decoded;
    try {
      if (data is String) {
        decoded = jsonDecode(data);
      } else if (data is List<int>) {
        decoded = jsonDecode(utf8.decode(data));
      }
    } catch (_) {
      sendError('invalid_json');
      return;
    }
    if (decoded is! Map) {
      sendError('invalid_message');
      return;
    }
    final message = Map<String, dynamic>.from(decoded);
    try {
      hub.handleMessage(this, message);
    } catch (error, stack) {
      // ignore: avoid_print
      print('Erreur message: $error\n$stack');
      sendError('internal_error');
    }
  }

  void _onDone() {
    if (closed) return;
    final room = this.room;
    closed = true;
    _subscription?.cancel();
    if (room != null) {
      room.onConnectionClosed(this);
    } else {
      channel.sink.close();
    }
  }

  void close() {
    if (closed) return;
    closed = true;
    _subscription?.cancel();
    try {
      channel.sink.close();
    } catch (_) {}
    final room = this.room;
    if (room != null) room.onConnectionClosed(this);
  }
}

/// Gestionnaire de salles.
class Hub {
  Hub();

  final Map<String, Room> rooms = {};
  final Random _random = Random.secure();
  Timer? _cleanupTimer;

  void startCleanup() {
    _cleanupTimer ??= Timer.periodic(const Duration(minutes: 10), (_) {
      final now = DateTime.now();
      rooms.removeWhere((code, room) {
        final stale =
            now.difference(room.lastActivityAt) > const Duration(hours: 2);
        final empty = room.humanConnectionCount == 0;
        return stale || (empty && room.started == false);
      });
    });
  }

  void stop() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    for (final room in rooms.values) {
      room.dispose();
    }
    rooms.clear();
  }

  String _newCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    while (true) {
      final buffer = StringBuffer();
      for (var i = 0; i < 5; i++) {
        buffer.write(alphabet[_random.nextInt(alphabet.length)]);
      }
      final code = buffer.toString();
      if (!rooms.containsKey(code)) return code;
    }
  }

  String newToken() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  void handleMessage(
      ClientConnection connection, Map<String, dynamic> message) {
    final type = message['type'];
    if (type is! String) {
      connection.sendError('invalid_message');
      return;
    }

    switch (type) {
      case 'create':
        _createRoom(connection, message);
      case 'join':
        _joinRoom(connection, message);
      case 'reconnect':
        _reconnect(connection, message);
      case 'ping':
        connection.send(
            {'type': 'pong', 'time': DateTime.now().millisecondsSinceEpoch});
      default:
        final room = connection.room;
        if (room == null) {
          connection.sendError('not_in_room');
          return;
        }
        room.handleClientMessage(connection, message);
    }
  }

  void _createRoom(ClientConnection connection, Map<String, dynamic> message) {
    if (connection.room != null) {
      connection.sendError('already_in_room');
      return;
    }
    final name = _cleanName(message['name']);
    if (name == null) {
      connection.sendError('invalid_name');
      return;
    }
    final format = _parseFormat(message['format']);
    final code = _newCode();
    final room = Room(
      hub: this,
      code: code,
      format: format,
    );
    rooms[code] = room;
    room.addHost(connection, name);
    connection.send({
      'type': 'welcome',
      'code': code,
      'token': connection.token,
      'seat': connection.seat,
      'format': format.name,
    });
    room.broadcastRoom();
    room.broadcastState();
  }

  void _joinRoom(ClientConnection connection, Map<String, dynamic> message) {
    if (connection.room != null) {
      connection.sendError('already_in_room');
      return;
    }
    final code = (message['code'] as String?)?.trim().toUpperCase();
    if (code == null || code.length != 5) {
      connection.sendError('invalid_room_code');
      return;
    }
    final token = message['token'] as String?;
    final room = rooms[code];
    if (room == null) {
      connection.sendError('room_not_found');
      return;
    }
    if (token != null && token.isNotEmpty) {
      final result = room.reconnect(connection, token);
      if (result == ReconnectResult.ok) return;
      connection.sendError(
        result == ReconnectResult.abandoned
            ? 'session_closed'
            : 'invalid_token',
      );
      return;
    }
    final name = _cleanName(message['name']);
    if (name == null) {
      connection.sendError('invalid_name');
      return;
    }
    final seat = room.join(connection, name);
    if (seat == null) {
      connection.sendError(room.started ? 'room_started' : 'room_full');
      return;
    }
    connection.send({
      'type': 'welcome',
      'code': code,
      'token': connection.token,
      'seat': connection.seat,
      'format': room.format.name,
    });
    room.broadcastRoom();
    room.broadcastState();
  }

  void _reconnect(ClientConnection connection, Map<String, dynamic> message) {
    if (connection.room != null) {
      connection.sendError('already_in_room');
      return;
    }
    final code = (message['code'] as String?)?.trim().toUpperCase();
    final token = message['token'] as String?;
    if (code == null || code.length != 5 || token == null) {
      connection.sendError('invalid_room_code');
      return;
    }
    final room = rooms[code];
    if (room == null) {
      connection.sendError('room_not_found');
      return;
    }
    final result = room.reconnect(connection, token);
    if (result != ReconnectResult.ok) {
      connection.sendError(
        result == ReconnectResult.abandoned
            ? 'session_closed'
            : 'invalid_token',
      );
      return;
    }
    connection.send({
      'type': 'welcome',
      'code': code,
      'token': token,
      'seat': connection.seat,
      'format': room.format.name,
    });
    room.broadcastRoom();
    room.broadcastState();
  }

  static String? _cleanName(Object? value) {
    if (value is! String) return null;
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty || name.length > 20) return null;
    return name;
  }

  static MatchFormat _parseFormat(Object? value) {
    switch (value) {
      case 'bestOf5':
        return MatchFormat.bestOf5;
      case 'singleSet':
        return MatchFormat.singleSet;
      default:
        return MatchFormat.bestOf3;
    }
  }
}
