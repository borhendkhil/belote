import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  runApp(BelloteApp(settings: settings));
}
