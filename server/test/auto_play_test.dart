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

  test('une seule carte légale est jouée par règle à l’échéance', () {
    final deal = dealWith(['9H']);
    deal.playCard(0, Card.parse('AH'));

    expect(deal.currentTurnSeat, 1);
    expect(deal.legalCardsFor(1), [Card.parse('9H')]);
    expect(cardByRule(deal, 1), Card.parse('9H'));
  });

  test('la dernière carte du dernier pli reste jouable par règle', () {
    final deal = dealWith(['9H']);
    expect(deal.handOf(1), hasLength(1));

    deal.playCard(0, Card.parse('AH'));
    expect(cardByRule(deal, 1), Card.parse('9H'));
  });

  test('plusieurs cartes légales laissent le choix au joueur', () {
    final deal = dealWith(['9H', 'JH']);
    deal.playCard(0, Card.parse('AH'));

    expect(deal.legalCardsFor(1), hasLength(2));
    expect(cardByRule(deal, 1), isNull);
  });

  test('ce n’est pas au tour du joueur : aucune carte par règle', () {
    final deal = dealWith(['9H']);
    expect(cardByRule(deal, 1), isNull);
    expect(cardByRule(deal, 2), isNull);
  });

  test('la belote n’est jamais annoncée par la carte par règle', () {
    final deal = dealWith(['KH']);
    deal.playCard(0, Card.parse('AH'));

    // Le joueur détient le roi d'atout : l'échéance joue la carte, mais ne
    // décide pas d'annoncer la belote à sa place.
    deal.belote!.holds[1] = true;
    expect(deal.belote!.canDeclareFirst(1, Card.parse('KH')), isTrue);
    expect(cardByRule(deal, 1), Card.parse('KH'));

    deal.playCard(1, Card.parse('KH'), declareBelote: false);
    expect(deal.log.events.where((event) => event.type == 'belote'), isEmpty);
    expect(deal.log.events.where((event) => event.type == 'rebelote'), isEmpty);
  });
}
