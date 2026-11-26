import 'dart:async';
import 'dart:math' as math;

import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import '../widgets/app_logo.dart';
import '../widgets/belote_banner.dart';
import '../widgets/bid_panel.dart';
import '../widgets/chat_sheet.dart';
import '../widgets/common.dart';
import '../widgets/log_sheet.dart';
import '../widgets/player_action_bubble.dart';
import '../widgets/player_pod.dart';
import '../widgets/playing_card.dart';
import '../widgets/result_overlay.dart';
import '../widgets/rules_sheet.dart';
import '../widgets/score_sheet.dart';
import '../widgets/score_table.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/turn_ring.dart';

/// Position réelle d'une carte de la main au moment où le joueur la joue.
/// Elle sert à faire partir le lancer exactement de l'emplacement qu'elle
/// occupait dans l'éventail, sans « saut » visuel.
class HandPlayOrigin {
  const HandPlayOrigin({
    required this.cardId,
    required this.center,
    required this.width,
    required this.angle,
  });

  final String cardId;
  final Offset center;
  final double width;

  /// Rotation de la carte dans l'éventail, en radians.
  final double angle;
}

class TableScreen extends StatefulWidget {
  const TableScreen({super.key, required this.client});

  final GameClient client;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  int? _dismissedDeal;
  Card? _hoveredCard;

  GameEvent? _announcement;
  Timer? _announcementTimer;
  final Map<int, GameEvent> _seatBubbles = {};
  final Map<int, Timer> _bubbleTimers = {};
  int? _lastEventSeq;
  int? _lastDeal;
  bool _animateDeal = false;
  Timer? _dealAnimationTimer;

  /// La feuille de score du dernier pli n'apparaît qu'une fois la dernière
  /// carte posée, sans attendre une animation de ramassage.
  Timer? _resultDelayTimer;
  int? _pendingResultDeal;
  String? _lastPhase;

  /// Signature de la main déjà affichée. Quand elle change (carte jouée ou
  /// nouvelle donne), les cartes restantes se replacent immédiatement : seul
  /// le soulèvement au survol reste animé.
  String _renderedHand = '';
  List<String> _lastHandIds = [];
  double _lastHandCenter = 0;
  double _lastCardWidth = 0;

  /// Hauteur réservée par l'éventail avant qu'il ne soit vidé : sans elle, le
  /// centre du tapis descendrait au moment où la dernière carte est jouée et
  /// le lancer démarrerait sous la main au lieu de partir de la carte.
  double _lastHandHeight = 0;

  /// Clés stables des cartes de l'éventail, pour relever leur position réelle
  /// au moment où le serveur retire une carte jouée de la main.
  final Map<String, GlobalKey> _handCardKeys = {};

  HandPlayOrigin? _lastPlayOrigin;

  GameClient get client => widget.client;

  @override
  void initState() {
    super.initState();
    _lastEventSeq = widget.client.view?.eventSeq;
    _lastDeal = widget.client.view?.dealsStarted;
    _lastPhase = widget.client.view?.phase;
    widget.client.addListener(_onClientChanged);
  }

