import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';

Future<void> showRulesSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = L10n.of(context);
      return AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              color: AppTheme.gold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('rulesTitle'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Text(
              l10n.t('rulesBody'),
              style: const TextStyle(
                color: AppTheme.cream,
                height: 1.5,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('close')),
          ),
        ],
      );
    },
  );
}
