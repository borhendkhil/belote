class ServerPlayer {
  const ServerPlayer({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.connected,
    required this.autoPlay,
  });

  final int seat;
  final String name;
  final bool isBot;
  final bool connected;
  final bool autoPlay;

  static ServerPlayer fromJson(Map<String, dynamic> json) => ServerPlayer(
        seat: json['seat'] as int,
        name: json['name'] as String? ?? '',
        isBot: json['isBot'] as bool? ?? false,
        connected: json['connected'] as bool? ?? false,
        autoPlay: json['autoPlay'] as bool? ?? false,
      );
}

class ChatEntry {
  const ChatEntry({
    required this.seat,
    required this.name,
    required this.text,
    required this.timestamp,
  });

  final int? seat;
  final String name;
  final String text;
  final int timestamp;

  static ChatEntry fromJson(Map<String, dynamic> json) => ChatEntry(
        seat: json['seat'] is int ? json['seat'] as int : null,
        name: json['name'] as String? ?? '',
        text: json['text'] as String? ?? '',
        timestamp: json['ts'] is int
            ? json['ts'] as int
            : DateTime.now().millisecondsSinceEpoch,
      );
}

class RoomInfo {
  const RoomInfo({
    required this.code,
    required this.hostSeat,
    required this.format,
    required this.started,
    required this.canStart,
    required this.seats,
    required this.chat,
  });

  final String code;
  final int hostSeat;
  final String format;
  final bool started;
  final bool canStart;
  final List<ServerPlayer?> seats;
  final List<ChatEntry> chat;

  int get filledSeats => seats.where((seat) => seat != null).length;

  ServerPlayer? seatAt(int seat) =>
      seat >= 0 && seat < seats.length ? seats[seat] : null;

  bool isHost(int? seat) => seat != null && seat == hostSeat;

  static RoomInfo fromJson(Map<String, dynamic> json) {
    final rawSeats = json['seats'] as List? ?? const [];
    final seats = <ServerPlayer?>[
      for (var i = 0; i < 4; i++)
        i < rawSeats.length && rawSeats[i] != null
            ? ServerPlayer.fromJson(
                Map<String, dynamic>.from(rawSeats[i] as Map),
              )
            : null,
    ];
    final rawChat = json['chat'] as List? ?? const [];
    return RoomInfo(
      code: json['code'] as String? ?? '',
      hostSeat: json['hostSeat'] as int? ?? 0,
      format: json['format'] as String? ?? 'bestOf3',
      started: json['started'] as bool? ?? false,
      canStart: json['canStart'] as bool? ?? false,
      seats: seats,
      chat: [
        for (final entry in rawChat)
          ChatEntry.fromJson(Map<String, dynamic>.from(entry as Map)),
      ],
    );
  }
}