  @override
  void didUpdateWidget(TableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      oldWidget.client.removeListener(_onClientChanged);
      _dealAnimationTimer?.cancel();
      _resultDelayTimer?.cancel();
      _animateDeal = false;
      _lastPlayOrigin = null;
      _lastHandIds = const [];
      _lastHandHeight = 0;
      _pendingResultDeal = null;
      _lastEventSeq = widget.client.view?.eventSeq;
      _lastDeal = widget.client.view?.dealsStarted;
      _lastPhase = widget.client.view?.phase;
      widget.client.addListener(_onClientChanged);
    }
  }

  @override
  void dispose() {
    widget.client.removeListener(_onClientChanged);
    _dealAnimationTimer?.cancel();
    _resultDelayTimer?.cancel();
    _announcementTimer?.cancel();
    for (final timer in _bubbleTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  /// Annonce « Belote » / « Rebelote » à toute la table dès que le moteur
  /// publie l'événement correspondant.
  void _onClientChanged() {
    final view = widget.client.view;
    if (view == null) return;
    final previousPhase = _lastPhase;
    _lastPhase = view.phase;
    // La dernière carte doit pouvoir se poser avant que la feuille de score
    // n'apparaisse ; aucun ramassage n'est joué pour le dernier pli.
    if (previousPhase == 'playing' &&
        view.isDealComplete &&
        view.lastTrick != null) {
      _resultDelayTimer?.cancel();
      _pendingResultDeal = view.dealsStarted;
      _resultDelayTimer = Timer(_throwDuration, () {
        if (!mounted) return;
        setState(() => _pendingResultDeal = null);
      });
    }
    // On n'anime que les vraies nouvelles donnes : un écran qui s'ouvre sur
    // une partie déjà en cours affiche directement l'éventail en place.
    final newDeal = _lastDeal != null && view.dealsStarted != _lastDeal;
    if (!newDeal) {
      final detected = _playedHandOrigin(view);
      if (detected != null) _lastPlayOrigin = detected;
    }
    if (newDeal) {
      _lastPlayOrigin = null;
      _resultDelayTimer?.cancel();
      _pendingResultDeal = null;
      _dealAnimationTimer?.cancel();
      _animateDeal = true;
      // L'animation de distribution ne joue qu'une fois par donne. Sans ce
      // retour à zéro, chaque carte jouée referait partir l'éventail du centre.
      _dealAnimationTimer = Timer(_dealEntranceReset, () {
        if (!mounted) return;
        setState(() => _animateDeal = false);
      });
    }
    _lastDeal = view.dealsStarted;
    final last = _lastEventSeq;
    if (last == null) {
      _lastEventSeq = view.eventSeq;
      return;
    }
    _lastEventSeq = view.eventSeq;

    final fresh = view.events.where((event) => event.seq > last).toList();
    var bubblesChanged = false;
    for (final event in fresh) {
      final key = actionBubbleKey(event.type);
      if (key == null) continue;
      final seat = event.data['seat'] as int?;
      if (seat == null) continue;
      _bubbleTimers[seat]?.cancel();
      _seatBubbles[seat] = event;
      _bubbleTimers[seat] = Timer(actionBubbleDuration, () {
        if (!mounted) return;
        setState(() {
          _seatBubbles.remove(seat);
          _bubbleTimers.remove(seat);
        });
      });
      bubblesChanged = true;
    }

    final latest = latestBeloteEvent(view.events, last);
    if (latest != null) {
      _announcementTimer?.cancel();
      _announcementTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _announcement = null);
      });
    }
    if (bubblesChanged || latest != null) {
      setState(() {
        if (latest != null) _announcement = latest;
      });
    }
  }

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

  /// Détecte l'unique carte qui vient de quitter la main et relève sa position
  /// réelle avant que l'éventail ne soit reconstruit. Couvre aussi la carte
  /// jouée automatiquement par le serveur à l'échéance du timer.
  HandPlayOrigin? _playedHandOrigin(PlayerView view) {
    if (_lastHandIds.isEmpty) return null;
    final remaining = view.hand.map((card) => card.id).toSet();
    final removed =
        _lastHandIds.where((id) => !remaining.contains(id)).toList();
    if (removed.length != 1) return null;
    final id = removed.first;
    final box =
        _handCardKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return HandPlayOrigin(
      cardId: id,
      center:
          box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2)),
      width: _lastCardWidth,
      // Même formule que l'AnimatedRotation de l'éventail.
      angle: (_lastHandIds.indexOf(id) - _lastHandCenter) * 0.045,
    );
  }

  Future<void> _onCardTap(Card card) async {
    if (_hoveredCard == card) {
      setState(() => _hoveredCard = null);
    }
    final view = client.view;
    if (view == null || !view.isMyTurn) return;
    if (!view.legalCards.contains(card)) return;

    // La belote se déclare au choix du joueur, une seule fois, en jouant le
    // roi ou la dame d'atout. La rebelote qui suit est automatique.
    final canBelote = view.canDeclareBelote &&
        view.trump != null &&
        card.suit == view.trump &&
        (card.rank == Rank.king || card.rank == Rank.queen);
    if (!canBelote) {
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
                      l10n.t('declareBelote'),
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
              const SizedBox(height: 8),
              Text(
                l10n.t('beloteHint'),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const Icon(Icons.campaign_outlined),
                label: Text(l10n.t('playWithBelote')),
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
    await client.play(card, belote: declare);
  }

  void _setHovered(Card? card) {
    if (_hoveredCard == card) return;
    setState(() => _hoveredCard = card);
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
        final showResult = view.isDealComplete &&
            _dismissedDeal != view.dealsStarted &&
            _pendingResultDeal != view.dealsStarted;
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
                      ),
                      const GoldDivider(),
                      Expanded(
                        child: _TableArea(
                          client: client,
                          view: view,
                          bubbles: Map<int, GameEvent>.from(_seatBubbles),
                          playOrigin: _lastPlayOrigin,
                        ),
                      ),
                      _SelfBar(
                        client: client,
                        view: view,
                        bubble: actionBubbleFor(
                          _seatBubbles[view.seat],
                          l10n,
                          view.seat,
                        ),
                      ),
                      _handStatus(context, l10n, view),
                      _hand(context, view, animateDeal: _animateDeal),
                      if (view.isBidding)
                        BidPanel(client: client, view: view)
                      else
                        const SizedBox(height: 6),
                    ],
                  ),
                  if (_announcement != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: const Alignment(0, -0.42),
                          child: BeloteBanner(
                            event: _announcement!,
                            client: client,
                          ),
                        ),
                      ),
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

  Widget _hand(
    BuildContext context,
    PlayerView view, {
    required bool animateDeal,
  }) {
    // Pendant les enchères, l'atout peut changer à chaque annonce : on fige
    // l'ordre affiché pour que les cartes ne sautent pas dans la main.
    final hand = orderedHand(
      view.hand,
      view.phase == 'bidding' ? null : view.trump,
    );
    // Quand la main change, on supprime l'animation de réagencement : les
    // cartes restantes prennent leur nouvelle place sans glisser.
    final signature = hand.map((card) => card.id).join(',');
    final animateReflow = _renderedHand == signature;
    if (hand.isEmpty) return SizedBox(height: _lastHandHeight);
    final legal = view.legalCards.toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const sidePadding = 10.0;
          const overlap = 0.62;
          const maxCardWidth = 62.0;
          const minCardWidth = 34.0;
          const arcLift = 9.0;
          // La carte sélectionnée monte franchement en Y : son angle et sa
          // position horizontale restent inchangés, aucun décalage en Z.
          const liftAmount = 16.0;

          final available = constraints.maxWidth - sidePadding * 2;
          final cardWidth = (available / (1 + overlap * (hand.length - 1)))
              .clamp(minCardWidth, maxCardWidth)
              .toDouble();
          final step = hand.length > 1
              ? math.min(
                  cardWidth * overlap,
                  (available - cardWidth) / (hand.length - 1),
                )
              : 0.0;
          final totalWidth = cardWidth + step * (hand.length - 1);
          final cardHeight = cardWidth * 1.45;
          final center = (hand.length - 1) / 2;
          // On réserve la hauteur du soulèvement pour que la carte levée ne
          // vienne pas chevaucher la ligne de statut au-dessus de la main.
          final fanHeight = cardHeight + arcLift + 12 + liftAmount;

          if (!animateReflow) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _renderedHand = signature;
              _lastHandIds = hand.map((card) => card.id).toList();
              _lastHandCenter = center;
              _lastCardWidth = cardWidth;
              _lastHandHeight = fanHeight + 4;
            });
          }

          final canPlay = view.isPlaying && view.isMyTurn;
          final playable = <int>[];
          for (var i = 0; i < hand.length; i++) {
            if (canPlay && legal.contains(hand[i])) playable.add(i);
          }
          final hoveredIndex =
              _hoveredCard == null ? -1 : hand.indexOf(_hoveredCard!);
          final lifted = <int>{
            ...playable,
            if (hoveredIndex >= 0) hoveredIndex,
          };
          // Ordre de rendu stable : une carte levée ne passe pas devant ses
          // voisines. Elle monte depuis l'éventail, sans créer de calque
          // « posé par-dessus » la main.
          final movement =
              animateReflow ? const Duration(milliseconds: 280) : Duration.zero;
          final movementCurve =
              animateReflow ? Curves.easeOutCubic : Curves.linear;

          Widget dealEntrance(int index, Widget child) => animateDeal
              ? _DealEntrance(
                  key: ValueKey('deal-${view.dealsStarted}-${hand[index].id}'),
                  order: index,
                  from: Offset((center - index) * step, -110),
                  child: child,
                )
              : child;

          return SizedBox(
            height: fanHeight,
            child: Center(
              child: AnimatedContainer(
                duration: movement,
                curve: movementCurve,
                width: totalWidth,
                height: fanHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < hand.length; i++)
                      AnimatedPositioned(
                        // Identité stable : quand une carte est jouée, les
                        // cartes restantes gardent leur état au lieu d'être
                        // réattribuées à un index et de rejouer leur entrée.
                        key: ValueKey('hand-${hand[i].id}'),
                        duration: movement,
                        curve: movementCurve,
                        left: i * step,
                        // Le soulèvement est appliqué ici, avant la rotation :
                        // c'est une translation verticale à l'écran, pas une
                        // translation locale qui pencherait avec la carte.
                        top: liftAmount +
                            arcLift +
                            4 -
                            arcLift * _fanArc(i, center) -
                            (lifted.contains(i) ? liftAmount : 0),
                        // À chaque nouvelle donne, les cartes partent du centre
                        // de la table et se posent en éventail, l'une après
                        // l'autre. La clé inclut le numéro de donne : les cartes
                        // déjà en main ne rejouent pas l'animation.
                        child: dealEntrance(
                          i,
                          MouseRegion(
                            onEnter: (_) => _setHovered(hand[i]),
                            onExit: (_) => _setHovered(null),
                            child: AnimatedRotation(
                              duration: movement,
                              curve: movementCurve,
                              // Éventail : les cartes s'inclinent vers l'extérieur.
                              turns: (i - center) * 0.045 / (2 * math.pi),
                              alignment: Alignment.bottomCenter,
                              child: PlayingCard(
                                key: _handCardKeys.putIfAbsent(
                                  hand[i].id,
                                  () => GlobalKey(),
                                ),
                                card: hand[i],
                                width: cardWidth,
                                shadow: 0.45,
                                highlighted: canPlay && legal.contains(hand[i]),
                                isTrump: view.trump == hand[i].suit,
                                onTap: canPlay && legal.contains(hand[i])
                                    ? () => _onCardTap(hand[i])
                                    : null,
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
      ),
    );
  }

  /// Hauteur relative d'une carte dans l'éventail (1 au centre, 0 aux bords).
  double _fanArc(int index, double center) {
    if (center <= 0) return 1;
    final t = (index - center) / center;
    return 1 - t * t;
  }
}

/// Vrai seulement avant la première carte du pli : la pièce d'ouverture est
/// retirée dès que le joueur concerné a joué (ou dès qu'un autre a ouvert).
bool shouldShowLeadCoin(PlayerView view, int seat) =>
    view.isPlaying && view.currentTrick.isEmpty && view.turnSeat == seat;

/// Construit la bulle d'action éventuelle d'un siège à partir de l'événement
/// reçu, sans jamais produire de bulle pour l'ouverture du pli.
Widget? actionBubbleFor(
  GameEvent? event,
  L10n l10n,
  int seat, {
  bool compact = false,
}) {
  if (event == null) return null;
  final key = actionBubbleKey(event.type);
  if (key == null) return null;
  return PlayerActionBubble(
    action: event.type,
    label: l10n.t(key),
    seat: seat,
    compact: compact,
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.client,
    required this.view,
    required this.onLeave,
    required this.onCopy,
  });

  final GameClient client;
  final PlayerView view;
  final VoidCallback onLeave;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final code = client.code ?? client.room?.code ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppLogo(height: compact ? 22 : 26),
              const SizedBox(width: 4),
              const Spacer(),
              if (!compact && code.isNotEmpty)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: onCopy,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.22),
                          ),
                        ),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
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
                    ),
                  ),
                ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: () => showChatSheet(context, client),
                tooltip: l10n.t('chat'),
                icon: const Icon(Icons.forum_outlined, size: 19),
                color: AppTheme.goldSoft,
                visualDensity: VisualDensity.compact,
              ),
              PopupMenuButton<String>(
                tooltip: l10n.t('menu'),
                icon: const Icon(
                  Icons.home_outlined,
                  size: 19,
                  color: AppTheme.goldSoft,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'log':
                      showLogSheet(context, client);
                    case 'score':
                      showScoreSheet(context, client: client, view: view);
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
                    value: 'score',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.scoreboard_outlined, size: 18),
                      title: Text(l10n.t('scoreSheet')),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'log',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.receipt_long_outlined, size: 18),
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
          );
        },
      ),
    );
  }
}

