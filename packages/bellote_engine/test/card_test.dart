import 'package:bellote_engine/bellote_engine.dart';
import 'package:test/test.dart';

Contract makeContract({
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

void main() {
  group('Cartes', () {
    test('le jeu contient 32 cartes uniques', () {
      final deck = fullDeck();
      expect(deck.length, 32);
      expect(deck.map((card) => card.id).toSet().length, 32);
    });

    test('total des points = 152 quelle que soit la couleur d\'atout', () {
      for (final suit in Suit.values) {
        expect(totalDeckPoints(suit), 152);
      }
    });

    test('hiérarchie et valeurs à l\'atout', () {
      expect(const Card(Rank.jack, Suit.hearts).points(Suit.hearts), 20);
      expect(const Card(Rank.nine, Suit.hearts).points(Suit.hearts), 14);
      expect(const Card(Rank.ace, Suit.hearts).points(Suit.hearts), 11);
      expect(const Card(Rank.ten, Suit.hearts).points(Suit.hearts), 10);
      expect(
        const Card(Rank.jack, Suit.hearts).strength(Suit.hearts),
        greaterThan(const Card(Rank.nine, Suit.hearts).strength(Suit.hearts)),
      );
      expect(
        const Card(Rank.nine, Suit.hearts).strength(Suit.hearts),
        greaterThan(const Card(Rank.ace, Suit.hearts).strength(Suit.hearts)),
      );
    });

    test('hiérarchie et valeurs hors atout', () {
      expect(const Card(Rank.ace, Suit.spades).points(Suit.hearts), 11);
      expect(const Card(Rank.ten, Suit.spades).points(Suit.hearts), 10);
      expect(const Card(Rank.jack, Suit.spades).points(Suit.hearts), 2);
      expect(const Card(Rank.nine, Suit.spades).points(Suit.hearts), 0);
      expect(
        const Card(Rank.ace, Suit.spades).strength(Suit.hearts),
        greaterThan(
          const Card(Rank.ten, Suit.spades).strength(Suit.hearts),
        ),
      );
    });

    test('la main classe chaque couleur par ses points, pas par rangs', () {
      const trump = Suit.spades;
      final hand = [
        Card.parse('7S'),
        Card.parse('AS'),
        Card.parse('KS'),
        Card.parse('10S'),
        Card.parse('JS'),
        Card.parse('QS'),
        Card.parse('9S'),
        Card.parse('8S'),
      ];
      expect(
        sortHand(hand, trump: trump).map((card) => card.id),
        ['JS', '9S', 'AS', '10S', 'KS', 'QS', '8S', '7S'],
      );

      // Hors atout : A, 10, R, D, V, 9, 8, 7.
      final mixed = [
        Card.parse('7H'),
        Card.parse('KH'),
        Card.parse('JH'),
        Card.parse('AH'),
        Card.parse('9H'),
        Card.parse('10H'),
        Card.parse('QH'),
        Card.parse('JS'),
      ];
      expect(
        sortHand(mixed, trump: trump).map((card) => card.id),
        ['AH', '10H', 'KH', 'QH', 'JH', '9H', '7H', 'JS'],
      );
    });

    test('les groupes de couleurs alternent ♠ ♥ ♣ ♦', () {
      final hand = [
        Card.parse('7D'),
        Card.parse('7C'),
        Card.parse('7H'),
        Card.parse('7S'),
      ];
      expect(
        sortHand(hand).map((card) => card.id),
        ['7S', '7H', '7C', '7D'],
      );
    });

    test('parsing et sérialisation', () {
      const card = Card(Rank.ten, Suit.diamonds);
      expect(card.id, '10D');
      expect(Card.parse('10D'), card);
      expect(Card.fromJson(card.toJson()), card);
    });
  });
}
