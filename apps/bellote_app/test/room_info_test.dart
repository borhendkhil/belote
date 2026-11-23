import 'package:bellote_app/models/room_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses room, seats and chat', () {
    final room = RoomInfo.fromJson({
      'code': 'ABCDE',
      'hostSeat': 2,
      'format': 'bestOf5',
      'started': true,
      'canStart': false,
      'seats': [
        null,
        {
          'seat': 1,
          'name': 'Sami',
          'isBot': false,
          'connected': true,
          'autoPlay': false,
        },
        {
          'seat': 2,
          'name': 'Bot 1',
          'isBot': true,
          'connected': true,
          'autoPlay': false,
        },
        null,
      ],
      'chat': [
        {'seat': 1, 'name': 'Sami', 'text': 'Salut', 'ts': 1000},
      ],
    });

    expect(room.code, 'ABCDE');
    expect(room.hostSeat, 2);
    expect(room.filledSeats, 2);
    expect(room.seatAt(1)!.name, 'Sami');
    expect(room.seatAt(0), isNull);
    expect(room.seatAt(2)!.isBot, isTrue);
    expect(room.chat.single.text, 'Salut');
    expect(room.isHost(2), isTrue);
    expect(room.isHost(1), isFalse);
  });

  test('fills missing seats and tolerates absent fields', () {
    final room = RoomInfo.fromJson({'code': 'XYZ12'});
    expect(room.seats.length, 4);
    expect(room.seats.every((seat) => seat == null), isTrue);
    expect(room.format, 'bestOf3');
    expect(room.started, isFalse);
    expect(room.hostSeat, 0);
  });
}
