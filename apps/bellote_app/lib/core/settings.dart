import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._({
    required SharedPreferences preferences,
    required String playerName,
    required String serverUrl,
    required String localeCode,
    required String format,
    required String? savedCode,
    required String? savedToken,
  })  : _prefs = preferences,
        _playerName = playerName,
        _serverUrl = serverUrl,
        _localeCode = localeCode,
        _format = format,
        _savedCode = savedCode,
        _savedToken = savedToken;

  static const defaultServer = String.fromEnvironment(
    'BELLOTE_SERVER',
    defaultValue: 'ws://localhost:8080/ws',
  );

  final SharedPreferences _prefs;

  String _playerName;
  String _serverUrl;
  String _localeCode;
  String _format;
  String? _savedCode;
  String? _savedToken;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final systemLocale = PlatformDispatcher.instance.locale.languageCode;
    final locale =
        prefs.getString('locale') ?? (systemLocale == 'fr' ? 'fr' : 'en');
    return SettingsController._(
      preferences: prefs,
      playerName: prefs.getString('playerName') ?? '',
      serverUrl: prefs.getString('serverUrl') ?? defaultServer,
      localeCode: locale == 'fr' ? 'fr' : 'en',
      format: prefs.getString('format') ?? 'bestOf3',
      savedCode: prefs.getString('sessionCode'),
      savedToken: prefs.getString('sessionToken'),
    );
  }

  String get playerName => _playerName;
  String get serverUrl => _serverUrl;
  String get localeCode => _localeCode;
  Locale get locale => Locale(_localeCode);
  String get format => _format;
  String? get savedCode => _savedCode;
  String? get savedToken => _savedToken;
  bool get hasSavedSession =>
      _savedCode != null &&
      _savedCode!.isNotEmpty &&
      _savedToken != null &&
      _savedToken!.isNotEmpty;

  Future<void> setPlayerName(String value) async {
    final name = value.trim();
    if (name == _playerName) return;
    _playerName = name;
    await _prefs.setString('playerName', name);
    notifyListeners();
  }

  Future<void> setServerUrl(String value) async {
    final normalized = normalizeServerUrl(value);
    if (normalized == _serverUrl) return;
    _serverUrl = normalized;
    await _prefs.setString('serverUrl', normalized);
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    final normalized = code == 'fr' ? 'fr' : 'en';
    if (normalized == _localeCode) return;
    _localeCode = normalized;
    await _prefs.setString('locale', normalized);
    notifyListeners();
  }

  Future<void> setFormat(String value) async {
    final normalized =
        value == 'bestOf5' || value == 'singleSet' ? value : 'bestOf3';
    if (normalized == _format) return;
    _format = normalized;
    await _prefs.setString('format', normalized);
    notifyListeners();
  }

  Future<void> saveSession(String code, String token) async {
    _savedCode = code;
    _savedToken = token;
    await _prefs.setString('sessionCode', code);
    await _prefs.setString('sessionToken', token);
    notifyListeners();
  }

  Future<void> clearSession() async {
    if (_savedCode == null && _savedToken == null) return;
    _savedCode = null;
    _savedToken = null;
    await _prefs.remove('sessionCode');
    await _prefs.remove('sessionToken');
    notifyListeners();
  }

  static String normalizeServerUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return defaultServer;
    if (value.startsWith('http://')) {
      value = 'ws://${value.substring(7)}';
    } else if (value.startsWith('https://')) {
      value = 'wss://${value.substring(8)}';
    } else if (!value.startsWith('ws://') && !value.startsWith('wss://')) {
      value = 'ws://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return defaultServer;
    if (uri.path.isEmpty || uri.path == '/') {
      value = '${value.replaceAll(RegExp(r'/+$'), '')}/ws';
    }
    return value;
  }
}
