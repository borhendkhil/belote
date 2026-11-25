import 'package:bellote_engine/bellote_engine.dart';
import 'package:bellote_server/bellote_server.dart';
import 'package:test/test.dart';

void main() {
  const contract = Contract(
    type: ContractType.points,
    amount: 90,
    trump: Suit.hearts,
    bidderSeat: 0,
    demandeurSeat: 0,
    counter: CounterState.none,
  );

  // Aucune autre couleur que celle demandée : fournir devient obligatoire.
  List<Card> plainCards() =>
      fullDeck().where((card) => card.suit != Suit.hearts).toList();

  Deal dealWith(List<String> seat1Hand) {
    final rest = plainCards();
    return Deal.readyToPlay(
      dealerSeat: 3,
      hands: {
        0: [Card.parse('AH'), ...rest.take(7)],
        1: [for (final id in seat1Hand) Card.parse(id)],
        2: rest.skip(7).take(8).toList(),
        3: rest.skip(15).take(8).toList(),
      },
      contract: contract,
      log: EventLog(),
    );
  }

  test('une seule carte légale est jouée automatiquement', () {
    final deal = dealWith(['9H']);
    deal.playCard(0, Card.parse('AH'));

    expect(deal.currentTurnSeat, 1);
    expect(deal.legalCardsFor(1), [Card.parse('9H')]);
    expect(forcedPlayCard(deal, 1), Card.parse('9H'));
  });

  test('la dernière carte de la main est jouée automatiquement', () {
    final deal = dealWith(['9H']);
    expect(deal.handOf(1), hasLength(1));

    deal.playCard(0, Card.parse('AH'));
    expect(forcedPlayCard(deal, 1), Card.parse('9H'));
  });

  test('plusieurs cartes légales laissent le choix au joueur', () {
    final deal = dealWith(['9H', 'JH']);
    deal.playCard(0, Card.parse('AH'));

    expect(deal.legalCardsFor(1), hasLength(2));
    expect(forcedPlayCard(deal, 1), isNull);
  });

  test('ce n’est pas au tour du joueur : aucune carte forcée', () {
    final deal = dealWith(['9H']);
    expect(forcedPlayCard(deal, 1), isNull);
    expect(forcedPlayCard(deal, 2), isNull);
  });

  test('une carte de belote garde le choix de la déclaration', () {
    final deal = dealWith(['KH']);
    deal.playCard(0, Card.parse('AH'));

    // Le joueur détient le roi et la dame d'atout : il doit pouvoir refuser.
    deal.belote!.holds[1] = true;
    expect(deal.belote!.canDeclareFirst(1, Card.parse('KH')), isTrue);
    expect(forcedPlayCard(deal, 1), isNull);
  });
}
