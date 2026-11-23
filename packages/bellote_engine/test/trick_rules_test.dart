import 'package:bellote_engine/bellote_engine.dart';
import 'package:test/test.dart';

List<PlayedCard> trick(List<(int, String)> plays) => [
      for (final entry in plays)
        PlayedCard(seat: entry.$1, card: Card.parse(entry.$2)),
    ];

void main() {
  const trump = Suit.hearts;

  group('Règles du pli', () {
    test(
        'à l\'atout, le joueur doit monter même si son partenaire est maître (cas 8)',
        () {
      // Leader 1, partenaire du joueur 0 = 2.
      final plays = trick([
        (1, '7H'),
        (2, '9H'),
        (3, '8H'),
      ]);
      final hand = [Card.parse('JH'), Card.parse('7S')];
      final legal = TrickRules.legalCards(
        seat: 0,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, {Card.parse('JH')});
    });

    test('hors atout, partenaire maître, joueur non bloqué : libre (cas 9)',
        () {
      final plays = trick([
        (1, 'AS'),
        (2, '7H'),
        (3, '8S'),
      ]);
      final hand = [
        Card.parse('KH'),
        Card.parse('7D'),
        Card.parse('8C'),
      ];
      final legal = TrickRules.legalCards(
        seat: 0,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, hand.toSet());
    });

    test(
        'hors couleur, partenaire maître avec la couleur demandée : '
        'aucune obligation de couper (cas 9b)', () {
      // Leader 1 entame pique, le partenaire (2) fournit l'as maître,
      // le joueur 0 est void à pique et possède des atouts.
      final plays = trick([
        (1, '7S'),
        (2, 'AS'),
        (3, '8S'),
      ]);
      final hand = [
        Card.parse('9H'),
        Card.parse('7D'),
        Card.parse('QC'),
      ];
      final legal = TrickRules.legalCards(
        seat: 0,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      // Il peut se défausser malgré ses atouts : le partenaire est maître.
      expect(legal, hand.toSet());
    });

    test('joueur bloqué à l\'atout, partenaire maître, peut surcouper (cas 10)',
        () {
      final plays = trick([
        (1, 'AS'),
        (2, '10H'),
        (3, '8S'),
      ]);
      final hand = [
        Card.parse('KH'),
        Card.parse('QH'),
        Card.parse('JH'),
      ];
      final legal = TrickRules.legalCards(
        seat: 0,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, {Card.parse('JH')});
    });

    test('joueur bloqué à l\'atout sans atout supérieur : pisse (cas 11)', () {
      final plays = trick([
        (1, 'AS'),
        (2, 'AH'),
        (3, '8S'),
      ]);
      final hand = [
        Card.parse('KH'),
        Card.parse('QH'),
        Card.parse('8H'),
      ];
      final legal = TrickRules.legalCards(
        seat: 0,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, hand.toSet());
    });

    test('adversaire maître après coupe, sans atout supérieur : pisse (cas 12)',
        () {
      final plays = trick([
        (1, 'AS'),
        (2, '7S'),
        (3, '9H'),
      ]);
      final hand = [
        Card.parse('8H'),
        Card.parse('QH'),
        Card.parse('7D'),
      ];
      final legal = TrickRules.legalCards(
        seat: 0,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, {Card.parse('8H'), Card.parse('QH')});
    });

    test('fournir la couleur demandée est obligatoire', () {
      final plays = trick([(1, 'AS'), (2, 'KS')]);
      final hand = [
        Card.parse('9S'),
        Card.parse('AH'),
        Card.parse('10D'),
      ];
      final legal = TrickRules.legalCards(
        seat: 3,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, {Card.parse('9S')});
    });

    test('à l\'atout, sans atout supérieur, obligation de pisser', () {
      final plays = trick([(1, '9H'), (2, 'AH')]);
      final hand = [
        Card.parse('QH'),
        Card.parse('8H'),
        Card.parse('AS'),
      ];
      final legal = TrickRules.legalCards(
        seat: 3,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, {Card.parse('QH'), Card.parse('8H')});
    });

    test('sans la couleur et sans atout : défausse libre', () {
      final plays = trick([(1, 'AS'), (2, 'KS')]);
      final hand = [Card.parse('7D'), Card.parse('8C')];
      final legal = TrickRules.legalCards(
        seat: 3,
        hand: hand,
        trick: plays,
        trump: trump,
      );
      expect(legal, hand.toSet());
    });

    test('détermination du gagnant : atout le plus fort', () {
      final plays = trick([
        (0, 'AS'),
        (1, '10H'),
        (2, 'AH'),
        (3, 'JH'),
      ]);
      expect(trickWinnerSeat(plays, trump), 3);
    });

    test('détermination du gagnant : couleur demandée sans atout', () {
      final plays = trick([
        (0, 'AS'),
        (1, '10S'),
        (2, 'KS'),
        (3, '7D'),
      ]);
      expect(trickWinnerSeat(plays, trump), 0);
    });

    test('une défausse ne peut jamais gagner', () {
      final plays = trick([
        (0, '10S'),
        (1, 'AS'),
        (2, 'KH'),
        (3, '7D'),
      ]);
      // Le roi de cœur est atout, mais c'est le seul atout : il gagne.
      expect(trickWinnerSeat(plays, trump), 2);
      final plays2 = trick([
        (0, '10S'),
        (1, 'AS'),
        (2, 'KH'),
        (3, '7D'),
      ]);
      expect(trickWinnerSeat(plays2, Suit.clubs), 1);
    });
  });
}
