import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';

/// Dernière annonce de belote ou rebelote publiée après [afterSeq].
///
/// Le joueur choisit de déclarer la belote en jouant le roi ou la dame d'atout ;
/// ce filtre prévient toute la table dès que l'événement correspondant arrive.
GameEvent? latestBeloteEvent(List<GameEvent> events, int afterSeq) {
  GameEvent? latest;
  for (final event in events) {
    if (event.seq <= afterSeq) continue;
    if (event.type == 'belote' || event.type == 'rebelote') latest = event;
  }
  return latest;
}

/// Bandeau doré affiché à toute la table quand une belote ou une rebelote
/// vient d'être annoncée.
class BeloteBanner extends StatelessWidget {
  const BeloteBanner({
    super.key,
    required this.event,
    required this.client,
  });

  final GameEvent event;
  final GameClient client;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final rebelote = event.type == 'rebelote';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.feltDeep.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.gold, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rebelote ? Icons.auto_awesome : Icons.music_note,
            color: AppTheme.gold,
            size: 20,
          ),
          const SizedBox(width: 9),
          Text(
            l10n.eventText(event, client.room, client.seat),
            style: const TextStyle(
              color: AppTheme.cream,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
