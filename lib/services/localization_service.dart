import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;

import 'app_logger_service.dart';
import 'client_config_service.dart';

class LanguagePack {
  LanguagePack({
    required this.localeTag,
    required this.locale,
    required this.strings,
    this.name,
    this.author,
    this.version,
    this.source,
    this.defaultFontFamily,
    this.defaultEnglishFontFamily,
    this.fontLocaleTag,
  });

  final String localeTag;
  final Locale locale;
  final Map<String, String> strings;
  final String? name;
  final String? author;
  final String? version;
  final String? source;
  final String? defaultFontFamily;
  final String? defaultEnglishFontFamily;
  final String? fontLocaleTag;
}

class LocalizationService extends ChangeNotifier {
  final AppLoggerService _logger = AppLoggerService();
  final Map<String, LanguagePack> _packs = {};

  late ClientConfigService _config;
  int _revision = 0;

  int get revision => _revision;
  List<LanguagePack> get languagePacks => List.unmodifiable(_packs.values);

  Future<void> initialize(ClientConfigService config) async {
    _config = config;
    await _loadLanguagePacks();
  }

  List<Locale> get supportedLocales {
    final locales = <Locale>[
      const Locale('en'),
      const Locale('zh'),
    ];

    for (final pack in _packs.values) {
      if (!_containsLocale(locales, pack.locale)) {
        locales.add(pack.locale);
      }
    }

    return locales;
  }

  bool isSupported(Locale locale) {
    return _resolveSupportedLocale(locale) != null;
  }

  Locale resolveSupportedLocale(Locale locale) {
    return _resolveSupportedLocale(locale) ?? _builtinFallbackLocale(locale);
  }

  Map<String, String>? getStringsFor(Locale locale) {
    final requestedKey = _localeKey(locale);
    final pack = _resolveLanguagePack(locale);
    _logger.info('Lang',
        'getStringsFor: locale=$locale, requestedKey=$requestedKey, resolvedKey=${pack == null ? "-" : _localeKey(pack.locale)}, found=${pack != null}, strings=${pack?.strings.length ?? 0}');
    return pack?.strings;
  }

  String get languagePreference {
    return _config.getLanguagePreference();
  }

  Future<void> setLanguagePreference(String value) async {
    await _config.setLanguagePreference(value);
    _revision++; // Force reload when language changes
    notifyListeners();
  }

  Locale get effectiveLocale {
    final preference = languagePreference.trim();
    if (preference.isEmpty || preference == 'system') {
      return _defaultLocaleFromSystem();
    }

    final normalized = _normalizeLocaleTag(preference);
    final locale = _parseLocaleTag(normalized);
    final supportedLocale = _resolveSupportedLocale(locale);
    if (supportedLocale != null) {
      return supportedLocale;
    }

    return _defaultLocaleFromSystem();
  }

  Future<void> reloadLanguagePacks() async {
    await _loadLanguagePacks();
    notifyListeners();
  }

