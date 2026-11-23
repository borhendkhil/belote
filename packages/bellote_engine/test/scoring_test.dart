import 'package:bellote_engine/bellote_engine.dart';
import 'package:test/test.dart';

Contract contract({
  int amount = 100,
  Suit trump = Suit.hearts,
  int bidderSeat = 0,
  int? demandeurSeat,
  CounterState counter = CounterState.none,
  bool capot = false,
}) =>
    Contract(
      type: capot ? ContractType.capot : ContractType.points,
      amount: capot ? null : amount,
      trump: trump,
      bidderSeat: bidderSeat,
      demandeurSeat: demandeurSeat ?? bidderSeat,
      counter: counter,
    );

ScoreBreakdown score({
  required Contract c,
  required int attackCards,
  required int defenseCards,
  int? lastTrickWinnerTeam,
  int? beloteTeam,
  int tricksPlayed = 8,
  Map<int, int>? tricksByTeam,
  bool earlyStopped = false,
}) =>
    scoreDeal(
      DealScoreInput(
        contract: c,
        cardPointsByTeam: {0: attackCards, 1: defenseCards},
        tricksByTeam: tricksByTeam ?? {c.team: 5, c.defenseTeam: 3},
        tricksPlayed: tricksPlayed,
        lastTrickWinningTeam: lastTrickWinnerTeam,
        beloteBonusTeam: beloteTeam,
        earlyStopped: earlyStopped,
      ),
    );

