import 'package:bellote_engine/bellote_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Enchères', () {
    test('progression 90 → 100 autorisée (cas 13)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 90, trump: Suit.hearts));
      expect(
        auction.canPerform(
          2,
          const NumberBid(amount: 100, trump: Suit.spades),
        ),
        isTrue,
      );
    });

    test('100 → 90 interdite (cas 14)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 100, trump: Suit.hearts));
      expect(
        auction.validate(2, const NumberBid(amount: 90, trump: Suit.spades)),
        'bid_must_be_higher',
      );
    });

    test('170 → 180 autorisée (cas 15)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 170, trump: Suit.hearts));
      expect(
        auction.canPerform(2, const NumberBid(amount: 180, trump: Suit.spades)),
        isTrue,
      );
    });

    test('180 → 190 interdite (cas 16)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 180, trump: Suit.hearts));
      expect(
        auction.validate(2, const NumberBid(amount: 190, trump: Suit.spades)),
        'invalid_bid_amount',
      );
      expect(auction.canPerform(2, const PassBid()), isTrue);
      expect(
        auction.canPerform(2, const CapotBid(trump: Suit.spades)),
        isTrue,
      );
    });

    test('quatre passes initiales annulent la donne (cas 17)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const PassBid());
      auction.perform(2, const PassBid());
      auction.perform(3, const PassBid());
      auction.perform(0, const PassBid());
      expect(auction.allPassed, isTrue);
      expect(auction.closed, isTrue);
      expect(auction.contract, isNull);
    });

    test('trois passes après la dernière enchère clôturent (cas 20)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 100, trump: Suit.hearts));
      auction.perform(2, const PassBid());
      auction.perform(3, const PassBid());
      expect(auction.closed, isFalse);
      auction.perform(0, const PassBid());
      expect(auction.closed, isTrue);
      expect(auction.contract!.amount, 100);
    });

    test('contre puis surcontre clôturent immédiatement (cas 21)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 100, trump: Suit.hearts));
      auction.perform(2, const CounterBid());
      expect(auction.closed, isFalse);
      expect(
        auction.canPerform(3, const NumberBid(amount: 110, trump: Suit.spades)),
        isFalse,
      );
      auction.perform(1, const SurcounterBid());
      expect(auction.closed, isTrue);
      expect(auction.contract!.counter, CounterState.surcountered);
    });

    test('capot clôt immédiatement et ne peut être contré (cas 22)', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 180, trump: Suit.hearts));
      auction.perform(2, const CapotBid(trump: Suit.spades));
      expect(auction.closed, isTrue);
      expect(auction.contract!.isCapot, isTrue);
      expect(auction.validate(3, const CounterBid()), 'auction_closed');
    });

    test('le contre est réservé à l\'équipe adverse', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 100, trump: Suit.hearts));
      expect(
          auction.validate(3, const CounterBid()), 'cannot_counter_own_team');
      expect(auction.validate(2, const CounterBid()), isNull);
    });

    test('le contre hors tour est autorisé', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 100, trump: Suit.hearts));
      // C'est au tour de 2, mais 0 (adverse) contre hors tour.
      expect(auction.turnSeat, 2);
      auction.perform(0, const CounterBid());
      expect(auction.turnSeat, 2);
      expect(auction.counter, CounterState.countered);
    });

    test('surcontre hors tour possible pour l\'équipe annonceuse', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 100, trump: Suit.hearts));
      auction.perform(2, const CounterBid());
      auction.perform(3, const SurcounterBid());
      expect(auction.closed, isTrue);
      expect(auction.contract!.counter, CounterState.surcountered);
    });

    test('le demandeur est le premier de l\'équipe à avoir annoncé la couleur',
        () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      // 1 passe, 2 passe, 3 annonce cœur, 0 passe, 1 passe, 2 passe.
      auction.perform(1, const PassBid());
      auction.perform(2, const PassBid());
      auction.perform(3, const NumberBid(amount: 90, trump: Suit.hearts));
      auction.perform(0, const PassBid());
      auction.perform(1, const PassBid());
      auction.perform(2, const PassBid());
      expect(auction.closed, isTrue);
      expect(auction.contract!.bidderSeat, 3);
      expect(auction.contract!.demandeurSeat, 3);
    });

    test('un partenaire peut surenchérir et rester demandeur initial', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const PassBid());
      auction.perform(2, const NumberBid(amount: 90, trump: Suit.hearts));
      auction.perform(3, const PassBid());
      auction.perform(0, const NumberBid(amount: 100, trump: Suit.hearts));
      auction.perform(1, const PassBid());
      auction.perform(2, const PassBid());
      auction.perform(3, const PassBid());
      expect(auction.closed, isTrue);
      expect(auction.contract!.bidderSeat, 0);
      expect(auction.contract!.demandeurSeat, 2);
    });

    test('changer de couleur impose une enchère strictement supérieure', () {
      final auction = Auction(dealerSeat: 0, firstBidderSeat: 1);
      auction.perform(1, const NumberBid(amount: 120, trump: Suit.hearts));
      expect(
        auction.validate(2, const NumberBid(amount: 120, trump: Suit.clubs)),
        'bid_must_be_higher',
      );
      expect(
        auction.validate(2, const NumberBid(amount: 110, trump: Suit.clubs)),
        'bid_must_be_higher',
      );
    });
  });
}
