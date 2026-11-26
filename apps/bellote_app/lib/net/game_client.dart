import 'dart:async';
import 'dart:convert';

import 'package:bellote_engine/bellote_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/settings.dart';
import '../models/room_info.dart';

enum ClientStage {
  idle,
  connecting,
  inLobby,
  playing,
  ended,
  reconnecting,
  error,
}

class NoticeEntry {
  const NoticeEntry({
    required this.code,
    required this.timestamp,
    this.seat,
    this.data = const {},
  });

  final String code;
  final int? seat;
  final int timestamp;
  final Map<String, dynamic> data;
}

/// Résultat d'une donne conservé pour la feuille de score.
class DealScoreEntry {
  const DealScoreEntry({
    required this.dealNumber,
    required this.result,
  });

  final int dealNumber;
  final DealResult result;
}

class GameClient extends ChangeNotifier {
  GameClient({required this.settings});

  final SettingsController settings;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Map<String, dynamic>? _pendingHello;
  bool _intentionalClose = false;
  int _reconnectAttempts = 0;

  ClientStage stage = ClientStage.idle;
  RoomInfo? room;
  PlayerView? view;
  int? seat;
  String? code;
  String? token;

  /// Échéance du tour en cours, convertie sur l'horloge du téléphone.
  DateTime? turnDeadline;

  /// Durée totale allouée au tour (45 s pour un humain, 900 ms pour un bot).
  Duration? turnDuration;

  /// Décalage entre l'horloge du serveur et celle de l'appareil.
  int _clockOffsetMs = 0;

