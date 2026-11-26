import 'package:bellote_engine/bellote_engine.dart' hide Card;
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import 'score_sheet.dart';

/// Petite feuille de score toujours visible en haut à droite du tapis.
///
/// Elle garde les totaux de la partie et les dernières donnes sous forme de
/// tableau manuscrit. Un appui ouvre la feuille complète.
class ScoreTable extends StatelessWidget {
  const ScoreTable({
    super.key,
    required this.client,
    required this.view,
    this.rows = 2,
  });

  final GameClient client;
  final PlayerView view;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final us = view.myTeam;
    final them = (us + 1) % 2;
    final history = client.dealHistory.reversed.take(rows).toList();

    TableRow scoreRow({
      required String label,
      required String ours,
      required String theirs,
      bool header = false,
      Color color = AppTheme.cream,
    }) {
      final style = AppTheme.handwriting(
        size: header ? 12 : 15,
        color: color,
        weight: header ? FontWeight.w700 : FontWeight.w600,
      );
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.5),
            child: Text(label, style: style, maxLines: 1),
          ),
          Text(
            ours,
            style: style,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          Text(
            theirs,
            style: style,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      );
    }

    final table = Table(
      defaultColumnWidth: const FixedColumnWidth(34),
      border: TableBorder(
        horizontalInside: BorderSide(
          color: AppTheme.gold.withValues(alpha: 0.22),
          width: 0.6,
        ),
        verticalInside: BorderSide(
          color: AppTheme.gold.withValues(alpha: 0.16),
          width: 0.6,
        ),
      ),
      children: [
        scoreRow(
          label: '',
          ours: l10n.t('teamUs'),
          theirs: l10n.t('teamThem'),
          header: true,
          color: AppTheme.goldSoft,
        ),
        scoreRow(
          label: l10n.t('totalScoreLabel'),
          ours: '${view.setScores[us] ?? 0}',
          theirs: '${view.setScores[them] ?? 0}',
          color: AppTheme.gold,
        ),
        for (final entry in history)
          scoreRow(
            label: l10n.t('dealNumberShort', {'number': entry.dealNumber}),
            ours: '${entry.result.pointsByTeam[us] ?? 0}',
            theirs: '${entry.result.pointsByTeam[them] ?? 0}',
          ),
        if (history.isEmpty)
          scoreRow(
            label: '—',
            ours: '—',
            theirs: '—',
            color: AppTheme.muted,
          ),
      ],
    );

    return Semantics(
      label: l10n.t('scoreSheet'),
      child: InkWell(
        onTap: () => showScoreSheet(context, client: client, view: view),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          key: const Key('score-table'),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: table),
        ),
      ),
    );
  }
}
