import 'card.dart';
import 'contract.dart';

/// Action possible pendant les enchères.
sealed class BidAction {
  const BidAction();

  String get type;

  Map<String, dynamic> toJson();

  static BidAction fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'pass':
        return const PassBid();
      case 'bid':
        return NumberBid(
          amount: json['amount'] as int,
          trump: Suit.fromName(json['suit'] as String),
        );
      case 'capot':
        return CapotBid(trump: Suit.fromName(json['suit'] as String));
      case 'counter':
        return const CounterBid();
      case 'surcounter':
        return const SurcounterBid();
      default:
        throw FormatException('Action d\'enchère inconnue: $type');
    }
  }
}

final class PassBid extends BidAction {
  const PassBid();

  @override
  String get type => 'pass';

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

final class NumberBid extends BidAction {
  const NumberBid({required this.amount, required this.trump});

  final int amount;
  final Suit trump;

  @override
  String get type => 'bid';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'suit': trump.name,
      };
}

final class CapotBid extends BidAction {
  const CapotBid({required this.trump});

  final Suit trump;

  @override
  String get type => 'capot';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'suit': trump.name};
}

final class CounterBid extends BidAction {
  const CounterBid();

  @override
  String get type => 'counter';

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

final class SurcounterBid extends BidAction {
  const SurcounterBid();

  @override
  String get type => 'surcounter';

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

class BidRecord {
  const BidRecord({
    required this.seat,
    required this.action,
  });

  final int seat;
  final BidAction action;

  Map<String, dynamic> toJson() => {
        'seat': seat,
        ...action.toJson(),
      };
}

/// Erreur de règle métier. Le serveur transforme le code en message localisé.
class RuleViolation implements Exception {
  const RuleViolation(this.code, [this.details]);

  final String code;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'RuleViolation($code)';
}

/// Machine à états des enchères.
class Auction {
  Auction({required this.dealerSeat, required this.firstBidderSeat})
      : turnSeat = firstBidderSeat;

  final int dealerSeat;
  final int firstBidderSeat;

  int turnSeat;
  int? amount;
  Suit? trump;
  int? bidderSeat;
  CounterState counter = CounterState.none;
  int passesInRow = 0;
  bool closed = false;
  bool allPassed = false;
  Contract? contract;

  final List<BidRecord> history = [];

  int get minimumAmount {
    if (amount == null) return 90;
    return amount! + 10;
  }

  bool get hasBid => bidderSeat != null;

  int? get contractTeam => bidderSeat == null ? null : teamOf(bidderSeat!);

  bool get bidsAllowed =>
      !closed &&
      counter == CounterState.none &&
      (amount == null || amount! < 180);

  /// Valide une action. Retourne `null` si elle est légale.
  String? validate(int seat, BidAction action) {
    if (seat < 0 || seat > 3) return 'invalid_seat';
    if (closed) return 'auction_closed';
    final isTurn = seat == turnSeat;

    switch (action) {
      case PassBid():
        if (!isTurn) return 'not_your_turn';
        return null;

      case NumberBid(:final amount):
        if (!isTurn) return 'not_your_turn';
        if (counter != CounterState.none) return 'bids_blocked_by_counter';
        if (amount < 90 || amount > 180 || amount % 10 != 0) {
          return 'invalid_bid_amount';
        }
        if (this.amount != null && amount <= this.amount!) {
          return 'bid_must_be_higher';
        }
        return null;

      case CapotBid():
        if (!isTurn) return 'not_your_turn';
        if (counter != CounterState.none) return 'bids_blocked_by_counter';
        return null;

      case CounterBid():
        // Le contre peut être annoncé hors tour.
        if (bidderSeat == null) return 'no_bid_to_counter';
        if (counter != CounterState.none) return 'already_countered';
        if (sameTeam(seat, bidderSeat!)) return 'cannot_counter_own_team';
        return null;

      case SurcounterBid():
        // Le surcontre peut être annoncé hors tour.
        if (bidderSeat == null) return 'no_bid_to_surcounter';
        if (counter != CounterState.countered)
          return 'no_counter_to_surcounter';
        if (!sameTeam(seat, bidderSeat!)) {
          return 'only_bidding_team_can_surcounter';
        }
        return null;
    }
  }

  bool canPerform(int seat, BidAction action) => validate(seat, action) == null;

  /// Applique une action validée. Lève une [RuleViolation] sinon.
  BidRecord perform(int seat, BidAction action) {
    final error = validate(seat, action);
    if (error != null) {
      throw RuleViolation(error, {
        'seat': seat,
        'action': action.toJson(),
      });
    }

    final wasTurn = seat == turnSeat;
    final record = BidRecord(seat: seat, action: action);
    history.add(record);

    switch (action) {
      case PassBid():
        passesInRow++;
        if (bidderSeat == null) {
          if (passesInRow >= 4) {
            allPassed = true;
            closed = true;
          }
        } else if (passesInRow >= 3) {
          closed = true;
        }

      case NumberBid(:final amount, :final trump):
        this.amount = amount;
        this.trump = trump;
        bidderSeat = seat;
        counter = CounterState.none;
        passesInRow = 0;

      case CapotBid(:final trump):
        this.trump = trump;
        bidderSeat = seat;
        amount = null;
        counter = CounterState.none;
        passesInRow = 0;
        closed = true;

      case CounterBid():
        counter = CounterState.countered;
        passesInRow = 0;

      case SurcounterBid():
        counter = CounterState.surcountered;
        closed = true;
    }

    if (closed && bidderSeat != null) {
      contract = Contract(
        type: amount == null ? ContractType.capot : ContractType.points,
        amount: amount,
        trump: trump!,
        bidderSeat: bidderSeat!,
        demandeurSeat: _findDemandeur(),
        counter: counter,
      );
    }

    if (!closed && wasTurn) {
      turnSeat = nextSeat(turnSeat);
    }

    return record;
  }

  /// Premier joueur de l'équipe preneuse ayant annoncé la couleur retenue.
  int _findDemandeur() {
    final team = teamOf(bidderSeat!);
    for (final record in history) {
      if (!sameTeam(record.seat, team)) continue;
      final action = record.action;
      if (action is NumberBid && action.trump == trump) return record.seat;
      if (action is CapotBid && action.trump == trump) return record.seat;
    }
    return bidderSeat!;
  }

  Map<String, dynamic> toJson() => {
        'turnSeat': turnSeat,
        'amount': amount,
        'trump': trump?.code,
        'bidderSeat': bidderSeat,
        'counter': counter.name,
        'passesInRow': passesInRow,
        'closed': closed,
        'allPassed': allPassed,
        'contract': contract?.toJson(),
        'history': [for (final record in history) record.toJson()],
      };
}
