import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'common.dart';

Future<void> showSettingsSheet(
  BuildContext context,
  SettingsController settings,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SettingsSheet(settings: settings),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings});

  final SettingsController settings;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.settings.playerName,
  );
  late final TextEditingController _server = TextEditingController(
    text: widget.settings.serverUrl,
  );
  late String _language = widget.settings.localeCode;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setPlayerName(_name.text);
    await widget.settings.setServerUrl(_server.text);
    await widget.settings.setLocale(_language);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.tune, color: AppTheme.gold, size: 20),
                const SizedBox(width: 10),
                Text(
                  l10n.t('settings'),
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 19,
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
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              maxLength: 20,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.t('playerName'),
                hintText: l10n.t('nameHint'),
                counterText: '',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.t('serverUrl'),
                hintText: l10n.t('serverHint'),
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 22),
            SectionLabel(l10n.t('language')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LanguageTile(
                    label: l10n.t('languageFrench'),
                    selected: _language == 'fr',
                    onTap: () => setState(() => _language = 'fr'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LanguageTile(
                    label: l10n.t('languageEnglish'),
                    selected: _language == 'en',
                    onTap: () => setState(() => _language = 'en'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l10n.t('saveSettings')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? AppTheme.gold : AppTheme.gold.withValues(alpha: 0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 16,
              color: selected ? AppTheme.gold : AppTheme.muted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.goldSoft : AppTheme.cream,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
