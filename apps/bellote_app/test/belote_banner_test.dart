import 'package:bellote_app/core/l10n.dart';
import 'package:bellote_app/core/settings.dart';
import 'package:bellote_app/core/theme.dart';
import 'package:bellote_app/models/room_info.dart';
import 'package:bellote_app/net/game_client.dart';
import 'package:bellote_app/widgets/belote_banner.dart';
import 'package:bellote_engine/bellote_engine.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameClient> makeClient() async {
    SharedPreferences.setMockInitialValues({'locale': 'fr'});
    final settings = await SettingsController.load();
    return GameClient(settings: settings)
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

  test('latestBeloteEvent ne retient que les annonces récentes', () {
    const events = [
      GameEvent(seq: 1, type: 'play', data: {'seat': 0}),
      GameEvent(seq: 2, type: 'belote', data: {'seat': 1}),
      GameEvent(seq: 3, type: 'play', data: {'seat': 2}),
      GameEvent(seq: 4, type: 'rebelote', data: {'seat': 1}),
    ];

    expect(latestBeloteEvent(events, 0)?.seq, 4);
    expect(latestBeloteEvent(events, 2)?.seq, 4);
    expect(latestBeloteEvent(events, 4), isNull);
    expect(latestBeloteEvent(const [], 0), isNull);
  });

  testWidgets('le bandeau annonce la belote à toute la table', (tester) async {
    final client = await makeClient();
    await tester.pumpWidget(
      wrap(
        BeloteBanner(
          event: const GameEvent(seq: 2, type: 'belote', data: {'seat': 1}),
          client: client,
        ),
      ),
    );

    expect(find.text('Ali annonce Belote'), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });

  testWidgets('le bandeau annonce la rebelote', (tester) async {
    final client = await makeClient();
    await tester.pumpWidget(
      wrap(
        BeloteBanner(
          event: const GameEvent(seq: 4, type: 'rebelote', data: {'seat': 1}),
          client: client,
        ),
      ),
    );

    expect(find.text('Ali annonce Rebelote'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
