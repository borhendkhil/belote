// Network smoke test: hosts a room with three bots on a running server and
// plays one complete deal through the real WebSocket protocol.
//
// Usage:
//   dart run tool/network_smoke.dart [ws://127.0.0.1:8080/ws]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main(List<String> args) async {
  final uri = args.isNotEmpty ? args.first : 'ws://127.0.0.1:8080/ws';
  stdout.writeln('Connecting to $uri ...');

  final channel = WebSocketChannel.connect(Uri.parse(uri));
  await channel.ready;
  final messages = StreamIterator<dynamic>(channel.stream);

  Future<Map<String, dynamic>> nextMessage({Set<String>? types}) async {
    while (await messages.moveNext().timeout(const Duration(seconds: 30))) {
      final raw = messages.current;
      if (raw is! String) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final message = Map<String, dynamic>.from(decoded);
      if (message['type'] == 'error') {
        throw StateError(
            'Server error: ${message['code']} ${message['message'] ?? ''}');
      }
      if (types == null || types.contains(message['type'])) return message;
    }
    throw StateError('WebSocket closed before the expected message');
  }

  void send(Map<String, dynamic> message) {
    channel.sink.add(jsonEncode(message));
  }

  Future<void> sendAction(Map<String, dynamic> message) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    send(message);
  }

  await nextMessage(types: {'hello'});
  send({'type': 'create', 'name': 'Réseau', 'format': 'bestOf3'});
  final welcome = await nextMessage(types: {'welcome'});
  final code = welcome['code'] as String;
  stdout.writeln('Room $code created, seat ${welcome['seat']}.');

  for (var i = 0; i < 3; i++) {
    send({'type': 'addBot'});
  }

  var room = <String, dynamic>{};
  for (var i = 0; i < 20; i++) {
    final message = await nextMessage(types: {'room'});
    room = Map<String, dynamic>.from(message['room'] as Map);
    if (room['canStart'] == true) break;
  }
  if (room['canStart'] != true) {
    throw StateError('Room never became ready to start');
  }
  stdout.writeln('Room full with bots, starting deal.');

  send({'type': 'start'});

  var bidPlaced = false;
  Map<String, dynamic>? finalView;
  for (var step = 0; step < 800; step++) {
    final message = await nextMessage();
    final rawView = message['view'];
    if (rawView is! Map) continue;
    final view = Map<String, dynamic>.from(rawView);
    final phase = view['phase'];

    if (phase == 'dealComplete' ||
        phase == 'setComplete' ||
        phase == 'matchComplete') {
      finalView = view;
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

    if (phase == 'playing') {
      final legal = view['legalCards'] as List? ?? const [];
      if (legal.isEmpty) throw StateError('No legal card offered');
      await sendAction({'type': 'play', 'card': legal.first});
      continue;
    }

    throw StateError('Unexpected phase while playing: $phase');
  }

  if (finalView == null) throw StateError('Deal did not complete');
  final result = finalView['result'] as Map?;
  final score = result?['score'] as Map?;
  stdout.writeln(
    'Deal complete after ${finalView['tricksPlayed']} tricks: '
    'contract ${result?['contract']}, '
    'attack ${score?['attackPoints']}, defense ${score?['defensePoints']}.',
  );
  if ((finalView['setScores'] as Map?)?.isEmpty ?? true) {
    throw StateError('Set scores were not reported');
  }

  send({'type': 'leave'});
  await channel.sink.close();
  stdout.writeln('Network smoke test passed.');
}
