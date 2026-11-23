import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/room_info.dart';
import '../net/game_client.dart';
import '../widgets/chat_sheet.dart';
import '../widgets/common.dart';
import '../widgets/rules_sheet.dart';
import '../widgets/settings_sheet.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key, required this.client});

  final GameClient client;

  Future<void> _copyCode(BuildContext context) async {
    final code = client.code ?? client.room?.code ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    showLocalizedSnack(context, L10n.of(context).t('copied'));
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final l10n = L10n.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('leaveRoom')),
        content: Text(l10n.t('leaveLobbyBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('stay')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('confirmLeave')),
          ),
        ],
      ),
    );
    if (leave == true) {
      await client.leaveRoom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: client,
      builder: (context, _) {
        final l10n = L10n.of(context);
        final room = client.room;
        if (room == null) {
          return Scaffold(
            body: Container(
              decoration: AppTheme.feltBackground(),
              child: Center(
                child: Text(
                  l10n.t('waitingConnection'),
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: AppTheme.feltBackground(),
            child: SafeArea(
              child: Column(
                children: [
                  _LobbyTopBar(
                    client: client,
                    room: room,
                    onLeave: () => _confirmLeave(context),
                  ),
                  const GoldDivider(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                          children: [
                            _CodeCard(
                              room: room,
                              onCopy: () => _copyCode(context),
                            ),
                            const SizedBox(height: 18),
                            SectionLabel(
                              l10n.t('playersLabel'),
                              trailing: StatusPill(
                                label: l10n.t('waitingPlayersCount', {
                                  'count': room.filledSeats,
                                }),
                                dense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _SeatList(client: client, room: room),
                            const SizedBox(height: 16),
                            _StatusCard(client: client, room: room),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: SizedBox(
                          width: double.infinity,
                          child: client.isHost
                              ? FilledButton.icon(
                                  onPressed:
                                      room.canStart ? client.startGame : null,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(l10n.t('startGame')),
                                )
                              : OutlinedButton.icon(
                                  onPressed: null,
                                  icon: const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.6,
                                    ),
                                  ),
                                  label: Text(l10n.t('waitingHost')),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LobbyTopBar extends StatelessWidget {
  const _LobbyTopBar({
    required this.client,
    required this.room,
    required this.onLeave,
  });

  final GameClient client;
  final RoomInfo room;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onLeave,
            tooltip: l10n.t('leaveRoom'),
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.muted,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('roomCreated'),
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${l10n.t('format')} · ${l10n.formatLabel(room.format)}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => showChatSheet(context, client),
            tooltip: l10n.t('chat'),
            icon: const Icon(Icons.forum_outlined, size: 20),
            color: AppTheme.goldSoft,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.t('menu'),
            icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.muted),
            onSelected: (value) {
              switch (value) {
                case 'rules':
                  showRulesSheet(context);
                case 'settings':
                  showSettingsSheet(context, client.settings);
                case 'leave':
                  onLeave();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rules',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined, size: 18),
                  title: Text(l10n.t('rules')),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune, size: 18),
                  title: Text(l10n.t('settings')),
                ),
              ),
              PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, size: 18),
                  title: Text(l10n.t('leaveRoom')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.room, required this.onCopy});

  final RoomInfo room;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.gold.withValues(alpha: 0.16),
            Colors.black.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('roomCode').toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room.code,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 7,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t('shareCode'),
                  style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onCopy,
            tooltip: l10n.t('copyCode'),
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _SeatList extends StatefulWidget {
  const _SeatList({required this.client, required this.room});

  final GameClient client;
  final RoomInfo room;

  @override
  State<_SeatList> createState() => _SeatListState();
}

class _SeatListState extends State<_SeatList> {
  int? _selected;

  void _onTap(int seat) {
    if (!widget.client.isHost) return;
    final selected = _selected;
    if (selected == null) {
      if (widget.room.seatAt(seat) == null) return;
      setState(() => _selected = seat);
      return;
    }
    if (selected == seat) {
      setState(() => _selected = null);
      return;
    }
    widget.client.swapSeats(selected, seat);
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final client = widget.client;
    final room = widget.room;
    final canArrange = client.isHost;
    return Column(
      children: [
        if (canArrange) ...[
          Row(
            children: [
              const Icon(
                Icons.swap_horiz,
                size: 15,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.t('swapSeatsHint'),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
        ],
        for (var seat = 0; seat < 4; seat++)
          _SeatTile(
            seat: seat,
            player: room.seatAt(seat),
            hostSeat: room.hostSeat,
            mySeat: client.seat,
            canManage: client.isHost,
            selected: _selected == seat,
            onSelect: canArrange ? () => _onTap(seat) : null,
            onAddBot: client.addBot,
            onRemoveBot: () => client.removeBot(seat),
          ),
      ],
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.player,
    required this.hostSeat,
    required this.mySeat,
    required this.canManage,
    required this.onAddBot,
    required this.onRemoveBot,
    this.selected = false,
    this.onSelect,
  });

  final int seat;
  final ServerPlayer? player;
  final int hostSeat;
  final int? mySeat;
  final bool canManage;
  final VoidCallback onAddBot;
  final VoidCallback onRemoveBot;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final empty = player == null;
    final isMe = player != null && seat == mySeat;
    final isHost = seat == hostSeat;
    final tint = teamColor(seat % 2);

    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: selected ? 0.32 : (isMe ? 0.24 : 0.13),
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : isMe
                    ? AppTheme.gold.withValues(alpha: 0.6)
                    : empty
                        ? AppTheme.gold.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.07),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: empty
                        ? null
                        : LinearGradient(
                            colors: [
                              tint.withValues(alpha: 0.32),
                              AppTheme.feltDeep,
                            ],
                          ),
                    color: empty ? Colors.black.withValues(alpha: 0.15) : null,
                    border: Border.all(
                      color: empty
                          ? AppTheme.gold.withValues(alpha: 0.18)
                          : tint.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Center(
                    child: empty
                        ? const Icon(
                            Icons.person_add_alt_1_outlined,
                            size: 17,
                            color: AppTheme.muted,
                          )
                        : player!.isBot
                            ? Icon(Icons.smart_toy_outlined,
                                size: 19, color: tint)
                            : Text(
                                initials(player!.name),
                                style: TextStyle(
                                  color: tint,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                  ),
                ),
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: AppTheme.feltDeep,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${seat + 1}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          empty
                              ? l10n.t('emptySeat')
                              : isMe
                                  ? '${player!.name}  ·  ${l10n.t('you')}'
                                  : player!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: empty ? AppTheme.muted : AppTheme.cream,
                            fontSize: 13,
                            fontWeight:
                                empty ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isHost && !empty) ...[
                        const SizedBox(width: 6),
                        StatusPill(
                          label: l10n.t('host'),
                          dense: true,
                          icon: Icons.star_border,
                        ),
                      ],
                      if (player?.autoPlay == true) ...[
                        const SizedBox(width: 6),
                        StatusPill(
                          label: l10n.t('autoControlled'),
                          dense: true,
                          color: AppTheme.muted,
                          icon: Icons.smart_toy,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      TeamDot(team: seat % 2, size: 6),
                      const SizedBox(width: 4),
                      Text(
                        l10n.teamName(seat % 2, (mySeat ?? 0) % 2),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.t('seatNumber', {'number': seat + 1}),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canManage)
              Icon(
                Icons.swap_horiz,
                size: 16,
                color: selected ? AppTheme.gold : AppTheme.muted,
              ),
            if (empty && canManage)
              TextButton.icon(
                onPressed: onAddBot,
                icon: const Icon(Icons.add, size: 15),
                label: Text(l10n.t('addBot')),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (!empty && player!.isBot && canManage && !isHost)
              IconButton(
                onPressed: onRemoveBot,
                tooltip: l10n.t('removeBot'),
                icon: const Icon(Icons.close, size: 17),
                color: AppTheme.muted,
                visualDensity: VisualDensity.compact,
              ),
            if (empty && !canManage)
              Text(
                l10n.t('waiting'),
                style: const TextStyle(color: AppTheme.muted, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.client, required this.room});

  final GameClient client;
  final RoomInfo room;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final ready = room.canStart;
    final String text;
    if (!client.isHost) {
      text = l10n.t('waitingHost');
    } else if (ready) {
      text = l10n.t('readyToStart');
    } else {
      text = '${l10n.t('waitingPlayers')} · '
          '${l10n.t('waitingPlayersCount', {'count': room.filledSeats})}';
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ready && client.isHost
            ? const Color(0xFF8BE0A8).withValues(alpha: 0.09)
            : Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ready && client.isHost
              ? const Color(0xFF8BE0A8).withValues(alpha: 0.3)
              : AppTheme.gold.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.hourglass_empty,
            size: 17,
            color: ready ? const Color(0xFF8BE0A8) : AppTheme.muted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ready ? const Color(0xFF8BE0A8) : AppTheme.muted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
