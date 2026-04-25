import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/download_intent.dart';
import '../models/plugin_manifest.dart';
import '../utils/constants.dart';
import 'app_logger_service.dart';
import 'client_config_service.dart';

class PluginLifecycleService extends ChangeNotifier {
  static final PluginLifecycleService _instance =
      PluginLifecycleService._internal();

  factory PluginLifecycleService() => _instance;

  PluginLifecycleService._internal();

  final AppLoggerService _logger = AppLoggerService();
  final ClientConfigService _config = ClientConfigService();

  final List<InstalledPlugin> _plugins = <InstalledPlugin>[];
  final Map<String, bool> _enabledState = <String, bool>{};

  late String _pluginsRootDir;
  late String _installedDir;
  late String _cacheDir;
  late String _logsDir;
  late String _statePath;
  late String _storeIndexPath;

  bool _initialized = false;
  Future<void>? _initializeFuture;

  bool get initialized => _initialized;
  String get pluginsRootDir => _pluginsRootDir;
  String get installedDir => _installedDir;
  String get cacheDir => _cacheDir;
  String get logsDir => _logsDir;
  String get storeIndexPath => _storeIndexPath;
  List<InstalledPlugin> get plugins => List.unmodifiable(_plugins);

  Future<void> initialize() {
    if (_initialized) {
      return Future.value();
    }
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      _pluginsRootDir = path.join(_config.baseDir, 'plugins');
      _installedDir = path.join(_pluginsRootDir, 'installed');
      _cacheDir = path.join(_pluginsRootDir, 'cache');
      _logsDir = path.join(_pluginsRootDir, 'logs');
      _statePath = path.join(_pluginsRootDir, 'plugins_state.json');
      _storeIndexPath = path.join(_pluginsRootDir, 'store_index.json');

      await _createDirectories();
      await _loadState();

      _initialized = true;
      await scanInstalledPlugins();
      _logger.info('Plugin', 'Plugin lifecycle service initialized');
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> _createDirectories() async {
    for (final dir in [_pluginsRootDir, _installedDir, _cacheDir, _logsDir]) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  Future<void> _loadState() async {
    _enabledState.clear();
    final file = File(_statePath);
    if (!await file.exists()) {
      return;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      final enabledRaw = decoded is Map ? decoded['enabled'] : null;
      if (enabledRaw is Map) {
        for (final entry in enabledRaw.entries) {
          _enabledState[entry.key.toString()] = entry.value == true;
        }
      }
    } catch (e) {
      _logger.warning('Plugin', 'Failed to load plugin state: $e');
    }
  }

  Future<void> _saveState() async {
    final content = const JsonEncoder.withIndent('  ').convert({
      'enabled': _enabledState,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await File(_statePath).writeAsString(content);
  }

  Future<void> scanInstalledPlugins() async {
    await ensureInitialized();
    _plugins.clear();

    final root = Directory(_installedDir);
    if (!await root.exists()) {
      notifyListeners();
      return;
    }

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }

      final plugin = await _readInstalledPlugin(entity);
      if (plugin != null) {
        _plugins.add(plugin);
      }
    }

    _plugins.sort((a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ));
    notifyListeners();
  }

  Future<InstalledPlugin?> _readInstalledPlugin(Directory directory) async {
    final manifestFile = File(path.join(directory.path, 'plugin.json'));
    if (!await manifestFile.exists()) {
      return null;
    }

    try {
      final manifest =
          PluginManifest.fromJsonString(await manifestFile.readAsString());
      final errors = manifest.validate();
      final entryPath =
          path.normalize(path.join(directory.path, manifest.entry));
      if (!await File(entryPath).exists() &&
          !await Directory(entryPath).exists()) {
        errors.add('entry does not exist: ${manifest.entry}');
      }
      final compatible = _isCompatible(manifest.minAppVersion);
      final enabled = _enabledState[manifest.id] ?? false;
      final state = errors.isNotEmpty
          ? PluginInstallState.invalid
          : (!compatible
              ? PluginInstallState.incompatible
              : (enabled
                  ? PluginInstallState.enabled
                  : PluginInstallState.disabled));

      return InstalledPlugin(
        manifest: manifest,
        directory: directory.path,
        state: state,
        enabled: enabled && state != PluginInstallState.invalid,
        lastError: errors.isEmpty ? null : errors.join('; '),
      );
    } catch (e) {
      return InstalledPlugin(
        manifest: PluginManifest(
          id: path.basename(directory.path),
          name: path.basename(directory.path),
          version: 'unknown',
          author: 'unknown',
          entry: '',
          capabilities: const <String>[],
        ),
        directory: directory.path,
        state: PluginInstallState.invalid,
        lastError: e.toString(),
      );
    }
  }

  Future<void> setPluginEnabled(String pluginId, bool enabled) async {
    await ensureInitialized();
    _enabledState[pluginId] = enabled;
    await _saveState();
    await scanInstalledPlugins();
    _logger.info(
      'Plugin',
      '${enabled ? 'Enabled' : 'Disabled'} plugin: $pluginId',
    );
  }

  Future<InstalledPlugin> installFromDirectory(String sourceDirectory) async {
    await ensureInitialized();
    final source = Directory(sourceDirectory);
    if (!await source.exists()) {
      throw StateError('Plugin directory does not exist: $sourceDirectory');
    }

    final manifestDir = await _findManifestDirectory(source);
    final manifest = PluginManifest.fromJsonString(
      await File(path.join(manifestDir.path, 'plugin.json')).readAsString(),
    );
    await _validateInstallCandidate(manifest, manifestDir);
    await _installDirectory(manifestDir, manifest);
    _enabledState[manifest.id] = true;
    await _saveState();
    await scanInstalledPlugins();

    final installed = getPlugin(manifest.id);
    if (installed == null) {
      throw StateError('Plugin installed but could not be reloaded');
    }
    _logger.info('Plugin', 'Installed plugin from directory: ${manifest.id}');
    return installed;
  }

  Future<InstalledPlugin> installFromPackage(String packagePath) async {
    await ensureInitialized();
    final file = File(packagePath);
    if (!await file.exists()) {
      throw StateError('Plugin package does not exist: $packagePath');
    }

    final lower = packagePath.toLowerCase();
    if (!lower.endsWith('.zip') && !lower.endsWith('.hanabi-plugin')) {
      throw StateError('Unsupported plugin package format: $packagePath');
    }

    final staging = Directory(path.join(
      _cacheDir,
      'install_${DateTime.now().millisecondsSinceEpoch}',
    ));
    await staging.create(recursive: true);
    try {
      var effectivePackagePath = packagePath;
      if (!lower.endsWith('.zip')) {
        final zipCopy = File(path.join(staging.path, 'package.zip'));
        await file.copy(zipCopy.path);
        effectivePackagePath = zipCopy.path;
      }
      await _extractZipPackage(effectivePackagePath, staging.path);
      return await installFromDirectory(staging.path);
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<void> _extractZipPackage(
      String packagePath, String destination) async {
    if (!Platform.isWindows) {
      throw StateError('Zip plugin install currently requires Windows');
    }

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        'Expand-Archive -LiteralPath \$env:HANABI_PLUGIN_PACKAGE '
            '-DestinationPath \$env:HANABI_PLUGIN_DEST -Force',
      ],
      environment: {
        'HANABI_PLUGIN_PACKAGE': packagePath,
        'HANABI_PLUGIN_DEST': destination,
      },
    ).timeout(const Duration(seconds: 45));

    if (result.exitCode != 0) {
      throw StateError(
        'Failed to extract plugin package: ${result.stderr ?? result.stdout}',
      );
    }
  }

  Future<Directory> _findManifestDirectory(Directory root) async {
    if (await File(path.join(root.path, 'plugin.json')).exists()) {
      return root;
    }

    final candidates = <Directory>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          await File(path.join(entity.path, 'plugin.json')).exists()) {
        candidates.add(entity);
      }
    }

    if (candidates.length == 1) {
      return candidates.single;
    }

    throw StateError('plugin.json not found in package root');
  }

