enum DownloadIntentType {
  http,
  magnet,
  torrentFile,
  ed2k,
  resolver,
  custom,
  unsupported,
}

extension DownloadIntentTypeName on DownloadIntentType {
  String get wireName {
    switch (this) {
      case DownloadIntentType.http:
        return 'http';
      case DownloadIntentType.magnet:
        return 'magnet';
      case DownloadIntentType.torrentFile:
        return 'torrent_file';
      case DownloadIntentType.ed2k:
        return 'ed2k';
      case DownloadIntentType.resolver:
        return 'resolver';
      case DownloadIntentType.custom:
        return 'custom';
      case DownloadIntentType.unsupported:
        return 'unsupported';
    }
  }

  static DownloadIntentType fromWireName(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'http':
        return DownloadIntentType.http;
      case 'magnet':
        return DownloadIntentType.magnet;
      case 'torrent_file':
      case 'torrentfile':
      case 'torrent':
        return DownloadIntentType.torrentFile;
      case 'ed2k':
      case 'edonkey':
        return DownloadIntentType.ed2k;
      case 'resolver':
        return DownloadIntentType.resolver;
      case 'custom':
        return DownloadIntentType.custom;
      default:
        return DownloadIntentType.unsupported;
    }
  }
}

class DownloadIntent {
  const DownloadIntent._({
    required this.rawValue,
    required this.normalizedValue,
    required this.type,
    required this.uri,
    this.sourceMeta = const <String, dynamic>{},
    this.pluginHint,
  });

  final String rawValue;
  final String normalizedValue;
  final DownloadIntentType type;
  final Uri? uri;
  final Map<String, dynamic> sourceMeta;
  final String? pluginHint;

  bool get isRecognized => type != DownloadIntentType.unsupported;
  bool get isCurrentlySupported => type == DownloadIntentType.http;
  bool get isHttp => type == DownloadIntentType.http;
  bool get isMagnet => type == DownloadIntentType.magnet;
  bool get isTorrentFile => type == DownloadIntentType.torrentFile;
  bool get isEd2k => type == DownloadIntentType.ed2k;
  bool get isResolver => type == DownloadIntentType.resolver;
  bool get isCustom => type == DownloadIntentType.custom;

  Map<String, dynamic> toJson() => {
        'rawValue': rawValue,
        'normalizedValue': normalizedValue,
        'type': type.wireName,
        if (uri != null) 'uri': uri.toString(),
        if (sourceMeta.isNotEmpty) 'sourceMeta': sourceMeta,
        if (pluginHint != null && pluginHint!.isNotEmpty)
          'pluginHint': pluginHint,
      };

  static DownloadIntent fromJson(Map<String, dynamic> json) {
    final raw = json['rawValue']?.toString() ??
        json['raw']?.toString() ??
        json['value']?.toString() ??
        '';
    final normalized = json['normalizedValue']?.toString();
    final type = DownloadIntentTypeName.fromWireName(json['type']?.toString());
    final uriText = json['uri']?.toString();
    final parsedUri = uriText == null ? null : Uri.tryParse(uriText);
    final sourceMetaRaw = json['sourceMeta'];
    final sourceMeta = sourceMetaRaw is Map
        ? sourceMetaRaw.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};

    if (type == DownloadIntentType.unsupported) {
      return parse(
        raw,
        sourceMeta: sourceMeta,
        pluginHint: json['pluginHint']?.toString(),
      );
    }

