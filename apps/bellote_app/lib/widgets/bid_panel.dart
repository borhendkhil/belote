import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import 'common.dart';

class BidPanel extends StatefulWidget {
  const BidPanel({super.key, required this.client, required this.view});

  final GameClient client;
  final PlayerView view;

  @override
  State<BidPanel> createState() => _BidPanelState();
}

class _BidPanelState extends State<BidPanel> {
  // Couleurs affichées dans l'ordre noir / rouge / noir / rouge attendu pour
  // les annonces. On n'utilise pas Suit.values (pique / cœur / carreau / trèfle).
  static const List<Suit> _suits = [
    Suit.spades,
    Suit.diamonds,
    Suit.clubs,
    Suit.hearts,
  ];

  /// Choix local du joueur humain : aucune couleur n'est présélectionnée et
  /// l'atout de la donne courante ne doit pas l'imposer.
  Suit? _suit;
  int? _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.view.canBidNumbers ? widget.view.minimumBid : null;
  }

  @override
  void didUpdateWidget(covariant BidPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final view = widget.view;
    final oldView = oldWidget.view;

    final newTurn = view.isMyTurn && !oldView.isMyTurn;
    final newDeal = view.dealsStarted != oldView.dealsStarted;
    final biddingRestarted = view.isBidding &&
        (!oldView.isBidding ||
            (view.auctionHistory.isEmpty && oldView.auctionHistory.isNotEmpty));
    if (newTurn || newDeal || biddingRestarted) {
      _suit = null;
    }

    if (_amount == null || _amount! < view.minimumBid) {
      _amount = view.canBidNumbers ? view.minimumBid : null;
    }
  }

  List<int> get _amounts {
    final view = widget.view;
    if (!view.canBidNumbers) return const [];
    final start = view.minimumBid < 90 ? 90 : view.minimumBid;
    if (start > view.maxBid) return const [];
    return [
      for (var amount = start; amount <= view.maxBid; amount += 10) amount,
    ];
  }

  String _bidLabel(L10n l10n) {
    for (final record in widget.view.auctionHistory.reversed) {
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
    return l10n.t('noBidsYet');
  }

  void _placeBid(int amount, Suit suit) {
    widget.client.bid(amount, suit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final view = widget.view;
    final amounts = _amounts;
    final suit = _suit;
    final selectedAmount = amounts.contains(_amount)
        ? _amount
        : (amounts.isEmpty ? null : amounts.first);
    final showSansBeloteHint = amounts.any(
      (amount) => amount == 170 || amount == 180,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.feltDeep.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: AppTheme.gold.withValues(alpha: 0.35)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel, size: 16, color: AppTheme.gold),
                const SizedBox(width: 8),
                Text(
                  l10n.t('bidding').toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(label: _bidLabel(l10n), dense: true),
                const Spacer(),
                if (view.canPass)
                  TextButton.icon(
                    onPressed: widget.client.pass,
                    icon: const Icon(Icons.block, size: 16),
                    label: Text(l10n.t('pass')),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            if (view.canCounter || view.canSurcounter) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      view.canCounter
                          ? l10n.t('counterAvailable')
                          : l10n.t('surcounterAvailable'),
                      style: const TextStyle(
                        color: AppTheme.goldSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: view.canCounter
                        ? widget.client.counter
                        : widget.client.surcounter,
                    icon: Icon(
                      view.canCounter
                          ? Icons.close_rounded
                          : Icons.replay_rounded,
                      size: 15,
                    ),
                    label: Text(
                      view.canCounter
                          ? l10n.t('counter')
                          : l10n.t('surcounter'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: AppTheme.cream,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (view.isMyTurn) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    l10n.t('trump'),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  for (final candidate in _suits) ...[
                    SuitBadge(
                      suit: candidate,
                      size: 15,
                      selected: candidate == suit,
                      onTap: () => setState(() => _suit = candidate),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  if (view.canCapot)
                    OutlinedButton.icon(
                      onPressed:
                          suit == null ? null : () => widget.client.capot(suit),
                      icon: const Icon(Icons.local_fire_department, size: 15),
                      label: Text(l10n.t('capot')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if (showSansBeloteHint)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.t('bidWithoutBeloteHint'),
                    style: const TextStyle(
                      color: AppTheme.goldSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (amounts.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: amounts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final amount = amounts[index];
                      final selected = amount == selectedAmount;
                      return GestureDetector(
                        onTap: () => setState(() => _amount = amount),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.gold
                                : Colors.black.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.goldSoft
                                  : AppTheme.gold.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            '$amount',
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.feltDeep
                                  : AppTheme.goldSoft,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: suit == null || selectedAmount == null
                      ? null
                      : () => _placeBid(selectedAmount, suit),
                  icon: const Icon(Icons.gavel, size: 18),
                  label: Text(
                    selectedAmount == null
                        ? l10n.t('capotOnly')
                        : suit == null
                            ? '${l10n.t('bid')} $selectedAmount'
                            : '${l10n.t('bid')} $selectedAmount ${suit.symbol}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ] else if (!view.canCounter && !view.canSurcounter)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      view.turnSeat == null
                          ? l10n.t('waiting')
                          : l10n.t('waitingTurn', {
                              'name': l10n.seatName(
                                widget.client.room,
                                view.turnSeat!,
                                me: widget.client.seat,
                              ),
                            }),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