  Future<void> _validateInstallCandidate(
    PluginManifest manifest,
    Directory sourceDirectory,
  ) async {
    final errors = manifest.validate();
    final entryPath =
        path.normalize(path.join(sourceDirectory.path, manifest.entry));
    if (!await File(entryPath).exists() &&
        !await Directory(entryPath).exists()) {
      errors.add('entry does not exist: ${manifest.entry}');
    }
    if (!_isCompatible(manifest.minAppVersion)) {
      errors.add(
        'requires app version >= ${manifest.minAppVersion}, current ${AppConstants.version}',
      );
    }
    if (errors.isNotEmpty) {
      throw StateError('Invalid plugin ${manifest.id}: ${errors.join('; ')}');
    }
  }

  Future<void> _installDirectory(
    Directory sourceDirectory,
    PluginManifest manifest,
  ) async {
    final target = Directory(path.join(_installedDir, manifest.id));
    final targetPath = path.normalize(target.path);
    final sourcePath = path.normalize(sourceDirectory.path);
    if (sourcePath == targetPath ||
        path.isWithin(sourcePath, targetPath) ||
        path.isWithin(targetPath, sourcePath)) {
      throw StateError('Cannot install a plugin over itself');
    }

    final backup = Directory(
      '${target.path}.rollback_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (await target.exists()) {
      await target.rename(backup.path);
    }

    try {
      await _copyDirectory(sourceDirectory, target);
      if (await backup.exists()) {
        await backup.delete(recursive: true);
      }
    } catch (_) {
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
      if (await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity
        in source.list(recursive: false, followLinks: false)) {
      final name = path.basename(entity.path);
      final targetPath = path.join(target.path, name);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  Future<void> uninstallPlugin(String pluginId) async {
    await ensureInitialized();
    final plugin = getPlugin(pluginId);
    if (plugin == null) {
      return;
    }

    _enabledState.remove(pluginId);
    await _saveState();
    final directory = Directory(plugin.directory);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await scanInstalledPlugins();
    _logger.info('Plugin', 'Uninstalled plugin: $pluginId');
  }

  InstalledPlugin? getPlugin(String pluginId) {
    for (final plugin in _plugins) {
      if (plugin.id == pluginId) {
        return plugin;
      }
    }
    return null;
  }

  List<InstalledPlugin> pluginsForIntent(DownloadIntent intent) {
    final capabilities = _capabilitiesForIntent(intent);
    return _plugins
        .where((plugin) =>
            plugin.enabled &&
            plugin.state == PluginInstallState.enabled &&
            capabilities.any(plugin.manifest.supportsCapability))
        .toList(growable: false);
  }

  InstalledPlugin? resolvePluginForIntent(DownloadIntent intent) {
    final candidates = pluginsForIntent(intent);
    if (candidates.isEmpty) {
      return null;
    }

    final hint = intent.pluginHint;
    if (hint != null && hint.isNotEmpty) {
      for (final plugin in candidates) {
        if (plugin.id == hint || plugin.name == hint) {
          return plugin;
        }
      }
    }
    return candidates.first;
  }

  String pluginLogDir(String pluginId) {
    return path.join(_logsDir, pluginId);
  }

  List<String> _capabilitiesForIntent(DownloadIntent intent) {
    final type = intent.type.wireName;
    switch (intent.type) {
      case DownloadIntentType.http:
        return ['download:http', 'intent:http'];
      case DownloadIntentType.magnet:
        return ['download:magnet', 'intent:magnet'];
      case DownloadIntentType.torrentFile:
        return ['download:torrent_file', 'intent:torrent_file'];
      case DownloadIntentType.resolver:
        return ['resolver', 'intent:resolver'];
      case DownloadIntentType.custom:
        return ['custom', 'intent:custom', 'download:$type'];
      case DownloadIntentType.unsupported:
        return const <String>[];
    }
  }

  bool _isCompatible(String? minAppVersion) {
    final minVersion = minAppVersion?.trim();
    if (minVersion == null || minVersion.isEmpty) {
      return true;
    }
    return _compareVersion(AppConstants.version, minVersion) >= 0;
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
