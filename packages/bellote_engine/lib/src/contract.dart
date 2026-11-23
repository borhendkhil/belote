import 'card.dart';

/// Type de contrat remporté par les enchères.
enum ContractType { points, capot }

/// État du contre.
enum CounterState { none, countered, surcountered }

bool sameTeam(int a, int b) => a % 2 == b % 2;

int teamOf(int seat) => seat % 2;

int nextSeat(int seat) => (seat + 1) % 4;

int partnerSeat(int seat) => (seat + 2) % 4;

/// Contrat définitif issu des enchères.
class Contract {
  const Contract({
    required this.type,
    required this.trump,
    required this.bidderSeat,
    required this.demandeurSeat,
    required this.counter,
    this.amount,
  });

  final ContractType type;
  final int? amount;
  final Suit trump;
  final int bidderSeat;
  final int demandeurSeat;
  final CounterState counter;

  bool get isCapot => type == ContractType.capot;

  int get team => teamOf(bidderSeat);

  int get defenseTeam => 1 - team;

  /// Montant du contrat à points. Vaut 0 pour un capot demandé.
  int get target => isCapot ? 0 : amount!;

  bool get isCountered => counter != CounterState.none;

  bool get isSurcountered => counter == CounterState.surcountered;

  /// Multiplicateur appliqué au score de base du contre.
  int get counterMultiplier => switch (counter) {
        CounterState.none => 1,
        CounterState.countered => 2,
        CounterState.surcountered => 4,
      };

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'amount': amount,
        'trump': trump.code,
        'bidderSeat': bidderSeat,
        'demandeurSeat': demandeurSeat,
        'counter': counter.name,
        'team': team,
      };

  static Contract fromJson(Map<String, dynamic> json) => Contract(
        type: ContractType.values.byName(json['type'] as String),
        amount: json['amount'] as int?,
        trump: Suit.fromCode(json['trump'] as String),
        bidderSeat: json['bidderSeat'] as int,
        demandeurSeat: json['demandeurSeat'] as int,
        counter: CounterState.values.byName(json['counter'] as String),
      );

  @override
  String toString() => isCapot
      ? 'Capot ${trump.name} par $bidderSeat'
      : '$amount ${trump.name} par $bidderSeat'
          '${counter == CounterState.countered ? ' (contré)' : counter == CounterState.surcountered ? ' (surcontré)' : ''}';
}
