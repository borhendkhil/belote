import 'dart:async';
import 'dart:math';

import 'package:bellote_engine/bellote_engine.dart';

import 'hub.dart';

class SeatSlot {
  SeatSlot({
    required this.token,
    required this.name,
    required this.isBot,
    this.connection,
  }) : connected = connection != null;

  final String token;
  String name;
  final bool isBot;
  ClientConnection? connection;
  bool connected;
  bool autoPlay = false;

  /// Vrai quand un joueur humain a volontairement quitté une partie
  /// commencée. Son siège reste occupé par un bot et n'est plus reprenable.
  bool abandoned = false;
  Timer? disconnectTimer;

  bool get isHuman => !isBot && !abandoned;

  Map<String, dynamic> toJson(int seat) => {
        'seat': seat,
        'name': name,
        'isBot': isBot,
        'connected': connected || isBot,
        'autoPlay': autoPlay,
        'abandoned': abandoned,
      };
}

/// Résultat d'une tentative de reprise de siège.
enum ReconnectResult { ok, notFound, abandoned }

class Room {
  Room({
    required this.hub,
    required this.code,
    required this.format,
  })  : createdAt = DateTime.now(),
        lastActivityAt = DateTime.now();

  final Hub hub;
  final String code;
  final MatchFormat format;
  final DateTime createdAt;
  DateTime lastActivityAt;

  final List<SeatSlot?> seats = List<SeatSlot?>.filled(4, null);
  int hostSeat = 0;
  bool started = false;
  BelloteGame? game;

  final SimpleBot _bot = SimpleBot();
  Timer? _actionTimer;
  Timer? _nextDealTimer;
  int _serial = 0;
  bool _disposed = false;
  DateTime? _turnDeadline;

  final List<Map<String, dynamic>> chat = [];
  final List<Map<String, dynamic>> notices = [];

  int get humanConnectionCount => seats
      .where((slot) => slot != null && slot.isHuman && slot.connected)
      .length;

  int get botCount => seats.where((slot) => slot?.isBot == true).length;

  int get filledSeats => seats.where((slot) => slot != null).length;

  bool get canStart => !started && filledSeats == 4;

  void touch() => lastActivityAt = DateTime.now();

  // ---------------------------------------------------------------------------
  // Entrée / sortie
  // ---------------------------------------------------------------------------

  int addHost(ClientConnection connection, String name) {
    final token = hub.newToken();
    seats[0] = SeatSlot(
        token: token, name: name, isBot: false, connection: connection);
    connection
      ..room = this
      ..seat = 0
      ..token = token
      ..name = name;
    hostSeat = 0;
    touch();
    return 0;
  }

  int? join(ClientConnection connection, String name) {
    if (started) return null;
    final seat = seats.indexWhere((slot) => slot == null);
    if (seat == -1) return null;
    final token = hub.newToken();
    seats[seat] = SeatSlot(
      token: token,
      name: name,
      isBot: false,
      connection: connection,
    );
    connection
      ..room = this
      ..seat = seat
      ..token = token
      ..name = name;
    touch();
    _transferHostIfNeeded();
    return seat;
  }

  ReconnectResult reconnect(ClientConnection connection, String token) {
    final seat = seats.indexWhere((slot) => slot?.token == token);
    if (seat == -1) return ReconnectResult.notFound;
    final slot = seats[seat]!;
    if (slot.abandoned) return ReconnectResult.abandoned;
    final previous = slot.connection;
    if (previous != null && previous != connection && !previous.closed) {
      previous.room = null;
      previous.close();
    }
    slot.connection = connection;
    slot.connected = true;
    slot.autoPlay = false;
    slot.disconnectTimer?.cancel();
    slot.disconnectTimer = null;
    connection
      ..room = this
      ..seat = seat
      ..token = token
      ..name = slot.name;
    touch();
    _serial++;
    _setupTimers();
    broadcastRoom();
    broadcastState();
    return ReconnectResult.ok;
  }

