import 'package:bellote_app/core/l10n.dart';
import 'package:bellote_app/core/settings.dart';
import 'package:bellote_app/core/theme.dart';
import 'package:bellote_app/net/game_client.dart';
import 'package:bellote_app/widgets/bid_panel.dart';
import 'package:bellote_app/widgets/common.dart';
import 'package:bellote_engine/bellote_engine.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:shared_preferences/shared_preferences.dart';

class RecordingClient extends GameClient {
  RecordingClient({required super.settings});

  int? bidAmount;
  Suit? bidSuit;
  Suit? capotSuit;
  int passCalls = 0;

  @override
  Future<void> bid(int amount, Suit suit) async {
    bidAmount = amount;
    bidSuit = suit;
  }

  @override
  Future<void> capot(Suit suit) async {
    capotSuit = suit;
  }

  @override
  Future<void> pass() async {
    passCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'locale': 'fr'});
    final settings = await SettingsController.load();
    client = RecordingClient(settings: settings)
      ..seat = 0
      ..code = 'ABCDE';
  });

  PlayerView bidView({
    bool isMyTurn = true,
    String phase = 'bidding',
    int dealsStarted = 1,
    Suit? trump,
    bool canPass = true,
    bool canBidNumbers = true,
    bool canCapot = true,
    int minimumBid = 90,
    int maxBid = 180,
    List<BidRecord> auctionHistory = const [],
    int? turnSeat = 0,
  }) {
    return PlayerView(
      seat: 0,
      phase: phase,
      dealerSeat: 3,
      turnSeat: turnSeat,
      isMyTurn: isMyTurn,
      contract: null,
      trump: trump,
      hand: const [],
      handCounts: const {0: 8, 1: 8, 2: 8, 3: 8},
      currentTrick: const [],
      legalCards: const [],
      lastTrick: null,
      lastTrickWinnerSeat: null,
      tricksPlayed: 0,
      cardPointsByTeam: const {0: 0, 1: 0},
      tricksByTeam: const {0: 0, 1: 0},
      setScores: const {0: 0, 1: 0},
      setsWon: const {0: 0, 1: 0},
      setNumber: 1,
      setTarget: 2000,
      maxSets: 3,
      isBelle: false,
      matchWinner: null,
      earlyStopped: false,
      earlyStopReason: null,
      result: null,
      canPass: canPass,
      canBidNumbers: canBidNumbers,
      canCapot: canCapot,
      canCounter: false,
      canSurcounter: false,
      minimumBid: minimumBid,
      maxBid: maxBid,
      auctionHistory: auctionHistory,
      auctionClosed: false,
      canDeclareBelote: false,
      holdsBelote: false,
      beloteDeclared: false,
      beloteCompleted: false,
      beloteDeclined: false,
      beloteTeam: null,
      canStartNextDeal: false,
      events: const [],
      eventSeq: 0,
      redeals: 0,
      dealsStarted: dealsStarted,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        L10nDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  Future<void> pumpPanel(WidgetTester tester, PlayerView view) async {
    await tester.pumpWidget(wrap(BidPanel(client: client, view: view)));
    // Pas de pumpAndSettle : l'indicateur d'attente (tour d'un autre joueur)
    // anime indéfiniment et ne se stabilise jamais.
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> chooseSuit(WidgetTester tester, Suit suit) async {
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is SuitBadge && widget.suit == suit,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  List<SuitBadge> badges(WidgetTester tester) =>
      tester.widgetList<SuitBadge>(find.byType(SuitBadge)).toList();

  FilledButton bidButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  OutlinedButton capotButton(WidgetTester tester) =>
      tester.widget<OutlinedButton>(find.byType(OutlinedButton));

  testWidgets('boutons de couleur dans l’ordre ♠ ♦ ♣ ♥ et sans présélection', (
    tester,
  ) async {
    // L'atout courant est fourni par la vue, mais ne doit pas préselectionner
    // la couleur : c'est un choix local au joueur humain.
    await pumpPanel(tester, bidView(trump: Suit.hearts));

    final suits = badges(tester).map((badge) => badge.suit).toList();
    expect(
      suits,
      const [Suit.spades, Suit.diamonds, Suit.clubs, Suit.hearts],
    );
    expect(
      suits.map((suit) => suit.symbol).toList(),
      ['♠', '♦', '♣', '♥'],
    );
    expect(badges(tester).map((badge) => badge.selected).toList(), [
      false,
      false,
      false,
      false,
    ]);

    // Le libellé sans couleur ne contient aucun symbole d'atout.
    expect(find.text('Annoncer 90'), findsOneWidget);
    expect(find.text('Annoncer 90 ♥'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.textContaining('♠'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.textContaining('♥'),
      ),
      findsNothing,
    );
  });

  testWidgets('annonce et capot désactivés tant qu’aucune couleur n’est prise',
      (
    tester,
  ) async {
    await pumpPanel(tester, bidView());

    expect(bidButton(tester).onPressed, isNull);
    expect(capotButton(tester).onPressed, isNull);
    expect(client.bidAmount, isNull);
    expect(client.capotSuit, isNull);

    // Le passage reste autorisé indépendamment du choix de couleur.
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(client.passCalls, 1);
  });

  testWidgets('choisir une couleur active annonce et capot et envoie le choix',
      (
    tester,
  ) async {
    await pumpPanel(tester, bidView());

    await chooseSuit(tester, Suit.spades);
    expect(badges(tester).map((badge) => badge.selected).toList(), [
      true,
      false,
      false,
      false,
    ]);
    expect(bidButton(tester).onPressed, isNotNull);
    expect(capotButton(tester).onPressed, isNotNull);
    expect(find.text('Annoncer 90 ♠'), findsOneWidget);

    // La sélection du montant reste inchangée et est bien envoyée avec l'atout.
    await tester.tap(find.text('100'));
    await tester.pumpAndSettle();
    expect(find.text('Annoncer 100 ♠'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(client.bidAmount, 100);
    expect(client.bidSuit, Suit.spades);

    await chooseSuit(tester, Suit.hearts);
    expect(find.text('Annoncer 100 ♥'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(client.capotSuit, Suit.hearts);
  });

  testWidgets('la couleur est oubliée au nouveau tour', (tester) async {
    await pumpPanel(tester, bidView());
    await chooseSuit(tester, Suit.clubs);
    expect(badges(tester).any((badge) => badge.selected), isTrue);

    await pumpPanel(tester, bidView(isMyTurn: false, turnSeat: 1));
    expect(find.byType(SuitBadge), findsNothing);

    await pumpPanel(tester, bidView(isMyTurn: true, turnSeat: 0));
    expect(badges(tester).map((badge) => badge.selected).toList(), [
      false,
      false,
      false,
      false,
    ]);
    expect(bidButton(tester).onPressed, isNull);
    expect(capotButton(tester).onPressed, isNull);
  });

  testWidgets('la couleur est oubliée à nouvelle donne', (tester) async {
    await pumpPanel(tester, bidView());
    await chooseSuit(tester, Suit.diamonds);
    expect(badges(tester).any((badge) => badge.selected), isTrue);

    await pumpPanel(tester, bidView(dealsStarted: 2));
    expect(badges(tester).map((badge) => badge.selected).toList(), [
      false,
      false,
      false,
      false,
    ]);
    expect(bidButton(tester).onPressed, isNull);
  });

  testWidgets('la couleur est oubliée quand les enchères reprennent', (
    tester,
  ) async {
    await pumpPanel(tester, bidView());
    await chooseSuit(tester, Suit.spades);

    // Nouvelle phase d'enchères après une donne jouée.
    await pumpPanel(tester, bidView(phase: 'playing'));
    await pumpPanel(tester, bidView(phase: 'bidding'));
    expect(badges(tester).any((badge) => badge.selected), isFalse);
    expect(bidButton(tester).onPressed, isNull);

    // Reprise des enchères après redistribution (historique vidé).
    await chooseSuit(tester, Suit.hearts);
    await pumpPanel(
      tester,
      bidView(
        auctionHistory: const [
          BidRecord(seat: 1, action: NumberBid(amount: 90, trump: Suit.hearts)),
        ],
      ),
    );
    await pumpPanel(tester, bidView());
    expect(badges(tester).any((badge) => badge.selected), isFalse);
    expect(bidButton(tester).onPressed, isNull);
  });

  testWidgets('indice 170/180 sans belote uniquement quand disponible', (
    tester,
  ) async {
    const hint = '170 / 180 : sans belote';

    await pumpPanel(tester, bidView(minimumBid: 90, maxBid: 180));
    expect(find.text(hint), findsOneWidget);

    await pumpPanel(tester, bidView(minimumBid: 90, maxBid: 170));
    expect(find.text(hint), findsOneWidget);

    await pumpPanel(tester, bidView(minimumBid: 90, maxBid: 160));
    expect(find.text(hint), findsNothing);

    await pumpPanel(tester, bidView(canBidNumbers: false, maxBid: 180));
    expect(find.text(hint), findsNothing);
    expect(find.text('Capot seulement'), findsOneWidget);
    // Le nombre reste indisponible, mais le choix de couleur garde le contrôle.
    expect(find.text('90'), findsNothing);
    expect(bidButton(tester).onPressed, isNull);
    expect(capotButton(tester).onPressed, isNull);
  });

  testWidgets('le passage reste masqué quand il n’est pas autorisé', (
    tester,
  ) async {
    await pumpPanel(tester, bidView(canPass: false));
    expect(find.byType(TextButton), findsNothing);

    await pumpPanel(tester, bidView(canPass: true));
    expect(find.byType(TextButton), findsOneWidget);
  });
}
