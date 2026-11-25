import 'dart:async';
import 'dart:convert';

import 'package:bellote_server/server_app.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('une carte légale unique est jouée sans action du client', () async {
    final server = await BelloteServer.start(host: '127.0.0.1', port: 0);
    addTearDown(server.close);

    final channel = WebSocketChannel.connect(server.wsUri);
    addTearDown(channel.sink.close);
    await channel.ready;
    final messages = StreamIterator<dynamic>(channel.stream);

    Future<Map<String, dynamic>> next({
      Set<String>? types,
      Duration timeout = const Duration(seconds: 30),
    }) async {
      while (
          await messages.moveNext().timeout(timeout, onTimeout: () => false)) {
        final raw = messages.current;
        if (raw is! String) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final message = Map<String, dynamic>.from(decoded);
        if (message['type'] == 'error') {
          fail('Server error: ${message['code']}');
        }
        if (types == null || types.contains(message['type'])) return message;
      }
      fail('WebSocket closed before the expected message');
    }

    void send(Map<String, dynamic> message) {
      channel.sink.add(jsonEncode(message));
    }

    Future<void> sendAction(Map<String, dynamic> message) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      send(message);
    }

    await next(types: {'hello'});
    send({'type': 'create', 'name': 'Autoplay', 'format': 'bestOf3'});
    await next(types: {'welcome'});
    for (var i = 0; i < 3; i++) {
      send({'type': 'addBot'});
    }

    var ready = false;
    for (var i = 0; i < 20; i++) {
      final message = await next(types: {'room'});
      final room = Map<String, dynamic>.from(message['room'] as Map);
      if (room['canStart'] == true) {
        ready = true;
        break;
      }
    }
    expect(ready, isTrue);

    send({'type': 'start'});
    var bidPlaced = false;

    for (var step = 0; step < 700; step++) {
      final message = await next(types: {'state'});
      final rawView = message['view'];
      if (rawView is! Map) continue;
      final view = Map<String, dynamic>.from(rawView);
      final phase = view['phase'];
      if (phase == 'dealComplete' ||
          phase == 'setComplete' ||
          phase == 'matchComplete') {
        break;
      }
      if (view['isMyTurn'] != true) continue;

      if (phase == 'bidding') {
        if (!bidPlaced && view['canBidNumbers'] == true) {
          await sendAction({
            'type': 'bid',
            'amount': view['minimumBid'],
            'suit': 'spades',
          });
          bidPlaced = true;
        } else if (view['canPass'] == true) {
          await sendAction({'type': 'pass'});
        }
        continue;
      }

      if (phase != 'playing') continue;
      final legal = view['legalCards'] as List? ?? const [];
      if (legal.isEmpty) fail('No legal card offered to the player');

      final seat = view['seat'] as int;
      final handCounts = Map<String, dynamic>.from(view['handCounts'] as Map);
      final before = handCounts['$seat'] as int;

      if (legal.length == 1) {
        // Aucun message n'est envoyé : le serveur doit jouer cette carte seul.
        var advanced = false;
        for (var wait = 0; wait < 25; wait++) {
          final nextState = await next(
            types: {'state'},
            timeout: const Duration(seconds: 5),
          );
          final nextView = Map<String, dynamic>.from(
            nextState['view'] as Map,
          );
          final nextCounts = Map<String, dynamic>.from(
            nextView['handCounts'] as Map,
          );
          if ((nextCounts['$seat'] as int) < before) {
            advanced = true;
            break;
          }
        }
        expect(advanced, isTrue, reason: 'La carte forcée n’a pas été jouée');
        return;
      }

      await sendAction({'type': 'play', 'card': legal.first});
    }

    fail('Aucun tour avec une seule carte légale n’est survenu');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