  void onConnectionClosed(ClientConnection connection) {
    final seat = connection.seat;
    if (seat == null || seat < 0 || seat > 3) return;
    final slot = seats[seat];
    if (slot == null || slot.connection != connection) return;
    slot.connection = null;
    slot.connected = false;
    touch();

    if (!started) {
      _transferHostIfNeeded();
      slot.disconnectTimer?.cancel();
      slot.disconnectTimer = Timer(const Duration(seconds: 30), () {
        if (!started && slot.connection == null) {
          seats[seat] = null;
          _transferHostIfNeeded();
          touch();
          broadcastRoom();
        }
      });
    } else {
      slot.disconnectTimer?.cancel();
      slot.disconnectTimer = Timer(const Duration(seconds: 20), () {
        if (game == null) return;
        if (slot.connection == null && !slot.autoPlay) {
          slot.autoPlay = true;
          _serial++;
          _setupTimers();
          broadcastRoom();
          broadcastState();
        }
      });
    }

    broadcastRoom();
    broadcastState();
  }

  void _transferHostIfNeeded() {
    if (seats[hostSeat] != null && seats[hostSeat]!.connected) return;
    final candidate = seats.indexWhere(
      (slot) => slot != null && slot.isHuman && slot.connected,
    );
    if (candidate != -1) {
      hostSeat = candidate;
    } else {
      final anyHuman = seats.indexWhere((slot) => slot != null && slot.isHuman);
      if (anyHuman != -1) hostSeat = anyHuman;
    }
  }

  // ---------------------------------------------------------------------------
  // Lobby
  // ---------------------------------------------------------------------------

  int? addBot(ClientConnection connection) {
    if (connection.seat != hostSeat) {
      connection.sendError('host_only');
      return null;
    }
    if (started) {
      connection.sendError('game_already_started');
      return null;
    }
    final seat = seats.indexWhere((slot) => slot == null);
    if (seat == -1) {
      connection.sendError('room_full');
      return null;
    }
    seats[seat] = SeatSlot(
      token: hub.newToken(),
      name: 'Bot ${botCount + 1}',
      isBot: true,
    );
    touch();
    broadcastRoom();
    return seat;
  }

  void removeBot(ClientConnection connection, int seat) {
    if (connection.seat != hostSeat) {
      connection.sendError('host_only');
      return;
    }
    if (started) {
      connection.sendError('game_already_started');
      return;
    }
    if (seat < 0 || seat > 3 || seats[seat]?.isBot != true) {
      connection.sendError('not_a_bot');
      return;
    }
    seats[seat] = null;
    _transferHostIfNeeded();
    touch();
    broadcastRoom();
  }

  /// Échange deux sièges avant le début de la partie (hôte uniquement).
  ///
  /// Permet à l'administrateur de composer les équipes (sièges pairs/impairs).
  void swapSeats(ClientConnection connection, int a, int b) {
    if (connection.seat != hostSeat) {
      connection.sendError('host_only');
      return;
    }
    if (started) {
      connection.sendError('game_already_started');
      return;
    }
    if (a < 0 || a > 3 || b < 0 || b > 3 || a == b) {
      return;
    }
    final slotA = seats[a];
    final slotB = seats[b];
    if (slotA == null && slotB == null) return;

    seats[a] = slotB;
    seats[b] = slotA;
    if (slotA?.connection != null) {
      slotA!.connection!
        ..seat = b
        ..send({'type': 'seat', 'seat': b});
    }
    if (slotB?.connection != null) {
      slotB!.connection!
        ..seat = a
        ..send({'type': 'seat', 'seat': a});
    }
    if (hostSeat == a) {
      hostSeat = b;
    } else if (hostSeat == b) {
      hostSeat = a;
    }
    touch();
    broadcastRoom();
  }

