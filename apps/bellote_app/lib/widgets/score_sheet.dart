import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart' hide Card;

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import 'common.dart';

Future<void> showScoreSheet(
  BuildContext context, {
  required GameClient client,
  required PlayerView view,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ScoreSheet(client: client, view: view),
  );
}

/// Feuille de score accessible depuis le coin en haut à droite : totaux de la
/// partie en cours et résultat de chaque donne déjà terminée.
class ScoreSheet extends StatelessWidget {
  const ScoreSheet({super.key, required this.client, required this.view});

  final GameClient client;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final us = view.myTeam;
    final them = (us + 1) % 2;
    final history = client.dealHistory.reversed.toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.scoreboard_outlined,
                  size: 18,
                  color: AppTheme.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.t('scoreSheet'),
                    style: const TextStyle(
                      color: AppTheme.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.t('close'),
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTheme.muted,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.t('scoreTotals'),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final team in [us, them]) ...[
                        if (team == them) const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TeamDot(team: team, size: 7),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.teamName(team, us),
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '${view.setScores[team] ?? 0}',
                                  style: TextStyle(
                                    color: teamColor(team),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.t('set', {'number': view.setNumber})}'
                    '  ·  ${l10n.t('setTarget', {'target': view.setTarget})}',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text(
              l10n.t('scoreHistory'),
              style: const TextStyle(
                color: AppTheme.goldSoft,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      l10n.t('noDealsYet'),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final result = entry.result;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 62,
                              child: Text(
                                l10n.t('dealShort', {
                                  'number': entry.dealNumber,
                                }),
                                style: const TextStyle(
                                  color: AppTheme.cream,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                l10n.contractLabel(result.contract),
                                style: const TextStyle(
                                  color: AppTheme.goldSoft,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${result.pointsByTeam[us] ?? 0}'
                              ' – '
                              '${result.pointsByTeam[them] ?? 0}',
                              style: const TextStyle(
                                color: AppTheme.cream,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