  /// Temps restant avant la fin du tour, ou null s'il n'y a pas d'échéance.
  Duration? get turnRemaining {
    final deadline = turnDeadline;
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String? errorCode;
  String? errorMessage;
  int errorNonce = 0;

  List<ChatEntry> chat = [];
  final List<NoticeEntry> notices = [];

  /// Historique des donnes terminées, affiché dans la feuille de score.
  final List<DealScoreEntry> dealHistory = [];

  bool get isConnected =>
      _channel != null &&
      stage != ClientStage.connecting &&
      stage != ClientStage.reconnecting &&
      stage != ClientStage.error &&
      stage != ClientStage.idle;

  bool get isReconnecting => stage == ClientStage.reconnecting;

  bool get inRoom => room != null;

  bool get isHost => seat != null && room?.hostSeat == seat;

  bool get hasSavedSession => settings.hasSavedSession;

  int get myTeam => (seat ?? 0) % 2;

  List<GameEvent> get events => view?.events ?? const [];

  List<ChatEntry> get chatMessages => chat;

  Future<void> createRoom({
    required String name,
    required String format,
  }) async {
    await settings.setPlayerName(name);
    await settings.setFormat(format);
    _resetRoomState();
    _intentionalClose = false;
    _pendingHello = {'type': 'create', 'name': name.trim(), 'format': format};
    await _openSocket();
  }

  Future<void> joinRoom({
    required String name,
    required String roomCode,
  }) async {
    await settings.setPlayerName(name);
    _resetRoomState();
    _intentionalClose = false;
    _pendingHello = {
      'type': 'join',
      'name': name.trim(),
      'code': roomCode.trim().toUpperCase(),
    };
    await _openSocket();
  }

  Future<void> resumeSession() async {
    if (!settings.hasSavedSession) return;
    _resetRoomState();
    _intentionalClose = false;
    _reconnectAttempts = 0;
    _pendingHello = {
      'type': 'reconnect',
      'code': settings.savedCode,
      'token': settings.savedToken,
    };
    await _openSocket(reconnecting: true);
  }

  Future<void> _openSocket({bool reconnecting = false}) async {
    await _closeSocket();
    stage = reconnecting ? ClientStage.reconnecting : ClientStage.connecting;
    errorCode = null;
    errorMessage = null;
    notifyListeners();

    WebSocketChannel? channel;
    try {
      final uri = Uri.parse(settings.serverUrl);
      channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 10));
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: true,
      );
      _startPing();
      final hello = _pendingHello;
      _pendingHello = null;
      if (hello != null) {
        _send(hello);
      }
      if (stage == ClientStage.reconnecting && settings.hasSavedSession) {
        // Le welcome officiel arrive ensuite.
      }
    } catch (error) {
      await channel?.sink.close();
      _channel = null;
      if (reconnecting && settings.hasSavedSession) {
        stage = ClientStage.reconnecting;
        _scheduleReconnect();
      } else {
        stage = ClientStage.idle;
        _setError('connection_failed', error.toString());
      }
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({'type': 'ping'});
    });
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (error) {
      _setError('connection_failed', error.toString());
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return;
      final message = Map<String, dynamic>.from(decoded);
      final type = message['type'];
      switch (type) {
        case 'hello':
          break;
        case 'welcome':
          _handleWelcome(message);
        case 'seat':
          final newSeat = message['seat'];
          if (newSeat is int) {
            seat = newSeat;
            notifyListeners();
          }
        case 'room':
          _handleRoom(message);
        case 'state':
          _handleState(message);
        case 'chat':
          _handleChat(message);
        case 'notice':
          _handleNotice(message);
        case 'error':
          _handleServerError(message);
        case 'left':
          _resetRoomState();
          stage = ClientStage.idle;
          notifyListeners();
        case 'pong':
          break;
      }
    } catch (error) {
      _setError('invalid_message', error.toString());
    }
  }

  void _handleWelcome(Map<String, dynamic> message) {
    final newCode = message['code'] as String?;
    final newToken = message['token'] as String?;
    final newSeat = message['seat'] as int?;
    if (newCode != null) code = newCode;
    if (newToken != null) token = newToken;
    if (newSeat != null) seat = newSeat;
    if (code != null && token != null) {
      settings.saveSession(code!, token!);
    }
    _reconnectAttempts = 0;
    stage = room?.started == true ? ClientStage.playing : ClientStage.inLobby;
    notifyListeners();
  }

  void _handleRoom(Map<String, dynamic> message) {
    final rawRoom = message['room'];
    if (rawRoom is! Map) return;
    room = RoomInfo.fromJson(Map<String, dynamic>.from(rawRoom));
    chat = room!.chat;
    if (stage == ClientStage.connecting && room != null) {
      stage = ClientStage.inLobby;
    }
    notifyListeners();
  }

  void _handleState(Map<String, dynamic> message) {
    final rawRoom = message['room'];
    if (rawRoom is Map) {
      room = RoomInfo.fromJson(Map<String, dynamic>.from(rawRoom));
      chat = room!.chat;
    }
    _applyTurnClock(message);
    final rawView = message['view'];
    if (rawView is Map) {
      view = PlayerView.fromJson(Map<String, dynamic>.from(rawView));
      seat = view!.seat;
      _rememberDealResult();
      stage =
          view!.matchWinner != null ? ClientStage.ended : ClientStage.playing;
    } else if (room?.started == true) {
      stage = ClientStage.inLobby;
    } else if (room != null) {
      stage = ClientStage.inLobby;
    }
    notifyListeners();
  }

  /// Une seule entrée par donne, même si le serveur renvoie plusieurs états.
  void _rememberDealResult() {
    final view = this.view;
    final result = view?.result;
    if (view == null || result == null) return;
    if (dealHistory.any((entry) => entry.dealNumber == view.dealsStarted)) {
      return;
    }
    dealHistory.add(
      DealScoreEntry(dealNumber: view.dealsStarted, result: result),
    );
  }

  /// Convertit l'échéance serveur en heure locale pour que la montre reste
  /// juste même si le téléphone n'est pas à l'heure du serveur.
  void _applyTurnClock(Map<String, dynamic> message) {
    final serverTime = message['serverTime'];
    if (serverTime is int) {
      _clockOffsetMs = serverTime - DateTime.now().millisecondsSinceEpoch;
    }
    final deadline = message['turnDeadline'];
    turnDeadline = deadline is int
        ? DateTime.fromMillisecondsSinceEpoch(deadline - _clockOffsetMs)
        : null;
    final duration = message['turnDurationMs'];
    turnDuration = duration is int ? Duration(milliseconds: duration) : null;
  }

  void _handleChat(Map<String, dynamic> message) {
    final entry = ChatEntry.fromJson(message);
    final duplicate = chat.any(
      (item) =>
          item.timestamp == entry.timestamp &&
          item.seat == entry.seat &&
          item.text == entry.text,
    );
    if (!duplicate) {
      chat = [...chat, entry];
      if (chat.length > 100) {
        chat = chat.sublist(chat.length - 100);
      }
      notifyListeners();
    }
  }

  void _handleNotice(Map<String, dynamic> message) {
    final code = message['code'] as String?;
    if (code == null) return;
    notices.add(
      NoticeEntry(
        code: code,
        seat: message['seat'] is int ? message['seat'] as int : null,
        timestamp: message['ts'] is int
            ? message['ts'] as int
            : DateTime.now().millisecondsSinceEpoch,
        data: message,
      ),
    );
    if (notices.length > 60) notices.removeAt(0);
    notifyListeners();
  }

  void _handleServerError(Map<String, dynamic> message) {
    final code = message['code'] as String? ?? 'internal_error';
    final text = message['message'] as String?;
    if (code == 'invalid_token' ||
        code == 'room_not_found' ||
        code == 'session_closed') {
      _clearSession();
      stage = ClientStage.idle;
      _setError(code, text);
      return;
    }
    if (code == 'too_fast') return;
    if (room == null &&
        (stage == ClientStage.connecting ||
            stage == ClientStage.reconnecting)) {
      stage = ClientStage.idle;
    }
    _setError(code, text);
  }

  void _setError(String code, [String? message]) {
    errorCode = code;
    errorMessage = message;
    errorNonce++;
    notifyListeners();
  }

  void clearError() {
    errorCode = null;
    errorMessage = null;
  }

  void _onDone() {
    _cleanupSocket();
    if (_intentionalClose) return;
    if (room != null || settings.hasSavedSession) {
      stage = ClientStage.reconnecting;
      notifyListeners();
      _scheduleReconnect();
    } else {
      stage = ClientStage.idle;
      notifyListeners();
    }
  }

  void _onError(Object error) {
    if (_intentionalClose) return;
    _cleanupSocket();
    if (room != null || settings.hasSavedSession) {
      stage = ClientStage.reconnecting;
      notifyListeners();
      _scheduleReconnect();
    } else {
      _setError('connection_failed', error.toString());
    }
  }

  void _scheduleReconnect() {
    if (_intentionalClose) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds =
        _reconnectAttempts <= 1 ? 1 : (_reconnectAttempts * 2).clamp(2, 12);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_intentionalClose) return;
    final savedCode = code ?? settings.savedCode;
    final savedToken = token ?? settings.savedToken;
    if (savedCode == null || savedToken == null) {
      stage = ClientStage.idle;
      notifyListeners();
      return;
    }
    _pendingHello = {
      'type': 'reconnect',
      'code': savedCode,
      'token': savedToken,
    };
    await _openSocket(reconnecting: true);
  }

  Future<void> _closeSocket() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupSocket();
  }

  void _cleanupSocket() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> addBot() async {
    _send({'type': 'addBot'});
  }

  Future<void> removeBot(int seat) async {
    _send({'type': 'removeBot', 'seat': seat});
  }

  Future<void> swapSeats(int a, int b) async {
    _send({'type': 'swapSeats', 'a': a, 'b': b});
  }

  Future<void> startGame() async {
    _send({'type': 'start'});
  }

  Future<void> nextDeal() async {
    _send({'type': 'nextDeal'});
  }

  Future<void> pass() async {
    _send({'type': 'pass'});
  }

  Future<void> bid(int amount, Suit suit) async {
    _send({'type': 'bid', 'amount': amount, 'suit': suit.name});
  }

  Future<void> capot(Suit suit) async {
    _send({'type': 'capot', 'suit': suit.name});
  }

  Future<void> counter() async {
    _send({'type': 'counter'});
  }

  Future<void> surcounter() async {
    _send({'type': 'surcounter'});
  }

  Future<void> play(Card card, {bool belote = false}) async {
    _send({'type': 'play', 'card': card.id, 'belote': belote});
  }

  Future<void> sendChat(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _send({'type': 'chat', 'text': trimmed});
  }

  Future<void> leaveRoom() async {
    _intentionalClose = true;
    _send({'type': 'leave'});
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _closeSocket();
    await _clearSession();
    _resetRoomState();
    stage = ClientStage.idle;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    await settings.clearSession();
  }

  void _resetRoomState() {
    _cleanupSocket();
    room = null;
    view = null;
    seat = null;
    code = null;
    token = null;
    turnDeadline = null;
    turnDuration = null;
    chat = [];
    notices.clear();
    dealHistory.clear();
    errorCode = null;
    errorMessage = null;
  }

  @override
  void dispose() {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    super.dispose();
  }
}
