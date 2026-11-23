import 'package:bellote_engine/bellote_engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.client});

  final GameClient client;

  @override
  Widget build(BuildContext context) {
    if (!client.isReconnecting && client.stage != ClientStage.connecting) {
      return const SizedBox.shrink();
    }
    final l10n = L10n.of(context);
    return Container(
      width: double.infinity,
      color: AppTheme.gold.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            client.isReconnecting
                ? l10n.t('reconnecting')
                : l10n.t('connecting'),
            style: const TextStyle(
              color: AppTheme.goldSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SuitBadge extends StatelessWidget {
  const SuitBadge({
    super.key,
    required this.suit,
    this.size = 22,
    this.selected = false,
    this.onTap,
    this.color,
  });

  final Suit suit;
  final double size;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? (suit.isRed ? AppTheme.red : AppTheme.ink);
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size * 1.8,
      height: size * 1.8,
      decoration: BoxDecoration(
        color: selected ? AppTheme.gold : AppTheme.cream,
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(
          color: selected
              ? AppTheme.goldSoft
              : Colors.black.withValues(alpha: 0.2),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          suit.symbol,
          style: TextStyle(
            color: selected ? AppTheme.feltDeep : ink,
            fontSize: size,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key, this.height = 1, this.opacity = 0.22});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: AppTheme.gold.withValues(alpha: opacity),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  text.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: GoldDivider()),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class TeamDot extends StatelessWidget {
  const TeamDot({super.key, required this.team, this.size = 8});

  final int team;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: teamColor(team),
        boxShadow: [
          BoxShadow(
            color: teamColor(team).withValues(alpha: 0.45),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

Color teamColor(int team) =>
    team == 0 ? AppTheme.gold : const Color(0xFF7CC7E8);

String _firstGlyph(String value) {
  if (value.isEmpty) return '?';
  return String.fromCharCode(value.runes.first);
}

String initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return _firstGlyph(parts.first).toUpperCase();
  }
  return '${_firstGlyph(parts.first)}${_firstGlyph(parts.last)}'.toUpperCase();
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.goldSoft;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 11,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 15, color: tint),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: dense ? 10 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

void showLocalizedSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
