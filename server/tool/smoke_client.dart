import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args.first : 'ws://127.0.0.1:8090/ws';
  final channel = IOWebSocketChannel.connect(Uri.parse(url));
  String? code;
  String? token;
  var seat = 0;
  String? phase;
  var dealt = false;

  final done = Completer<void>();
  late StreamSubscription<dynamic> subscription;

  void send(Map<String, dynamic> message) {
    channel.sink.add(jsonEncode(message));
  }

  subscription = channel.stream.listen(
    (dynamic raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = message['type'];
      if (type == 'hello') {
        print('hello');
        send({'type': 'create', 'name': 'Smoke', 'format': 'bestOf3'});
      } else if (type == 'welcome') {
        code = message['code'] as String;
        token = message['token'] as String;
        seat = message['seat'] as int;
        print('welcome code=$code seat=$seat');
        send({'type': 'addBot'});
        send({'type': 'addBot'});
        send({'type': 'addBot'});
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          send({'type': 'start'});
        });
      } else if (type == 'room') {
        final room = message['room'] as Map<String, dynamic>;
        final seats = room['seats'] as List;
        final filled = seats.where((entry) => entry != null).length;
        print('room filled=$filled started=${room['started']}');
        if (room['started'] == true && !dealt) {
          dealt = true;
        }
      } else if (type == 'state') {
        final view = message['view'] as Map<String, dynamic>?;
        if (view == null) return;
        phase = message['phase'] as String?;
        final myTurn = view['isMyTurn'] == true;
        final isBidding = phase == 'bidding';
        final isPlaying = phase == 'playing';
        if (myTurn && isBidding) {
          if (view['canBidNumbers'] == true) {
            final hand = (view['hand'] as List).cast<String>();
            final suit = hand.first.substring(hand.first.length - 1);
            final suitName = switch (suit) {
              'S' => 'spades',
              'H' => 'hearts',
              'D' => 'diamonds',
              _ => 'clubs',
            };
            send({
              'type': 'bid',
              'amount': view['minimumBid'],
              'suit': suitName,
            });
          } else {
            send({'type': 'pass'});
          }
        } else if (myTurn && isPlaying) {
          final legal = (view['legalCards'] as List).cast<String>();
          if (legal.isNotEmpty) {
            send({'type': 'play', 'card': legal.first});
          }
        }
        if (view['result'] != null && !done.isCompleted) {
          final result = view['result'] as Map<String, dynamic>;
          print('deal result: ${result['score']}');
          done.complete();
        }
      } else if (type == 'error') {
        print('ERROR ${message['code']} ${message['details'] ?? ''}');
      } else if (type == 'notice') {
        print('notice ${message['code']}');
      }
    },
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
    onError: (Object error) {
      print('stream error: $error');
      if (!done.isCompleted) done.completeError(error);
    },
  );

  await done.future.timeout(
    const Duration(seconds: 40),
    onTimeout: () {
      print('timeout (phase=$phase)');
    },
  );
  print('closing');
  await subscription.cancel();
  await channel.sink.close();
  if (code != null && token != null) {
    print('room=$code token=$token');
  }
  exit(0);
}