  void start(ClientConnection connection) {
    if (connection.seat != hostSeat) {
      connection.sendError('host_only');
      return;
    }
    if (started) {
      connection.sendError('game_already_started');
      return;
    }
    if (filledSeats < 4) {
      connection.sendError('not_enough_players');
      return;
    }
    started = true;
    touch();
    game = BelloteGame(
      config: GameConfig(
        format: format,
        earlyStopEnabled: true,
        random: Random.secure(),
      ),
    );
    game!.start();
    _serial++;
    _setupTimers();
    broadcastRoom();
    broadcastState();
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  void handleClientMessage(
    ClientConnection connection,
    Map<String, dynamic> message,
  ) {
    final seat = connection.seat;
    if (seat == null) {
      connection.sendError('not_in_room');
      return;
    }
    if (connection.closed) return;

    final type = message['type'] as String? ?? '';
    if (type == 'chat') {
      _handleChat(connection, message);
      return;
    }
    if (!started) {
      switch (type) {
        case 'addBot':
          addBot(connection);
          return;
        case 'removeBot':
          final target = message['seat'];
          removeBot(connection, target is num ? target.toInt() : -1);
          return;
        case 'swapSeats':
          final a = message['a'];
          final b = message['b'];
          if (a is! num || b is! num) {
            connection.sendError('invalid_message');
            return;
          }
          swapSeats(connection, a.toInt(), b.toInt());
          return;
        case 'start':
          start(connection);
          return;
        case 'leave':
          _leaveLobby(connection);
          return;
        case 'ping':
          connection.send({'type': 'pong'});
          return;
        default:
          connection.sendError('game_not_started');
          return;
      }
    }

    if (type == 'leave') {
      _leaveGame(connection);
      return;
    }
    if (type == 'nextDeal') {
      if (connection.seat != hostSeat) {
        connection.sendError('host_only');
        return;
      }
      final game = this.game;
      if (game == null ||
          (game.phase != GamePhase.dealComplete &&
              game.phase != GamePhase.setComplete)) {
        connection.sendError('deal_not_complete');
        return;
      }
      _nextDealNow();
      return;
    }
    if (type == 'ping') {
      connection.send({'type': 'pong'});
      return;
    }

    final game = this.game;
    if (game == null) {
      connection.sendError('game_not_started');
      return;
    }

    final now = DateTime.now();
    if (now.difference(connection.lastActionAt) <
        const Duration(milliseconds: 60)) {
      connection.sendError('too_fast');
      return;
    }
    connection.lastActionAt = now;

    try {
      switch (type) {
        case 'pass':
          game.placeBid(seat, const PassBid());
        case 'bid':
          final amount = message['amount'];
          final suit = message['suit'];
          if (amount is! num || suit is! String) {
            connection.sendError('invalid_message');
            return;
          }
          game.placeBid(
            seat,
            NumberBid(amount: amount.toInt(), trump: _parseSuit(suit)),
          );
        case 'capot':
          final suit = message['suit'];
          if (suit is! String) {
            connection.sendError('invalid_message');
            return;
          }
          game.placeBid(seat, CapotBid(trump: _parseSuit(suit)));
        case 'counter':
          game.placeBid(seat, const CounterBid());
        case 'surcounter':
          game.placeBid(seat, const SurcounterBid());
        case 'play':
          final cardId = message['card'];
          if (cardId is! String) {
            connection.sendError('invalid_message');
            return;
          }
          game.playCard(
            seat,
            Card.parse(cardId),
            declareBelote:
                message['belote'] == true || message['declareBelote'] == true,
            declareRebelote: message['rebelote'] == true ||
                message['declareRebelote'] == true,
          );
        default:
          connection.sendError('unknown_message');
          return;
      }
    } on RuleViolation catch (violation) {
      connection.sendError(
        violation.code,
        details: violation.details,
      );
      return;
    } on FormatException catch (error) {
      connection.sendError('invalid_card', message: error.message);
      return;
    }

    touch();
    _refresh();
  }

  Suit _parseSuit(String value) {
    final normalized = value.toLowerCase();
    for (final suit in Suit.values) {
      if (suit.name == normalized) return suit;
    }
    return Suit.fromCode(value.toUpperCase());
  }

  void _handleChat(ClientConnection connection, Map<String, dynamic> message) {
    final text = (message['text'] as String?)?.trim();
    if (text == null || text.isEmpty) return;
    final clipped = text.length > 180 ? text.substring(0, 180) : text;
    final seat = connection.seat;
    final entry = {
      'seat': seat,
      'name': seat == null ? '?' : (seats[seat]?.name ?? '?'),
      'text': clipped,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    chat.add(entry);
    if (chat.length > 60) chat.removeAt(0);
    _broadcast({'type': 'chat', ...entry});
  }

  void _leaveLobby(ClientConnection connection) {
    final seat = connection.seat;
    if (seat == null) return;
    seats[seat] = null;
    connection
      ..room = null
      ..seat = null;
    _transferHostIfNeeded();
    touch();
    connection.send({'type': 'left'});
    broadcastRoom();
    connection.close();
  }

  void _leaveGame(ClientConnection connection) {
    final seat = connection.seat;
    if (seat == null) return;
    final slot = seats[seat];
    if (slot == null) return;
    // Départ volontaire : le siège est définitivement abandonné et joué par
    // un bot. Le jeton de session ne permet plus de revenir dans la partie.
    slot.abandoned = true;
    slot.autoPlay = true;
    slot.connected = false;
    slot.connection = null;
    slot.disconnectTimer?.cancel();
    slot.disconnectTimer = null;
    connection
      ..room = null
      ..seat = null;
    connection.send({'type': 'left'});
    connection.close();
    _transferHostIfNeeded();
    touch();
    _serial++;
    _setupTimers();
    broadcastRoom();
    broadcastState();
    _broadcast({
      'type': 'notice',
      'code': 'player_left_bot',
      'seat': seat,
    });
  }

  // ---------------------------------------------------------------------------
  // Boucle de jeu et bots
  // ---------------------------------------------------------------------------

  void _refresh() {
    if (_disposed) return;
    _serial++;
    _actionTimer?.cancel();
    _actionTimer = null;
    _nextDealTimer?.cancel();
    _nextDealTimer = null;
    _turnDeadline = null;

    final game = this.game;
    if (game == null) {
      broadcastState();
      return;
    }

    switch (game.phase) {
      case GamePhase.dealComplete:
      case GamePhase.setComplete:
        _nextDealTimer = Timer(const Duration(seconds: 6), _nextDealNow);
      case GamePhase.matchComplete:
        break;
      case GamePhase.bidding:
      case GamePhase.playing:
        _scheduleAction(game);
    }
    broadcastRoom();
    broadcastState();
  }

  void _scheduleAction(BelloteGame game) {
    final seat = _actingSeat(game);
    if (seat == null) return;
    final slot = seats[seat];
    final auto = slot == null || slot.isBot || slot.autoPlay || !slot.connected;
    final delay =
        auto ? const Duration(milliseconds: 900) : const Duration(seconds: 45);
    _turnDeadline = DateTime.now().add(delay);
    final serial = _serial;
    _actionTimer = Timer(delay, () {
      if (_disposed || serial != _serial) return;
      final current = this.game;
      if (current == null) return;
      if (_actingSeat(current) != seat) return;
      final isBotTurn = seats[seat] == null ||
          seats[seat]!.isBot ||
          seats[seat]!.autoPlay ||
          !seats[seat]!.connected;
      if (!isBotTurn) {
        _broadcast({
          'type': 'notice',
          'code': 'turn_timeout',
          'seat': seat,
        });
      }
      _performBotAction(seat);
      _refresh();
    });
  }

  int? _actingSeat(BelloteGame game) {
    final deal = game.deal;
    if (deal == null) return null;
    switch (game.phase) {
      case GamePhase.bidding:
        return deal.auction.turnSeat;
      case GamePhase.playing:
        return deal.currentTurnSeat;
      default:
        return null;
    }
  }

  void _performBotAction(int seat) {
    final game = this.game;
    if (game == null) return;
    try {
      if (game.phase == GamePhase.bidding) {
        final action = _bot.decideBid(game, seat);
        game.placeBid(seat, action);
        return;
      }
      if (game.phase == GamePhase.playing) {
        final decision = _bot.decidePlay(game, seat);
        if (decision != null) {
          game.playCard(
            seat,
            decision.card,
            declareBelote: decision.declareBelote,
            declareRebelote: decision.declareRebelote,
          );
        }
        return;
      }
    } catch (error, stack) {
      // Filet de sécurité : jouer un coup légal minimal pour ne jamais bloquer.
      // ignore: avoid_print
      print('Bot erreur: $error\n$stack');
      try {
        if (game.phase == GamePhase.bidding) {
          game.placeBid(seat, const PassBid());
        } else if (game.phase == GamePhase.playing) {
          final legal = game.deal!.legalCardsFor(seat);
          if (legal.isNotEmpty) {
            game.playCard(seat, legal.first);
          }
        }
      } catch (_) {}
    }
  }

  void _nextDealNow() {
    _nextDealTimer?.cancel();
    _nextDealTimer = null;
    final game = this.game;
    if (game == null) return;
    if (game.phase != GamePhase.dealComplete &&
        game.phase != GamePhase.setComplete) {
      return;
    }
    try {
      game.nextDeal();
    } catch (error) {
      // ignore: avoid_print
      print('nextDeal erreur: $error');
    }
    _refresh();
  }

  void _setupTimers() {
    _actionTimer?.cancel();
    _actionTimer = null;
    _turnDeadline = null;
    final game = this.game;
    if (game == null) return;
    if (game.phase == GamePhase.bidding || game.phase == GamePhase.playing) {
      _scheduleAction(game);
    }
  }

  // ---------------------------------------------------------------------------
  // Diffusion
  // ---------------------------------------------------------------------------

  Map<String, dynamic> roomJson() => {
        'code': code,
        'hostSeat': hostSeat,
        'format': format.name,
        'started': started,
        'canStart': canStart,
        'seats': [
          for (var i = 0; i < 4; i++) seats[i]?.toJson(i),
        ],
        'chat': chat.length > 20 ? chat.sublist(chat.length - 20) : chat,
      };

  List<Map<String, dynamic>> playersJson() => [
        for (var i = 0; i < 4; i++)
          if (seats[i] != null) seats[i]!.toJson(i),
      ];

  void broadcastRoom() {
    final payload = {'type': 'room', 'room': roomJson()};
    _broadcast(payload);
  }

  void broadcastState() {
    final game = this.game;
    final base = {
      'type': 'state',
      'room': roomJson(),
      'players': playersJson(),
      'turnDeadline': _turnDeadline?.millisecondsSinceEpoch,
      'serverTime': DateTime.now().millisecondsSinceEpoch,
      if (game != null) 'phase': game.phase.name,
    };
    for (var seat = 0; seat < 4; seat++) {
      final slot = seats[seat];
      if (slot == null || slot.isBot) continue;
      final connection = slot.connection;
      if (connection == null || connection.closed) continue;
      final message = <String, dynamic>{
        ...base,
        if (game != null) 'view': game.viewFor(seat).toJson(),
      };
      connection.send(message);
    }
  }

  void _broadcast(Map<String, dynamic> message) {
    for (final slot in seats) {
      final connection = slot?.connection;
      if (connection != null && !connection.closed) {
        connection.send(message);
      }
    }
  }

  void broadcastNotice(String code, [Map<String, dynamic> data = const {}]) {
    final entry = {
      'type': 'notice',
      'code': code,
      ...data,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    notices.add(entry);
    if (notices.length > 40) notices.removeAt(0);
    _broadcast(entry);
  }

  void dispose() {
    _disposed = true;
    _actionTimer?.cancel();
    _nextDealTimer?.cancel();
    for (final slot in seats) {
      slot?.disconnectTimer?.cancel();
    }
  }
}
