import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../models/plugin_manifest.dart';
import '../models/plugin_store_models.dart';
import 'app_logger_service.dart';
import 'plugin_lifecycle_service.dart';
import 'plugin_signature_verifier.dart';

class PluginStoreMirrorSource {
  const PluginStoreMirrorSource({
    required this.id,
    required this.label,
    required this.url,
  });

  final String id;
  final String label;
  final String url;
}

class PluginStoreService extends ChangeNotifier {
  static final PluginStoreService _instance = PluginStoreService._internal();

  factory PluginStoreService() => _instance;

  PluginStoreService._internal();

  final PluginLifecycleService _pluginService = PluginLifecycleService();
  final AppLoggerService _logger = AppLoggerService();
  final PluginSignatureVerifier _signatureVerifier =
      const PluginSignatureVerifier();
  static const List<PluginStoreMirrorSource> _officialMirrors =
      <PluginStoreMirrorSource>[
    PluginStoreMirrorSource(
      id: 'github_raw',
      label: 'GitHub Raw',
      url:
          'https://raw.githubusercontent.com/buaoyezz/Hanabi-Download-Manager-X/main/plugins/store_index.json',
    ),
    PluginStoreMirrorSource(
      id: 'jsdelivr',
      label: 'jsDelivr',
      url:
          'https://cdn.jsdelivr.net/gh/buaoyezz/Hanabi-Download-Manager-X@main/plugins/store_index.json',
    ),
    PluginStoreMirrorSource(
      id: 'ghproxy',
      label: 'ghproxy',
      url:
          'https://ghproxy.net/https://raw.githubusercontent.com/buaoyezz/Hanabi-Download-Manager-X/main/plugins/store_index.json',
    ),
    PluginStoreMirrorSource(
      id: 'ghfast',
      label: 'ghfast',
      url:
          'https://ghfast.top/https://raw.githubusercontent.com/buaoyezz/Hanabi-Download-Manager-X/main/plugins/store_index.json',
    ),
  ];

  PluginStoreIndex _index = const PluginStoreIndex(entries: []);
  Future<void>? _initializeFuture;
  bool _loading = false;
  String? _lastError;
  String? _activeSourceLabel;
  String? _activeSourceUrl;
  String? _selectedSourceId;

  PluginStoreIndex get index => _index;
  bool get loading => _loading;
  String? get lastError => _lastError;
  List<PluginStoreMirrorSource> get officialMirrors =>
      List.unmodifiable(_officialMirrors);
  String get defaultIndexUrl => _officialMirrors.first.url;
  String? get activeSourceLabel => _activeSourceLabel;
  String? get activeSourceUrl => _activeSourceUrl;
  String? get selectedSourceId => _selectedSourceId;
  PluginStoreMirrorSource? get selectedMirror {
    final sourceId = _selectedSourceId;
    if (sourceId == null) {
      return null;
    }
    for (final source in _officialMirrors) {
      if (source.id == sourceId) {
        return source;
      }
    }
    return null;
  }

