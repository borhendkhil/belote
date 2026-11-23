import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import '../widgets/bid_panel.dart';
import '../widgets/chat_sheet.dart';
import '../widgets/common.dart';
import '../widgets/log_sheet.dart';
import '../widgets/player_pod.dart';
import '../widgets/playing_card.dart';
import '../widgets/result_overlay.dart';
import '../widgets/rules_sheet.dart';
import '../widgets/settings_sheet.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key, required this.client});

  final GameClient client;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  int? _dismissedDeal;

  GameClient get client => widget.client;

  Future<void> _confirmLeave(BuildContext context) async {
    final l10n = L10n.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('leaveConfirmTitle')),
        content: Text(l10n.t('leaveConfirmBody')),
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

  Future<void> _copyCode() async {
    final code = client.code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showLocalizedSnack(context, L10n.of(context).t('copied'));
  }

  Future<void> _onCardTap(Card card) async {
    final view = client.view;
    if (view == null || !view.isMyTurn) return;
    if (!view.legalCards.contains(card)) return;

    final isTrumpPair = view.trump != null &&
        card.suit == view.trump &&
        (card.rank == Rank.king || card.rank == Rank.queen);
    final canBelote = isTrumpPair && view.canDeclareBelote;
    final canRebelote = isTrumpPair && view.canDeclareRebelote;

    if (!canBelote && !canRebelote) {
      await client.play(card);
      return;
    }

    final l10n = L10n.of(context);
    final declare = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: AppTheme.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      canBelote
                          ? l10n.t('declareBelote')
                          : l10n.t('declareRebelote'),
                      style: const TextStyle(
                        color: AppTheme.cream,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    l10n.cardLabel(card),
                    style: const TextStyle(
                      color: AppTheme.goldSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const Icon(Icons.campaign_outlined),
                label: Text(
                  canBelote
                      ? l10n.t('playWithBelote')
                      : l10n.t('playWithRebelote'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(l10n.t('playWithoutBelote')),
              ),
            ],
          ),
        ),
      ),
    );

    if (declare == null) return;
    await client.play(
      card,
      belote: declare && canBelote,
      rebelote: declare && canRebelote,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: client,
      builder: (context, _) {
        final view = client.view;
        if (view == null) {
          return _buildWaiting(context);
        }
        final l10n = L10n.of(context);
        final showResult =
            view.isDealComplete && _dismissedDeal != view.dealsStarted;
        final matchOver = view.matchWinner != null;

        return Scaffold(
          body: Container(
            decoration: AppTheme.feltBackground(),
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _TopBar(
                        client: client,
                        view: view,
                        onLeave: () => _confirmLeave(context),
                        onCopy: _copyCode,
                        onShowResult: () =>
                            setState(() => _dismissedDeal = null),
                      ),
                      const GoldDivider(),
                      Expanded(
                        child: _TableArea(client: client, view: view),
                      ),
                      _SelfBar(client: client, view: view),
                      _handStatus(context, l10n, view),
                      _hand(context, view),
                      if (view.isBidding)
                        BidPanel(client: client, view: view)
                      else
                        const SizedBox(height: 6),
                    ],
                  ),
                  if (showResult)
                    ResultOverlay(
                      client: client,
                      view: view,
                      onDismiss: matchOver
                          ? null
                          : () => setState(
                                () => _dismissedDeal = view.dealsStarted,
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

  Widget _buildWaiting(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      body: Container(
        decoration: AppTheme.feltBackground(),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.gold),
                const SizedBox(height: 18),
                Text(
                  l10n.t('waitingConnection'),
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: client.leaveRoom,
                  child: Text(l10n.t('leaveGame')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handStatus(BuildContext context, L10n l10n, PlayerView view) {
    final String? message;
    if (view.isPlaying && view.isMyTurn) {
      message = view.canDeclareBelote
          ? l10n.t('beloteHint')
          : view.canDeclareRebelote
              ? l10n.t('rebeloteHint')
              : l10n.t('tapCardToPlay');
    } else if (view.isPlaying && view.turnSeat != null) {
      message = l10n.t('waitingTurn', {
        'name': l10n.seatName(client.room, view.turnSeat!, me: client.seat),
      });
    } else {
      message = null;
    }

    return SizedBox(
      height: 24,
      child: message == null
          ? const SizedBox.shrink()
          : Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    view.isMyTurn ? Icons.touch_app : Icons.hourglass_empty,
                    size: 13,
                    color: view.isMyTurn ? AppTheme.gold : AppTheme.muted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            view.isMyTurn ? AppTheme.goldSoft : AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _hand(BuildContext context, PlayerView view) {
    final hand = view.hand;
    if (hand.isEmpty) return const SizedBox(height: 10);
    final legal = view.legalCards.toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 5.0;
          const sidePadding = 14.0;
          final available =
              constraints.maxWidth - sidePadding * 2 - gap * (hand.length - 1);
          final cardWidth =
              (available / hand.length).clamp(32.0, 62.0).toDouble();
          final totalWidth = cardWidth * hand.length + gap * (hand.length - 1);
          return SizedBox(
            height: cardWidth * 1.45 + 12,
            child: Center(
              child: SizedBox(
                width: totalWidth,
                height: cardWidth * 1.45,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < hand.length; i++)
                      Positioned(
                        left: i * (cardWidth + gap),
                        top: 0,
                        child: PlayingCard(
                          card: hand[i],
                          width: cardWidth,
                          highlighted: view.isMyTurn && legal.contains(hand[i]),
                          dimmed: view.isMyTurn && !legal.contains(hand[i]),
                          isTrump: view.trump == hand[i].suit,
                          onTap: view.isMyTurn && legal.contains(hand[i])
                              ? () => _onCardTap(hand[i])
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.client,
    required this.view,
    required this.onLeave,
    required this.onCopy,
    required this.onShowResult,
  });

  final GameClient client;
  final PlayerView view;
  final VoidCallback onLeave;
  final VoidCallback onCopy;
  final VoidCallback onShowResult;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final code = client.code ?? client.room?.code ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onLeave,
                tooltip: l10n.t('leaveGame'),
                icon: const Icon(Icons.logout, size: 19),
                color: AppTheme.muted,
                visualDensity: VisualDensity.compact,
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onCopy,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.copy_rounded,
                            size: 11,
                            color: AppTheme.muted,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${l10n.t('set', {'number': view.setNumber})}'
                      '  ·  ${l10n.t('setTarget', {'target': view.setTarget})}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _ScorePill(
                view: view,
                onTap: view.isDealComplete ? onShowResult : null,
              ),
              if (!compact) ...[
                IconButton(
                  onPressed: () => showChatSheet(context, client),
                  tooltip: l10n.t('chat'),
                  icon: const Icon(Icons.forum_outlined, size: 19),
                  color: AppTheme.goldSoft,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => showLogSheet(context, client),
                  tooltip: l10n.t('log'),
                  icon: const Icon(Icons.receipt_long_outlined, size: 19),
                  color: AppTheme.goldSoft,
                  visualDensity: VisualDensity.compact,
                ),
              ],
              PopupMenuButton<String>(
                tooltip: l10n.t('menu'),
                icon: const Icon(
                  Icons.more_vert,
                  size: 19,
                  color: AppTheme.muted,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'chat':
                      showChatSheet(context, client);
                    case 'log':
                      showLogSheet(context, client);
                    case 'rules':
                      showRulesSheet(context);
                    case 'settings':
                      showSettingsSheet(context, client.settings);
                    case 'leave':
                      onLeave();
                  }
                },
                itemBuilder: (context) => [
                  if (compact)
                    PopupMenuItem(
                      value: 'chat',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.forum_outlined, size: 18),
                        title: Text(l10n.t('chat')),
                      ),
                    ),
                  if (compact)
                    PopupMenuItem(
                      value: 'log',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                        ),
                        title: Text(l10n.t('log')),
                      ),
                    ),
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
                      title: Text(l10n.t('leaveGame')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.view, this.onTap});

  final PlayerView view;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TeamDot(team: 0, size: 6),
                const SizedBox(width: 4),
                Text(
                  '${view.setScores[0] ?? 0}',
                  style: TextStyle(
                    color: teamColor(0),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 3),
                const Text(
                  '–',
                  style: TextStyle(color: AppTheme.muted, fontSize: 9),
                ),
                const SizedBox(width: 3),
                Text(
                  '${view.setScores[1] ?? 0}',
                  style: TextStyle(
                    color: teamColor(1),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                TeamDot(team: 1, size: 6),
              ],
            ),
            Text(
              l10n.t('setsWonShort', {
                'count': (view.setsWon[0] ?? 0) + (view.setsWon[1] ?? 0),
              }),
              style: const TextStyle(color: AppTheme.muted, fontSize: 7.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableArea extends StatelessWidget {
  const _TableArea({required this.client, required this.view});

  final GameClient client;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final room = client.room;
    final me = client.seat ?? view.seat;
    final partner = (me + 2) % 4;
    final left = (me + 1) % 4;
    final right = (me + 3) % 4;

    Widget pod(int seat, {bool compact = false}) {
      final player = room?.seatAt(seat);
      return PlayerPod(
        seat: seat,
        name: l10n.seatName(room, seat, me: me),
        team: seat % 2,
        cardCount: view.handCounts[seat] ?? 0,
        isTurn: view.turnSeat == seat,
        isDealer: view.dealerSeat == seat,
        isBot: player?.isBot ?? true,
        autoPlay: player?.autoPlay ?? false,
        connected: player?.connected ?? false,
        bidLabel: _bidForSeat(seat),
        tricksWon: view.isPlaying ? view.tricksByTeam[seat % 2] : null,
        cardPoints: view.isPlaying ? view.cardPointsByTeam[seat % 2] : null,
        belote: view.beloteTeam == (seat % 2),
        compact: compact,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 320;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Column(
                children: [
                  Center(child: pod(partner, compact: tight)),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        pod(left, compact: true),
                        Expanded(
                          child: _TrickArea(client: client, view: view),
                        ),
                        pod(right, compact: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (view.lastTrick != null && !tight)
              Positioned(
                top: 0,
                left: 0,
                child: _LastTrickPanel(client: client, view: view),
              ),
          ],
        );
      },
    );
  }

  String? _bidForSeat(int seat) {
    for (final record in view.auctionHistory.reversed) {
      if (record.seat != seat) continue;
      final action = record.action;
      if (action is NumberBid) {
        return '${action.amount} ${action.trump.symbol}';
      }
      if (action is CapotBid) return 'Capot ${action.trump.symbol}';
      if (action is CounterBid) return '×2';
      if (action is SurcounterBid) return '×4';
    }
    return null;
  }
}

class _TrickArea extends StatelessWidget {
  const _TrickArea({required this.client, required this.view});

  final GameClient client;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final me = client.seat ?? view.seat;
    final trump = view.trump;
    final master = trump == null ? null : trickMaster(view.currentTrick, trump);

    Widget slot(PlayedCard? play, Alignment alignment) {
      if (play == null) {
        return Align(
          alignment: alignment,
          child: Container(
            width: 40,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
                width: 1,
              ),
            ),
          ),
        );
      }
      return Align(
        alignment: alignment,
        child: _PlayedCardAnimation(
          key: ValueKey(
            '${play.seat}-${play.card.id}-${view.tricksPlayed}',
          ),
          from: _entryOffset(play.seat, me),
          child: PlayingCard(
            card: play.card,
            width: 40,
            highlighted: master?.seat == play.seat,
            isTrump: trump == play.card.suit,
          ),
        ),
      );
    }

    final positions = <int, Alignment>{
      me: Alignment.bottomCenter,
      (me + 2) % 4: Alignment.topCenter,
      (me + 1) % 4: Alignment.centerLeft,
      (me + 3) % 4: Alignment.centerRight,
    };

    PlayedCard? playOf(int seat) {
      for (final play in view.currentTrick) {
        if (play.seat == seat) return play;
      }
      return null;
    }

    final contractText = view.contract != null
        ? l10n.contractLabel(view.contract)
        : _latestBid(l10n);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (trump != null) ...[
                SuitBadge(suit: trump, size: 11),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  contractText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.goldSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (view.contract != null)
            Text(
              l10n.t('contractBy', {
                'name': l10n.seatName(
                  client.room,
                  view.contract!.bidderSeat,
                  me: me,
                ),
              }),
              style: const TextStyle(color: AppTheme.muted, fontSize: 8.5),
            ),
          const SizedBox(height: 5),
          SizedBox(
            width: 168,
            height: 128,
            child: Stack(
              children: [
                for (final entry in positions.entries)
                  slot(playOf(entry.key), entry.value),
                if (view.currentTrick.isEmpty)
                  Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'B',
                          style: TextStyle(
                            color: AppTheme.gold,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamDot(team: 0, size: 5),
              const SizedBox(width: 4),
              Text(
                '${view.cardPointsByTeam[0] ?? 0}',
                style: TextStyle(
                  color: teamColor(0),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 9),
              TeamDot(team: 1, size: 5),
              const SizedBox(width: 4),
              Text(
                '${view.cardPointsByTeam[1] ?? 0}',
                style: TextStyle(
                  color: teamColor(1),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _latestBid(L10n l10n) {
    for (final record in view.auctionHistory.reversed) {
      final action = record.action;
      if (action is NumberBid) {
        return '${action.amount} ${action.trump.symbol}';
      }
      if (action is CapotBid) {
        return '${l10n.t('capot')} ${action.trump.symbol}';
      }
      if (action is CounterBid) return '×2';
      if (action is SurcounterBid) return '×4';
    }
    return l10n.t('bidding');
  }
}

/// Direction d'où arrive la carte jouée, vue depuis [me].
Offset _entryOffset(int seat, int me) {
  if (seat == me) return const Offset(0, 46);
  if (seat == (me + 2) % 4) return const Offset(0, -46);
  if (seat == (me + 1) % 4) return const Offset(-52, 0);
  return const Offset(52, 0);
}

/// Fait glisser la carte jouée depuis son siège vers sa position au centre.
class _PlayedCardAnimation extends StatelessWidget {
  const _PlayedCardAnimation({
    super.key,
    required this.from,
    required this.child,
  });

  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final slide = Offset(from.dx * (1 - t), from.dy * (1 - t));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: slide,
            child: Transform.rotate(
              angle: (1 - t) * 0.05,
              child: Transform.scale(scale: 0.82 + 0.18 * t, child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Petit panneau du dernier pli terminé, affiché en haut à gauche de la table.
class _LastTrickPanel extends StatelessWidget {
  const _LastTrickPanel({required this.client, required this.view});

  final GameClient client;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final trick = view.lastTrick;
    if (trick == null) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final winner = trick.winnerSeat == (client.seat ?? view.seat)
        ? l10n.t('you')
        : l10n.seatName(client.room, trick.winnerSeat, me: client.seat);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.t('lastTrick'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 54,
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final play in trick.plays)
                  PlayingCard(
                    card: play.card,
                    width: 26,
                    isTrump: view.trump == play.card.suit,
                    highlighted: play.seat == trick.winnerSeat,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${trick.points} · $winner',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: teamColor(trick.winningTeam),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfBar extends StatelessWidget {
  const _SelfBar({required this.client, required this.view});

  final GameClient client;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final team = view.myTeam;
    final player = client.room?.seatAt(view.seat);
    final tint = teamColor(team);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: view.isMyTurn
              ? AppTheme.gold
              : Colors.white.withValues(alpha: 0.07),
          width: view.isMyTurn ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [tint.withValues(alpha: 0.35), AppTheme.feltDeep],
              ),
              border: Border.all(color: tint.withValues(alpha: 0.6)),
            ),
            child: Center(
              child: Text(
                initials(player?.name ?? l10n.t('you')),
                style: TextStyle(
                  color: tint,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player?.name ?? l10n.t('you'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.cream,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    TeamDot(team: team, size: 5),
                    const SizedBox(width: 3),
                    Text(
                      l10n.teamName(team, team),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  view.isPlaying
                      ? '${l10n.t('pointsWon', {
                              'points': view.cardPointsByTeam[team] ?? 0
                            })}'
                          '  ·  ${l10n.t('tricksWon', {
                              'count': view.tricksByTeam[team] ?? 0
                            })}'
                      : '${view.hand.length} ${l10n.t('cards')}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 8.5),
                ),
              ],
            ),
          ),
          if (view.holdsBelote)
            StatusPill(
              label: view.beloteCompleted || view.beloteDeclared
                  ? l10n.t('belote')
                  : l10n.t('beloteAvailable'),
              dense: true,
              color: view.beloteDeclined ? AppTheme.muted : AppTheme.gold,
              icon: Icons.music_note,
            ),
          if (view.contract != null) ...[
            const SizedBox(width: 6),
            StatusPill(label: l10n.contractLabel(view.contract), dense: true),
          ],
        ],
      ),
    );
  }
}
