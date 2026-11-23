import 'package:bellote_app/core/l10n.dart';
import 'package:bellote_app/core/settings.dart';
import 'package:bellote_app/core/theme.dart';
import 'package:bellote_app/models/room_info.dart';
import 'package:bellote_app/net/game_client.dart';
import 'package:bellote_app/screens/lobby_screen.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameClient> makeClient({required int seat}) async {
    SharedPreferences.setMockInitialValues({'locale': 'fr'});
    final settings = await SettingsController.load();
    return GameClient(settings: settings)
      ..seat = seat
      ..code = 'ABCDE'
      ..room = const RoomInfo(
        code: 'ABCDE',
        hostSeat: 0,
        format: 'bestOf3',
        started: false,
        canStart: true,
        seats: [
          ServerPlayer(
            seat: 0,
            name: 'Hôte',
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
        chat: [],
      );
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
      home: LobbyScreen(client: client),
    );
  }

  testWidgets('host sees the seat swap hint on a small phone', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    addTearDown(tester.view.reset);

    final client = await makeClient(seat: 0);
    await tester.pumpWidget(appFor(client));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Touchez un siège puis un autre pour échanger les joueurs '
        'et composer les équipes.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.swap_horiz), findsNWidgets(5));
  });

  testWidgets('a non-host guest does not see seat arrangement controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(tester.view.reset);

    final client = await makeClient(seat: 1);
    await tester.pumpWidget(appFor(client));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
  });
}