void main() {
  group('Comptage des donnees', () {
    test('contrat 100, 94 et 68 : chuté, défense 160 (cas 1)', () {
      final result = score(
        c: contract(amount: 100),
        attackCards: 94,
        defenseCards: 58,
        lastTrickWinnerTeam: 1,
      );
      expect(result.roundedAttack, 90);
      expect(result.roundedDefense, 70);
      expect(result.contractMade, isFalse);
      expect(result.attackPoints, 0);
      expect(result.defensePoints, 160);
    });

    test('contrat 90, 85 et 77 : réussi, 90 / 80 (cas 2)', () {
      final result = score(
        c: contract(amount: 90),
        attackCards: 85,
        defenseCards: 67,
        lastTrickWinnerTeam: 1,
      );
      expect(result.roundedAttack, 90);
      expect(result.roundedDefense, 80);
      expect(result.contractMade, isTrue);
      expect(result.attackPoints, 90);
      expect(result.defensePoints, 80);
    });

    test('contrat 120, 105 + belote 20 = 125, défense 57 (cas 3)', () {
      final result = score(
        c: contract(amount: 120),
        attackCards: 105,
        defenseCards: 47,
        lastTrickWinnerTeam: 1,
        beloteTeam: 0,
      );
      expect(result.roundedAttack, 130);
      expect(result.roundedDefense, 60);
      expect(result.contractMade, isTrue);
      expect(result.attackPoints, 130);
      expect(result.defensePoints, 60);
    });

    test('contrat chuté, belote défense : défense 180, attaque 0 (cas 4)', () {
      final result = score(
        c: contract(amount: 100),
        attackCards: 40,
        defenseCards: 102,
        beloteTeam: 1,
      );
      expect(result.contractMade, isFalse);
      expect(result.attackPoints, 0);
      expect(result.defensePoints, 180);
    });

    test('contrat chuté, belote attaque : défense 160, attaque 20 (cas 5)', () {
      final result = score(
        c: contract(amount: 100),
        attackCards: 40,
        defenseCards: 102,
        beloteTeam: 0,
      );
      expect(result.contractMade, isFalse);
      expect(result.attackPoints, 20);
      expect(result.defensePoints, 160);
    });

    test('capot demandé réussi, belote défense : attaque 520 (cas 6)', () {
      final result = score(
        c: contract(capot: true),
        attackCards: 152,
        defenseCards: 0,
        lastTrickWinnerTeam: 0,
        beloteTeam: 1,
        tricksByTeam: {0: 8, 1: 0},
      );
      expect(result.contractMade, isTrue);
      expect(result.attackPoints, 520);
      expect(result.defensePoints, 0);
    });

    test('contré, attaque chute : défense 320 (cas 7)', () {
      final result = score(
        c: contract(amount: 100, counter: CounterState.countered),
        attackCards: 80,
        defenseCards: 72,
      );
      expect(result.contractMade, isFalse);
      expect(result.defensePoints, 320);
      expect(result.attackPoints, 0);
    });

    test('contré, belote déclarée : le gagnant reçoit 20 en plus', () {
      final result = score(
        c: contract(amount: 100, counter: CounterState.countered),
        attackCards: 70,
        defenseCards: 82,
        beloteTeam: 0,
      );
      expect(result.contractMade, isFalse);
      expect(result.defensePoints, 340);
      expect(result.attackPoints, 0);
    });

    test('surcontré : 640 pour le gagnant', () {
      final result = score(
        c: contract(amount: 160, counter: CounterState.surcountered),
        attackCards: 150,
        defenseCards: 2,
        tricksByTeam: {0: 7, 1: 1},
      );
      expect(result.contractMade, isFalse);
      expect(result.defensePoints, 640);
    });

    test('capot non demandé non contré : 250 à l\'attaque (cas 9.1)', () {
      final result = score(
        c: contract(amount: 120),
        attackCards: 152,
        defenseCards: 0,
        lastTrickWinnerTeam: 0,
        tricksByTeam: {0: 8, 1: 0},
      );
      expect(result.capotNotCalled, isTrue);
      expect(result.attackPoints, 250);
      expect(result.defensePoints, 0);
    });

    test('capot non demandé avec belote attaque : 270', () {
      final result = score(
        c: contract(amount: 120),
        attackCards: 152,
        defenseCards: 0,
        lastTrickWinnerTeam: 0,
        beloteTeam: 0,
        tricksByTeam: {0: 8, 1: 0},
      );
      expect(result.attackPoints, 270);
    });

    test('arrondi à la dizaine : 154→150, 155→160, 165→170', () {
      expect(roundToTen(154), 150);
      expect(roundToTen(155), 160);
      expect(roundToTen(156), 160);
      expect(roundToTen(163), 160);
      expect(roundToTen(165), 170);
    });

    test('pas de dix de der en cas d\'arrêt anticipé (cas 31)', () {
      final result = score(
        c: contract(amount: 120),
        attackCards: 80,
        defenseCards: 32,
        tricksPlayed: 7,
        beloteTeam: null,
        earlyStopped: true,
      );
      expect(result.rawAttack, 80);
      expect(result.attackPoints, 0);
      expect(result.defensePoints, 160);
    });

    test('aucune belote sans déclaration validée (cas 32)', () {
      final result = score(
        c: contract(amount: 120),
        attackCards: 60,
        defenseCards: 52,
        tricksPlayed: 7,
        beloteTeam: null,
        earlyStopped: true,
      );
      expect(result.attackPoints, 0);
      expect(result.defensePoints, 160);
    });
  });

  group('Arrêt anticipé', () {
    test('maximum 130 face à 120 : la donne continue (cas 23)', () {
      expect(
        isOrdinaryContractImpossible(maximumRaw: 130, contractAmount: 120),
        isFalse,
      );
    });

    test('maximum 120 face à 120 : la donne continue (cas 24)', () {
      expect(
        isOrdinaryContractImpossible(maximumRaw: 120, contractAmount: 120),
        isFalse,
      );
    });

    test('maximum 110 face à 120 : arrêt (cas 25)', () {
      expect(
        isOrdinaryContractImpossible(maximumRaw: 110, contractAmount: 120),
        isTrue,
      );
    });

    test('maximum théorique inclut les cartes restantes et le dix de der', () {
      final maximum = maximumAttackPoints(
        attackPointsSecured: 20,
        remainingCardPoints: 80,
        tricksRemaining: 4,
        attackBeloteCanStillBeEarned: false,
        attackBeloteAlreadySecured: false,
      );
      expect(maximum, 110);
    });

    test('maximum inclut une belote attaque encore réalisable (cas 29)', () {
      final maximum = maximumAttackPoints(
        attackPointsSecured: 0,
        remainingCardPoints: 100,
        tricksRemaining: 3,
        attackBeloteCanStillBeEarned: true,
        attackBeloteAlreadySecured: false,
      );
      expect(roundToTen(maximum), 130);
      expect(
        isOrdinaryContractImpossible(maximumRaw: maximum, contractAmount: 120),
        isFalse,
      );
    });

    test('belote non déclarable : maximum insuffisant, arrêt (cas 30)', () {
      final maximum = maximumAttackPoints(
        attackPointsSecured: 0,
        remainingCardPoints: 100,
        tricksRemaining: 3,
        attackBeloteCanStillBeEarned: false,
        attackBeloteAlreadySecured: false,
      );
      expect(roundToTen(maximum), 110);
      expect(
        isOrdinaryContractImpossible(maximumRaw: maximum, contractAmount: 120),
        isTrue,
      );
    });

    test('une belote déjà sécurisée n\'est pas comptée deux fois', () {
      final maximum = maximumAttackPoints(
        attackPointsSecured: 100,
        remainingCardPoints: 40,
        tricksRemaining: 2,
        attackBeloteCanStillBeEarned: false,
        attackBeloteAlreadySecured: true,
      );
      expect(maximum, 170);
    });
  });
}
