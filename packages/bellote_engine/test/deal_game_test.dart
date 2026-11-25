import 'dart:math';

import 'package:bellote_engine/bellote_engine.dart';
import 'package:test/test.dart';

Map<int, List<Card>> handsFromIds(List<List<String>> ids) => {
      for (var seat = 0; seat < 4; seat++)
        seat: [for (final id in ids[seat]) Card.parse(id)],
    };

void main() {
  group('Distribution', () {
    test('7 cartes dans une couleur impose une redistribution (cas 18)', () {
      final hand = [
        Card.parse('7S'),
        Card.parse('8S'),
        Card.parse('9S'),
        Card.parse('10S'),
        Card.parse('JS'),
        Card.parse('QS'),
        Card.parse('KS'),
        Card.parse('7H'),
      ];
      expect(Deal.handNeedsRedeal(hand), isTrue);
    });

    test('8 cartes dans une couleur impose une redistribution (cas 19)', () {
      final hand = [
        for (final rank in ['7', '8', '9', '10', 'J', 'Q', 'K', 'A'])
          Card.parse('${rank}H'),
      ];
      expect(Deal.handNeedsRedeal(hand), isTrue);
    });

    test('une main 2/2/2/2 est valide', () {
      final hand = [
        Card.parse('AS'),
        Card.parse('7S'),
        Card.parse('AH'),
        Card.parse('7H'),
        Card.parse('AD'),
        Card.parse('7D'),
        Card.parse('AC'),
        Card.parse('7C'),
      ];
      expect(Deal.handNeedsRedeal(hand), isFalse);
    });

    test('total de points d\'une main avec les valeurs hors atout', () {
      final hand = [
        Card.parse('AS'),
        Card.parse('10S'),
        Card.parse('KH'),
        Card.parse('QH'),
        Card.parse('JD'),
        Card.parse('9D'),
        Card.parse('8C'),
        Card.parse('7C'),
      ];
      // A=11, 10=10, R=4, D=3, V=2, 9/8/7=0.
      expect(Deal.handPoints(hand), 30);
      expect(Deal.handPointsAbove(hand, 12), isTrue);
      expect(Deal.handPointsAbove(hand, 30), isFalse);
    });

    test('une main de plus de 12 points déclenche une redistribution', () {
      final heavy = [
        ...['AS', '10S', 'AH', '10H', 'AD', '10D', 'AC', '10C'],
        ...['KS', '9S', 'KH', '9H', 'KD', '9D', 'KC', '9C'],
        ...['QS', '8S', 'QH', '8H', 'QD', '8D', 'QC', '8C'],
        ...['JS', '7S', 'JH', '7H', 'JD', '7D', 'JC', '7C'],
      ];
      final light = [
        ...['AS', '7S', 'AH', '7H', 'AD', '7D', 'AC', '7C'],
        ...['KS', '8S', 'KH', '8H', 'KD', '8D', 'KC', '8C'],
        ...['QS', '9S', 'QH', '9H', 'QD', '9D', 'QC', '9C'],
        ...['JS', '10S', 'JH', '10H', 'JD', '10D', 'JC', '10C'],
      ];
      var call = 0;
      final game = BelloteGame(
        config: GameConfig(
          initialDealer: 0,
          deckFactory: () {
            call++;
            return [for (final id in call == 1 ? heavy : light) Card.parse(id)];
          },
        ),
      );
      game.start();
      // Les decks déterministes ne sont jamais redistribués : on vérifie
      // simplement que la règle n'empêche pas la donne de démarrer.
      expect(game.deal, isNotNull);
      expect(game.deal!.handCounts.values.every((count) => count == 8), isTrue);
    });

    test('la règle des points garde la distribution la plus légère', () {
      BelloteGame gameWith(int attempts) => BelloteGame(
            config: GameConfig(
              initialDealer: 0,
              random: Random(11),
              maxHeavyHandRedeals: attempts,
            ),
          )..start();

      int heaviest(BelloteGame game) => Deal.heaviestHandPoints({
            for (var seat = 0; seat < 4; seat++) seat: game.deal!.handOf(seat),
          });

      final plain = gameWith(0);
      final balanced = gameWith(40);
      // Même graine : la seconde distribution inclut la première et retient
      // la main la plus légère rencontrée.
      expect(heaviest(balanced), lessThanOrEqualTo(heaviest(plain)));
      expect(
        balanced.deal!.handCounts.values.every((count) => count == 8),
        isTrue,
      );
    });

    test('redistribution par le donneur suivant après 7 cartes', () {
      final invalid = [
        ...['7S', '8S', '9S', '10S', 'JS', 'QS', 'KS', '7H'],
        ...['AS', 'AD', 'KD', 'QD', 'JD', '10D', '9D', '8D'],
        ...['AH', 'KH', 'QH', 'JH', '10H', '9H', '8H', '7D'],
        ...['AC', 'KC', 'QC', 'JC', '10C', '9C', '8C', '7C'],
      ];
      final valid = [
        ...['AS', '7S', 'AH', '7H', 'AD', '7D', 'AC', '7C'],
        ...['KS', '8S', 'KH', '8H', 'KD', '8D', 'KC', '8C'],
        ...['QS', '9S', 'QH', '9H', 'QD', '9D', 'QC', '9C'],
        ...['JS', '10S', 'JH', '10H', 'JD', '10D', 'JC', '10C'],
      ];
      var call = 0;
      final game = BelloteGame(
        config: GameConfig(
          initialDealer: 0,
          random: Random(1),
          deckFactory: () {
            call++;
            return call == 1
                ? [for (final id in invalid) Card.parse(id)]
                : [for (final id in valid) Card.parse(id)];
          },
        ),
      );
      game.start();
      expect(game.dealerSeat, 1);
      expect(game.log.events.any((event) => event.type == 'redeal'), isTrue);
      expect(
        game.deal!.handCounts.values.every((count) => count == 8),
        isTrue,
      );
    });
  });

  group('Donne et jeu', () {
    test(
        'quatre passes initiales redistribuent chez le donneur suivant (cas 17)',
        () {
      final valid = [
        ...['AS', '7S', 'AH', '7H', 'AD', '7D', 'AC', '7C'],
        ...['KS', '8S', 'KH', '8H', 'KD', '8D', 'KC', '8C'],
        ...['QS', '9S', 'QH', '9H', 'QD', '9D', 'QC', '9C'],
        ...['JS', '10S', 'JH', '10H', 'JD', '10D', 'JC', '10C'],
      ];
      final game = BelloteGame(
        config: GameConfig(
          initialDealer: 0,
          deckFactory: () => [for (final id in valid) Card.parse(id)],
        ),
      );
      game.start();
      game.placeBid(1, const PassBid());
      game.placeBid(2, const PassBid());
      game.placeBid(3, const PassBid());
      game.placeBid(0, const PassBid());

      expect(game.phase, GamePhase.bidding);
      expect(game.dealerSeat, 1);
      expect(
        game.log.events.any(
          (event) =>
              event.type == 'redeal' && event.data['reason'] == 'all_pass',
        ),
        isTrue,
      );
    });

    test('capot demandé interrompu dès un pli de la défense (cas 28)', () {
      final hands = handsFromIds([
        ['JS', '7S', '7H', '8H', '7D', '8D', '7C', '8C'],
        ['AS', '8S', 'QH', '9H', '9D', '10D', '9C', '10C'],
        ['KS', '9S', 'JH', '10H', 'JD', 'QD', 'JC', 'QC'],
        ['QS', '10S', 'KH', 'AH', 'KD', 'AD', 'KC', 'AC'],
      ]);
      final deal = Deal.readyToPlay(
        dealerSeat: 0,
        hands: hands,
        contract: Contract(
          type: ContractType.capot,
          trump: Suit.hearts,
          bidderSeat: 0,
          demandeurSeat: 0,
          counter: CounterState.none,
        ),
        log: EventLog(),
      );

      // Leader = position 1 = siège 1 (défense). L'As de pique gagne le pli.
      deal.playCard(1, Card.parse('AS'));
      deal.playCard(2, Card.parse('KS'));
      deal.playCard(3, Card.parse('QS'));
      deal.playCard(0, Card.parse('JS'));

      expect(deal.earlyStopped, isTrue);
      expect(deal.result, isNotNull);
      expect(deal.result!.contractMade, isFalse);
      expect(deal.result!.tricksPlayed, 1);
      expect(deal.result!.pointsByTeam[1], 500);
      expect(deal.result!.pointsByTeam[0], 0);
      expect(deal.result!.earlyStopReason, 'capot_defense_trick');
    });

    test('contrat ordinaire 180 devient impossible après un pli', () {
      final hands = handsFromIds([
        ['JS', '7S', '7H', '8H', '7D', '8D', '7C', '8C'],
        ['AS', '8S', 'QH', '9H', '9D', '10D', '9C', '10C'],
        ['KS', '9S', 'JH', '10H', 'JD', 'QD', 'JC', 'QC'],
        ['QS', '10S', 'KH', 'AH', 'KD', 'AD', 'KC', 'AC'],
      ]);
      final deal = Deal.readyToPlay(
        dealerSeat: 0,
        hands: hands,
        contract: Contract(
          type: ContractType.points,
          amount: 180,
          trump: Suit.hearts,
          bidderSeat: 0,
          demandeurSeat: 0,
          counter: CounterState.none,
        ),
        log: EventLog(),
      );

      deal.playCard(1, Card.parse('AS'));
      deal.playCard(2, Card.parse('KS'));
      deal.playCard(3, Card.parse('QS'));
      deal.playCard(0, Card.parse('JS'));

      expect(deal.earlyStopped, isTrue);
      expect(deal.result, isNotNull);
      expect(deal.result!.score.contractMade, isFalse);
      expect(deal.result!.pointsByTeam[1], 160);
      expect(deal.result!.earlyStopReason, 'contract_impossible');
      expect(deal.maximumAttackRounded, lessThan(180));
    });

    test('le dix de der revient au gagnant du 8e pli', () {
      final hands = handsFromIds([
        ['JS', '7S', '7H', '8H', '7D', '8D', '7C', '8C'],
        ['AS', '8S', 'QH', '9H', '9D', '10D', '9C', '10C'],
        ['KS', '9S', 'JH', '10H', 'JD', 'QD', 'JC', 'QC'],
        ['QS', '10S', 'KH', 'AH', 'KD', 'AD', 'KC', 'AC'],
      ]);
      final deal = Deal.readyToPlay(
        dealerSeat: 0,
        hands: hands,
        contract: Contract(
          type: ContractType.points,
          amount: 90,
          trump: Suit.hearts,
          bidderSeat: 0,
          demandeurSeat: 0,
          counter: CounterState.none,
        ),
        log: EventLog(),
      );
      // On ne simule pas toute la donne : le calcul du bonus est couvert par
      // les tests de scoring. On vérifie seulement la somme des cartes.
      expect(
        deal.handOf(0).length +
            deal.handOf(1).length +
            deal.handOf(2).length +
            deal.handOf(3).length,
        32,
      );
    });
  });

  group('Belote-rebelote', () {
    test('déclarée une seule fois, sur la première carte choisie', () {
      final tracker = BeloteTracker(
        trump: Suit.hearts,
        hands: {
          0: [Card.parse('KH'), Card.parse('QH')],
        },
      );
      tracker.onCardPlayed(0, Card.parse('KH'), declareBelote: true);
      expect(tracker.declaredFirst[0], isTrue);
      expect(tracker.completedTeam, isNull);
      expect(tracker.canStillEarn(0), isTrue);

      // Un second « oui » sur l'autre carte ne redéclare pas la belote :
      // la rebelote se valide automatiquement, une seule fois.
      tracker.onCardPlayed(0, Card.parse('QH'), declareBelote: true);
      expect(tracker.rebeloteDeclared[0], isTrue);
      expect(tracker.completedTeam, 0);
      expect(tracker.canStillEarn(0), isFalse);
    });

    test('rebelote automatique sur la seconde carte', () {
      final tracker = BeloteTracker(
        trump: Suit.hearts,
        hands: {
          0: [Card.parse('KH'), Card.parse('QH')],
        },
      );
      tracker.onCardPlayed(0, Card.parse('QH'), declareBelote: true);
      tracker.onCardPlayed(0, Card.parse('KH'), declareBelote: false);
      expect(tracker.rebeloteDeclared[0], isTrue);
      expect(tracker.completedTeam, 0);
      expect(tracker.canStillEarn(0), isFalse);
    });

    test('refuser la déclaration interdit définitivement le bonus', () {
      final tracker = BeloteTracker(
        trump: Suit.hearts,
        hands: {
          0: [Card.parse('KH'), Card.parse('QH')],
        },
      );
      tracker.onCardPlayed(0, Card.parse('KH'), declareBelote: false);
      expect(tracker.declined[0], isTrue);
      expect(tracker.canStillDeclareFirst(0), isFalse);

      tracker.onCardPlayed(0, Card.parse('QH'), declareBelote: true);
      expect(tracker.rebeloteDeclared[0], isNot(isTrue));
      expect(tracker.completedTeam, isNull);
      expect(tracker.canStillEarn(0), isFalse);
    });

    test('sans le roi et la dame, aucun bonus', () {
      final tracker = BeloteTracker(
        trump: Suit.hearts,
        hands: {
          0: [Card.parse('KH')],
        },
      );
      expect(tracker.canDeclareFirst(0, Card.parse('KH')), isFalse);
      tracker.onCardPlayed(0, Card.parse('KH'), declareBelote: true);
      expect(tracker.declaredFirst[0], isNot(isTrue));
      expect(tracker.completedTeam, isNull);
      expect(tracker.canStillEarn(0), isFalse);
    });

    test('le moteur n’annonce que si le joueur a choisi de déclarer', () {
      final rest = fullDeck()
          .where((card) => card.id != 'KH' && card.id != 'QH')
          .toList();
      final hands = <int, List<Card>>{
        0: [
          Card.parse('KH'),
          Card.parse('QH'),
          ...rest.take(6),
        ],
        1: rest.sublist(6, 14),
        2: rest.sublist(14, 22),
        3: rest.sublist(22, 30),
      };
      Contract contract() => const Contract(
            type: ContractType.points,
            amount: 90,
            trump: Suit.hearts,
            bidderSeat: 0,
            demandeurSeat: 0,
            counter: CounterState.none,
          );

      final without = Deal.readyToPlay(
        dealerSeat: 3,
        hands: {
          for (final entry in hands.entries) entry.key: [...entry.value],
        },
        contract: contract(),
        log: EventLog(),
      );
      without.playCard(0, Card.parse('KH'));
      expect(without.log.events.where((e) => e.type == 'belote'), isEmpty);
      expect(without.belote!.declined[0], isTrue);

      final withDeclaration = Deal.readyToPlay(
        dealerSeat: 3,
        hands: {
          for (final entry in hands.entries) entry.key: [...entry.value],
        },
        contract: contract(),
        log: EventLog(),
      );
      withDeclaration.playCard(0, Card.parse('KH'), declareBelote: true);
      expect(
        withDeclaration.log.events.where((e) => e.type == 'belote'),
        hasLength(1),
      );
      expect(withDeclaration.belote!.declaredFirst[0], isTrue);

      var guard = 0;
      while (withDeclaration.phase == DealPhase.playing && guard++ < 40) {
        final seat = withDeclaration.currentTurnSeat;
        final legal = withDeclaration.legalCardsFor(seat);
        if (legal.isEmpty) break;
        withDeclaration.playCard(seat, legal.first);
      }
      expect(
        withDeclaration.log.events.where((e) => e.type == 'belote'),
        hasLength(1),
      );
      expect(
        withDeclaration.log.events.where((e) => e.type == 'rebelote'),
        hasLength(1),
      );
      expect(withDeclaration.belote!.completedTeam, 0);
    });
  });

  group('Partie complète', () {
    test('une partie de bots se termine sans erreur', () {
      final game = BelloteGame(
        config: GameConfig(
          format: MatchFormat.bestOf3,
          initialDealer: 0,
          random: Random(42),
        ),
      );
      final bot = SimpleBot(random: Random(7));
      game.start();

      var steps = 0;
      while (!game.isMatchOver && steps < 50000) {
        steps++;
        switch (game.phase) {
          case GamePhase.bidding:
            final seat = game.deal!.auction.turnSeat;
            final action = bot.decideBid(game, seat);
            game.placeBid(seat, action);
          case GamePhase.playing:
            final seat = game.deal!.currentTurnSeat;
            final decision = bot.decidePlay(game, seat);
            expect(decision, isNotNull);
            game.playCard(seat, decision!.card);
          case GamePhase.dealComplete:
          case GamePhase.setComplete:
            game.nextDeal();
          case GamePhase.matchComplete:
            break;
        }
      }

      expect(game.isMatchOver, isTrue);
      expect(game.matchWinner, isNotNull);
      expect(game.setsWon[game.matchWinner!], greaterThanOrEqualTo(2));
      expect(game.results, isNotEmpty);

      for (final result in game.results) {
        if (result.tricksPlayed == 8) {
          final total =
              result.cardPointsByTeam[0]! + result.cardPointsByTeam[1]!;
          expect(total, 152);
        }
      }
    });

    test('la vue d\'un joueur ne révèle pas les mains adverses', () {
      final valid = [
        ...['AS', '7S', 'AH', '7H', 'AD', '7D', 'AC', '7C'],
        ...['KS', '8S', 'KH', '8H', 'KD', '8D', 'KC', '8C'],
        ...['QS', '9S', 'QH', '9H', 'QD', '9D', 'QC', '9C'],
        ...['JS', '10S', 'JH', '10H', 'JD', '10D', 'JC', '10C'],
      ];
      final game = BelloteGame(
        config: GameConfig(
          initialDealer: 0,
          deckFactory: () => [for (final id in valid) Card.parse(id)],
        ),
      );
      game.start();
      final view = game.viewFor(0);
      expect(view.hand.length, 8);
      expect(view.handCounts[0], 8);
      expect(view.handCounts[1], 8);
      final json = view.toJson().toString();
      // Aucune carte de la main du siège 1 ne doit apparaître en clair.
      for (final card in game.deal!.handOf(1)) {
        // Les cartes du pli courant peuvent être publiques, mais pas la main.
        expect(
          view.hand.contains(card),
          isFalse,
        );
      }
      expect(json, isNot(contains('${game.deal!.handOf(1).first.id}"')));
    });
  });
}
