import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Anneau de compte à rebours autour de l'avatar du joueur dont c'est le tour.
/// La portion colorée représente le temps restant ; elle rétrécit puis rougit
/// quand l'échéance approche.
class TurnRing extends StatefulWidget {
  const TurnRing({
    super.key,
    required this.deadline,
    required this.duration,
    required this.size,
    required this.child,
    this.thickness = 3.2,
  });

  /// Échéance du tour, sur l'horloge de l'appareil.
  final DateTime deadline;

  /// Durée totale allouée au tour.
  final Duration duration;

  /// Diamètre de l'avatar entouré.
  final double size;

  final Widget child;
  final double thickness;

  @override
  State<TurnRing> createState() => _TurnRingState();
}

class _TurnRingState extends State<TurnRing> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(TurnRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds;
    final left = widget.deadline.difference(DateTime.now()).inMilliseconds;
    final progress = total <= 0 ? 0.0 : (left.clamp(0, total) / total);
    // Doré tant qu'il reste du temps, puis bascule vers le rouge.
    final color = progress > 0.5
        ? AppTheme.gold
        : Color.lerp(
            const Color(0xFFE05252),
            AppTheme.gold,
            (progress / 0.5).clamp(0.0, 1.0),
          )!;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: CustomPaint(
              painter: TurnRingPainter(
                progress: progress,
                color: color,
                thickness: widget.thickness,
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class TurnRingPainter extends CustomPainter {
  TurnRingPainter({
    required this.progress,
    required this.color,
    required this.thickness,
  });

  final double progress;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(thickness / 2, thickness / 2) &
        Size(size.width - thickness, size.height - thickness);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Départ en haut, sens horaire.
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(TurnRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.thickness != thickness;
}
