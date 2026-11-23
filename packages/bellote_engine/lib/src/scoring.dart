import 'contract.dart';

/// Arrondi à la dizaine la plus proche (unité 5 arrondie au supérieur).
int roundToTen(int points) => ((points + 5) ~/ 10) * 10;

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.attackTeam,
    required this.defenseTeam,
    required this.rawAttack,
    required this.rawDefense,
    required this.roundedAttack,
    required this.roundedDefense,
    required this.contractMade,
    required this.attackPoints,
    required this.defensePoints,
    required this.earlyStopped,
    required this.capotNotCalled,
    this.beloteTeam,
    this.mode = 'B',
  });

  final int attackTeam;
  final int defenseTeam;
  final int rawAttack;
  final int rawDefense;
  final int roundedAttack;
  final int roundedDefense;
  final bool contractMade;
  final int attackPoints;
  final int defensePoints;
  final bool earlyStopped;
  final bool capotNotCalled;
  final int? beloteTeam;
  final String mode;

  int pointsFor(int team) => team == attackTeam ? attackPoints : defensePoints;

  Map<String, dynamic> toJson() => {
        'attackTeam': attackTeam,
        'defenseTeam': defenseTeam,
        'rawAttack': rawAttack,
        'rawDefense': rawDefense,
        'roundedAttack': roundedAttack,
        'roundedDefense': roundedDefense,
        'contractMade': contractMade,
        'attackPoints': attackPoints,
        'defensePoints': defensePoints,
        'earlyStopped': earlyStopped,
        'capotNotCalled': capotNotCalled,
        'beloteTeam': beloteTeam,
        'mode': mode,
      };

  static ScoreBreakdown fromJson(Map<String, dynamic> json) => ScoreBreakdown(
        attackTeam: json['attackTeam'] as int,
        defenseTeam: json['defenseTeam'] as int,
        rawAttack: json['rawAttack'] as int,
        rawDefense: json['rawDefense'] as int,
        roundedAttack: json['roundedAttack'] as int,
        roundedDefense: json['roundedDefense'] as int,
        contractMade: json['contractMade'] as bool,
        attackPoints: json['attackPoints'] as int,
        defensePoints: json['defensePoints'] as int,
        earlyStopped: json['earlyStopped'] as bool,
        capotNotCalled: json['capotNotCalled'] as bool,
        beloteTeam: json['beloteTeam'] as int?,
        mode: json['mode'] as String? ?? 'B',
      );
}

class DealScoreInput {
  const DealScoreInput({
    required this.contract,
    required this.cardPointsByTeam,
    required this.tricksByTeam,
    required this.tricksPlayed,
    required this.lastTrickWinningTeam,
    required this.beloteBonusTeam,
    required this.earlyStopped,
  });

  final Contract contract;
  final Map<int, int> cardPointsByTeam;
  final Map<int, int> tricksByTeam;
  final int tricksPlayed;
  final int? lastTrickWinningTeam;
  final int? beloteBonusTeam;
  final bool earlyStopped;
}

/// Comptage final d'une donne, y compris les cas de contrat chuté et de capot.
ScoreBreakdown scoreDeal(DealScoreInput input) {
  final contract = input.contract;
  final attack = contract.team;
  final defense = 1 - attack;

  var rawAttack = input.cardPointsByTeam[attack] ?? 0;
  var rawDefense = input.cardPointsByTeam[defense] ?? 0;

  final lastTrickPlayed = input.tricksPlayed >= 8;

  if (lastTrickPlayed && input.lastTrickWinningTeam != null) {
    if (input.lastTrickWinningTeam == attack) {
      rawAttack += 10;
    } else {
      rawDefense += 10;
    }
  }

  if (input.beloteBonusTeam == attack) rawAttack += 20;
  if (input.beloteBonusTeam == defense) rawDefense += 20;

  final roundedAttack = roundToTen(rawAttack);
  final roundedDefense = roundToTen(rawDefense);

  final attackTookAllTricks = (input.tricksByTeam[attack] ?? 0) == 8;
  final capotNotCalled = !contract.isCapot &&
      !contract.isCountered &&
      lastTrickPlayed &&
      attackTookAllTricks;

  var contractMade = false;
  var attackPoints = 0;
  var defensePoints = 0;

  if (contract.isCapot) {
    // Le capot demandé se juge uniquement au nombre de plis.
    contractMade = attackTookAllTricks && !input.earlyStopped;
    final winner = contractMade ? attack : defense;
    final beloteBonus = input.beloteBonusTeam != null ? 20 : 0;
    if (winner == attack) {
      attackPoints = 500 + beloteBonus;
      defensePoints = 0;
    } else {
      attackPoints = 0;
      defensePoints = 500 + beloteBonus;
    }
  } else if (!contract.isCountered) {
    if (capotNotCalled) {
      contractMade = true;
      attackPoints = 250 + (input.beloteBonusTeam == attack ? 20 : 0);
      defensePoints = input.beloteBonusTeam == defense ? 20 : 0;
    } else {
      contractMade = roundedAttack >= contract.target;
      if (contractMade) {
        attackPoints = roundedAttack;
        defensePoints = roundedDefense;
      } else {
        attackPoints = input.beloteBonusTeam == attack ? 20 : 0;
        defensePoints = 160 + (input.beloteBonusTeam == defense ? 20 : 0);
      }
    }
  } else {
    // Contrat contré ou surcontré : score fixe pour le gagnant.
    contractMade = roundedAttack >= contract.target;
    final base = contract.isSurcountered ? 640 : 320;
    final winner = contractMade ? attack : defense;
    final total = base + (input.beloteBonusTeam != null ? 20 : 0);
    if (winner == attack) {
      attackPoints = total;
      defensePoints = 0;
    } else {
      attackPoints = 0;
      defensePoints = total;
    }
  }

  return ScoreBreakdown(
    attackTeam: attack,
    defenseTeam: defense,
    rawAttack: rawAttack,
    rawDefense: rawDefense,
    roundedAttack: roundedAttack,
    roundedDefense: roundedDefense,
    contractMade: contractMade,
    attackPoints: attackPoints,
    defensePoints: defensePoints,
    earlyStopped: input.earlyStopped,
    capotNotCalled: capotNotCalled,
    beloteTeam: input.beloteBonusTeam,
  );
}

/// Calcule le maximum théorique de points de l'attaque après un pli complet.
int maximumAttackPoints({
  required int attackPointsSecured,
  required int remainingCardPoints,
  required int tricksRemaining,
  required bool attackBeloteCanStillBeEarned,
  required bool attackBeloteAlreadySecured,
}) {
  final lastTrickPotential = tricksRemaining > 0 ? 10 : 0;
  final securedBelote = attackBeloteAlreadySecured ? 20 : 0;
  final potentialBelote =
      attackBeloteCanStillBeEarned && !attackBeloteAlreadySecured ? 20 : 0;
  return attackPointsSecured +
      securedBelote +
      remainingCardPoints +
      lastTrickPotential +
      potentialBelote;
}

bool isOrdinaryContractImpossible({
  required int maximumRaw,
  required int contractAmount,
}) =>
    roundToTen(maximumRaw) < contractAmount;
