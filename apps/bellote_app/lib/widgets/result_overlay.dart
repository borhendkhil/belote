import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import 'common.dart';

class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.client,
    required this.view,
    this.onDismiss,
  });

  final GameClient client;
  final PlayerView view;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final result = view.result;
    final matchOver = view.matchWinner != null;
    final setComplete = view.phase == 'setComplete';
    final won = matchOver && view.matchWinner == view.myTeam;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Material(
                  color: AppTheme.felt,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (matchOver && !won
                                        ? AppTheme.muted
                                        : AppTheme.gold)
                                    .withValues(alpha: 0.16),
                                border: Border.all(
                                  color: matchOver && !won
                                      ? AppTheme.muted.withValues(alpha: 0.5)
                                      : AppTheme.gold.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Icon(
                                matchOver
                                    ? (won
                                        ? Icons.emoji_events
                                        : Icons.sentiment_dissatisfied)
                                    : setComplete
                                        ? Icons.workspace_premium_outlined
                                        : Icons.flag_outlined,
                                color: matchOver && !won
                                    ? AppTheme.muted
                                    : AppTheme.gold,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    matchOver
                                        ? (won
                                            ? l10n.t('matchWon')
                                            : l10n.t('matchLost'))
                                        : setComplete
                                            ? l10n.t('setWon')
                                            : l10n.t('dealResult'),
                                    style: const TextStyle(
                                      color: AppTheme.cream,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    matchOver
                                        ? l10n.t('matchEndTitle')
                                        : setComplete
                                            ? l10n.t('set', {
                                                'number': view.setNumber,
                                              })
                                            : l10n.t('dealNumber', {
                                                'number': view.dealsStarted,
                                              }),
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!matchOver && onDismiss != null)
                              IconButton(
                                onPressed: onDismiss,
                                icon: const Icon(Icons.close),
                                color: AppTheme.muted,
                                tooltip: l10n.t('seeTable'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (matchOver) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                for (final team in const [0, 1])
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            TeamDot(team: team, size: 6),
                                            const SizedBox(width: 5),
                                            Text(
                                              l10n.teamName(team, view.myTeam),
                                              style: const TextStyle(
                                                color: AppTheme.muted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${view.setsWon[team] ?? 0}',
                                          style: TextStyle(
                                            color: teamColor(team),
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          l10n.t('matchScores'),
                                          style: const TextStyle(
                                            color: AppTheme.muted,
                                            fontSize: 8.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (result != null) ...[
                          _ContractBanner(
                            l10n: l10n,
                            contract: result.contract,
                            contractMade: result.contractMade,
                            myTeam: view.myTeam,
                          ),
                          if (result.earlyStopped) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.red.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.red.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.block,
                                    size: 15,
                                    color: Color(0xFFFFB4AB),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      result.earlyStopReason ==
                                              'capot_defense_trick'
                                          ? l10n.t('earlyStopCapot')
                                          : l10n.t('earlyStopContract'),
                                      style: const TextStyle(
                                        color: Color(0xFFFFB4AB),
                                        fontSize: 11.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _TeamScore(
                                  team: 0,
                                  myTeam: view.myTeam,
                                  points: result.score.pointsFor(0),
                                  l10n: l10n,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TeamScore(
                                  team: 1,
                                  myTeam: view.myTeam,
                                  points: result.score.pointsFor(1),
                                  l10n: l10n,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ScoreTable(l10n: l10n, result: result, view: view),
                          const SizedBox(height: 14),
                          _SetSummary(l10n: l10n, view: view),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                l10n.t('waiting'),
                                style: const TextStyle(color: AppTheme.muted),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        if (matchOver)
                          FilledButton.icon(
                            onPressed: client.leaveRoom,
                            icon: const Icon(Icons.home_outlined),
                            label: Text(l10n.t('backToMenu')),
                          )
                        else ...[
                          if (client.isHost)
                            FilledButton.icon(
                              onPressed: view.canStartNextDeal
                                  ? client.nextDeal
                                  : null,
                              icon: const Icon(Icons.skip_next),
                              label: Text(l10n.t('nextDeal')),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  color: AppTheme.gold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l10n.t('newDealSoon'),
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (onDismiss != null) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: onDismiss,
                              child: Text(l10n.t('seeTable')),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContractBanner extends StatelessWidget {
  const _ContractBanner({
    required this.l10n,
    required this.contract,
    required this.contractMade,
    required this.myTeam,
  });

  final L10n l10n;
  final Contract contract;
  final bool contractMade;
  final int myTeam;

  @override
  Widget build(BuildContext context) {
    final tint =
        contractMade ? const Color(0xFF8BE0A8) : const Color(0xFFFFB4AB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            contractMade ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: tint,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.contractLabel(contract),
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  contractMade
                      ? l10n.t('contractMade')
                      : l10n.t('contractFailed'),
                  style: TextStyle(
                    color: tint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l10n.teamName(contract.team, myTeam),
            style: const TextStyle(color: AppTheme.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.team,
    required this.myTeam,
    required this.points,
    required this.l10n,
  });

  final int team;
  final int myTeam;
  final int points;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final tint = teamColor(team);
    final mine = team == myTeam;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: mine ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: mine ? 0.55 : 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamDot(team: team, size: 7),
              const SizedBox(width: 6),
              Text(
                l10n.teamName(team, myTeam),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '$points',
            style: TextStyle(
              color: tint,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.t('points'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _ScoreTable extends StatelessWidget {
  const _ScoreTable({
    required this.l10n,
    required this.result,
    required this.view,
  });

  final L10n l10n;
  final DealResult result;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row(
            l10n.t('rawPoints'),
            '${result.cardPointsByTeam[0] ?? 0}',
            '${result.cardPointsByTeam[1] ?? 0}',
          ),
          _row(
            l10n.t('roundedPoints'),
            '${score.attackTeam == 0 ? score.roundedAttack : score.roundedDefense}',
            '${score.attackTeam == 1 ? score.roundedAttack : score.roundedDefense}',
          ),
          _row(
            l10n.t('tricks'),
            '${result.tricksByTeam[0] ?? 0}',
            '${result.tricksByTeam[1] ?? 0}',
          ),
          if (score.beloteTeam != null)
            _row(
              l10n.t('belote'),
              score.beloteTeam == 0 ? '+20' : '—',
              score.beloteTeam == 1 ? '+20' : '—',
            ),
          if (score.capotNotCalled) _row(l10n.t('capot'), '+250', '—'),
        ],
      ),
    );
  }

  Widget _row(String label, String team0, String team1) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              team0,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.cream,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              team1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.cream,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetSummary extends StatelessWidget {
  const _SetSummary({required this.l10n, required this.view});

  final L10n l10n;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.t('setScores'),
          style: const TextStyle(color: AppTheme.muted, fontSize: 10.5),
        ),
        Text(
          '${view.setScores[0] ?? 0} – ${view.setScores[1] ?? 0}'
          '  ·  ${l10n.t('setTarget', {'target': view.setTarget})}',
          style: const TextStyle(
            color: AppTheme.goldSoft,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
