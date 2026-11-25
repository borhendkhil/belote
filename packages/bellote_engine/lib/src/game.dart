import 'dart:math';

import 'auction.dart';
import 'card.dart';
import 'contract.dart';
import 'deal.dart';
import 'events.dart';
import 'view.dart';

enum MatchFormat { bestOf3, bestOf5, singleSet }

class GameConfig {
  const GameConfig({
    this.format = MatchFormat.bestOf3,
    this.initialDealer,
    this.redealOnSevenOrEightSameSuit = true,
    this.redealOnHeavyHand = true,
    this.heavyHandLimit = 12,
    this.maxHeavyHandRedeals = 40,
    this.earlyStopEnabled = true,
    this.random,
    this.deckFactory,
  });

  final MatchFormat format;
  final int? initialDealer;
  final bool redealOnSevenOrEightSameSuit;

  /// Redistribue tant qu'une main dépasse [heavyHandLimit] points.
  final bool redealOnHeavyHand;

  /// Seuil de points d'une main (valeurs hors atout) déclenchant une
  /// redistribution.
  final int heavyHandLimit;

  /// Nombre maximal de redistributions tentées pour la règle des points.
  ///
  /// Avec les valeurs usuelles la quasi-totalité des mains dépasse 12 points :
  /// on conserve alors la distribution la plus légère rencontrée afin de
  /// garantir que la partie démarre toujours.
  final int maxHeavyHandRedeals;

  /// Désactivable pour les tests du comptage normal.
  final bool earlyStopEnabled;
  final Random? random;

  /// Source de deck déterministe pour les tests.
  final List<Card> Function()? deckFactory;

  int get setTarget => format == MatchFormat.singleSet ? 3000 : 2000;

  int get setsToWin => switch (format) {
        MatchFormat.bestOf3 => 2,
        MatchFormat.bestOf5 => 3,
        MatchFormat.singleSet => 1,
      };

  int get maxSets => switch (format) {
        MatchFormat.bestOf3 => 3,
        MatchFormat.bestOf5 => 5,
        MatchFormat.singleSet => 1,
      };
}

enum GamePhase {
  bidding,
  playing,
  dealComplete,
  setComplete,
  matchComplete,
}

/// Partie complète : rotation du donneur, sets, belle et score cumulé.
class BelloteGame {
  BelloteGame({required this.config})
      : _random = config.random ?? Random(),
        dealerSeat =
            config.initialDealer ?? (config.random ?? Random()).nextInt(4);

  final GameConfig config;
  final Random _random;
  final EventLog log = EventLog();

  int dealerSeat;
  Deal? _deal;

  final Map<int, int> setScores = {0: 0, 1: 0};
  final Map<int, int> setsWon = {0: 0, 1: 0};
  int setNumber = 1;

  int? matchWinner;
  GamePhase phase = GamePhase.bidding;
  bool started = false;

  final List<DealResult> results = [];
  final List<int> setWinners = [];
  final List<Map<int, int>> completedSetScores = [];

  int _dealsStarted = 0;
  int _redeals = 0;

  Deal? get deal => _deal;

  bool get isBelle =>
      config.maxSets > 1 && setNumber == config.maxSets && matchWinner == null;

  bool get isMatchOver => matchWinner != null;

  int? get setLeader {
    final a = setScores[0] ?? 0;
    final b = setScores[1] ?? 0;
    if (a == b) return null;
    return a > b ? 0 : 1;
  }

  /// Démarre la partie et distribue la première donne.
  void start() {
    if (started) throw StateError('La partie a déjà démarré');
    started = true;
    _startDeal();
  }

  void _startDeal() {
    if (isMatchOver) throw StateError('La partie est terminée');

    var attempts = 0;
    while (true) {
      attempts++;
      if (attempts > 1000) {
        throw StateError('Impossible de distribuer une donne valide');
      }
      final hands = _dealHands();
      if (config.redealOnSevenOrEightSameSuit &&
          Deal.anyHandNeedsRedeal(hands)) {
        _redeals++;
        log.add('redeal', {
          'reason': 'seven_or_eight_same_suit',
          'dealerSeat': dealerSeat,
          'nextDealerSeat': nextSeat(dealerSeat),
          'setNumber': setNumber,
        });
        dealerSeat = nextSeat(dealerSeat);
        continue;
      }

      final dealtHands = _applyHeavyHandRedeal(hands);

      _dealsStarted++;
      _deal = Deal.start(
        dealerSeat: dealerSeat,
        hands: dealtHands,
        log: log,
      );
      phase = GamePhase.bidding;
      log.add('deal_started', {
        'dealerSeat': dealerSeat,
        'setNumber': setNumber,
        'dealNumber': _dealsStarted,
        'handCounts': {
          for (final entry in dealtHands.entries)
            '${entry.key}': entry.value.length,
        },
      });
      return;
    }
  }