    return DownloadIntent._(
      rawValue: raw,
      normalizedValue: normalized ?? raw,
      type: type,
      uri: parsedUri,
      sourceMeta: Map.unmodifiable(sourceMeta),
      pluginHint: json['pluginHint']?.toString(),
    );
  }

  static DownloadIntent parse(
    String? raw, {
    Map<String, dynamic>? sourceMeta,
    String? pluginHint,
  }) {
    final value = raw?.trim() ?? '';
    final Map<String, dynamic> meta =
        Map.unmodifiable(sourceMeta ?? const <String, dynamic>{});
    final hint = _cleanPluginHint(pluginHint);
    if (value.isEmpty) {
      return DownloadIntent._(
        rawValue: '',
        normalizedValue: '',
        type: DownloadIntentType.unsupported,
        uri: null,
        sourceMeta: meta,
        pluginHint: hint,
      );
    }

    if (_looksLikeEd2kFileLink(value)) {
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: _normalizeEd2kFileLink(value),
        type: DownloadIntentType.ed2k,
        uri: Uri.tryParse(value),
        sourceMeta: meta,
        pluginHint: hint,
      );
    }

    final parsed = Uri.tryParse(value);
    if (parsed == null) {
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: value,
        type: DownloadIntentType.unsupported,
        uri: null,
        sourceMeta: meta,
        pluginHint: hint,
      );
    }

    final scheme = parsed.scheme.toLowerCase();
    if ((scheme == 'http' || scheme == 'https') &&
        parsed.hasScheme &&
        parsed.hasAuthority) {
      final normalized = parsed
          .replace(
            scheme: scheme,
            host: parsed.host.toLowerCase(),
          )
          .toString()
          .split('#')
          .first;
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: normalized,
        type: DownloadIntentType.http,
        uri: parsed,
        sourceMeta: meta,
        pluginHint: hint,
      );
    }

    if (scheme == 'magnet') {
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: _normalizeMagnet(parsed),
        type: DownloadIntentType.magnet,
        uri: parsed,
        sourceMeta: meta,
        pluginHint: _pluginHintFromUri(parsed, hint),
      );
    }

    if (scheme == 'file' && _looksLikeTorrentFilePath(parsed.path)) {
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: _normalizeFileUri(parsed),
        type: DownloadIntentType.torrentFile,
        uri: parsed,
        sourceMeta: meta,
        pluginHint: _pluginHintFromUri(parsed, hint),
      );
    }

    if (scheme == 'resolver' || scheme == 'hanabi-resolver') {
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: value,
        type: DownloadIntentType.resolver,
        uri: parsed,
        sourceMeta: meta,
        pluginHint: _pluginHintFromUri(parsed, hint),
      );
    }

    if (scheme.startsWith('hanabi+') || scheme.startsWith('plugin+')) {
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: value,
        type: DownloadIntentType.custom,
        uri: parsed,
        sourceMeta: meta,
        pluginHint: _pluginHintFromUri(parsed, hint),
      );
    }

    if (_looksLikeTorrentFilePath(value)) {
      return DownloadIntent._(
        rawValue: value,
        normalizedValue: _normalizeTorrentPath(value),
        type: DownloadIntentType.torrentFile,
        uri: null,
        sourceMeta: meta,
        pluginHint: hint,
      );
    }

    return DownloadIntent._(
      rawValue: value,
      normalizedValue: value,
      type: DownloadIntentType.unsupported,
      uri: parsed,
      sourceMeta: meta,
      pluginHint: hint,
    );
  }

  String? suggestedFileName() {
    switch (type) {
      case DownloadIntentType.http:
        return _sanitizeFileName(_httpFileName(uri));
      case DownloadIntentType.magnet:
        return _sanitizeFileName(_magnetDisplayName(uri));
      case DownloadIntentType.torrentFile:
        return _sanitizeFileName(_fileNameFromPath(normalizedValue));
      case DownloadIntentType.ed2k:
        return _sanitizeFileName(_ed2kFileName(normalizedValue));
      case DownloadIntentType.resolver:
        return _sanitizeFileName(_resolverDisplayName(uri));
      case DownloadIntentType.custom:
        return _sanitizeFileName(_customDisplayName(uri));
      case DownloadIntentType.unsupported:
        return null;
    }
  }

  DownloadIntent copyWith({
    String? rawValue,
    String? normalizedValue,
    DownloadIntentType? type,
    Uri? uri,
    Map<String, dynamic>? sourceMeta,
    String? pluginHint,
  }) {
    return DownloadIntent._(
      rawValue: rawValue ?? this.rawValue,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      type: type ?? this.type,
      uri: uri ?? this.uri,
      sourceMeta: Map.unmodifiable(sourceMeta ?? this.sourceMeta),
      pluginHint: pluginHint ?? this.pluginHint,
    );
  }

  static String _normalizeMagnet(Uri uri) {
    final pairs = <String>[];
    final entries = uri.queryParametersAll.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    for (final entry in entries) {
      final key = entry.key.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }

      final values = entry.value
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList()
        ..sort();

      if (values.isEmpty) {
        pairs.add(Uri.encodeQueryComponent(key));
        continue;
      }

      for (final value in values) {
        pairs.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
        );
      }
    }

    if (pairs.isEmpty) {
      return 'magnet:?';
    }

    return 'magnet:?${pairs.join('&')}';
  }

  static String _normalizeFileUri(Uri uri) {
    try {
      return uri.toFilePath();
    } catch (_) {
      return uri.toString();
    }
  }

  static String _normalizeTorrentPath(String value) {
    return value.trim().replaceAll('/', '\\');
  }

  static bool _looksLikeEd2kFileLink(String value) {
    return RegExp(
      r'^ed2k://\|file\|[^\r\n|]+\|[1-9]\d*\|[0-9a-f]{32}\|(?:[^\r\n|]*\|)*/$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static String _normalizeEd2kFileLink(String value) {
    final parts = value.trim().split('|');
    if (parts.length >= 6) {
      parts[0] = 'ed2k://';
      parts[1] = 'file';
      parts[4] = parts[4].toUpperCase();
    }
    return parts.join('|');
  }

  static bool _looksLikeTorrentFilePath(String value) {
    final lower = value.trim().toLowerCase();
    if (!lower.endsWith('.torrent')) {
      return false;
    }

    if (RegExp(r'^[a-z][a-z0-9+.-]*://').hasMatch(lower)) {
      return false;
    }

    return true;
  }

  static String? _httpFileName(Uri? uri) {
    if (uri == null || uri.pathSegments.isEmpty) {
      return null;
    }

    final lastSegment = uri.pathSegments.last.trim();
    if (lastSegment.isEmpty) {
      return null;
    }

    return lastSegment;
  }

  static String? _magnetDisplayName(Uri? uri) {
    final displayName = uri?.queryParameters['dn']?.trim();
    if (displayName == null || displayName.isEmpty) {
      return null;
    }

    return displayName;
  }

  static String? _resolverDisplayName(Uri? uri) {
    return uri?.queryParameters['name']?.trim();
  }

  static String? _customDisplayName(Uri? uri) {
    return uri?.queryParameters['name']?.trim() ??
        uri?.queryParameters['filename']?.trim();
  }

  static String? _fileNameFromPath(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final normalized = text.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index == -1) {
      return normalized;
    }
    return normalized.substring(index + 1);
  }

  static String? _ed2kFileName(String? value) {
    final parts = value?.split('|') ?? const <String>[];
    if (parts.length < 6 || parts[1].toLowerCase() != 'file') {
      return null;
    }
    try {
      return Uri.decodeComponent(parts[2]);
    } catch (_) {
      return parts[2];
    }
  }

  static String? _pluginHintFromUri(Uri uri, String? fallback) {
    return _cleanPluginHint(
      uri.queryParameters['plugin'] ??
          uri.queryParameters['pluginHint'] ??
          (uri.host.isEmpty ? null : uri.host) ??
          fallback,
    );
  }

  static String? _cleanPluginHint(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  static String? _sanitizeFileName(String? value) {
    final sanitized = (value ?? '')
        .replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001F]'), '_')
        .trim();
    if (sanitized.isEmpty) {
      return null;
    }
    return sanitized;
  }
}
