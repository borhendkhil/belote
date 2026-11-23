import 'dart:math' as math;

import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart' hide Card;

import '../core/theme.dart';

class PlayingCard extends StatelessWidget {
  const PlayingCard({
    super.key,
    this.card,
    this.width = 64,
    this.faceDown = false,
    this.highlighted = false,
    this.dimmed = false,
    this.raised = false,
    this.isTrump = false,
    this.onTap,
    this.heroTag,
  });

  final Card? card;
  final double width;
  final bool faceDown;
  final bool highlighted;
  final bool dimmed;
  final bool raised;

  /// Teinte dorée appliquée aux cartes de la couleur d'atout.
  final bool isTrump;
  final VoidCallback? onTap;
  final String? heroTag;

  double get height => width * 1.45;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: dimmed ? 0.38 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        height: height,
        transform: Matrix4.translationValues(0, raised ? -10 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.11),
          boxShadow: [
            BoxShadow(
              color: isTrump
                  ? const Color(0xFFE6C55C).withValues(alpha: 0.32)
                  : Colors.black.withValues(alpha: highlighted ? 0.45 : 0.28),
              blurRadius: highlighted ? 16 : (isTrump ? 10 : 8),
              offset: Offset(0, highlighted ? 7 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(width * 0.11),
            onTap: dimmed ? null : onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.11),
                border: Border.all(
                  color: highlighted
                      ? AppTheme.gold
                      : isTrump
                          ? const Color(0xFFD9B94C)
                          : Colors.black.withValues(alpha: 0.28),
                  width: highlighted ? 2.2 : (isTrump ? 1.4 : 0.8),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: faceDown || card == null
                  ? const _CardBack()
                  : _CardFace(card: card!, width: width, isTrump: isTrump),
            ),
          ),
        ),
      ),
    );

    if (heroTag == null) return content;
    return Hero(tag: heroTag!, child: content);
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.width,
    this.isTrump = false,
  });

  final Card card;
  final double width;
  final bool isTrump;

  @override
  Widget build(BuildContext context) {
    final color =
        card.suit.isRed ? const Color(0xFFB3261E) : const Color(0xFF1B2520);
    final rank = switch (card.rank) {
      Rank.seven => '7',
      Rank.eight => '8',
      Rank.nine => '9',
      Rank.ten => '10',
      Rank.jack => 'V',
      Rank.queen => 'D',
      Rank.king => 'R',
      Rank.ace => 'A',
    };
    final rankEn = switch (card.rank) {
      Rank.seven => '7',
      Rank.eight => '8',
      Rank.nine => '9',
      Rank.ten => '10',
      Rank.jack => 'J',
      Rank.queen => 'Q',
      Rank.king => 'K',
      Rank.ace => 'A',
    };
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final label = isFr ? rank : rankEn;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isTrump
              ? const [Color(0xFFFFF9DF), Color(0xFFF7E6A8)]
              : const [Color(0xFFFFFDF6), Color(0xFFF3EAD4)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: width * 0.09,
            top: width * 0.06,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: width * 0.27,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                  ),
                ),
                Text(
                  card.suit.symbol,
                  style: TextStyle(
                    color: color,
                    fontSize: width * 0.22,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              card.suit.symbol,
              style: TextStyle(color: color, fontSize: width * 0.52, height: 1),
            ),
          ),
          Positioned(
            right: width * 0.09,
            bottom: width * 0.06,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: width * 0.27,
                      fontWeight: FontWeight.w800,
                      height: 0.95,
                    ),
                  ),
                  Text(
                    card.suit.symbol,
                    style: TextStyle(
                      color: color,
                      fontSize: width * 0.22,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14513D), Color(0xFF0A2D22)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _CardBackPainter()),
          Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gold, width: 1.4),
                color: Colors.black.withValues(alpha: 0.18),
              ),
              child: const Center(
                child: Text(
                  'B',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    const step = 10.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x.toDouble(), size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    final border = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
        const Radius.circular(6),
      ),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CardBackStack extends StatelessWidget {
  const CardBackStack({
    super.key,
    required this.count,
    this.width = 22,
    this.maxVisible = 5,
  });

  final int count;
  final double width;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = math.min(count, maxVisible);
    final height = width * 1.42;
    return SizedBox(
      width: width + (visible - 1) * width * 0.34 + 2,
      height: height,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * width * 0.34,
              top: 0,
              child: PlayingCard(width: width, faceDown: true),
            ),
          if (count > maxVisible)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.feltDeep,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: AppTheme.goldSoft,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
