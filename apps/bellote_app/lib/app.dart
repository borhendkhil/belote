import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:material_ui/material_ui.dart';

import 'core/l10n.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'net/game_client.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/table_screen.dart';

class BelloteApp extends StatefulWidget {
  const BelloteApp({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<BelloteApp> createState() => _BelloteAppState();
}

class _BelloteAppState extends State<BelloteApp> {
  late final GameClient _client;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _client = GameClient(settings: widget.settings);
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Belote Contrée',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: widget.settings.locale,
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            L10nDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          scaffoldMessengerKey: _messengerKey,
          home: _AppShell(
            client: _client,
            settings: widget.settings,
            messengerKey: _messengerKey,
          ),
        );
      },
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.client,
    required this.settings,
    required this.messengerKey,
  });

  final GameClient client;
  final SettingsController settings;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late int _lastErrorNonce = widget.client.errorNonce;

  @override
  void initState() {
    super.initState();
    widget.client.addListener(_onClientChanged);
  }

  @override
  void didUpdateWidget(covariant _AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      oldWidget.client.removeListener(_onClientChanged);
      widget.client.addListener(_onClientChanged);
      _lastErrorNonce = widget.client.errorNonce;
    }
  }

  @override
  void dispose() {
    widget.client.removeListener(_onClientChanged);
    super.dispose();
  }

  void _onClientChanged() {
    if (!mounted) return;
    setState(() {});

    final nonce = widget.client.errorNonce;
    if (nonce == _lastErrorNonce) return;
    _lastErrorNonce = nonce;
    final code = widget.client.errorCode;
    if (code == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = widget.messengerKey.currentState;
      if (messenger == null) return;
      final l10n = L10n(widget.settings.locale);
      final text = code == 'connection_failed'
          ? l10n.t('connectionError')
          : l10n.errorText(code);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
      widget.client.clearError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    Widget screen;
    if (client.room != null) {
      final inGame = client.view != null ||
          client.stage == ClientStage.playing ||
          client.stage == ClientStage.ended ||
          client.room!.started;
      screen =
          inGame ? TableScreen(client: client) : LobbyScreen(client: client);
    } else {
      screen = HomeScreen(client: client);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_screenKey(client)), child: screen),
    );
  }

  String _screenKey(GameClient client) {
    if (client.room == null) return 'home';
    final inGame = client.view != null ||
        client.stage == ClientStage.playing ||
        client.stage == ClientStage.ended ||
        client.room!.started;
    return inGame ? 'table' : 'lobby';
  }
}
