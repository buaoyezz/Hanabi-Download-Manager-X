import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const _zhArbPath = 'lib/l10n/app_zh.arb';
const _enArbPath = 'lib/l10n/app_en.arb';
const _autoSourceField = 'x-auto-source-zh';
const _autoSyncedAtField = 'x-auto-synced-at';
const _autoSyncDisabledField = 'x-auto-sync-disabled';
const _autoSyncPendingField = 'x-auto-sync-pending';
const _translationRequestTimeout = Duration(seconds: 12);
const _translationRetryDelays = <Duration>[
  Duration(milliseconds: 800),
  Duration(seconds: 2),
];

Future<void> main(List<String> args) async {
  final forceTranslate = args.contains('--force-translate');
  final dryRun = args.contains('--dry-run');

  final zhFile = File(_zhArbPath);
  final enFile = File(_enArbPath);

  if (!await zhFile.exists()) {
    stderr.writeln('Missing source ARB: $_zhArbPath');
    exitCode = 1;
    return;
  }

  if (!await enFile.exists()) {
    stderr.writeln('Missing target ARB: $_enArbPath');
    exitCode = 1;
    return;
  }

  final zh = _decodeArb(await zhFile.readAsString());
  final en = _decodeArb(await enFile.readAsString());
  final translator = _Translator();

  final output = <String, dynamic>{};
  var translatedCount = 0;
  var seededCount = 0;
  var keptCount = 0;
  var failedCount = 0;
  var removedCount = 0;

  for (final entry in zh.entries) {
    if (_isGlobalMetadataKey(entry.key)) {
      if (entry.key == '@@locale') {
        output[entry.key] = 'en';
      } else {
        output[entry.key] = entry.value;
      }
    }
  }

  final zhKeys = _translationKeys(zh);
  final enKeys = _translationKeys(en).toSet();
  final now = DateTime.now().toIso8601String();

  for (final key in zhKeys) {
    final sourceValue = zh[key];
    if (sourceValue is! String) {
      output[key] = sourceValue;
      continue;
    }

    final sourceMeta = _metadataMap(zh['@$key']);
    final existingValue = en[key];
    final existingMeta = _metadataMap(en['@$key']);
    final autoSyncDisabled = existingMeta[_autoSyncDisabledField] == true;
    final pendingRetry = existingMeta[_autoSyncPendingField] == true;
    final previousSource = existingMeta[_autoSourceField]?.toString();
    _TranslationAttempt? translationAttempt;

    dynamic nextValue = existingValue;
    if (autoSyncDisabled && existingValue != null) {
      keptCount++;
    } else if (forceTranslate || existingValue == null || pendingRetry) {
      translationAttempt = await _translateWithFallback(
        key: key,
        source: sourceValue,
        fallback: existingValue?.toString(),
        translator: translator,
      );
      nextValue = translationAttempt.value;
    } else if (previousSource == null) {
      seededCount++;
    } else if (previousSource != sourceValue) {
      translationAttempt = await _translateWithFallback(
        key: key,
        source: sourceValue,
        fallback: existingValue.toString(),
        translator: translator,
      );
      nextValue = translationAttempt.value;
    } else {
      keptCount++;
    }

    output[key] = nextValue;

    final mergedMeta = <String, dynamic>{};
    if (existingMeta.isNotEmpty) {
      mergedMeta.addAll(existingMeta);
    }
    if (sourceMeta.isNotEmpty) {
      mergedMeta.addAll(sourceMeta);
    }

    if (translationAttempt != null) {
      if (translationAttempt.succeeded) {
        translatedCount++;
        mergedMeta[_autoSourceField] = sourceValue;
        mergedMeta[_autoSyncedAtField] = now;
        mergedMeta.remove(_autoSyncPendingField);
      } else {
        failedCount++;
        mergedMeta[_autoSyncPendingField] = true;
      }
    } else if (!autoSyncDisabled && previousSource == null) {
      mergedMeta[_autoSourceField] = sourceValue;
      mergedMeta[_autoSyncedAtField] = now;
      mergedMeta.remove(_autoSyncPendingField);
    }

    output['@$key'] = mergedMeta;
    enKeys.remove(key);
  }

  removedCount = enKeys.length;

  final encoded = const JsonEncoder.withIndent('  ').convert(output);
  final nextContent = '$encoded\n';
  final previousContent = await enFile.readAsString();
  if (!dryRun) {
    if (previousContent != nextContent) {
      await enFile.writeAsString(nextContent);
    }
  }

  await translator.close();

  stdout.writeln(
    'l10n sync complete: translated=$translatedCount, seeded=$seededCount, kept=$keptCount, failed=$failedCount, removed=$removedCount${dryRun ? ' (dry-run)' : ''}',
  );
}

Map<String, dynamic> _decodeArb(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('ARB root must be an object');
  }
  return decoded;
}

