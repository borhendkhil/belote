import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import '../widgets/rules_sheet.dart';
import '../widgets/settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.client});

  final GameClient client;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.client.settings.playerName,
  );
  final TextEditingController _code = TextEditingController();

  GameClient get client => widget.client;

  bool get _busy => client.stage == ClientStage.connecting;

  bool get _nameOk => _name.text.trim().isNotEmpty;
  bool get _codeOk => _code.text.trim().length == 5;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_nameOk || _busy) return;
    await client.createRoom(name: _name.text, format: client.settings.format);
  }

  Future<void> _join() async {
    if (!_nameOk || !_codeOk || _busy) return;
    await client.joinRoom(name: _name.text, roomCode: _code.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: client,
      builder: (context, _) {
        final l10n = L10n.of(context);
        final settings = client.settings;

        return Scaffold(
          body: Container(
            decoration: AppTheme.feltBackground(),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                    children: [
                      ConnectionBanner(client: client),
                      Row(
                        children: [
                          StatusPill(
                            label: l10n.t('version'),
                            dense: true,
                            color: AppTheme.muted,
                            icon: Icons.circle,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => settings.setLocale(
                              settings.localeCode == 'fr' ? 'en' : 'fr',
                            ),
                            icon: const Icon(Icons.translate, size: 17),
                            label: Text(settings.localeCode.toUpperCase()),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                showSettingsSheet(context, settings),
                            tooltip: l10n.t('settings'),
                            icon: const Icon(Icons.tune, size: 20),
                            color: AppTheme.goldSoft,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Center(child: AppLogo(height: 88)),
                      const SizedBox(height: 14),
                      Text(
                        l10n.t('appTitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.cream,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.t('tagline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (client.hasSavedSession) ...[
                        _ResumeCard(client: client),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _name,
                        maxLength: 20,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l10n.t('playerName'),
                          hintText: l10n.t('nameHint'),
                          counterText: '',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CreateCard(
                        l10n: l10n,
                        format: settings.format,
                        onFormat: settings.setFormat,
                        onStart: _nameOk && !_busy ? _create : null,
                        busy: _busy,
                      ),
                      const SizedBox(height: 14),
                      _JoinCard(
                        l10n: l10n,
                        codeController: _code,
                        onCodeChanged: () => setState(() {}),
                        onJoin: _nameOk && _codeOk && !_busy ? _join : null,
                        busy: _busy,
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => showRulesSheet(context),
                              icon: const Icon(
                                Icons.menu_book_outlined,
                                size: 17,
                              ),
                              label: Text(l10n.t('rules')),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  showSettingsSheet(context, settings),
                              icon: const Icon(Icons.tune, size: 17),
                              label: Text(l10n.t('settings')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.client});

  final GameClient client;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final settings = client.settings;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppTheme.gold, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  l10n.t('resumeGame'),
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (settings.savedCode != null)
                StatusPill(
                  label: settings.savedCode!,
                  dense: true,
                  icon: Icons.tag,
                ),
              IconButton(
                onPressed: settings.clearSession,
                tooltip: l10n.t('clearSession'),
                icon: const Icon(Icons.close, size: 17),
                color: AppTheme.muted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.t('resumeHint'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: client.resumeSession,
              icon: const Icon(Icons.play_arrow_rounded, size: 19),
              label: Text(l10n.t('resumeGame')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.l10n,
    required this.format,
    required this.onFormat,
    required this.onStart,
    required this.busy,
  });

  final L10n l10n;
  final String format;
  final ValueChanged<String> onFormat;
  final VoidCallback? onStart;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    const formats = ['bestOf3', 'bestOf5', 'singleSet'];
    return _SectionCard(
      title: l10n.t('createRoom'),
      icon: Icons.add_circle_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.t('formatHint'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final item in formats)
                _FormatChip(
                  label: l10n.formatLabel(item),
                  selected: format == item,
                  onTap: () => onFormat(item),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onStart,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.feltDeep,
                    ),
                  )
                : const Icon(Icons.casino_outlined, size: 19),
            label: Text(l10n.t('createRoom')),
          ),
        ],
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.l10n,
    required this.codeController,
    required this.onCodeChanged,
    required this.onJoin,
    required this.busy,
  });

  final L10n l10n;
  final TextEditingController codeController;
  final VoidCallback onCodeChanged;
  final VoidCallback? onJoin;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: l10n.t('joinRoom'),
      icon: Icons.group_add_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.t('joinHint'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: codeController,
            maxLength: 5,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onCodeChanged(),
            onSubmitted: (_) => onJoin?.call(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            ],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
            ),
            decoration: InputDecoration(
              hintText: 'ABCDE',
              counterText: '',
              prefixIcon: const Icon(Icons.tag, size: 19),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onJoin,
            icon: busy
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login, size: 18),
            label: Text(l10n.t('joinRoom')),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : AppTheme.gold.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.goldSoft : AppTheme.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
