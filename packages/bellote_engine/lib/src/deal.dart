import 'auction.dart';
import 'belote.dart';
import 'card.dart';
import 'contract.dart';
import 'events.dart';
import 'rules.dart';
import 'scoring.dart';

enum DealPhase { bidding, playing, complete, redeal }

class DealResult {
  const DealResult({
    required this.contract,
    required this.score,
    required this.tricksPlayed,
    required this.earlyStopped,
    required this.cardPointsByTeam,
    required this.tricksByTeam,
    required this.beloteTeam,
    this.earlyStopReason,
  });

  final Contract contract;
  final ScoreBreakdown score;
  final int tricksPlayed;
  final bool earlyStopped;
  final Map<int, int> cardPointsByTeam;
  final Map<int, int> tricksByTeam;
  final int? beloteTeam;
  final String? earlyStopReason;

  int get attackTeam => contract.team;

  int get defenseTeam => contract.defenseTeam;

  bool get contractMade => score.contractMade;

  Map<int, int> get pointsByTeam => {
        0: score.pointsFor(0),
        1: score.pointsFor(1),
      };

  Map<String, dynamic> toJson() => {
        'contract': contract.toJson(),
        'score': score.toJson(),
        'tricksPlayed': tricksPlayed,
        'earlyStopped': earlyStopped,
        'earlyStopReason': earlyStopReason,
        'cardPointsByTeam': {
          for (final entry in cardPointsByTeam.entries)
            '${entry.key}': entry.value,
        },
        'tricksByTeam': {
          for (final entry in tricksByTeam.entries) '${entry.key}': entry.value,
        },
        'beloteTeam': beloteTeam,
        'pointsByTeam': {
          for (final entry in pointsByTeam.entries) '${entry.key}': entry.value,
        },
      };

  static DealResult fromJson(Map<String, dynamic> json) => DealResult(
        contract: Contract.fromJson(
          Map<String, dynamic>.from(json['contract'] as Map),
        ),
        score: ScoreBreakdown.fromJson(
          Map<String, dynamic>.from(json['score'] as Map),
        ),
        tricksPlayed: json['tricksPlayed'] as int,
        earlyStopped: json['earlyStopped'] as bool,
        earlyStopReason: json['earlyStopReason'] as String?,
        cardPointsByTeam: {
          for (final entry in (json['cardPointsByTeam'] as Map).entries)
            int.parse('${entry.key}'): entry.value as int,
        },
        tricksByTeam: {
          for (final entry in (json['tricksByTeam'] as Map).entries)
            int.parse('${entry.key}'): entry.value as int,
        },
        beloteTeam: json['beloteTeam'] as int?,
      );
}

/// Une donne : enchères puis jeu des cartes.
class Deal {
  Deal._({
    required this.dealerSeat,
    required Map<int, List<Card>> hands,
    required this.auction,
    required this.log,
  }) : _hands = {
          for (final entry in hands.entries) entry.key: [...entry.value],
        } {
    currentTurnSeat = nextSeat(dealerSeat);
  }

  /// Donne démarrant par la phase d'enchères.
  factory Deal.start({
    required int dealerSeat,
    required Map<int, List<Card>> hands,
    required EventLog log,
  }) {
    return Deal._(
      dealerSeat: dealerSeat,
      hands: hands,
      auction: Auction(
        dealerSeat: dealerSeat,
        firstBidderSeat: nextSeat(dealerSeat),
      ),
      log: log,
    );
  }

  /// Donne construite directement en phase de jeu (tests, reprise).
  factory Deal.readyToPlay({
    required int dealerSeat,
    required Map<int, List<Card>> hands,
    required Contract contract,
    required EventLog log,
  }) {
    final auction = Auction(
      dealerSeat: dealerSeat,
      firstBidderSeat: nextSeat(dealerSeat),
    )
      ..amount = contract.amount
      ..trump = contract.trump
      ..bidderSeat = contract.bidderSeat
      ..counter = contract.counter
      ..closed = true
      ..contract = contract;

    final deal = Deal._(
      dealerSeat: dealerSeat,
      hands: hands,
      auction: auction,
      log: log,
    );
    deal.phase = DealPhase.playing;
    deal.contract = contract;
    deal.currentTurnSeat = nextSeat(dealerSeat);
    deal.belote = BeloteTracker(trump: contract.trump, hands: deal._hands);
    return deal;
  }

  final int dealerSeat;
  final Map<int, List<Card>> _hands;
  final Auction auction;
  final EventLog log;

  DealPhase phase = DealPhase.bidding;
  Contract? contract;
  BeloteTracker? belote;

  int currentTurnSeat = 0;
  final List<TrickRecord> tricks = [];
  final List<PlayedCard> currentPlays = [];
  int? currentLeaderSeat;

