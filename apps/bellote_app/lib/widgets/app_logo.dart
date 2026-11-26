import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';

/// Logo officiel de Belote, utilisé sur toutes les pages de l'application.
/// Il est toujours présenté dans un disque, comme un cache de table.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 34});

  /// Diamètre du disque en pixels logiques.
  final double height;

  static const String asset = 'assets/images/belote-logo.jpeg';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: L10n.of(context).t('appTitle'),
      child: Container(
        width: height,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.7),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            asset,
            width: height,
            height: height,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
