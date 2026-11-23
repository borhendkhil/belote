import 'auction.dart';
import 'card.dart';
import 'contract.dart';
import 'deal.dart';
import 'events.dart';
import 'rules.dart';

/// Vue d'une partie filtrée pour un siège donné.
///
/// Les mains adverses ne figurent que sous forme de nombre de cartes.
class PlayerView {
  const PlayerView({
    required this.seat,
    required this.phase,
    required this.dealerSeat,
    required this.turnSeat,
    required this.isMyTurn,
    required this.contract,
    required this.trump,
    required this.hand,
    required this.handCounts,
    required this.currentTrick,
    required this.legalCards,
    required this.lastTrick,
    required this.lastTrickWinnerSeat,
    required this.tricksPlayed,
    required this.cardPointsByTeam,
    required this.tricksByTeam,
    required this.setScores,
    required this.setsWon,
    required this.setNumber,
    required this.setTarget,
    required this.maxSets,
    required this.isBelle,
    required this.matchWinner,
    required this.earlyStopped,
    required this.earlyStopReason,
    required this.result,
    required this.canPass,
    required this.canBidNumbers,
    required this.canCapot,
    required this.canCounter,
    required this.canSurcounter,
    required this.minimumBid,
    required this.maxBid,
    required this.auctionHistory,
    required this.auctionClosed,
    required this.canDeclareBelote,
    required this.canDeclareRebelote,
    required this.holdsBelote,
    required this.beloteDeclared,
    required this.beloteCompleted,
    required this.beloteDeclined,
    required this.beloteTeam,
    required this.canStartNextDeal,
    required this.events,
    required this.eventSeq,
    required this.redeals,
    required this.dealsStarted,
  });

  final int seat;
  final String phase;
  final int dealerSeat;
  final int? turnSeat;
  final bool isMyTurn;
  final Contract? contract;
  final Suit? trump;
  final List<Card> hand;
  final Map<int, int> handCounts;
  final List<PlayedCard> currentTrick;
  final List<Card> legalCards;
  final TrickRecord? lastTrick;
  final int? lastTrickWinnerSeat;
  final int tricksPlayed;
  final Map<int, int> cardPointsByTeam;
  final Map<int, int> tricksByTeam;
  final Map<int, int> setScores;
  final Map<int, int> setsWon;
  final int setNumber;
  final int setTarget;
  final int maxSets;
  final bool isBelle;
  final int? matchWinner;
  final bool earlyStopped;
  final String? earlyStopReason;
  final DealResult? result;
  final bool canPass;
  final bool canBidNumbers;
  final bool canCapot;
  final bool canCounter;
  final bool canSurcounter;
  final int minimumBid;
  final int maxBid;
  final List<BidRecord> auctionHistory;
  final bool auctionClosed;
  final bool canDeclareBelote;
  final bool canDeclareRebelote;
  final bool holdsBelote;
  final bool beloteDeclared;
  final bool beloteCompleted;
  final bool beloteDeclined;
  final int? beloteTeam;
  final bool canStartNextDeal;
  final List<GameEvent> events;
  final int eventSeq;
  final int redeals;
  final int dealsStarted;

  int get myTeam => teamOf(seat);

  bool get isBidding => phase == 'bidding';

  bool get isPlaying => phase == 'playing';

  bool get isDealComplete =>
      phase == 'dealComplete' ||
      phase == 'setComplete' ||
      phase == 'matchComplete';

  Map<String, dynamic> toJson() => {
        'seat': seat,
        'phase': phase,
        'dealerSeat': dealerSeat,
        'turnSeat': turnSeat,
        'isMyTurn': isMyTurn,
        'contract': contract?.toJson(),
        'trump': trump?.code,
        'hand': [for (final card in hand) card.id],
        'handCounts': {
          for (final entry in handCounts.entries) '${entry.key}': entry.value,
        },
        'currentTrick': [for (final play in currentTrick) play.toJson()],
        'legalCards': [for (final card in legalCards) card.id],
        'lastTrick': lastTrick?.toJson(),
        'lastTrickWinnerSeat': lastTrickWinnerSeat,
        'tricksPlayed': tricksPlayed,
        'cardPointsByTeam': {
          for (final entry in cardPointsByTeam.entries)
            '${entry.key}': entry.value,
        },
        'tricksByTeam': {
          for (final entry in tricksByTeam.entries) '${entry.key}': entry.value,
        },
        'setScores': {
          for (final entry in setScores.entries) '${entry.key}': entry.value,
        },
        'setsWon': {
          for (final entry in setsWon.entries) '${entry.key}': entry.value,
        },
        'setNumber': setNumber,
        'setTarget': setTarget,
        'maxSets': maxSets,
        'isBelle': isBelle,
        'matchWinner': matchWinner,
        'earlyStopped': earlyStopped,
        'earlyStopReason': earlyStopReason,
        'result': result?.toJson(),
        'canPass': canPass,
        'canBidNumbers': canBidNumbers,
        'canCapot': canCapot,
        'canCounter': canCounter,
        'canSurcounter': canSurcounter,
        'minimumBid': minimumBid,
        'maxBid': maxBid,
        'auctionHistory': [
          for (final record in auctionHistory) record.toJson()
        ],
        'auctionClosed': auctionClosed,
        'canDeclareBelote': canDeclareBelote,
        'canDeclareRebelote': canDeclareRebelote,
        'holdsBelote': holdsBelote,
        'beloteDeclared': beloteDeclared,
        'beloteCompleted': beloteCompleted,
        'beloteDeclined': beloteDeclined,
        'beloteTeam': beloteTeam,
        'canStartNextDeal': canStartNextDeal,
        'events': [for (final event in events) event.toJson()],
        'eventSeq': eventSeq,
        'redeals': redeals,
        'dealsStarted': dealsStarted,
      };

