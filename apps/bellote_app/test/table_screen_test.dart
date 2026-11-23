import 'package:bellote_app/core/l10n.dart';
import 'package:bellote_app/core/settings.dart';
import 'package:bellote_app/core/theme.dart';
import 'package:bellote_app/net/game_client.dart';
import 'package:bellote_app/models/room_info.dart';
import 'package:bellote_app/screens/table_screen.dart';
import 'package:bellote_app/widgets/playing_card.dart';
import 'package:bellote_engine/bellote_engine.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameClient> makeClient() async {
    SharedPreferences.setMockInitialValues({'locale': 'fr'});
    final settings = await SettingsController.load();
    final client = GameClient(settings: settings)
      ..seat = 0
      ..code = 'ABCDE'
      ..room = RoomInfo(
        code: 'ABCDE',
        hostSeat: 0,
        format: 'bestOf3',
        started: true,
        canStart: false,
        seats: const [
          ServerPlayer(
            seat: 0,
            name: 'Moi',
            isBot: false,
            connected: true,
            autoPlay: false,
          ),
          ServerPlayer(
            seat: 1,
            name: 'Ali',
            isBot: false,
            connected: true,
            autoPlay: false,
          ),
          ServerPlayer(
            seat: 2,
            name: 'Partenaire',
            isBot: false,
            connected: true,
            autoPlay: false,
          ),
          ServerPlayer(
            seat: 3,
            name: 'Sami',
            isBot: false,
            connected: true,
            autoPlay: false,
          ),
        ],
        chat: const [],
      )
      ..view = _playingView();
    return client;
  }

  Widget appFor(GameClient client) {
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
      home: TableScreen(client: client),
    );
  }

  testWidgets('table renders trump tint, last trick panel and played card', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Dernier pli'), findsOneWidget);

    // 8 trump cards in hand + 4 in the last trick + none in the current trick.
    expect(
      find.byWidgetPredicate(
          (widget) => widget is PlayingCard && widget.isTrump),
      findsNWidgets(12),
    );
  });

  testWidgets('table fits a small phone without overflow', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

PlayerView _playingView() {
  final hand = [
    Card.parse('AS'),
    Card.parse('KS'),
    Card.parse('QS'),
    Card.parse('JS'),
    Card.parse('10S'),
    Card.parse('9S'),
    Card.parse('8S'),
    Card.parse('7S'),
  ];
  return PlayerView(
    seat: 0,
    phase: 'playing',
    dealerSeat: 3,
    turnSeat: 0,
    isMyTurn: true,
    contract: const Contract(
      type: ContractType.points,
      amount: 100,
      trump: Suit.spades,
      bidderSeat: 0,
      demandeurSeat: 0,
      counter: CounterState.none,
    ),
    trump: Suit.spades,
    hand: hand,
    handCounts: const {0: 8, 1: 6, 2: 6, 3: 6},
    currentTrick: const [
      PlayedCard(seat: 1, card: Card(Rank.ace, Suit.hearts)),
      PlayedCard(seat: 2, card: Card(Rank.ten, Suit.hearts)),
    ],
    legalCards: hand,
    lastTrick: const TrickRecord(
      leaderSeat: 0,
      plays: [
        PlayedCard(seat: 0, card: Card(Rank.ace, Suit.spades)),
        PlayedCard(seat: 1, card: Card(Rank.seven, Suit.spades)),
        PlayedCard(seat: 2, card: Card(Rank.eight, Suit.spades)),
        PlayedCard(seat: 3, card: Card(Rank.nine, Suit.spades)),
      ],
      winnerSeat: 0,
      points: 25,
      winningTeam: 0,
    ),
    lastTrickWinnerSeat: 0,
    tricksPlayed: 3,
    cardPointsByTeam: const {0: 40, 1: 12},
    tricksByTeam: const {0: 2, 1: 1},
    setScores: const {0: 120, 1: 90},
    setsWon: const {0: 0, 1: 0},
    setNumber: 1,
    setTarget: 2000,
    maxSets: 3,
    isBelle: false,
    matchWinner: null,
    earlyStopped: false,
    earlyStopReason: null,
    result: null,
    canPass: false,
    canBidNumbers: false,
    canCapot: false,
    canCounter: false,
    canSurcounter: false,
    minimumBid: 100,
    maxBid: 180,
    auctionHistory: const [],
    auctionClosed: true,
    canDeclareBelote: false,
    canDeclareRebelote: false,
    holdsBelote: false,
    beloteDeclared: false,
    beloteCompleted: false,
    beloteDeclined: false,
    beloteTeam: null,
    canStartNextDeal: false,
    events: const [],
    eventSeq: 1,
    redeals: 0,
    dealsStarted: 1,
  );
}
