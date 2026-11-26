import 'package:bellote_app/app.dart';
import 'package:bellote_app/core/settings.dart';
import 'package:bellote_app/widgets/app_logo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen renders in French and switches to English', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'locale': 'fr'});
    final settings = await SettingsController.load();

    await tester.pumpWidget(BelloteApp(settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Belote Contrée'), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Créer une partie'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Rejoindre'), findsOneWidget);

    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Create a game'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Join'), findsOneWidget);
  });
}
