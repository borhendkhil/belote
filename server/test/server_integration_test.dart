import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bellote_server/server_app.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('health endpoint reports the server as ready', () async {
    final server = await BelloteServer.start(host: '127.0.0.1', port: 0);
    addTearDown(server.close);

    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/health'),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(response.statusCode, 200);
    expect(json['status'], 'ok');
    expect(json['rooms'], 0);
  });

  test('a player who leaves after the start cannot rejoin', () async {
    final server = await BelloteServer.start(host: '127.0.0.1', port: 0);
    addTearDown(server.close);

    final channel = WebSocketChannel.connect(server.wsUri);
    await channel.ready;
    final messages = StreamIterator<dynamic>(channel.stream);

    Future<Map<String, dynamic>> next({Set<String>? types}) async {
      while (await messages.moveNext().timeout(const Duration(seconds: 20))) {
        final raw = messages.current;
        if (raw is! String) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final message = Map<String, dynamic>.from(decoded);
        expect(message['type'], isNot('error'), reason: '${message['code']}');
        if (types == null || types.contains(message['type'])) return message;
      }
      fail('WebSocket closed before the expected message');
    }

    await next(types: {'hello'});
    channel.sink.add(
      jsonEncode({'type': 'create', 'name': 'Fugueur', 'format': 'bestOf3'}),
    );
    final welcome = await next(types: {'welcome'});
    final code = welcome['code'] as String;
    final token = welcome['token'] as String;

    for (var i = 0; i < 3; i++) {
      channel.sink.add(jsonEncode({'type': 'addBot'}));
    }

    var canStart = false;
    for (var i = 0; i < 20; i++) {
      final message = await next(types: {'room'});
      final room = Map<String, dynamic>.from(message['room'] as Map);
      canStart = room['canStart'] == true;
      if (canStart) break;
    }
    expect(canStart, isTrue);

    channel.sink.add(jsonEncode({'type': 'start'}));
    await next(types: {'state'});

    channel.sink.add(jsonEncode({'type': 'leave'}));
    await next(types: {'left'});
    await channel.sink.close();

    final retry = WebSocketChannel.connect(server.wsUri);
    await retry.ready;
    final retryMessages = StreamIterator<dynamic>(retry.stream);
    await retryMessages.moveNext(); // hello
    retry.sink.add(
      jsonEncode({'type': 'reconnect', 'code': code, 'token': token}),
    );

    Map<String, dynamic>? error;
    while (await retryMessages.moveNext().timeout(
          const Duration(seconds: 10),
        )) {
      final raw = retryMessages.current;
      if (raw is! String) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final message = Map<String, dynamic>.from(decoded);
      if (message['type'] == 'error') {
        error = message;
        break;
      }
    }
    await retry.sink.close();

    expect(error, isNotNull, reason: 'The abandoned session was accepted');
    expect(error!['code'], 'session_closed');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the host can swap seats to compose the teams', () async {
    final server = await BelloteServer.start(host: '127.0.0.1', port: 0);
    addTearDown(server.close);

    final channel = WebSocketChannel.connect(server.wsUri);
    addTearDown(channel.sink.close);
    await channel.ready;
    final messages = StreamIterator<dynamic>(channel.stream);

    Future<Map<String, dynamic>> next({Set<String>? types}) async {
      while (await messages.moveNext().timeout(const Duration(seconds: 20))) {
        final raw = messages.current;
        if (raw is! String) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final message = Map<String, dynamic>.from(decoded);
        expect(message['type'], isNot('error'), reason: '${message['code']}');
        if (types == null || types.contains(message['type'])) return message;
      }
      fail('WebSocket closed before the expected message');
    }

    void send(Map<String, dynamic> message) {
      channel.sink.add(jsonEncode(message));
    }

    await next(types: {'hello'});
    send({'type': 'create', 'name': 'Capitaine', 'format': 'bestOf3'});
    final welcome = await next(types: {'welcome'});
    expect(welcome['seat'], 0);

    for (var i = 0; i < 3; i++) {
      send({'type': 'addBot'});
    }
    var room = <String, dynamic>{};
    for (var i = 0; i < 20; i++) {
      final message = await next(types: {'room'});
      room = Map<String, dynamic>.from(message['room'] as Map);
      if (room['canStart'] == true) break;
    }
    expect(room['canStart'], isTrue);

    send({'type': 'swapSeats', 'a': 0, 'b': 2});
    final seatUpdate = await next(types: {'seat'});
    expect(seatUpdate['seat'], 2);

    for (var i = 0; i < 10; i++) {
      final message = await next(types: {'room'});
      room = Map<String, dynamic>.from(message['room'] as Map);
      if (room['hostSeat'] == 2) break;
    }
    expect(room['hostSeat'], 2);
    final seats = room['seats'] as List;
    expect((seats[2] as Map)['name'], 'Capitaine');
    expect((seats[0] as Map)['isBot'], isTrue);
    expect(room['canStart'], isTrue);

    send({'type': 'start'});
    final state = await next(types: {'state'});
    final view = Map<String, dynamic>.from(state['view'] as Map);
    expect(view['seat'], 2);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a host plus three bots can complete a full deal', () async {
    final server = await BelloteServer.start(host: '127.0.0.1', port: 0);
    addTearDown(server.close);

    final channel = WebSocketChannel.connect(server.wsUri);
    addTearDown(channel.sink.close);
    await channel.ready;
    final messages = StreamIterator<dynamic>(channel.stream);

    Future<Map<String, dynamic>> nextMessage({
      Set<String>? types,
    }) async {
      while (await messages.moveNext().timeout(const Duration(seconds: 30))) {
        final raw = messages.current;
        if (raw is! String) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final message = Map<String, dynamic>.from(decoded);
        if (message['type'] == 'error') {
          fail('Server error: ${message['code']} ${message['message'] ?? ''}');
        }
        if (types == null || types.contains(message['type'])) {
          return message;
        }
      }
      fail('WebSocket closed before the expected message');
    }

    void send(Map<String, dynamic> message) {
      channel.sink.add(jsonEncode(message));
    }

    Future<void> sendAction(Map<String, dynamic> message) async {
      // The server enforces a small anti-spam delay between game actions.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      send(message);
    }

    await nextMessage(types: {'hello'});
    send({'type': 'create', 'name': 'Testeur', 'format': 'bestOf3'});
    final welcome = await nextMessage(types: {'welcome'});
    expect(welcome['seat'], 0);
    expect((welcome['code'] as String).length, 5);
    final code = welcome['code'] as String;

    for (var i = 0; i < 3; i++) {
      send({'type': 'addBot'});
    }

    // Wait until the room is full and ready to start.
    var room = <String, dynamic>{};
    for (var i = 0; i < 20; i++) {
      final message = await nextMessage(types: {'room'});
      room = Map<String, dynamic>.from(message['room'] as Map);
      if (room['canStart'] == true) break;
    }
    expect(room['code'], code);
    expect(room['canStart'], isTrue);

    send({'type': 'start'});

    var bidPlaced = false;
    Map<String, dynamic>? finalView;
    for (var step = 0; step < 600; step++) {
      final message = await nextMessage();

      final rawView = message['view'];
      if (rawView is! Map) continue;
      final view = Map<String, dynamic>.from(rawView);
      expect(view['seat'], 0);
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
        if (legal.isEmpty) {
          fail('No legal card offered to the player');
        }
        await sendAction({'type': 'play', 'card': legal.first});
        continue;
      }

      fail('Unexpected phase while playing: $phase');
    }

    expect(finalView, isNotNull, reason: 'The deal did not complete');
    expect(finalView!['phase'], 'dealComplete');
    expect(finalView['result'], isNotNull);
    expect(finalView['tricksPlayed'], inInclusiveRange(1, 8));
    final result = finalView['result'] as Map;
    final score = result['score'] as Map;
    expect(score['attackPoints'], isA<int>());
    expect(score['defensePoints'], isA<int>());
    expect(
      (finalView['setScores'] as Map)
          .values
          .fold<int>(0, (sum, value) => sum + (value as int)),
      greaterThan(0),
    );

    send({'type': 'leave'});
  }, timeout: const Timeout(Duration(seconds: 120)));
}
