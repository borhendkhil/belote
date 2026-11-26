import 'package:bellote_app/core/l10n.dart';
import 'package:bellote_app/core/theme.dart';
import 'package:bellote_app/widgets/player_pod.dart';
import 'package:bellote_app/widgets/turn_ring.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Finder ringFinder() => find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is TurnRingPainter,
      );

  TurnRingPainter painterOf(WidgetTester tester) =>
      (tester.widget<CustomPaint>(ringFinder()).painter as TurnRingPainter);

  testWidgets('l\'anneau se redessine à chaque battement', (tester) async {
    await tester.pumpWidget(
      wrap(
        TurnRing(
          deadline: DateTime.now().add(const Duration(seconds: 30)),
          duration: const Duration(seconds: 45),
          size: 40,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );

    final first = painterOf(tester);
    expect(first.progress, greaterThan(0.5));
    // Le timer interne relance un repaint même sans nouvelle trame de test.
    await tester.pump(const Duration(milliseconds: 250));
    final second = painterOf(tester);
    expect(identical(first, second), isFalse);
  });

  testWidgets('l\'anneau rougit quand le temps est presque écoulé', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TurnRing(
          deadline: DateTime.now().add(const Duration(seconds: 2)),
          duration: const Duration(seconds: 45),
          size: 40,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );
    final painter = painterOf(tester);
    expect(painter.progress, lessThan(0.1));
    expect(painter.color.r, greaterThan(painter.color.g));
  });

  testWidgets('la montre n\'apparaît que pour un tour humain', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PlayerPod(
          seat: 1,
          name: 'Ali',
          team: 1,
          isTurn: true,
          turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
          turnDuration: const Duration(seconds: 45),
        ),
      ),
    );
    expect(find.byType(TurnRing), findsOneWidget);

    // Un bot joue en 900 ms : pas de montre autour de son avatar.
    await tester.pumpWidget(
      wrap(
        PlayerPod(
          seat: 1,
          name: 'Bot',
          team: 1,
          isTurn: true,
          turnDeadline: DateTime.now().add(const Duration(milliseconds: 700)),
          turnDuration: const Duration(milliseconds: 900),
        ),
      ),
    );
    expect(find.byType(TurnRing), findsNothing);
  });
}
