import 'dart:math' as math;

import 'package:bellote_app/core/l10n.dart';
import 'package:bellote_app/core/settings.dart';
import 'package:bellote_app/core/theme.dart';
import 'package:bellote_app/net/game_client.dart';
import 'package:bellote_app/models/room_info.dart';
import 'package:bellote_app/screens/table_screen.dart';
import 'package:bellote_app/widgets/playing_card.dart';
import 'package:bellote_app/widgets/turn_ring.dart';
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

    // Le panneau du dernier pli est à droite de la table.
    expect(tester.getCenter(find.text('Dernier pli')).dx, greaterThan(195));

    // Ses 4 cartes sont côte à côte (même ordonnée, abscisses croissantes).
    final panelCards = find.byWidgetPredicate(
      (widget) => widget is PlayingCard && widget.width == 23,
    );
    expect(panelCards, findsNWidgets(4));
    final tops = [
      for (var i = 0; i < 4; i++) tester.getTopLeft(panelCards.at(i)).dy,
    ];
    final lefts = [
      for (var i = 0; i < 4; i++) tester.getTopLeft(panelCards.at(i)).dx,
    ];
    expect(tops.toSet().length, 1);
    expect(lefts, orderedEquals([...lefts]..sort()));

    // 8 trump cards in hand + 4 in the last trick + none in the current trick.
    expect(
      find.byWidgetPredicate(
          (widget) => widget is PlayingCard && widget.isTrump),
      findsNWidgets(12),
    );
  });

  test('la main alterne les couleurs et commence par l\'atout', () {
    final hand = [
      Card.parse('AS'),
      Card.parse('10S'),
      Card.parse('KH'),
      Card.parse('7H'),
      Card.parse('AC'),
      Card.parse('QC'),
      Card.parse('AD'),
      Card.parse('9D'),
    ];

    // Les couleurs sont contiguës puis alternées noir/rouge.
    List<Suit> suitBlocks(List<Card> cards) {
      final blocks = <Suit>[];
      for (final card in cards) {
        if (blocks.isEmpty || blocks.last != card.suit) blocks.add(card.suit);
      }
      return blocks;
    }

    final hearts = orderedHand(hand, Suit.hearts);
    expect(hearts.length, hand.length);
    final heartBlocks = suitBlocks(hearts);
    // L'atout (cœur) passe devant, puis les couleurs alternent.
    expect(heartBlocks.first, Suit.hearts);
    expect(heartBlocks.toSet().length, heartBlocks.length);
    for (var i = 1; i < heartBlocks.length; i++) {
      expect(heartBlocks[i].isRed, isNot(heartBlocks[i - 1].isRed));
    }
    // Les rangs restent groupés par couleur, dans l'ordre du moteur.
    expect(
      hearts.where((card) => card.suit == Suit.hearts).map((card) => card.rank),
      [Rank.king, Rank.seven],
    );

    final spades = orderedHand(hand, Suit.spades);
    final spadeBlocks = suitBlocks(spades);
    expect(spadeBlocks.first, Suit.spades);
    for (var i = 1; i < spadeBlocks.length; i++) {
      expect(spadeBlocks[i].isRed, isNot(spadeBlocks[i - 1].isRed));
    }
  });

  test('une couleur absente ne casse pas l\'alternance', () {
    // Atout cœur, aucune carte de pique en main : après le cœur ce doit être
    // du noir (trèfle), pas du carreau.
    final hand = [
      Card.parse('KH'),
      Card.parse('7H'),
      Card.parse('AD'),
      Card.parse('9D'),
      Card.parse('AC'),
      Card.parse('QC'),
    ];
    final ordered = orderedHand(hand, Suit.hearts);
    final suits = <Suit>[];
    for (final card in ordered) {
      if (suits.isEmpty || suits.last != card.suit) suits.add(card.suit);
    }
    expect(suits, [Suit.hearts, Suit.clubs, Suit.diamonds]);
    expect(ordered.length, hand.length);
  });

  testWidgets('les cartes gardent leur place pendant les enchères', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final cards = [
      Card.parse('KH'),
      Card.parse('7S'),
      Card.parse('AD'),
      Card.parse('9C'),
      Card.parse('QH'),
      Card.parse('8S'),
      Card.parse('10D'),
      Card.parse('JC'),
    ];
    final client = await makeClient();
    client.view = _playingView(
      cards: cards,
      phase: 'bidding',
      trump: Suit.spades,
      auctionClosed: false,
    );
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();

    List<Card> handOrder() => find
        .byWidgetPredicate(
          (widget) => widget is PlayingCard && widget.width > 50,
        )
        .evaluate()
        .map((element) => (element.widget as PlayingCard).card!)
        .toList();

    final before = handOrder();
    expect(before.first.suit, Suit.spades);

    // Une nouvelle annonce change l'atout, mais pas la place des cartes.
    client.view = _playingView(
      cards: cards,
      phase: 'bidding',
      trump: Suit.hearts,
      auctionClosed: false,
    );
    client.notifyListeners();
    await tester.pumpAndSettle();
    expect(handOrder(), before);

    // Le contrat verrouillé rétablit l'atout en tête de main.
    client.view = _playingView(
      cards: cards,
      phase: 'playing',
      trump: Suit.hearts,
      auctionClosed: true,
    );
    client.notifyListeners();
    await tester.pumpAndSettle();
    expect(handOrder().first.suit, Suit.hearts);
  });

  testWidgets('la montre entoure mon avatar pendant mon tour', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    client.turnDeadline = DateTime.now().add(const Duration(seconds: 30));
    client.turnDuration = const Duration(seconds: 45);
    await tester.pumpWidget(appFor(client));
    await tester.pump();

    // Une seule montre : c'est mon tour, aucun autre siège ne joue.
    expect(find.byType(TurnRing), findsOneWidget);
    final painter = tester
        .widget<CustomPaint>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is TurnRingPainter,
          ),
        )
        .painter as TurnRingPainter;
    expect(painter.progress, greaterThan(0.5));
  });

  testWidgets('la carte jouée arrive avec une animation de lancer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    await tester.pumpWidget(appFor(client));
    // Première image : la carte part de son siège.
    await tester.pump();

    final card = find
        .byWidgetPredicate(
          (widget) => widget is PlayingCard && widget.width == 40,
        )
        .first;
    final start = tester.getCenter(card);

    // Rotation du lancer : demi-tour complet (π rad) au départ.
    double? rotationOf(Finder finder) {
      double? angle;
      for (final transform in tester.widgetList<Transform>(
        find.ancestor(of: finder, matching: find.byType(Transform)),
      )) {
        final m = transform.transform;
        final a = math.atan2(m.storage[1], m.storage[0]);
        if (a.abs() > 0.001) angle = a;
      }
      return angle;
    }

    expect(rotationOf(card)!.abs(), closeTo(math.pi, 0.2));

    await tester.pump(const Duration(milliseconds: 320));
    final mid = tester.getCenter(card);

    await tester.pumpAndSettle();
    final end = tester.getCenter(card);

    // En vol, puis immobile à sa place définitive.
    expect((mid - end).distance, greaterThan(3));
    expect((start - end).distance, greaterThan((mid - end).distance));
    // Le trajet est rectiligne : l'axe horizontal ne bouge pas.
    expect((mid.dx - end.dx).abs(), lessThan(1));
    expect((start.dx - end.dx).abs(), lessThan(1));
    // Elle finit bien droite sur le tapis.
    expect(rotationOf(card)?.abs() ?? 0, lessThan(0.05));
  });

  testWidgets(
      'le lancer reste animé même si le téléphone désactive les '
      'animations', (tester) async {
    // Réglage Android « Supprimer les animations » / échelle d'animation 0.
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    await tester.pumpWidget(appFor(client));
    await tester.pump();

    final card = find
        .byWidgetPredicate(
          (widget) => widget is PlayingCard && widget.width == 40,
        )
        .first;
    final start = tester.getCenter(card);

    await tester.pump(const Duration(milliseconds: 320));
    final mid = tester.getCenter(card);

    await tester.pumpAndSettle();
    final end = tester.getCenter(card);

    // Sans `AnimationBehavior.preserve`, la carte sauterait à sa place finale.
    expect((mid - end).distance, greaterThan(20));
    expect((start - end).distance, greaterThan((mid - end).distance));
  });

  testWidgets('le pli terminé est ramassé immédiatement', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    Finder trickCards() => find.byWidgetPredicate(
          (widget) => widget is PlayingCard && widget.width == 40,
        );
    // La 4e carte du pli (9♠, jouée par le siège 3) doit arriver en vol.
    Finder fourthCard() => find.byWidgetPredicate(
          (widget) =>
              widget is PlayingCard &&
              widget.width == 40 &&
              widget.card == const Card(Rank.nine, Suit.spades),
        );

    final client = await makeClient();
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();
    expect(trickCards(), findsNWidgets(2));

    final finished = await makeClient();
    finished.view = _playingView(
      currentTrick: const [],
      tricksPlayed: 4,
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
    );
    await tester.pumpWidget(appFor(finished));
    await tester.pump();
    // Les 4 cartes sont encore là, en train d'être ramassées.
    expect(trickCards(), findsNWidgets(4));

    // La 4e carte traverse la table avant que le pli ne soit ramassé.
    final start = tester.getCenter(fourthCard());
    await tester.pump(const Duration(milliseconds: 200));
    final mid = tester.getCenter(fourthCard());
    await tester.pump(const Duration(milliseconds: 220));
    final landed = tester.getCenter(fourthCard());
    expect((start - landed).distance, greaterThan(40));
    expect((mid - landed).distance, greaterThan(3));

    await tester.pumpAndSettle();
    // Elles disparaissent aussitôt : plus aucune carte au centre.
    expect(trickCards(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les couleurs non demandées ne sont pas grisées', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    // Seul l'as de pique est jouable : les 7 autres cartes restent normales.
    client.view = _playingView(legal: const [Card(Rank.ace, Suit.spades)]);
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();

    // Aucune carte n'est grisée, même hors de la couleur demandée.
    expect(
      find.byWidgetPredicate(
          (widget) => widget is PlayingCard && widget.dimmed),
      findsNothing,
    );
    // Seule la carte jouable est mise en avant.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PlayingCard && widget.highlighted && widget.width > 50,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la carte jouable monte en Y sans changer d’angle ni de place', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    Finder cardFinder(Card card) => find.byWidgetPredicate(
          (widget) =>
              widget is PlayingCard && widget.width > 50 && widget.card == card,
        );
    AnimatedPositioned positionOf(Card card) =>
        tester.widget<AnimatedPositioned>(
          find
              .ancestor(
                of: cardFinder(card),
                matching: find.byType(AnimatedPositioned),
              )
              .first,
        );
    AnimatedRotation rotationOf(Card card) => tester.widget<AnimatedRotation>(
          find
              .ancestor(
                of: cardFinder(card),
                matching: find.byType(AnimatedRotation),
              )
              .first,
        );
    AnimatedContainer containerOf(Card card) =>
        tester.widget<AnimatedContainer>(
          find
              .descendant(
                of: cardFinder(card),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
    BoxShadow castShadowOf(Card card) =>
        (containerOf(card).decoration! as BoxDecoration).boxShadow!.last;

    const card = Card(Rank.ace, Suit.spades);
    final cards = [
      card,
      Card.parse('KS'),
      Card.parse('QS'),
      Card.parse('JS'),
      Card.parse('10S'),
      Card.parse('9S'),
      Card.parse('8S'),
      Card.parse('7S'),
    ];
    final client = await makeClient();
    client.view = _playingView(cards: cards, legal: const [card]);
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();

    expect(cardFinder(card), findsOneWidget);
    final lifted = positionOf(card);
    final liftedRotation = rotationOf(card);
    expect(liftedRotation.turns, isNot(0));
    // Aucune transformation locale qui ferait avancer la carte en Z.
    expect(containerOf(card).transform, isNull);
    final liftedShadow = castShadowOf(card);
    expect(
      (containerOf(card).decoration! as BoxDecoration).boxShadow!.first.offset,
      Offset.zero,
    );

    // L'ordre de rendu reste stable : la carte levée ne passe pas au-dessus
    // de ses voisines comme un calque posé sur la main.
    final stack = find
        .ancestor(
          of: find.byType(AnimatedPositioned).first,
          matching: find.byType(Stack),
        )
        .first;
    final children = tester.widget<Stack>(stack).children;
    final expectedOrder = orderedHand(cards, Suit.spades);
    expect(children.length, expectedOrder.length);
    for (var i = 0; i < expectedOrder.length; i++) {
      final childCard = tester.widget<PlayingCard>(
        find.descendant(
          of: find.byWidget(children[i]),
          matching: find.byType(PlayingCard),
        ),
      );
      expect(childCard.card, expectedOrder[i]);
    }

    // Même main, aucune carte jouable : la carte revient à sa place de base.
    client.view = _playingView(legal: const []);
    client.notifyListeners();
    await tester.pumpAndSettle();

    final flat = positionOf(card);
    expect(flat.left, lifted.left);
    expect(flat.top! - lifted.top!, greaterThan(12));
    expect(lifted.top, flat.top! - 16.0);
    expect(rotationOf(card).turns, liftedRotation.turns);

    // L'ombre portée ne change pas : la carte ne gagne pas en profondeur.
    final flatShadow = castShadowOf(card);
    expect(flatShadow.offset, liftedShadow.offset);
    expect(flatShadow.blurRadius, liftedShadow.blurRadius);
  });

  testWidgets('les cartes glissent quand l’éventail se resserre', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final eight = [
      Card.parse('AS'),
      Card.parse('KS'),
      Card.parse('QS'),
      Card.parse('JS'),
      Card.parse('10S'),
      Card.parse('9S'),
      Card.parse('8S'),
      Card.parse('7S'),
    ];
    final client = await makeClient();
    client.view = _playingView(cards: eight, legal: eight);
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();

    Finder lastCard() => find.byWidgetPredicate(
          (widget) =>
              widget is PlayingCard &&
              widget.width > 50 &&
              widget.card == Card.parse('7S'),
        );
    final start = tester.getCenter(lastCard());

    final seven = eight.sublist(1);
    client.view = _playingView(cards: seven, legal: seven);
    client.notifyListeners();
    await tester.pump(const Duration(milliseconds: 90));
    final mid = tester.getCenter(lastCard());
    await tester.pump(const Duration(milliseconds: 400));
    final end = tester.getCenter(lastCard());

    expect((start - end).distance, greaterThan(8));
    expect((mid - start).distance, greaterThan(1));
    expect((mid - end).distance, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('une annonce de belote s\'affiche puis s\'efface',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    await tester.pumpWidget(appFor(client));
    await tester.pump();

    // Le siège 1 vient de jouer son roi d'atout : le serveur publie belote.
    client.view = _playingView(
      events: const [
        GameEvent(seq: 2, type: 'belote', data: {'seat': 1}),
      ],
      eventSeq: 2,
    );
    client.notifyListeners();
    await tester.pump();

    expect(find.text('Ali annonce Belote'), findsOneWidget);

    // Le bandeau est temporaire.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Ali annonce Belote'), findsNothing);
  });

  testWidgets(
      'la belote se déclare au choix, une seule fois, sur un honneur d’atout',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(tester.view.reset);

    final client = await makeClient();
    client.view = _playingView(canDeclareBelote: true);
    await tester.pumpWidget(appFor(client));
    await tester.pump();

    Finder handCard(String id) => find.byWidgetPredicate(
          (widget) =>
              widget is PlayingCard &&
              widget.card == Card.parse(id) &&
              widget.onTap != null,
        );

    // Une carte qui n'est ni le roi ni la dame d'atout ne propose rien.
    await tester.tap(handCard('8S'));
    await tester.pumpAndSettle();
    expect(find.text('Déclarer Belote'), findsNothing);

    // Le roi d'atout propose la déclaration, au choix du joueur.
    await tester.tap(handCard('KS'));
    await tester.pumpAndSettle();
    expect(find.text('Déclarer Belote'), findsOneWidget);
    expect(find.text('Jouer et dire « Belote »'), findsOneWidget);
    expect(find.text('Jouer sans déclarer'), findsOneWidget);

    await tester.tap(find.text('Jouer sans déclarer'));
    await tester.pumpAndSettle();
    expect(find.text('Déclarer Belote'), findsNothing);

    // La belote déjà annoncée ne redemande jamais (pas de seconde annonce).
    client.view = _playingView(canDeclareBelote: false, beloteDeclared: true);
    client.notifyListeners();
    await tester.pump();
    await tester.tap(handCard('QS'));
    await tester.pumpAndSettle();
    expect(find.text('Déclarer Belote'), findsNothing);
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

PlayerView _playingView({
  String phase = 'playing',
  Suit? trump = Suit.spades,
  bool auctionClosed = true,
  List<PlayedCard> currentTrick = const [
    PlayedCard(seat: 1, card: Card(Rank.ace, Suit.hearts)),
    PlayedCard(seat: 2, card: Card(Rank.ten, Suit.hearts)),
  ],
  List<Card>? legal,
  List<Card>? cards,
  TrickRecord? lastTrick = const TrickRecord(
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
  int tricksPlayed = 3,
  List<GameEvent> events = const [],
  int eventSeq = 1,
  bool canDeclareBelote = false,
  bool beloteDeclared = false,
}) {
  final hand = cards ??
      [
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
    phase: phase,
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
    trump: trump,
    hand: hand,
    handCounts: {0: hand.length, 1: 6, 2: 6, 3: 6},
    currentTrick: currentTrick,
    legalCards: legal ?? hand,
    lastTrick: lastTrick,
    lastTrickWinnerSeat: lastTrick?.winnerSeat,
    tricksPlayed: tricksPlayed,
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
    auctionClosed: auctionClosed,
    canDeclareBelote: canDeclareBelote,
    holdsBelote: false,
    beloteDeclared: beloteDeclared,
    beloteCompleted: false,
    beloteDeclined: false,
    beloteTeam: null,
    canStartNextDeal: false,
    events: events,
    eventSeq: eventSeq,
    redeals: 0,
    dealsStarted: 1,
  );
}