  Future<void> initialize() {
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      await _pluginService.ensureInitialized();
      await loadLocalIndex();
      if (_index.entries.isEmpty) {
        unawaited(refreshOfficialIndex(silent: true));
      }
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> loadLocalIndex() async {
    await _pluginService.ensureInitialized();
    final file = File(_pluginService.storeIndexPath);
    if (!await file.exists()) {
      _index = const PluginStoreIndex(entries: []);
      _lastError = null;
      _activeSourceLabel = 'Local cache';
      _activeSourceUrl = file.path;
      _selectedSourceId = null;
      notifyListeners();
      return;
    }

    try {
      _index = PluginStoreIndex.fromJsonString(await file.readAsString());
      _lastError = null;
      _activeSourceLabel = 'Local cache';
      _activeSourceUrl = file.path;
      _selectedSourceId = null;
    } catch (e) {
      _lastError = e.toString();
      _index = const PluginStoreIndex(entries: []);
    }
    notifyListeners();
  }

  Future<void> refreshOfficialIndex({bool silent = false}) async {
    _selectedSourceId = null;
    await _refreshFromCandidates(
      _officialMirrors.map((source) => source.url).toList(growable: false),
      labelsByUrl: {
        for (final source in _officialMirrors) source.url: source.label,
      },
      reportError: !silent,
    );
  }

  Future<void> refreshSelectedSource() async {
    final source = selectedMirror;
    if (source == null) {
      await refreshOfficialIndex();
      return;
    }
    await refreshOfficialMirror(source);
  }

  Future<void> refreshOfficialMirror(PluginStoreMirrorSource source) async {
    _selectedSourceId = source.id;
    await _refreshFromCandidates(
      [source.url],
      labelsByUrl: {source.url: source.label},
      reportError: true,
    );
  }

  Future<void> refreshFromUrl(String indexUrl) async {
    _selectedSourceId = null;
    await _refreshFromCandidates(
      [indexUrl],
      labelsByUrl: {indexUrl: 'Custom'},
      reportError: true,
    );
  }

  Future<void> _refreshFromCandidates(
    List<String> candidates, {
    required Map<String, String> labelsByUrl,
    required bool reportError,
  }) async {
    await _pluginService.ensureInitialized();
    _loading = true;
    if (reportError) {
      _lastError = null;
    }
    notifyListeners();

    final failures = <String>[];
    try {
      for (final candidate in candidates) {
        final trimmed = candidate.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        try {
          final content = await _loadIndexContent(trimmed);
          final index = PluginStoreIndex.fromJsonString(content);
          await File(_pluginService.storeIndexPath).writeAsString(
            const JsonEncoder.withIndent('  ').convert(index.toJson()),
          );
          _index = index;
          _activeSourceLabel = labelsByUrl[trimmed] ?? 'Remote';
          _activeSourceUrl = trimmed;
          _lastError = null;
          _logger.info(
            'PluginStore',
            'Loaded plugin index: ${index.entries.length} from $trimmed',
          );
          return;
        } catch (e) {
          failures.add('${labelsByUrl[trimmed] ?? trimmed}: $e');
          _logger.warning(
            'PluginStore',
            'Failed to load plugin index candidate $trimmed: $e',
          );
        }
      }

      if (reportError) {
        _lastError = failures.isEmpty
            ? 'No plugin index source available'
            : failures.join('\n');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String> _loadIndexContent(String indexUrl) async {
    final uri = Uri.parse(indexUrl);
    if (uri.scheme == 'file') {
      return File(uri.toFilePath()).readAsString();
    }
    if (uri.scheme.isEmpty) {
      return File(indexUrl).readAsString();
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('store index returned HTTP ${response.statusCode}');
    }
    return response.body;
  }

  Future<InstalledPlugin> installEntry(PluginStoreEntry entry) async {
    await _pluginService.ensureInitialized();
    if (!entry.isInstallable) {
      throw StateError('Plugin store entry is not installable: ${entry.id}');
    }

    final packageFile = await _downloadPackage(entry);
    final packageSha256 =
        await _signatureVerifier.verifyHashIfPresent(packageFile, entry.hash);
    await _signatureVerifier.verifyStoreEntrySignature(
      file: packageFile,
      entry: entry,
      index: _index,
      packageSha256: packageSha256,
    );
    return _pluginService.installFromPackage(packageFile.path);
  }

  List<PluginStoreEntry> availableUpdates() {
    return _index.entries.where((entry) {
      final installed = _pluginService.getPlugin(entry.id);
      if (installed == null || !entry.isInstallable) {
        return false;
      }
      return _compareVersion(entry.version, installed.version) > 0;
    }).toList(growable: false);
  }

  Future<List<InstalledPlugin>> updateAllAvailable() async {
    final updates = availableUpdates();
    final installed = <InstalledPlugin>[];
    for (final entry in updates) {
      installed.add(await installEntry(entry));
    }
    return installed;
  }

  Future<File> _downloadPackage(PluginStoreEntry entry) async {
    final uri = Uri.parse(entry.downloadUrl);
    final fileName = path.basename(uri.path).isEmpty
        ? '${entry.id}-${entry.version}.hanabi-plugin.zip'
        : path.basename(uri.path);
    final target = File(path.join(_pluginService.cacheDir, fileName));

    if (uri.scheme == 'file') {
      return File(uri.toFilePath()).copy(target.path);
    }
    if (uri.scheme.isEmpty) {
      return File(entry.downloadUrl).copy(target.path);
    }

    final response = await http.get(uri).timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('plugin package returned HTTP ${response.statusCode}');
    }
    await target.writeAsBytes(response.bodyBytes);
    return target;
  }

  int _compareVersion(String left, String right) {
    final leftParts = left.split('.').map(_parseVersionPart).toList();
    final rightParts = right.split('.').map(_parseVersionPart).toList();
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var i = 0; i < maxLength; i++) {
      final leftValue = i < leftParts.length ? leftParts[i] : 0;
      final rightValue = i < rightParts.length ? rightParts[i] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  int _parseVersionPart(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '0') ?? 0;
  }
}
