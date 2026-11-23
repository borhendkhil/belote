class GameEvent {
  const GameEvent({
    required this.seq,
    required this.type,
    required this.data,
  });

  final int seq;
  final String type;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'type': type,
        'data': data,
      };

  static GameEvent fromJson(Map<String, dynamic> json) => GameEvent(
        seq: json['seq'] as int,
        type: json['type'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
      );
}

/// Journal borné des événements du moteur.
class EventLog {
  EventLog({this.capacity = 300});

  final int capacity;
  final List<GameEvent> _events = [];
  int _seq = 0;

  int get lastSeq => _seq;

  List<GameEvent> get events => List.unmodifiable(_events);

  GameEvent add(String type, [Map<String, dynamic> data = const {}]) {
    final event = GameEvent(seq: ++_seq, type: type, data: data);
    _events.add(event);
    if (_events.length > capacity) {
      _events.removeRange(0, _events.length - capacity);
    }
    return event;
  }

  List<GameEvent> recent([int count = 40]) {
    if (_events.length <= count) return List.unmodifiable(_events);
    return List.unmodifiable(_events.sublist(_events.length - count));
  }

  List<GameEvent> since(int seq) =>
      List.unmodifiable(_events.where((event) => event.seq > seq));
}
