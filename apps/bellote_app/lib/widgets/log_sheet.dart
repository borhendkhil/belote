import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import 'common.dart';

Future<void> showLogSheet(BuildContext context, GameClient client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LogSheet(client: client),
  );
}

class LogSheet extends StatelessWidget {
  const LogSheet({super.key, required this.client});

  final GameClient client;

  IconData _icon(String type) => switch (type) {
        'bid' || 'capot' || 'pass' || 'counter' || 'surcounter' => Icons.gavel,
        'contract' => Icons.handshake_outlined,
        'play' => Icons.style_outlined,
        'trick' => Icons.check_circle_outline,
        'belote' || 'rebelote' => Icons.music_note,
        'deal_started' || 'redeal' => Icons.casino_outlined,
        'early_stop' => Icons.block,
        'deal_end' => Icons.flag_outlined,
        'set_end' => Icons.emoji_events_outlined,
        'match_end' => Icons.workspace_premium_outlined,
        _ => Icons.chevron_right,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: AppTheme.gold,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.t('log'),
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppTheme.muted,
                ),
              ],
            ),
          ),
          const GoldDivider(),
          Expanded(
            child: ListenableBuilder(
              listenable: client,
              builder: (context, _) {
                final view = client.view;
                final events = view?.events ?? const [];
                if (events.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.t('waiting'),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final reversed = events.reversed.toList();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  itemCount: reversed.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppTheme.gold.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final event = reversed[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              _icon(event.type),
                              size: 14,
                              color: AppTheme.goldSoft,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.eventText(event, client.room, client.seat),
                              style: const TextStyle(
                                color: AppTheme.cream,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