class _TableArea extends StatelessWidget {
  const _TableArea({
    required this.client,
    required this.view,
    required this.bubbles,
    this.playOrigin,
  });

  final GameClient client;
  final PlayerView view;
  final Map<int, GameEvent> bubbles;
  final HandPlayOrigin? playOrigin;

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
        isTurn: view.turnSeat == seat,
        isDealer: view.dealerSeat == seat,
        isLeading: shouldShowLeadCoin(view, seat),
        bubble: actionBubbleFor(
          bubbles[seat],
          l10n,
          seat,
          compact: compact,
        ),
        isBot: player?.isBot ?? true,
        autoPlay: player?.autoPlay ?? false,
        connected: player?.connected ?? false,
        bidLabel: _bidForSeat(seat),
        cardPoints: view.isPlaying ? view.cardPointsByTeam[seat % 2] : null,
        belote: view.beloteTeam == (seat % 2),
        compact: compact,
        turnDeadline: client.turnDeadline,
        turnDuration: client.turnDuration,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 320;
        final compactScore = tight || constraints.maxWidth < 380;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Column(
                children: [
                  Center(child: pod(partner, compact: true)),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        pod(left, compact: true),
                        Expanded(
                          child: _TrickArea(
                            client: client,
                            view: view,
                            playOrigin: playOrigin,
                          ),
                        ),
                        pod(right, compact: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: ScoreTable(
                client: client,
                view: view,
                rows: compactScore ? 1 : 2,
                compact: compactScore,
              ),
            ),
            if (!tight && (view.lastTrick != null || view.contract != null))
              Positioned(
                top: 0,
                right: 0,
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

/// Durée du lancer d'une carte vers le tapis (assez lente pour être vue).
const _throwDuration = Duration(milliseconds: 520);

/// L'animation de distribution contient jusqu'à 220 ms de décalage et 380 ms
/// de vol : on la coupe ensuite pour ne plus jamais la rejouer pendant le pli.
const _dealEntranceReset = Duration(milliseconds: 700);

class _TrickArea extends StatefulWidget {
  const _TrickArea({
    required this.client,
    required this.view,
    this.playOrigin,
  });

  final GameClient client;
  final PlayerView view;
  final HandPlayOrigin? playOrigin;

  @override
  State<_TrickArea> createState() => _TrickAreaState();
}

class _TrickAreaState extends State<_TrickArea> {
  /// Repère du centre du tapis : sert à convertir la position globale de la
  /// carte jouée en décalage local pour le lancer.
  final GlobalKey _centerKey = GlobalKey();

  /// Cartes du pli en cours : elles restent au centre jusqu'à la fin du pli,
  /// puis s'envolent vers le joueur qui l'a remporté.
  List<PlayedCard> _floor = const [];

  /// Pli terminé en train de quitter le centre.
  final List<_TrickFlight> _flights = [];

  /// Évite de rejouer l'envol du même pli si le serveur renvoie plusieurs états.
  final Set<String> _seenTricks = {};

  /// Dernière carte en vol avant que le pli ne soit ramassé. On attend la fin
  /// du lancer pour que la quatrième carte soit réellement vue au centre.
  Timer? _pendingTimer;
  _TrickFlight? _pendingFlight;
  bool _pendingSkipCollection = false;

  String _trickKey(PlayerView view) =>
      '${view.dealsStarted}:${view.tricksPlayed}';

  static bool _sameCards(List<PlayedCard> a, List<PlayedCard> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].card.id != b[i].card.id) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _floor = List.of(widget.view.currentTrick);
    _seenTricks.add(_trickKey(widget.view));
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    super.dispose();
  }

  void _cancelPending() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingFlight = null;
    _pendingSkipCollection = false;
  }

  void _startPending(_TrickFlight flight, {required bool skipCollection}) {
    _cancelPending();
    _pendingFlight = flight;
    _pendingSkipCollection = skipCollection;
    _pendingTimer = Timer(_throwDuration, () {
      if (!mounted) return;
      setState(() {
        if (!_pendingSkipCollection && _pendingFlight != null) {
          _flights.add(_pendingFlight!);
        }
        _floor = const [];
        _pendingFlight = null;
        _pendingTimer = null;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _TrickArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    final view = widget.view;
    final previous = oldWidget.view;
    final leftPlay = previous.phase == 'playing' && view.phase != 'playing';
    if (view.dealsStarted != previous.dealsStarted ||
        view.tricksPlayed < previous.tricksPlayed ||
        (leftPlay && view.lastTrick == null)) {
      _cancelPending();
      setState(() {
        _floor = List.of(view.currentTrick);
        _flights.clear();
        _seenTricks
          ..clear()
          ..add(_trickKey(view));
      });
      return;
    }

    if (_pendingFlight != null) {
      // Un nouvel état du même pli arrive pendant le lancer : on laisse les
      // cartes déjà en vol terminer leur trajet.
      if (view.tricksPlayed == previous.tricksPlayed &&
          view.dealsStarted == previous.dealsStarted) {
        return;
      }
      _cancelPending();
    }

    final key = _trickKey(view);
    final trick = view.lastTrick;
    // Le dernier pli de la donne ne doit pas être ramassé : la feuille de score
    // s'ouvre dès que la dernière carte est posée.
    final dealFinished = leftPlay && view.isDealComplete && trick != null;
    final completed = !dealFinished &&
        view.tricksPlayed > previous.tricksPlayed &&
        trick != null &&
        _seenTricks.add(key);
    if (dealFinished || completed) {
      if (dealFinished) _seenTricks.add(key);
      final flight = _TrickFlight(
        id: key,
        plays: List.of(trick.plays),
        winnerSeat: view.lastTrickWinnerSeat ?? trick.winnerSeat,
      );
      // On garde les quatre cartes au centre le temps du dernier lancer, puis
      // seulement on déclenche le ramassage.
      setState(() => _floor = List.of(trick.plays));
      _startPending(flight, skipCollection: dealFinished);
      return;
    }
    if (!_sameCards(_floor, view.currentTrick)) {
      setState(() => _floor = List.of(view.currentTrick));
    }
  }

  void _finishFlight(String id) {
    if (!mounted) return;
    setState(() => _flights.removeWhere((flight) => flight.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final view = widget.view;
    final me = client.seat ?? view.seat;
    final trump = view.trump;
    // Seul le pli en cours occupe le centre. Les plis terminés sont en vol
    // vers leur vainqueur, puis disparaissent définitivement du tapis.
    final plays = _floor;
    final master = trump == null ? null : trickMaster(view.currentTrick, trump);
    final masterCard = master?.card.id;

    // Pli légèrement incliné : chaque carte garde son coin lisible.
    final tilts = <int, double>{
      me: -0.05,
      (me + 2) % 4: 0.05,
      (me + 1) % 4: -0.09,
      (me + 3) % 4: 0.09,
    };

    Widget cardFace(PlayedCard play, {bool highlighted = false}) =>
        Transform.rotate(
          angle: tilts[play.seat] ?? 0,
          child: PlayingCard(
            card: play.card,
            width: 40,
            highlighted: highlighted,
            isTrump: trump == play.card.suit,
          ),
        );

    // Fond du tapis : uniquement les quatre enseignes, dans leurs couleurs de
    // carte légèrement transparentes, sans carré ni flou.
    const suitSlots = <Suit>[
      Suit.hearts,
      Suit.spades,
      Suit.diamonds,
      Suit.clubs,
    ];
    Widget cardGlow(int seat, Alignment alignment) {
      final suit = suitSlots[(seat - me + 4) % suitSlots.length];
      final ink = suit.isRed ? AppTheme.red : AppTheme.ink;
      return Align(
        key: ValueKey('card-glow-$seat'),
        alignment: alignment,
        child: Text(
          suit.symbol,
          style: TextStyle(
            color: ink.withValues(alpha: 0.55),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget slot(PlayedCard play, Alignment alignment) {
      var from = _entryOffset(play.seat, me);
      double? startScale;
      var angleDelta = math.pi;
      final origin = widget.playOrigin;
      // La carte du joueur doit partir de sa vraie place dans l'éventail.
      // Les cartes des autres sièges gardent leur entrée depuis le pod.
      if (origin != null && play.seat == me && origin.cardId == play.card.id) {
        final box = _centerKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final topLeft = box.localToGlobal(Offset.zero);
          final slotCenter = Offset(
            topLeft.dx + (alignment.x + 1) * box.size.width / 2,
            topLeft.dy + (alignment.y + 1) * box.size.height / 2,
          );
          from = origin.center - slotCenter;
          startScale = (origin.width / 40).clamp(1.0, 2.0).toDouble();
          angleDelta = origin.angle - (tilts[play.seat] ?? 0);
        }
      }
      // La clé porte sur le créneau lui-même, pas seulement sur l'animation :
      // sans elle, Flutter réutilise un créneau vide pour la nouvelle carte et
      // déplace toutes les cartes déjà posées d'un index, ce qui relance leur
      // contrôleur de lancer.
      return Align(
        key: ValueKey('slot-played-${play.seat}-${play.card.id}'),
        alignment: alignment,
        child: _PlayedCardAnimation(
          key: ValueKey('flight-${play.seat}-${play.card.id}'),
          from: from,
          startScale: startScale,
          angleDelta: angleDelta,
          child: cardFace(play, highlighted: masterCard == play.card.id),
        ),
      );
    }

    final positions = <int, Alignment>{
      me: const Alignment(0, 0.42),
      (me + 2) % 4: const Alignment(0, -0.42),
      (me + 1) % 4: const Alignment(-0.34, 0),
      (me + 3) % 4: const Alignment(0.34, 0),
    };
    // Le centre ne contient que le pli en cours. L'ordre de la Stack suit
    // l'ordre de jeu : première carte en bas, dernière carte posée au-dessus.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        key: _centerKey,
        width: 168,
        height: 128,
        child: Stack(
          key: const Key('trick-center'),
          clipBehavior: Clip.none,
          children: [
            for (final entry in positions.entries)
              cardGlow(entry.key, entry.value),
            for (final play in plays)
              slot(play, positions[play.seat] ?? Alignment.center),
            for (final flight in _flights)
              for (final play in flight.plays)
                Align(
                  key: ValueKey(
                    'collect-${flight.id}-${play.card.id}',
                  ),
                  alignment: positions[play.seat] ?? Alignment.center,
                  child: _TrickCollectAnimation(
                    to: _entryOffset(flight.winnerSeat, me),
                    onDone: () => _finishFlight(flight.id),
                    child: cardFace(play),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Réordonne la main pour l'affichage : l'atout d'abord (sauf s'il est le seul
/// représentant de son camp, cas où on l'intercale), puis les couleurs
/// alternées noir/rouge (BRBR ou RBRB). Deux blocs voisins n'ont ainsi jamais
/// la même teinte, ce qui rend la main beaucoup plus lisible.
List<Card> orderedHand(List<Card> hand, Suit? trump) {
  // Seules les couleurs réellement en main comptent : sinon une couleur absente
  // consommerait un tour d'alternance et deux couleurs de même teinte se
  // retrouveraient voisines (atout rouge suivi du carreau, par exemple).
  final present = {for (final card in hand) card.suit};
  final blacks = <Suit>[
    Suit.spades,
    Suit.clubs,
  ].where(present.contains).toList();
  final reds = <Suit>[
    Suit.hearts,
    Suit.diamonds,
  ].where(present.contains).toList();
  final order = <Suit>[];
  // Sans atout, on commence par la couleur la plus fournie : c'est la seule
  // façon d'éviter deux blocs de même teinte quand l'autre camp est épuisé.
  var wantBlack = blacks.length >= reds.length;
  if (trump != null && present.contains(trump)) {
    final trumpIsRed = trump.isRed;
    (trumpIsRed ? reds : blacks).remove(trump);
    final sameColor = trumpIsRed ? reds : blacks;
    final opposite = trumpIsRed ? blacks : reds;
    if (sameColor.isEmpty && opposite.length > 1) {
      // L'atout est le seul représentant de son camp : on l'intercale entre
      // les deux couleurs adverses plutôt que de laisser deux rouges (ou deux
      // noirs) se toucher.
      order.add(opposite.removeAt(0));
      order.add(trump);
    } else {
      order.add(trump);
    }
    // Après un atout rouge, on enchaîne obligatoirement sur du noir.
    wantBlack = trumpIsRed;
  }
  // Alterne tant qu'il reste des deux couleurs, puis vide la couleur restante.
  while (blacks.isNotEmpty || reds.isNotEmpty) {
    final pool = wantBlack ? blacks : reds;
    final fallback = wantBlack ? reds : blacks;
    order.add((pool.isNotEmpty ? pool : fallback).removeAt(0));
    wantBlack = !wantBlack;
  }
  // Conserve l'ordre des rangs fourni par le moteur à l'intérieur d'une couleur.
  return [
    for (final suit in order)
      for (final card in hand)
        if (card.suit == suit) card,
  ];
}

/// Direction d'où arrive la carte jouée, vue depuis [me].
Offset _entryOffset(int seat, int me) {
  // Assez loin pour que la carte traverse réellement la table : elle part du
  // siège du joueur et vient se poser au centre, en ligne droite.
  if (seat == me) return const Offset(0, 150);
  if (seat == (me + 2) % 4) return const Offset(0, -145);
  if (seat == (me + 1) % 4) return const Offset(-150, 0);
  return const Offset(150, 0);
}

/// Fait arriver une carte de la main depuis le centre du tapis jusqu'à sa
/// place dans l'éventail, avec un léger décalage pour chaque carte.
class _DealEntrance extends StatefulWidget {
  const _DealEntrance({
    super.key,
    required this.order,
    required this.from,
    required this.child,
  });

  final int order;
  final Offset from;
  final Widget child;

  @override
  State<_DealEntrance> createState() => _DealEntranceState();
}

class _DealEntranceState extends State<_DealEntrance>
    with SingleTickerProviderStateMixin {
  static const _flight = Duration(milliseconds: 380);

  late final int _delayMs = math.min(widget.order * 28, 220).toInt();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _flight.inMilliseconds + _delayMs),
    // Même logique que le lancer : l'animation reste visible même si le
    // téléphone désactive les animations système.
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delayMs / (_flight.inMilliseconds + _delayMs),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      child: widget.child,
      builder: (context, child) {
        final t = _entrance.value;
        final remaining = 1 - t;
        return Opacity(
          opacity: (t * 4).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              widget.from.dx * remaining,
              widget.from.dy * remaining,
            ),
            child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
          ),
        );
      },
    );
  }
}

/// Pli terminé qui quitte le centre en direction du vainqueur.
class _TrickFlight {
  const _TrickFlight({
    required this.id,
    required this.plays,
    required this.winnerSeat,
  });

  final String id;
  final List<PlayedCard> plays;
  final int winnerSeat;
}

/// Ramasse les cartes du pli vers le siège du vainqueur, sans les conserver au
/// centre de la table une fois l'animation terminée.
class _TrickCollectAnimation extends StatefulWidget {
  const _TrickCollectAnimation({
    required this.to,
    required this.onDone,
    required this.child,
  });

  final Offset to;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_TrickCollectAnimation> createState() => _TrickCollectAnimationState();
}

class _TrickCollectAnimationState extends State<_TrickCollectAnimation>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 420);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    animationBehavior: AnimationBehavior.preserve,
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = Curves.easeInCubic.transform(_controller.value);
        return Opacity(
          opacity: 1 - progress,
          child: Transform.translate(
            offset: Offset(
              widget.to.dx * progress,
              widget.to.dy * progress,
            ),
            child: Transform.scale(
              scale: 1 - 0.35 * progress,
              child: Transform.rotate(
                angle: progress * math.pi * 0.8,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fait glisser la carte jouée depuis son siège vers sa position au centre.
class _PlayedCardAnimation extends StatefulWidget {
  const _PlayedCardAnimation({
    super.key,
    required this.from,
    required this.child,
    this.startScale,
    this.angleDelta = math.pi,
  });

  final Offset from;
  final Widget child;

  /// Quand la carte vient de la main du joueur, elle conserve sa taille et sa
  /// rotation initiales : la transition se fait sans coupure visuelle.
  final double? startScale;
  final double angleDelta;

  @override
  State<_PlayedCardAnimation> createState() => _PlayedCardAnimationState();
}

class _PlayedCardAnimationState extends State<_PlayedCardAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: _throwDuration,
    // Certains téléphones désactivent les animations système : sans
    // `preserve`, le lancer sauterait directement à sa place finale.
    animationBehavior: AnimationBehavior.preserve,
  )..forward();

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.from;

    return AnimatedBuilder(
      animation: _flight,
      child: widget.child,
      builder: (context, child) {
        final t = _flight.value;
        // Départ progressif puis décélération : le trajet reste lisible au lieu
        // de traverser la table d'un coup.
        final travel = Curves.easeInOutCubic.transform(t);
        final remaining = 1 - travel;
        // Trajectoire rectiligne, sans arc.
        final offset = Offset(from.dx * remaining, from.dy * remaining);
        // Un demi-tour pour les autres sièges ; pour le joueur, on part de
        // l'orientation réelle de sa carte dans l'éventail.
        final angle = remaining * widget.angleDelta;
        final fromHand = widget.startScale != null;
        // Elle part de sa taille dans la main, puis se pose au format du pli.
        final scale = fromHand
            ? 1 +
                (widget.startScale! - 1) *
                    Curves.easeOutCubic.transform(remaining)
            : 1.22 - 0.22 * Curves.easeOutBack.transform(t);
        return Opacity(
          opacity: fromHand ? 1.0 : (t * 10).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Petit panneau du dernier pli terminé, affiché en haut à droite de la table.
class _LastTrickPanel extends StatelessWidget {
  const _LastTrickPanel({required this.client, required this.view});

  final GameClient client;
  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final trick = view.lastTrick;
    final contract = view.contract;
    if (trick == null && contract == null) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final me = client.seat ?? view.seat;
    final winner = trick == null
        ? ''
        : trick.winnerSeat == me
            ? l10n.t('you')
            : l10n.seatName(client.room, trick.winnerSeat, me: client.seat);
    final bidder = contract == null
        ? ''
        : l10n.seatName(client.room, contract.bidderSeat, me: client.seat);

    return Container(
      key: const Key('corner-panel'),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (trick != null) ...[
            Text(
              l10n.t('lastTrick'),
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 7.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < trick.plays.length; i++) ...[
                  if (i > 0) const SizedBox(width: 1),
                  PlayingCard(
                    card: trick.plays[i].card,
                    width: 23,
                    isTrump: view.trump == trick.plays[i].card.suit,
                    highlighted: trick.plays[i].seat == trick.winnerSeat,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: Text(
                '${trick.points} · $winner',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: teamColor(trick.winningTeam),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (contract != null) ...[
            if (trick != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.gold.withValues(alpha: 0.2),
                ),
              ),
            // La couleur est déjà incluse dans le libellé du contrat : on
            // évite d'afficher deux fois le même atout dans ce panneau. Le
            // contrat et le nom du déclarant sont sur la même ligne.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      l10n.contractLabel(contract),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.goldSoft,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      l10n.t('contractBy', {'name': bidder}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelfBar extends StatelessWidget {
  const _SelfBar({
    required this.client,
    required this.view,
    this.bubble,
  });

  final GameClient client;
  final PlayerView view;
  final Widget? bubble;

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
          Builder(
            builder: (context) {
              final avatar = Container(
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
              );
              final deadline = client.turnDeadline;
              final duration = client.turnDuration;
              final showClock = view.isMyTurn &&
                  deadline != null &&
                  (duration?.inMilliseconds ?? 0) >= 5000;
              final decorated = Stack(
                clipBehavior: Clip.none,
                children: [
                  if (shouldShowLeadCoin(view, view.seat))
                    Positioned(
                      left: -7,
                      top: 7,
                      child: LeadCoin(label: l10n.t('leadCoinLabel')),
                    ),
                  if (bubble != null)
                    Positioned(bottom: 34, left: -6, child: bubble!),
                  avatar,
                ],
              );
              if (!showClock) return decorated;
              return TurnRing(
                deadline: deadline,
                duration: duration!,
                size: 28,
                child: decorated,
              );
            },
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
                      ? l10n.t('pointsWon', {
                          'points': view.cardPointsByTeam[team] ?? 0,
                        })
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
        ],
      ),
    );
  }
}