bool _isMetadataKey(String key) => key.startsWith('@');

bool _isGlobalMetadataKey(String key) => key.startsWith('@@');

Iterable<String> _translationKeys(Map<String, dynamic> arb) sync* {
  for (final key in arb.keys) {
    if (_isMetadataKey(key)) {
      continue;
    }
    yield key;
  }
}

Map<String, dynamic> _metadataMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

Future<_TranslationAttempt> _translateWithFallback({
  required String key,
  required String source,
  String? fallback,
  required _Translator translator,
}) async {
  try {
    return _TranslationAttempt(
      value: await translator.translate(source),
      succeeded: true,
    );
  } catch (error) {
    if (error is! _TranslationProviderUnavailable) {
      stderr.writeln('translate failed for "$key": $error');
    }
    return _TranslationAttempt(
      value: fallback ?? source,
      succeeded: false,
    );
  }
}

_MaskedSource _maskSource(String source) {
  final tokens = <String, String>{};
  var index = 0;
  var masked = source;

  final newlineMatches = '\n'.allMatches(masked).length;
  for (var i = 0; i < newlineMatches; i++) {
    final token = '__HANABI_NL_${index}__';
    tokens[token] = '\n';
    masked = masked.replaceFirst('\n', token);
    index++;
  }

  final placeholderPattern = RegExp(r'\{[a-zA-Z0-9_]+\}');
  masked = masked.replaceAllMapped(placeholderPattern, (match) {
    final token = '__HANABI_PH_${index}__';
    tokens[token] = match.group(0)!;
    index++;
    return token;
  });

  return _MaskedSource(masked, tokens);
}

class _MaskedSource {
  const _MaskedSource(this.text, this.tokens);

  final String text;
  final Map<String, String> tokens;

  String restore(String value) {
    var restored = value;
    for (final entry in tokens.entries) {
      restored = restored.replaceAll(entry.key, entry.value);
    }
    return restored;
  }
}

class _Translator {
  _Translator() : _client = _createHttpClient();

  final http.Client _client;
  bool _providerAvailable = true;
  bool _providerUnavailableLogged = false;

  Future<void> close() async {
    _client.close();
  }

  Future<String> translate(String source) async {
    if (source.trim().isEmpty) {
      return source;
    }

    if (!_providerAvailable) {
      throw const _TranslationProviderUnavailable();
    }

    final masked = _maskSource(source);
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': 'zh-CN',
      'tl': 'en',
      'dt': 't',
      'q': masked.text,
    });

    for (var attempt = 0;
        attempt <= _translationRetryDelays.length;
        attempt++) {
      try {
        final response =
            await _client.get(uri).timeout(_translationRequestTimeout);
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
        }

        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! List || decoded.isEmpty || decoded.first is! List) {
          throw const FormatException('Unexpected translation payload');
        }

        final buffer = StringBuffer();
        for (final segment in decoded.first as List) {
          if (segment is List && segment.isNotEmpty && segment.first != null) {
            buffer.write(segment.first.toString());
          }
        }

        final translated = buffer.toString().trim();
        return masked.restore(translated.isEmpty ? source : translated);
      } on TimeoutException catch (error) {
        if (_shouldTripCircuit(attempt)) {
          _markProviderUnavailable(error);
          rethrow;
        }
      } on SocketException catch (error) {
        if (_shouldTripCircuit(attempt)) {
          _markProviderUnavailable(error);
          rethrow;
        }
      } on http.ClientException catch (error) {
        if (_shouldTripCircuit(attempt)) {
          _markProviderUnavailable(error);
          rethrow;
        }
      }

      await Future<void>.delayed(_translationRetryDelays[attempt]);
    }

    throw StateError('Unreachable translation retry state');
  }

  bool _shouldTripCircuit(int attempt) {
    return attempt >= _translationRetryDelays.length;
  }

  void _markProviderUnavailable(Object error) {
    _providerAvailable = false;
    if (_providerUnavailableLogged) {
      return;
    }

    _providerUnavailableLogged = true;
    stderr.writeln(
      'translation provider unavailable (translate.googleapis.com): $error',
    );
    stderr.writeln(
      'remaining keys will fall back to existing English text or Chinese source. '
      'Set HTTPS_PROXY/HTTP_PROXY if you need this script to translate through a proxy.',
    );
  }
}

http.Client _createHttpClient() {
  final client = HttpClient()
    ..connectionTimeout = _translationRequestTimeout
    ..findProxy = HttpClient.findProxyFromEnvironment;
  return IOClient(client);
}

class _TranslationProviderUnavailable implements Exception {
  const _TranslationProviderUnavailable();

  @override
  String toString() => 'translation provider is unavailable';
}

class _TranslationAttempt {
  const _TranslationAttempt({
    required this.value,
    required this.succeeded,
  });

  final String value;
  final bool succeeded;
}