  /// Applique la règle « une main de plus de [GameConfig.heavyHandLimit]
  /// points est redistribuée ».
  ///
  /// La distribution est retirée jusqu'à [GameConfig.maxHeavyHandRedeals]
  /// fois. Comme presque toutes les mains dépassent le seuil, on garde la
  /// distribution la plus légère rencontrée plutôt que de bloquer la partie.
  Map<int, List<Card>> _applyHeavyHandRedeal(Map<int, List<Card>> hands) {
    if (!config.redealOnHeavyHand || config.deckFactory != null) return hands;

    var best = hands;
    var bestScore = Deal.heaviestHandPoints(best);
    if (bestScore <= config.heavyHandLimit) return best;

    for (var attempt = 0; attempt < config.maxHeavyHandRedeals; attempt++) {
      final candidate = _dealHands();
      if (config.redealOnSevenOrEightSameSuit &&
          Deal.anyHandNeedsRedeal(candidate)) {
        continue;
      }
      final score = Deal.heaviestHandPoints(candidate);
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
      if (bestScore <= config.heavyHandLimit) break;
    }
    return best;
  }

  Map<int, List<Card>> _dealHands() {
    final deck = config.deckFactory?.call() ?? fullDeck();
    if (deck.length != 32) {
      throw StateError('Le deck doit contenir exactement 32 cartes');
    }
    final ids = deck.map((card) => card.id).toSet();
    if (ids.length != 32) {
      throw StateError('Le deck contient des doublons');
    }
    final shuffled =
        config.deckFactory != null ? [...deck] : (deck..shuffle(_random));
    return {
      for (var seat = 0; seat < 4; seat++)
        seat: shuffled.sublist(seat * 8, seat * 8 + 8),
    };
  }

  void placeBid(int seat, BidAction action) {
    if (phase != GamePhase.bidding || _deal == null) {
      throw const RuleViolation('not_bidding_phase');
    }

    _deal!.placeBid(seat, action);

    if (_deal!.needsRedeal) {
      log.add('redeal', {
        'reason': 'all_pass',
        'dealerSeat': dealerSeat,
        'nextDealerSeat': nextSeat(dealerSeat),
        'setNumber': setNumber,
      });
      _redeals++;
      dealerSeat = nextSeat(dealerSeat);
      _startDeal();
      return;
    }

    if (_deal!.phase == DealPhase.playing) {
      phase = GamePhase.playing;
    }
  }

  void playCard(
    int seat,
    Card card, {
    bool declareBelote = false,
  }) {
    if (phase != GamePhase.playing || _deal == null) {
      throw const RuleViolation('not_playing_phase');
    }

    _deal!.playCard(seat, card, declareBelote: declareBelote);

    if (_deal!.isComplete) {
      _completeDeal(_deal!.result!);
    }
  }

  void _completeDeal(DealResult result) {
    results.add(result);
    setScores[0] = (setScores[0] ?? 0) + result.pointsByTeam[0]!;
    setScores[1] = (setScores[1] ?? 0) + result.pointsByTeam[1]!;

    log.add('set_score', {
      'team0': setScores[0],
      'team1': setScores[1],
      'dealPoints': {
        '0': result.pointsByTeam[0],
        '1': result.pointsByTeam[1],
      },
      'setNumber': setNumber,
    });

    final target = config.setTarget;
    final a = setScores[0]!;
    final b = setScores[1]!;
    final targetReached = a >= target || b >= target;

    if (!targetReached) {
      phase = GamePhase.dealComplete;
      return;
    }

    if (a == b) {
      // Égalité exacte au-dessus du seuil : nouvelle donne dans le même set.
      phase = GamePhase.dealComplete;
      log.add('set_tie_replay', {
        'team0': a,
        'team1': b,
        'setNumber': setNumber,
      });
      return;
    }

    final winner = a > b ? 0 : 1;
    setsWon[winner] = (setsWon[winner] ?? 0) + 1;
    setWinners.add(winner);
    completedSetScores.add(Map.unmodifiable(Map.of(setScores)));

    log.add('set_end', {
      'winner': winner,
      'team0': a,
      'team1': b,
      'setNumber': setNumber,
      'setsWon': {'0': setsWon[0], '1': setsWon[1]},
    });

    if (setsWon[winner]! >= config.setsToWin) {
      matchWinner = winner;
      phase = GamePhase.matchComplete;
      log.add('match_end', {
        'winner': winner,
        'setsWon': {'0': setsWon[0], '1': setsWon[1]},
      });
    } else {
      phase = GamePhase.setComplete;
    }
  }

