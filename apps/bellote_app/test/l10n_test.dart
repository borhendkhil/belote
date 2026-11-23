import 'package:bellote_app/core/l10n.dart';
import 'package:bellote_engine/bellote_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fr = L10n(Locale('fr'));
  const en = L10n(Locale('en'));

  test('translates static keys and falls back to the key', () {
    expect(fr.t('playOnline'), 'Jouer en ligne');
    expect(en.t('playOnline'), 'Play online');
    expect(fr.t('missing_key'), 'missing_key');
  });

  test('interpolates named arguments', () {
    expect(fr.t('waitingFor', {'name': 'Ali'}), 'En attente de Ali');
    expect(en.t('waitingPlayersCount', {'count': 3}), '3/4 players');
  });

  test('uses French rank and suit labels', () {
    expect(fr.rankLabel(Rank.jack), 'V');
    expect(en.rankLabel(Rank.jack), 'J');
    expect(fr.suitName(Suit.hearts), 'Cœur');
    expect(en.suitName(Suit.hearts), 'Hearts');
    expect(fr.cardLabel(Card.parse('AS')), 'A♠');
  });

  test('maps server error codes to readable messages', () {
    expect(fr.errorText('not_your_turn'), 'Ce n’est pas votre tour.');
    expect(en.errorText('not_your_turn'), 'It is not your turn.');
    expect(en.errorText('unknown_code'), 'Something went wrong.');
    expect(en.errorText(null), 'Something went wrong.');
  });

  test('formats contracts including counters', () {
    final contract = Contract(
      type: ContractType.points,
      amount: 120,
      trump: Suit.spades,
      bidderSeat: 0,
      demandeurSeat: 0,
      counter: CounterState.countered,
    );
    expect(fr.contractLabel(contract), '120 ♠ ×2');
    expect(en.contractLabel(null), 'No contract');
  });

  test('formats match types', () {
    expect(fr.formatLabel('bestOf3'), 'Meilleur des 3 sets');
    expect(en.formatLabel('singleSet'), 'Single set to 3000');
  });
}