  static PlayerView fromJson(Map<String, dynamic> json) {
    Map<int, int> intMap(Object? raw) {
      if (raw is! Map) return {};
      return {
        for (final entry in raw.entries)
          int.parse('${entry.key}'): entry.value as int,
      };
    }

    return PlayerView(
      seat: json['seat'] as int,
      phase: json['phase'] as String,
      dealerSeat: json['dealerSeat'] as int,
      turnSeat: json['turnSeat'] as int?,
      isMyTurn: json['isMyTurn'] as bool,
      contract: json['contract'] == null
          ? null
          : Contract.fromJson(
              Map<String, dynamic>.from(json['contract'] as Map),
            ),
      trump:
          json['trump'] == null ? null : Suit.fromCode(json['trump'] as String),
      hand: [
        for (final card in (json['hand'] as List? ?? const []))
          Card.parse(card as String),
      ],
      handCounts: intMap(json['handCounts']),
      currentTrick: [
        for (final play in (json['currentTrick'] as List? ?? const []))
          PlayedCard.fromJson(Map<String, dynamic>.from(play as Map)),
      ],
      legalCards: [
        for (final card in (json['legalCards'] as List? ?? const []))
          Card.parse(card as String),
      ],
      lastTrick: json['lastTrick'] == null
          ? null
          : TrickRecord.fromJson(
              Map<String, dynamic>.from(json['lastTrick'] as Map),
            ),
      lastTrickWinnerSeat: json['lastTrickWinnerSeat'] as int?,
      tricksPlayed: json['tricksPlayed'] as int? ?? 0,
      cardPointsByTeam: intMap(json['cardPointsByTeam']),
      tricksByTeam: intMap(json['tricksByTeam']),
      setScores: intMap(json['setScores']),
      setsWon: intMap(json['setsWon']),
      setNumber: json['setNumber'] as int? ?? 1,
      setTarget: json['setTarget'] as int? ?? 2000,
      maxSets: json['maxSets'] as int? ?? 3,
      isBelle: json['isBelle'] as bool? ?? false,
      matchWinner: json['matchWinner'] as int?,
      earlyStopped: json['earlyStopped'] as bool? ?? false,
      earlyStopReason: json['earlyStopReason'] as String?,
      result: json['result'] == null
          ? null
          : DealResult.fromJson(
              Map<String, dynamic>.from(json['result'] as Map),
            ),
      canPass: json['canPass'] as bool? ?? false,
      canBidNumbers: json['canBidNumbers'] as bool? ?? false,
      canCapot: json['canCapot'] as bool? ?? false,
      canCounter: json['canCounter'] as bool? ?? false,
      canSurcounter: json['canSurcounter'] as bool? ?? false,
      minimumBid: json['minimumBid'] as int? ?? 90,
      maxBid: json['maxBid'] as int? ?? 180,
      auctionHistory: [
        for (final record in (json['auctionHistory'] as List? ?? const []))
          BidRecord(
            seat: (record as Map)['seat'] as int,
            action: BidAction.fromJson(
              Map<String, dynamic>.from(record),
            ),
          ),
      ],
      auctionClosed: json['auctionClosed'] as bool? ?? false,
      canDeclareBelote: json['canDeclareBelote'] as bool? ?? false,
      canDeclareRebelote: json['canDeclareRebelote'] as bool? ?? false,
      holdsBelote: json['holdsBelote'] as bool? ?? false,
      beloteDeclared: json['beloteDeclared'] as bool? ?? false,
      beloteCompleted: json['beloteCompleted'] as bool? ?? false,
      beloteDeclined: json['beloteDeclined'] as bool? ?? false,
      beloteTeam: json['beloteTeam'] as int?,
      canStartNextDeal: json['canStartNextDeal'] as bool? ?? false,
      events: [
        for (final event in (json['events'] as List? ?? const []))
          GameEvent.fromJson(Map<String, dynamic>.from(event as Map)),
      ],
      eventSeq: json['eventSeq'] as int? ?? 0,
      redeals: json['redeals'] as int? ?? 0,
      dealsStarted: json['dealsStarted'] as int? ?? 0,
    );
  }
}