  final Map<int, int> cardPointsByTeam = {0: 0, 1: 0};
  final Map<int, int> tricksWonByTeam = {0: 0, 1: 0};
  final Map<int, List<Card>> wonCardsByTeam = {0: [], 1: []};

  bool earlyStopped = false;
  DealResult? result;
  TrickRecord? lastTrick;
  int? lastTrickWinnerSeat;

  int get tricksPlayed => tricks.length;

  bool get isComplete => phase == DealPhase.complete;

  bool get needsRedeal => phase == DealPhase.redeal;

  int get defenseTeam => contract!.defenseTeam;

  List<Card> handOf(int seat) => List.unmodifiable(_hands[seat] ?? const []);

  Map<int, int> get handCounts => {
        for (final entry in _hands.entries) entry.key: entry.value.length,
      };

  int get remainingCardPoints {
    if (contract == null) return 0;
    final trump = contract!.trump;
    return _hands.values
        .expand((hand) => hand)
        .fold(0, (sum, card) => sum + card.points(trump));
  }

  /// Vérifie si une main contient 7 ou 8 cartes de la même couleur.
  static bool handNeedsRedeal(List<Card> hand) {
    final counts = <Suit, int>{};
    for (final card in hand) {
      counts[card.suit] = (counts[card.suit] ?? 0) + 1;
    }
    return counts.values.any((count) => count >= 7);
  }

  static bool anyHandNeedsRedeal(Map<int, List<Card>> hands) =>
      hands.values.any(handNeedsRedeal);

  // ---------------------------------------------------------------------------
  // Enchères
  // ---------------------------------------------------------------------------

