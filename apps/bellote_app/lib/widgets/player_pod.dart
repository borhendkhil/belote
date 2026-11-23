import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/playing_card.dart';

class PlayerPod extends StatelessWidget {
  const PlayerPod({
    super.key,
    required this.seat,
    required this.name,
    required this.team,
    required this.cardCount,
    required this.isTurn,
    this.isDealer = false,
    this.isBot = false,
    this.autoPlay = false,
    this.connected = true,
    this.bidLabel,
    this.tricksWon,
    this.cardPoints,
    this.belote = false,
    this.rebelote = false,
    this.compact = false,
    this.onTap,
  });

  final int seat;
  final String name;
  final int team;
  final int cardCount;
  final bool isTurn;
  final bool isDealer;
  final bool isBot;
  final bool autoPlay;
  final bool connected;
  final String? bidLabel;
  final int? tricksWon;
  final int? cardPoints;
  final bool belote;
  final bool rebelote;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tint = teamColor(team);
    final avatarSize = compact ? 34.0 : 42.0;
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
                    Container(
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
                          if (cardPoints != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              l10n.t('pointsWon', {'points': cardPoints}),
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cardCount > 0)
                  CardBackStack(
                    count: cardCount,
                    width: compact ? 11 : 13,
                    maxVisible: 3,
                  )
                else
                  const SizedBox(height: 16),
                if (cardCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$cardCount',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
            if (tricksWon != null && !compact) ...[
              const SizedBox(height: 3),
              Text(
                l10n.t('tricksWon', {'count': tricksWon}),
                style: const TextStyle(color: AppTheme.muted, fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
