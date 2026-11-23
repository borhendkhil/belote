import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../net/game_client.dart';
import 'common.dart';

Future<void> showChatSheet(BuildContext context, GameClient client) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChatSheet(client: client),
  );
}

class ChatSheet extends StatefulWidget {
  const ChatSheet({super.key, required this.client});

  final GameClient client;

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    widget.client.sendChat(value);
    _text.clear();
    _focus.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.68;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.forum_outlined,
                    color: AppTheme.gold,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.t('chat'),
                    style: const TextStyle(
                      color: AppTheme.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.client.code != null) ...[
                    const SizedBox(width: 8),
                    StatusPill(
                      label: widget.client.code!,
                      dense: true,
                      icon: Icons.tag,
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppTheme.muted,
                  ),
                ],
              ),
            ),
            const GoldDivider(),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.client,
                builder: (context, _) {
                  final messages = widget.client.chat;
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.t('chatEmpty'),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final entry = messages[index];
                      final mine = entry.seat == widget.client.seat;
                      final tint = entry.seat == null
                          ? AppTheme.muted
                          : teamColor(entry.seat! % 2);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine ? l10n.t('you') : entry.name,
                              style: TextStyle(
                                color: tint,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? AppTheme.gold.withValues(alpha: 0.16)
                                    : Colors.black.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: mine
                                      ? AppTheme.gold.withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Text(
                                entry.text,
                                style: const TextStyle(
                                  color: AppTheme.cream,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const GoldDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      textInputAction: TextInputAction.send,
                      maxLength: 180,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: l10n.t('typeMessage'),
                        counterText: '',
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    tooltip: l10n.t('send'),
                    icon: const Icon(Icons.send),
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