  void placeBid(int seat, BidAction action) {
    if (phase != DealPhase.bidding) {
      throw const RuleViolation('not_bidding_phase');
    }
    final record = auction.perform(seat, action);

    switch (record.action) {
      case PassBid():
        log.add('pass', {'seat': seat});
      case NumberBid(:final amount, :final trump):
        log.add('bid', {
          'seat': seat,
          'amount': amount,
          'suit': trump.name,
        });
      case CapotBid(:final trump):
        log.add('capot', {'seat': seat, 'suit': trump.name});
      case CounterBid():
        log.add('counter', {'seat': seat});
      case SurcounterBid():
        log.add('surcounter', {'seat': seat});
    }

    if (auction.allPassed) {
      phase = DealPhase.redeal;
      return;
    }

    if (auction.closed) {
      contract = auction.contract!;
      belote = BeloteTracker(trump: contract!.trump, hands: _hands);
      phase = DealPhase.playing;
      currentTurnSeat = nextSeat(dealerSeat);
      log.add('contract', {
        ...contract!.toJson(),
        'demandeurSeat': contract!.demandeurSeat,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Jeu des cartes
  // ---------------------------------------------------------------------------

  Set<Card> legalCardsFor(int seat) {
    if (phase != DealPhase.playing || seat != currentTurnSeat) return const {};
    final contract = this.contract;
    if (contract == null) return const {};
    return TrickRules.legalCards(
      seat: seat,
      hand: _hands[seat] ?? const [],
      trick: currentPlays,
      trump: contract.trump,
    );
  }

  bool canDeclareBelote(int seat) =>
      phase == DealPhase.playing &&
      belote != null &&
      belote!.canStillDeclareFirst(seat);

  bool canDeclareRebelote(int seat) =>
      phase == DealPhase.playing &&
      belote != null &&
      belote!.declaredFirst[seat] == true &&
      belote!.completed[seat] != true &&
      _hands[seat]!.any((card) => belote!.isBeloteCard(seat, card));

  void playCard(
    int seat,
    Card card, {
    bool declareBelote = false,
    bool declareRebelote = false,
  }) {
    if (phase != DealPhase.playing) {
      throw const RuleViolation('not_playing_phase');
    }
    if (seat != currentTurnSeat) {
      throw RuleViolation('not_your_turn', {'seat': seat});
    }
    final hand = _hands[seat];
    if (hand == null || !hand.contains(card)) {
      throw RuleViolation('card_not_in_hand', {'card': card.id});
    }
    final legal = legalCardsFor(seat);
    if (!legal.contains(card)) {
      throw RuleViolation('illegal_card', {
        'card': card.id,
        'legal': [for (final legalCard in legal) legalCard.id],
      });
    }

    hand.remove(card);

    if (declareBelote && belote!.canDeclareFirst(seat, card)) {
      log.add('belote', {'seat': seat});
    }
    if (declareRebelote && belote!.canDeclareRebelote(seat, card)) {
      log.add('rebelote', {'seat': seat});
    }
    belote!.onCardPlayed(
      seat,
      card,
      declareBelote: declareBelote,
      declareRebelote: declareRebelote,
    );

    final play = PlayedCard(seat: seat, card: card);
    if (currentPlays.isEmpty) currentLeaderSeat = seat;
    currentPlays.add(play);
    log.add('play', {
      'seat': seat,
      'card': card.id,
      'belote': declareBelote && belote!.declaredFirst[seat] == true,
      'rebelote': declareRebelote && belote!.completed[seat] == true,
    });

    if (currentPlays.length < 4) {
      currentTurnSeat = nextSeat(seat);
      return;
    }

    _completeTrick();
  }

  void _completeTrick() {
    final contract = this.contract!;
    final trump = contract.trump;
    final winnerSeat = trickWinnerSeat(currentPlays, trump);
    final points = trickCardPoints(currentPlays, trump);
    final winningTeam = teamOf(winnerSeat);

    final record = TrickRecord(
      leaderSeat: currentLeaderSeat ?? currentPlays.first.seat,
      plays: List.unmodifiable(currentPlays),
      winnerSeat: winnerSeat,
      points: points,
      winningTeam: winningTeam,
    );

    tricks.add(record);
    lastTrick = record;
    lastTrickWinnerSeat = winnerSeat;
    currentPlays.clear();
    currentLeaderSeat = null;

    cardPointsByTeam[winningTeam] =
        (cardPointsByTeam[winningTeam] ?? 0) + points;
    tricksWonByTeam[winningTeam] = (tricksWonByTeam[winningTeam] ?? 0) + 1;
    wonCardsByTeam[winningTeam]!.addAll(
      record.plays.map((play) => play.card),
    );

    log.add('trick', {
      'winnerSeat': winnerSeat,
      'winningTeam': winningTeam,
      'points': points,
      'trickNumber': tricks.length,
      'plays': [for (final play in record.plays) play.toJson()],
    });

    if (contract.isCapot) {
      final defenseWon = (tricksWonByTeam[contract.defenseTeam] ?? 0) > 0;
      if (defenseWon) {
        earlyStopped = true;
        log.add('early_stop', {
          'reason': 'capot_defense_trick',
          'tricksPlayed': tricks.length,
        });
        _finish(earlyStopped: true, reason: 'capot_defense_trick');
        return;
      }
    } else if (tricks.length < 8) {
      final maximum = maximumAttackRaw;
      final rounded = roundToTen(maximum);
      if (rounded < contract.target) {
        earlyStopped = true;
        log.add('early_stop', {
          'reason': 'contract_impossible',
          'maximumRaw': maximum,
          'maximumRounded': rounded,
          'contractAmount': contract.target,
          'tricksPlayed': tricks.length,
        });
        _finish(earlyStopped: true, reason: 'contract_impossible');
        return;
      }
    }

    if (tricks.length >= 8) {
      _finish(earlyStopped: false);
      return;
    }

    currentTurnSeat = winnerSeat;
  }

  /// Maximum théorique de points de l'attaque après le pli courant.
  int get maximumAttackRaw {
    final contract = this.contract!;
    final attack = contract.team;
    final beloteValue = belote;
    final beloteSecured = beloteValue?.completedTeam == attack;
    final canStillEarn =
        !beloteSecured && (beloteValue?.canStillEarn(attack) ?? false);

    return maximumAttackPoints(
      attackPointsSecured: cardPointsByTeam[attack] ?? 0,
      remainingCardPoints: remainingCardPoints,
      tricksRemaining: 8 - tricks.length,
      attackBeloteCanStillBeEarned: canStillEarn,
      attackBeloteAlreadySecured: beloteSecured,
    );
  }

  int get maximumAttackRounded => roundToTen(maximumAttackRaw);

  void _finish({required bool earlyStopped, String? reason}) {
    final contract = this.contract!;
    final beloteTeam = belote?.completedTeam;
    final score = scoreDeal(
      DealScoreInput(
        contract: contract,
        cardPointsByTeam: cardPointsByTeam,
        tricksByTeam: tricksWonByTeam,
        tricksPlayed: tricks.length,
        lastTrickWinningTeam:
            tricks.length >= 8 ? teamOf(lastTrickWinnerSeat ?? 0) : null,
        beloteBonusTeam: beloteTeam,
        earlyStopped: earlyStopped,
      ),
    );

    result = DealResult(
      contract: contract,
      score: score,
      tricksPlayed: tricks.length,
      earlyStopped: earlyStopped,
      earlyStopReason: reason,
      cardPointsByTeam: Map.unmodifiable(cardPointsByTeam),
      tricksByTeam: Map.unmodifiable(tricksWonByTeam),
      beloteTeam: beloteTeam,
    );
    phase = DealPhase.complete;

    log.add('deal_end', {
      ...result!.toJson(),
      'earlyStopped': earlyStopped,
    });
  }
}