  Future<void> _loadLanguagePacks() async {
    final langDir = Directory(path.join(_config.baseDir, 'lang'));
    if (!await langDir.exists()) {
      await langDir.create(recursive: true);
      _logger.info('Lang', 'Created language pack directory: ${langDir.path}');
    }

    final Map<String, LanguagePack> loaded = {};

    await for (final entity in langDir.list()) {
      if (entity is! File) continue;
      final ext = path.extension(entity.path).toLowerCase();
      if (ext != '.json' && ext != '.arb') continue;

      try {
        final content = await entity.readAsString();
        final data = jsonDecode(content);
        if (data is! Map<String, dynamic>) {
          _logger.warning('Lang', 'Invalid pack (not object): ${entity.path}');
          continue;
        }

        final localeTag = _extractLocaleTag(data, entity.path);
        if (localeTag == null || localeTag.isEmpty) {
          _logger.warning('Lang', 'Missing locale tag: ${entity.path}');
          continue;
        }

        final normalizedTag = _normalizeLocaleTag(localeTag);
        final locale = _parseLocaleTag(normalizedTag);

        if (_isBuiltInLocaleTag(normalizedTag)) {
          _logger.warning(
              'Lang', 'Ignore built-in locale pack: $normalizedTag');
          continue;
        }

        final strings = _extractStrings(data);
        if (strings.isEmpty) {
          _logger.warning('Lang', 'No strings in pack: ${entity.path}');
          continue;
        }

        final key = _localeKey(locale);
        loaded[key] = LanguagePack(
          localeTag: normalizedTag,
          locale: locale,
          strings: strings,
          name:
              _readString(data, '@@languageName') ?? _readString(data, 'name'),
          author: _readString(data, 'author'),
          version: _readString(data, 'version'),
          source: _readString(data, 'source'),
          defaultFontFamily: _readString(data, '@@defaultFont') ??
              _readString(data, 'defaultFont'),
          defaultEnglishFontFamily: _readString(data, '@@defaultEnglishFont') ??
              _readString(data, 'defaultEnglishFont'),
          fontLocaleTag: _readString(data, '@@fontLocale') ??
              _readString(data, 'fontLocale'),
        );
        _logger.info('Lang',
            'Loaded pack: $normalizedTag -> key=$key, strings=${strings.length}');
      } catch (e) {
        _logger.error('Lang', 'Failed to load pack ${entity.path}: $e');
      }
    }

    _packs
      ..clear()
      ..addAll(loaded);
    _revision++;
    _logger.info('Lang',
        'Loaded ${_packs.length} language pack(s), keys: ${_packs.keys.join(", ")}');
  }

  Locale _defaultLocaleFromSystem() {
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    final resolvedSystemLocale = _resolveSupportedLocale(system);
    if (resolvedSystemLocale != null) {
      return resolvedSystemLocale;
    }

    return _builtinFallbackLocale(system);
  }

  String? _extractLocaleTag(Map<String, dynamic> data, String filePath) {
    final fromData =
        _readString(data, '@@locale') ?? _readString(data, 'locale');
    if (fromData != null && fromData.trim().isNotEmpty) {
      return fromData.trim();
    }

    final base = path.basenameWithoutExtension(filePath);
    if (base.startsWith('app_') && base.length > 4) {
      return base.substring(4);
    }
    return base;
  }

  Map<String, String> _extractStrings(Map<String, dynamic> data) {
    final Map<String, String> result = {};
    final dynamic rawStrings = data['strings'];

    if (rawStrings is Map) {
      rawStrings.forEach((key, value) {
        if (key is String && value is String) {
          result[key] = value;
        }
      });
      return result;
    }

    data.forEach((key, value) {
      if (key.startsWith('@')) return;
      if (value is String) {
        result[key] = value;
      }
    });

    return result;
  }