  /// Démarre la donne suivante (après une donne ou un set terminé).
  void nextDeal() {
    if (phase == GamePhase.matchComplete) {
      throw StateError('La partie est terminée');
    }
    if (phase != GamePhase.dealComplete && phase != GamePhase.setComplete) {
      throw const RuleViolation('deal_not_complete');
    }

    if (phase == GamePhase.setComplete) {
      setNumber++;
      setScores[0] = 0;
      setScores[1] = 0;
    }

    dealerSeat = nextSeat(dealerSeat);
    _deal = null;
    _startDeal();
  }

  /// Vue filtrée pour un joueur. Ne révèle jamais les mains adverses.
  PlayerView viewFor(int seat) {
    if (seat < 0 || seat > 3) {
      throw ArgumentError.value(seat, 'seat');
    }
    final deal = _deal;
    final contract = deal?.contract;

    final bidding = phase == GamePhase.bidding && deal != null;
    final playing = phase == GamePhase.playing && deal != null;
    final auction = deal?.auction;

    final legalCards = playing ? deal.legalCardsFor(seat) : <Card>{};
    final isTurn = bidding
        ? auction!.turnSeat == seat
        : playing
            ? deal.currentTurnSeat == seat
            : false;

    final canBidNumbers = bidding &&
        isTurn &&
        auction!.counter == CounterState.none &&
        (auction.amount ?? 0) < 180;
    final canCapot = bidding && isTurn && auction!.counter == CounterState.none;
    final canCounter = bidding && auction!.canPerform(seat, const CounterBid());
    final canSurcounter =
        bidding && auction!.canPerform(seat, const SurcounterBid());
    final canPass =
        bidding && isTurn && auction!.validate(seat, const PassBid()) == null;

    final tracker = deal?.belote;
    final dealComplete = deal?.phase == DealPhase.complete;

    return PlayerView(
      seat: seat,
      phase: phase.name,
      dealerSeat: dealerSeat,
      turnSeat: bidding
          ? auction!.turnSeat
          : playing
              ? deal.currentTurnSeat
              : null,
      isMyTurn: isTurn,
      contract: contract,
      trump: contract?.trump ?? auction?.trump,
      hand: deal == null
          ? const []
          : sortHand(deal.handOf(seat), trump: contract?.trump),
      handCounts: deal?.handCounts ?? const {0: 0, 1: 0, 2: 0, 3: 0},
      currentTrick:
          deal == null ? const [] : List.unmodifiable(deal.currentPlays),
      legalCards: sortHand(legalCards.toList(), trump: contract?.trump),
      lastTrick: deal?.lastTrick,
      lastTrickWinnerSeat: deal?.lastTrickWinnerSeat,
      tricksPlayed: deal?.tricksPlayed ?? 0,
      cardPointsByTeam: Map.unmodifiable(
        deal?.cardPointsByTeam ?? const {0: 0, 1: 0},
      ),
      tricksByTeam: Map.unmodifiable(
        deal?.tricksWonByTeam ?? const {0: 0, 1: 0},
      ),
      setScores: Map.unmodifiable(setScores),
      setsWon: Map.unmodifiable(setsWon),
      setNumber: setNumber,
      setTarget: config.setTarget,
      maxSets: config.maxSets,
      isBelle: isBelle,
      matchWinner: matchWinner,
      earlyStopped: deal?.earlyStopped ?? false,
      earlyStopReason: deal?.result?.earlyStopReason,
      result: dealComplete ? deal!.result : null,
      canPass: canPass,
      canBidNumbers: canBidNumbers,
      canCapot: canCapot,
      canCounter: canCounter,
      canSurcounter: canSurcounter,
      minimumBid: auction?.minimumAmount ?? 90,
      maxBid: 180,
      auctionHistory: auction?.history ?? const [],
      auctionClosed: auction?.closed ?? false,
      canDeclareBelote: playing && (deal.canDeclareBelote(seat)),
      holdsBelote: tracker?.holds[seat] == true,
      beloteDeclared: tracker?.declaredFirst[seat] == true,
      beloteCompleted: tracker?.completed[seat] == true,
      beloteDeclined: tracker?.declined[seat] == true,
      beloteTeam: tracker?.completedTeam,
      canStartNextDeal:
          phase == GamePhase.dealComplete || phase == GamePhase.setComplete,
      events: log.recent(50),
      eventSeq: log.lastSeq,
      redeals: _redeals,
      dealsStarted: _dealsStarted,
    );
  }

  Map<String, dynamic> toJson() => {
        'config': {
          'format': config.format.name,
          'setTarget': config.setTarget,
          'setsToWin': config.setsToWin,
          'maxSets': config.maxSets,
        },
        'dealerSeat': dealerSeat,
        'setScores': {'0': setScores[0], '1': setScores[1]},
        'setsWon': {'0': setsWon[0], '1': setsWon[1]},
        'setNumber': setNumber,
        'matchWinner': matchWinner,
        'phase': phase.name,
        'results': [for (final result in results) result.toJson()],
      };
}
