import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/turn_ring.dart';

class PlayerPod extends StatelessWidget {
  const PlayerPod({
    super.key,
    required this.seat,
    required this.name,
    required this.team,
    required this.isTurn,
    this.isDealer = false,
    this.isLeading = false,
    this.bubble,
    this.isBot = false,
    this.autoPlay = false,
    this.connected = true,
    this.bidLabel,
    this.tricksWon,
    this.cardPoints,
    this.belote = false,
    this.rebelote = false,
    this.compact = false,
    this.turnDeadline,
    this.turnDuration,
    this.onTap,
  });

  final int seat;
  final String name;
  final int team;
  final bool isTurn;
  final bool isDealer;

  /// Vrai quand ce siège s'apprête à ouvrir le pli : une pièce dorée est
  /// affichée à côté de l'avatar, distincte du marqueur « D » du donneur.
  final bool isLeading;

  /// Bulle temporaire (passe / belote / rebelote) affichée près du siège.
  final Widget? bubble;

  final bool isBot;
  final bool autoPlay;
  final bool connected;
  final String? bidLabel;
  final int? tricksWon;
  final int? cardPoints;
  final bool belote;
  final bool rebelote;
  final bool compact;

  /// Échéance du tour et durée totale, pour l'anneau de compte à rebours.
  final DateTime? turnDeadline;
  final Duration? turnDuration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tint = teamColor(team);
    final avatarSize = compact ? 34.0 : 42.0;
    // Les points et les plis sont toujours affichés sous le nom, y compris
    // dans les pod compacts de gauche et de droite.
    final stats = [
      if (cardPoints != null) l10n.t('pointsWon', {'points': cardPoints}),
      if (tricksWon != null) l10n.t('tricksWon', {'count': tricksWon}),
    ].join('  ·  ');
    // L'anneau n'a de sens que sur un tour humain (les bots jouent en 0,9 s).
    final showClock = isTurn &&
        turnDeadline != null &&
        (turnDuration?.inMilliseconds ?? 0) >= 5000;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: isTurn ? 0.30 : 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isTurn ? AppTheme.gold : Colors.white.withValues(alpha: 0.08),
            width: isTurn ? 1.6 : 1,
          ),
          boxShadow: isTurn
              ? [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.18),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bidLabel != null && bidLabel!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  bidLabel!,
                  style: const TextStyle(
                    color: AppTheme.feltDeep,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Builder(
                      builder: (context) {
                        final avatar = Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                tint.withValues(alpha: 0.34),
                                AppTheme.feltDeep,
                              ],
                            ),
                            border: Border.all(
                              color: isTurn
                                  ? AppTheme.gold
                                  : tint.withValues(alpha: 0.6),
                              width: isTurn ? 2 : 1.2,
                            ),
                          ),
                          child: Center(
                            child: isBot
                                ? Icon(
                                    Icons.smart_toy_outlined,
                                    size: avatarSize * 0.48,
                                    color: tint,
                                  )
                                : Text(
                                    initials(name),
                                    style: TextStyle(
                                      color: tint,
                                      fontSize: avatarSize * 0.36,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        );
                        if (!showClock) return avatar;
                        return TurnRing(
                          deadline: turnDeadline!,
                          duration: turnDuration!,
                          size: avatarSize,
                          child: avatar,
                        );
                      },
                    ),
                    if (isLeading)
                      Positioned(
                        left: -9,
                        top: avatarSize / 2 - 7,
                        child: LeadCoin(label: l10n.t('leadCoinLabel')),
                      ),
                    if (isDealer)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.feltDeep,
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'D',
                              style: TextStyle(
                                color: AppTheme.feltDeep,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (bubble != null)
                      Positioned(
                        bottom: avatarSize + 4,
                        left: -6,
                        child: bubble!,
                      ),
                    if (!connected)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.feltDeep,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off,
                            size: 10,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!compact) const SizedBox(width: 9),
                if (!compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: AppTheme.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (autoPlay) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.smart_toy,
                              size: 12,
                              color: AppTheme.muted,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          TeamDot(team: team, size: 6),
                          const SizedBox(width: 4),
                          Text(
                            team == 0 ? l10n.t('teamUs') : l10n.t('teamThem'),
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            if (belote || rebelote) ...[
              const SizedBox(height: 4),
              StatusPill(
                label: rebelote ? l10n.t('belote') : l10n.t('beloteAvailable'),
                dense: true,
                color: AppTheme.gold,
                icon: Icons.music_note,
              ),
            ],
            if (compact) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: 72,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 2),
              SizedBox(
                width: compact ? 72 : null,
                child: Text(
                  stats,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: compact ? 8 : 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pièce dorée posée à côté du siège qui s'apprête à ouvrir le pli.
///
/// Elle remplace l'ancienne bulle « ouverture » : elle n'apparaît que tant
/// qu'aucune carte n'a été jouée dans le pli courant.
class LeadCoin extends StatelessWidget {
  const LeadCoin({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFF6D77A), Color(0xFFC99635)],
          ),
          border: Border.all(color: AppTheme.feltDeep, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.45),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.bolt,
            size: 8,
            color: AppTheme.feltDeep,
          ),
        ),
      ),
    );
  }
}
