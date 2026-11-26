import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';

/// Logo officiel de Belote, utilisé sur toutes les pages de l'application.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 34});

  final double height;

  static const String asset = 'assets/images/belote-logo.jpeg';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: L10n.of(context).t('appTitle'),
      child: Image.asset(
        asset,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
