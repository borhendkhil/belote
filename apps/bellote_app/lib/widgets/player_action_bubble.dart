import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Durée d'affichage d'une bulle d'action près du siège qui l'a effectuée.
const actionBubbleDuration = Duration(milliseconds: 3200);

/// Clé de traduction associée à une action jouable en bulle.
///
/// Aucune bulle n'est produite pour l'ouverture du pli : celle-ci est indiquée
/// par la pièce dorée du [LeadCoin].
String? actionBubbleKey(String type) => switch (type) {
      'pass' => 'bubblePass',
      'belote' => 'bubbleBelote',
      'rebelote' => 'bubbleRebelote',
      _ => null,
    };

/// Petite bulle de discussion affichée près d'un joueur après une action
/// (passe, belote, rebelote). Chaque action a sa propre couleur et son icône.
class PlayerActionBubble extends StatelessWidget {
  const PlayerActionBubble({
    super.key,
    required this.action,
    required this.label,
    required this.seat,
    this.compact = false,
  });

  final String action;
  final String label;
  final int seat;
  final bool compact;

  static Color colorOf(String action) => switch (action) {
        'pass' => const Color(0xFF5C8178),
        'belote' => AppTheme.gold,
        'rebelote' => const Color(0xFF78D4C5),
        _ => AppTheme.muted,
      };

  Color get color => colorOf(action);

  bool get _darkInk => action != 'pass';

  IconData get _icon => switch (action) {
        'pass' => Icons.block,
        'belote' => Icons.music_note,
        'rebelote' => Icons.auto_awesome,
        _ => Icons.chat_bubble_outline,
      };

  @override
  Widget build(BuildContext context) {
    final ink = _darkInk ? AppTheme.feltDeep : AppTheme.cream;
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(3),
            bottomLeft: Radius.circular(12),
          ),
          border: Border.all(color: ink.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.34),
              blurRadius: 9,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: compact ? 11 : 13, color: ink),
            SizedBox(width: compact ? 3 : 5),
            Text(
              label,
              style: TextStyle(
                color: ink,
                fontSize: compact ? 9.5 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
