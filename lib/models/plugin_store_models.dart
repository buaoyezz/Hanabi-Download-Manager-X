import 'dart:convert';

class PluginStoreSigningKey {
  const PluginStoreSigningKey({
    required this.id,
    required this.algorithm,
    required this.publicKey,
    this.name = '',
  });

  final String id;
  final String algorithm;
  final String publicKey;
  final String name;

  factory PluginStoreSigningKey.fromJson(Map<String, dynamic> json) {
    return PluginStoreSigningKey(
      id: json['id']?.toString().trim() ?? '',
      algorithm: json['algorithm']?.toString().trim().isNotEmpty == true
          ? json['algorithm']!.toString().trim()
          : 'ed25519',
      publicKey: json['publicKey']?.toString().trim() ??
          json['public_key']?.toString().trim() ??
          '',
      name: json['name']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'algorithm': algorithm,
        'publicKey': publicKey,
        if (name.isNotEmpty) 'name': name,
      };

  bool get isUsable =>
      id.isNotEmpty && algorithm.isNotEmpty && publicKey.isNotEmpty;
}

class PluginStoreEntry {
  const PluginStoreEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.downloadUrl,
    required this.hash,
    this.iconUrl,
    this.category = 'other',
    this.minAppVersion,
    this.channel = 'stable',
    this.capabilities = const <String>[],
    this.changelog = '',
    this.reviewStatus = 'published',
    this.signature = '',
    this.signingKeyId,
    this.manifestVersion = 1,
    this.apiVersion = '1.0',
    this.maxAppVersion,
    this.intentSchemes = const <String>[],
    this.permissions = const <String>[],
  });

  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final String downloadUrl;
  final String? iconUrl;
  final String hash;
  final String category;
  final String? minAppVersion;
  final String channel;
  final List<String> capabilities;
  final String changelog;
  final String reviewStatus;
  final String signature;
  final String? signingKeyId;
  final int manifestVersion;
  final String apiVersion;
  final String? maxAppVersion;
  final List<String> intentSchemes;
  final List<String> permissions;

  factory PluginStoreEntry.fromJson(Map<String, dynamic> json) {
    final capabilitiesRaw = json['capabilities'];
    final intentSchemesRaw = json['intentSchemes'] ?? json['intent_schemes'];
    final permissionsRaw = json['permissions'];
    return PluginStoreEntry(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      author: json['author']?.toString().trim() ?? '',
      downloadUrl: json['downloadUrl']?.toString().trim() ??
          json['download_url']?.toString().trim() ??
          '',
      iconUrl: json['iconUrl']?.toString().trim() ??
          json['icon_url']?.toString().trim(),
      hash: json['hash']?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? 'other',
      minAppVersion: json['minAppVersion']?.toString().trim() ??
          json['min_app_version']?.toString().trim(),
      channel: json['channel']?.toString().trim().isNotEmpty == true
          ? json['channel']!.toString().trim()
          : 'stable',
      capabilities: capabilitiesRaw is List
          ? capabilitiesRaw
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      changelog: json['changelog']?.toString().trim() ?? '',
      reviewStatus: json['reviewStatus']?.toString().trim() ??
          json['review_status']?.toString().trim() ??
          'published',
      signature: json['signature']?.toString().trim() ?? '',
      signingKeyId: json['signingKeyId']?.toString().trim() ??
          json['signing_key_id']?.toString().trim(),
      manifestVersion: _intValue(json['manifestVersion'], 1),
      apiVersion: json['apiVersion']?.toString().trim().isNotEmpty == true
          ? json['apiVersion']!.toString().trim()
          : '1.0',
      maxAppVersion: json['maxAppVersion']?.toString().trim() ??
          json['max_app_version']?.toString().trim(),
      intentSchemes: _stringList(intentSchemesRaw),
      permissions: permissionsRaw is Map
          ? permissionsRaw.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key.toString())
              .toList(growable: false)
          : _stringList(permissionsRaw),
    );
  }

  Map<String, dynamic> toJson() => {
        'manifestVersion': manifestVersion,
        'apiVersion': apiVersion,
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'author': author,
        'downloadUrl': downloadUrl,
        if (iconUrl != null && iconUrl!.isNotEmpty) 'iconUrl': iconUrl,
        'hash': hash,
        if (category.isNotEmpty && category != 'other') 'category': category,
        if (minAppVersion != null && minAppVersion!.isNotEmpty)
          'minAppVersion': minAppVersion,
        if (maxAppVersion != null && maxAppVersion!.isNotEmpty)
          'maxAppVersion': maxAppVersion,
        'channel': channel,
        'capabilities': capabilities,
        if (intentSchemes.isNotEmpty) 'intentSchemes': intentSchemes,
        if (permissions.isNotEmpty) 'permissions': permissions,
        if (changelog.isNotEmpty) 'changelog': changelog,
        'reviewStatus': reviewStatus,
        if (signature.isNotEmpty) 'signature': signature,
        if (signingKeyId != null && signingKeyId!.isNotEmpty)
          'signingKeyId': signingKeyId,
      };

  bool get isPublished => reviewStatus == 'published';
  bool get hasSignature =>
      signature.isNotEmpty && signingKeyId?.trim().isNotEmpty == true;
  bool get isInstallable =>
      id.isNotEmpty &&
      downloadUrl.isNotEmpty &&
      isPublished &&
      manifestVersion == 1 &&
      RegExp(r'^1(?:\.\d+)?$').hasMatch(apiVersion);
}

List<String> _stringList(Object? raw) {
  return raw is List
      ? raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false)
      : const <String>[];
}

int _intValue(Object? raw, int fallback) {
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

class PluginStoreIndex {
  const PluginStoreIndex({
    required this.entries,
    this.signingKeys = const <PluginStoreSigningKey>[],
    this.generatedAt,
    this.channel = 'stable',
  });

  final List<PluginStoreEntry> entries;
  final List<PluginStoreSigningKey> signingKeys;
  final DateTime? generatedAt;
  final String channel;

  factory PluginStoreIndex.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['plugins'] ?? json['entries'];
    final signingKeysRaw = json['signingKeys'] ?? json['signing_keys'];
    final entries = entriesRaw is List
        ? entriesRaw
            .whereType<Map>()
            .map((entry) => entry.map(
                  (key, value) => MapEntry(key.toString(), value),
                ))
            .map(PluginStoreEntry.fromJson)
            .toList(growable: false)
        : const <PluginStoreEntry>[];
    final signingKeys = signingKeysRaw is List
        ? signingKeysRaw
            .whereType<Map>()
            .map((key) => key.map(
                  (entryKey, value) => MapEntry(entryKey.toString(), value),
                ))
            .map(PluginStoreSigningKey.fromJson)
            .toList(growable: false)
        : const <PluginStoreSigningKey>[];

    return PluginStoreIndex(
      entries: entries,
      signingKeys: signingKeys,
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      channel: json['channel']?.toString().trim().isNotEmpty == true
          ? json['channel']!.toString().trim()
          : 'stable',
    );
  }

  factory PluginStoreIndex.fromJsonString(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('plugin store index must be a JSON object');
    }
    return PluginStoreIndex.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
        'channel': channel,
        if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
        if (signingKeys.isNotEmpty)
          'signingKeys': signingKeys.map((key) => key.toJson()).toList(),
        'plugins': entries.map((entry) => entry.toJson()).toList(),
      };

  PluginStoreSigningKey? findSigningKey(String? id) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final signingKey in signingKeys) {
      if (signingKey.id == normalized) {
        return signingKey;
      }
    }
    return null;
  }
}
