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

    test('parsing et sérialisation', () {
      const card = Card(Rank.ten, Suit.diamonds);
      expect(card.id, '10D');
      expect(Card.parse('10D'), card);
      expect(Card.fromJson(card.toJson()), card);
    });
  });
}