  String? _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    return null;
  }

  bool _containsLocale(List<Locale> locales, Locale locale) {
    return locales.any((item) => _localeKey(item) == _localeKey(locale));
  }

  String _normalizeLocaleTag(String tag) {
    return tag.replaceAll('-', '_').trim();
  }

  Locale _parseLocaleTag(String tag) {
    final parts = tag.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return const Locale('en');
    if (parts.length == 1) return Locale(parts[0]);
    if (parts.length == 2) {
      if (_looksLikeScriptCode(parts[1])) {
        return Locale.fromSubtags(
          languageCode: parts[0],
          scriptCode: _normalizeScriptCode(parts[1]),
        );
      }
      return Locale(parts[0], parts[1]);
    }

    final hasScriptCode = _looksLikeScriptCode(parts[1]);
    return Locale.fromSubtags(
      languageCode: parts[0],
      scriptCode: hasScriptCode ? _normalizeScriptCode(parts[1]) : null,
      countryCode: hasScriptCode ? parts[2] : parts[1],
    );
  }

  bool _looksLikeScriptCode(String value) {
    return value.length == 4 && RegExp(r'^[A-Za-z]{4}$').hasMatch(value);
  }

  String _normalizeScriptCode(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _localeKey(Locale locale) {
    final buffer = StringBuffer(locale.languageCode);
    final script = locale.scriptCode;
    final country = locale.countryCode;
    if (script != null && script.isNotEmpty) {
      buffer.write('_$script');
    }
    if (country != null && country.isNotEmpty) {
      buffer.write('_$country');
    }
    return buffer.toString();
  }

  bool _isBuiltInLocaleTag(String localeTag) {
    final normalizedTag = _normalizeLocaleTag(localeTag);
    return normalizedTag == 'en' || normalizedTag == 'zh';
  }

  Locale? _resolveSupportedLocale(Locale locale) {
    final exactPack = _packs[_localeKey(locale)];
    if (exactPack != null) {
      return exactPack.locale;
    }

    final exactBuiltin = _exactBuiltInLocale(locale);
    if (exactBuiltin != null) {
      return exactBuiltin;
    }

    final fallbackPack = _resolveLanguagePack(locale);
    if (fallbackPack != null) {
      return fallbackPack.locale;
    }

    final languageCode = locale.languageCode.toLowerCase();
    if (languageCode == 'en' || languageCode == 'zh') {
      return _builtinFallbackLocale(locale);
    }

    return null;
  }

  LanguagePack? _resolveLanguagePack(Locale locale) {
    final exactPack = _packs[_localeKey(locale)];
    if (exactPack != null) {
      return exactPack;
    }

    final languageCode = locale.languageCode.toLowerCase();
    if (languageCode == 'zh' && _isTraditionalChineseLocale(locale)) {
      return _findSupportedTraditionalChinesePack(requestedLocale: locale);
    }

    return _packs[languageCode];
  }

  Locale? _exactBuiltInLocale(Locale locale) {
    final normalizedKey = _normalizeLocaleTag(_localeKey(locale));
    if (normalizedKey == 'en') {
      return const Locale('en');
    }
    if (normalizedKey == 'zh') {
      return const Locale('zh');
    }
    return null;
  }

  Locale _builtinFallbackLocale(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'zh') {
      return const Locale('zh');
    }
    return const Locale('en');
  }

  bool _isTraditionalChineseLocale(Locale locale) {
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();
    return scriptCode == 'hant' ||
        countryCode == 'TW' ||
        countryCode == 'HK' ||
        countryCode == 'MO';
  }

  LanguagePack? _findSupportedTraditionalChinesePack(
      {Locale? requestedLocale}) {
    final candidates = _packs.values
        .where((pack) => pack.locale.languageCode.toLowerCase() == 'zh')
        .where((pack) => _isTraditionalChineseLocale(pack.locale))
        .toList();
    if (candidates.isEmpty) {
      return null;
    }

    final requestedCountryCode = requestedLocale?.countryCode?.toUpperCase();
    if (requestedCountryCode != null && requestedCountryCode.isNotEmpty) {
      for (final pack in candidates) {
        if (pack.locale.countryCode?.toUpperCase() == requestedCountryCode) {
          return pack;
        }
      }
    }

    for (final pack in candidates) {
      if (pack.locale.scriptCode?.toLowerCase() == 'hant') {
        return pack;
      }
    }

    const preferredCountries = <String>['TW', 'HK', 'MO'];
    for (final countryCode in preferredCountries) {
      for (final pack in candidates) {
        if (pack.locale.countryCode?.toUpperCase() == countryCode) {
          return pack;
        }
      }
    }

    for (final pack in _packs.values) {
      if (pack.locale.languageCode.toLowerCase() != 'zh') {
        continue;
      }
      if (_isTraditionalChineseLocale(pack.locale)) {
        return pack;
      }
    }
    return null;
  }
}
