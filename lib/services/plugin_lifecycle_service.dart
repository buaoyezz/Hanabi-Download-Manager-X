import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:path/path.dart' as path;

import '../models/download_intent.dart';
import '../models/plugin_manifest.dart';
import '../utils/constants.dart';
import 'app_logger_service.dart';
import 'client_config_service.dart';
import 'plugin_diagnostic_logger.dart';

class PluginLifecycleService extends ChangeNotifier {
  static final PluginLifecycleService _instance =
      PluginLifecycleService._internal();

  factory PluginLifecycleService() => _instance;

  PluginLifecycleService._internal();

  final AppLoggerService _logger = AppLoggerService();
  final ClientConfigService _config = ClientConfigService();
  final PluginDiagnosticLogger _diag = PluginDiagnosticLogger();

  final List<InstalledPlugin> _plugins = <InstalledPlugin>[];
  final Map<String, bool> _enabledState = <String, bool>{};
  final Map<String, Map<String, dynamic>> _pluginSettings =
      <String, Map<String, dynamic>>{};

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
      _diag.mark('lifecycle.initialize.start');
      _pluginsRootDir = path.join(_config.baseDir, 'plugins');
      _installedDir = path.join(_pluginsRootDir, 'installed');
      _cacheDir = path.join(_pluginsRootDir, 'cache');
      _logsDir = path.join(_pluginsRootDir, 'logs');
      _statePath = path.join(_pluginsRootDir, 'plugins_state.json');
      _storeIndexPath = path.join(_pluginsRootDir, 'store_index.json');
      _diag.mark('lifecycle.initialize.paths', data: <String, Object?>{
        'root': _pluginsRootDir,
        'installed': _installedDir,
        'cache': _cacheDir,
        'logs': _logsDir,
        'state': _statePath,
      });

      await _createDirectories();
      await _loadState();

      _initialized = true;
      await scanInstalledPlugins();
      _logger.info('Plugin', 'Plugin lifecycle service initialized');
      _diag.mark('lifecycle.initialize.done', data: <String, Object?>{
        'plugins': _plugins.map((plugin) => plugin.id).toList(),
      });
    } catch (e, stackTrace) {
      _diag.error(
        'lifecycle.initialize.error',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
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
        _diag.mark('lifecycle.directory.create', data: <String, Object?>{
          'path': dir,
        });
        await directory.create(recursive: true);
      }
    }
  }

  Future<void> _loadState() async {
    _enabledState.clear();
    _pluginSettings.clear();
    final file = File(_statePath);
    if (!await file.exists()) {
      _diag.mark('lifecycle.state.missing', data: <String, Object?>{
        'path': _statePath,
      });
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
      final settingsRaw = decoded is Map ? decoded['settings'] : null;
      if (settingsRaw is Map) {
        for (final entry in settingsRaw.entries) {
          if (entry.value is Map) {
            _pluginSettings[entry.key.toString()] =
                Map<String, dynamic>.from(entry.value as Map);
          }
        }
      }
      _diag.mark('lifecycle.state.loaded', data: <String, Object?>{
        'enabled': Map<String, bool>.from(_enabledState),
        'settingsKeys': _pluginSettings.keys.toList(),
      });
    } catch (e) {
      _diag.error('lifecycle.state.load.error', e);
      _logger.warning('Plugin', 'Failed to load plugin state: $e');
    }
  }

  Future<void> _saveState() async {
    _diag.mark('lifecycle.state.save.start', data: <String, Object?>{
      'enabled': Map<String, bool>.from(_enabledState),
      'settingsKeys': _pluginSettings.keys.toList(),
    });
    final content = const JsonEncoder.withIndent('  ').convert({
      'enabled': _enabledState,
      'settings': _pluginSettings,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await File(_statePath).writeAsString(content);
    _diag.mark('lifecycle.state.save.done', data: <String, Object?>{
      'path': _statePath,
      'bytes': content.length,
    });
  }

  Map<String, dynamic>? getPluginSettings(String pluginId) {
    return _pluginSettings[pluginId];
  }

  Future<void> savePluginSettings(
      String pluginId, Map<String, dynamic> settings) async {
    _diag.mark('settings.save.start', pluginId: pluginId, data: settings);
    _pluginSettings[pluginId] = Map<String, dynamic>.from(settings);
    await _saveState();
    notifyListeners();
    _diag.mark('settings.save.done', pluginId: pluginId);
  }

  Future<void> scanInstalledPlugins() async {
    _diag.mark('scan.public.start');
    await _scanPluginsInternal();
    _scheduleNotify();
    _diag.mark('scan.public.done', data: <String, Object?>{
      'count': _plugins.length,
      'plugins': _plugins.map((plugin) => plugin.id).toList(),
    });
  }

  /// Scan without notifying — used by install/uninstall which schedule
  /// their own deferred notification to avoid mid-build crashes.
  Future<void> _scanPluginsInternal() async {
    await ensureInitialized();
    _diag.mark('scan.internal.start', data: <String, Object?>{
      'installedDir': _installedDir,
    });
    _plugins.clear();

    final root = Directory(_installedDir);
    if (!await root.exists()) {
      _diag.mark('scan.internal.missingRoot', data: <String, Object?>{
        'installedDir': _installedDir,
      });
      return;
    }

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }

      final plugin = await _readInstalledPlugin(entity);
      if (plugin != null) {
        _plugins.add(plugin);
        _diag.mark(
          'scan.internal.plugin.added',
          pluginId: plugin.id,
          data: <String, Object?>{
            'directory': entity.path,
            'state': plugin.state.name,
            'enabled': plugin.enabled,
            'lastError': plugin.lastError,
          },
        );
      }
    }

    _plugins.sort((a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ));
    _diag.mark('scan.internal.done', data: <String, Object?>{
      'count': _plugins.length,
      'plugins': _plugins.map((plugin) => plugin.id).toList(),
    });
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
      _diag.mark(
        'scan.readPlugin.parsed',
        pluginId: manifest.id,
        data: <String, Object?>{
          'directory': directory.path,
          'entry': manifest.entry,
          'icon': manifest.icon,
          'uiExtensions': manifest.uiExtensions?.keys.toList(),
          'state': state.name,
          'enabled': enabled,
          'errors': errors,
        },
      );

      return InstalledPlugin(
        manifest: manifest,
        directory: directory.path,
        state: state,
        enabled: enabled && state != PluginInstallState.invalid,
        lastError: errors.isEmpty ? null : errors.join('; '),
      );
    } catch (e) {
      _diag.error(
        'scan.readPlugin.error',
        e,
        pluginId: path.basename(directory.path),
        data: <String, Object?>{'directory': directory.path},
      );
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
    try {
      _diag.mark(
        'enabled.set.start',
        pluginId: pluginId,
        data: <String, Object?>{'enabled': enabled},
      );
      await ensureInitialized();
      _enabledState[pluginId] = enabled;
      await _saveState();
      await _scanPluginsInternal();
      _scheduleNotify();
      _logger.info(
        'Plugin',
        '${enabled ? 'Enabled' : 'Disabled'} plugin: $pluginId',
      );
      _diag.mark(
        'enabled.set.done',
        pluginId: pluginId,
        data: <String, Object?>{'enabled': enabled},
      );
    } catch (e, stackTrace) {
      _diag.error(
        'enabled.set.error',
        e,
        pluginId: pluginId,
        stackTrace: stackTrace,
        data: <String, Object?>{'enabled': enabled},
      );
      rethrow;
    }
  }

  Future<InstalledPlugin> installFromDirectory(String sourceDirectory) async {
    String? pluginId;
    try {
      _diag.mark('install.directory.start', data: <String, Object?>{
        'sourceDirectory': sourceDirectory,
      });
      await ensureInitialized();
      final source = Directory(sourceDirectory);
      final sourceExists = await source.exists();
      _diag.mark('install.directory.sourceChecked', data: <String, Object?>{
        'sourceDirectory': sourceDirectory,
        'exists': sourceExists,
      });
      if (!sourceExists) {
        throw StateError('Plugin directory does not exist: $sourceDirectory');
      }

      final manifestDir = await _findManifestDirectory(source);
      _diag.mark('install.directory.manifestDir', data: <String, Object?>{
        'sourceDirectory': sourceDirectory,
        'manifestDir': manifestDir.path,
      });
      final manifest = PluginManifest.fromJsonString(
        await File(path.join(manifestDir.path, 'plugin.json')).readAsString(),
      );
      pluginId = manifest.id;
      _diag.mark(
        'install.directory.manifestParsed',
        pluginId: manifest.id,
        data: <String, Object?>{
          'name': manifest.name,
          'version': manifest.version,
          'entry': manifest.entry,
          'icon': manifest.icon,
          'uiExtensions': manifest.uiExtensions?.keys.toList(),
        },
      );
      await _validateInstallCandidate(manifest, manifestDir);
      _diag.mark('install.directory.validated', pluginId: manifest.id);
      await _settlePluginUiBeforeFileMutation(manifest.id);
      await _installDirectory(manifestDir, manifest);
      _enabledState[manifest.id] = true;
      await _saveState();
      await _scanPluginsInternal();

      final installed = getPlugin(manifest.id);
      if (installed == null) {
        throw StateError('Plugin installed but could not be reloaded');
      }
      _logger.info('Plugin', 'Installed plugin from directory: ${manifest.id}');
      _diag.mark(
        'install.directory.done',
        pluginId: manifest.id,
        data: <String, Object?>{
          'installedDirectory': installed.directory,
          'state': installed.state.name,
          'enabled': installed.enabled,
        },
      );
      _scheduleNotify(delay: const Duration(milliseconds: 700));
      return installed;
    } catch (e, stackTrace) {
      _diag.error(
        'install.directory.error',
        e,
        pluginId: pluginId,
        stackTrace: stackTrace,
        data: <String, Object?>{'sourceDirectory': sourceDirectory},
      );
      rethrow;
    }
  }

  Future<InstalledPlugin> installFromPackage(String packagePath) async {
    try {
      _diag.mark('install.package.start', data: <String, Object?>{
        'packagePath': packagePath,
      });
      await ensureInitialized();
      final file = File(packagePath);
      if (!await file.exists()) {
        _diag.mark('install.package.missing', data: <String, Object?>{
          'packagePath': packagePath,
        });
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
      _diag.mark('install.package.staging.created', data: <String, Object?>{
        'packagePath': packagePath,
        'staging': staging.path,
      });
      try {
        var effectivePackagePath = packagePath;
        if (!lower.endsWith('.zip')) {
          final zipCopy = File(path.join(staging.path, 'package.zip'));
          _diag.mark('install.package.copyToZip.start', data: <String, Object?>{
            'from': packagePath,
            'to': zipCopy.path,
          });
          await file.copy(zipCopy.path);
          effectivePackagePath = zipCopy.path;
          _diag.mark('install.package.copyToZip.done', data: <String, Object?>{
            'to': zipCopy.path,
          });
        }
        await _extractZipPackage(effectivePackagePath, staging.path);
        final installed = await installFromDirectory(staging.path);
        _diag.mark(
          'install.package.done',
          pluginId: installed.id,
          data: <String, Object?>{'packagePath': packagePath},
        );
        return installed;
      } finally {
        if (await staging.exists()) {
          _diag.mark('install.package.staging.delete', data: <String, Object?>{
            'staging': staging.path,
          });
          await staging.delete(recursive: true);
        }
      }
    } catch (e, stackTrace) {
      _diag.error(
        'install.package.error',
        e,
        stackTrace: stackTrace,
        data: <String, Object?>{'packagePath': packagePath},
      );
      rethrow;
    }
  }

  Future<void> _extractZipPackage(
      String packagePath, String destination) async {
    if (!Platform.isWindows) {
      throw StateError('Zip plugin install currently requires Windows');
    }

    _diag.mark('install.package.extract.start', data: <String, Object?>{
      'packagePath': packagePath,
      'destination': destination,
    });
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
      _diag.mark('install.package.extract.failed', data: <String, Object?>{
        'packagePath': packagePath,
        'destination': destination,
        'exitCode': result.exitCode,
        'stdout': result.stdout?.toString(),
        'stderr': result.stderr?.toString(),
      });
      throw StateError(
        'Failed to extract plugin package: ${result.stderr ?? result.stdout}',
      );
    }
    _diag.mark('install.package.extract.done', data: <String, Object?>{
      'packagePath': packagePath,
      'destination': destination,
    });
  }

  Future<Directory> _findManifestDirectory(Directory root) async {
    _diag.mark('manifest.find.start', data: <String, Object?>{
      'root': root.path,
    });
    if (await File(path.join(root.path, 'plugin.json')).exists()) {
      _diag.mark('manifest.find.root', data: <String, Object?>{
        'root': root.path,
      });
      return root;
    }

    final candidates = <Directory>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          await File(path.join(entity.path, 'plugin.json')).exists()) {
        candidates.add(entity);
        _diag.mark('manifest.find.candidate', data: <String, Object?>{
          'root': root.path,
          'candidate': entity.path,
        });
      }
    }

    if (candidates.length == 1) {
      _diag.mark('manifest.find.single', data: <String, Object?>{
        'root': root.path,
        'candidate': candidates.single.path,
      });
      return candidates.single;
    }

    _diag.mark('manifest.find.failed', data: <String, Object?>{
      'root': root.path,
      'candidateCount': candidates.length,
      'candidates': candidates.map((candidate) => candidate.path).toList(),
    });
    throw StateError('plugin.json not found in package root');
  }

  Future<void> _validateInstallCandidate(
    PluginManifest manifest,
    Directory sourceDirectory,
  ) async {
    _diag.mark(
      'install.validate.start',
      pluginId: manifest.id,
      data: <String, Object?>{
        'sourceDirectory': sourceDirectory.path,
        'entry': manifest.entry,
        'minAppVersion': manifest.minAppVersion,
      },
    );
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
      _diag.mark(
        'install.validate.failed',
        pluginId: manifest.id,
        data: <String, Object?>{
          'sourceDirectory': sourceDirectory.path,
          'entryPath': entryPath,
          'errors': errors,
        },
      );
      throw StateError('Invalid plugin ${manifest.id}: ${errors.join('; ')}');
    }
    _diag.mark(
      'install.validate.done',
      pluginId: manifest.id,
      data: <String, Object?>{
        'sourceDirectory': sourceDirectory.path,
        'entryPath': entryPath,
      },
    );
  }

  Future<void> _installDirectory(
    Directory sourceDirectory,
    PluginManifest manifest,
  ) async {
    final target = Directory(path.join(_installedDir, manifest.id));
    final targetPath = path.normalize(target.path);
    final sourcePath = path.normalize(sourceDirectory.path);
    _diag.mark(
      'install.copyPlan.start',
      pluginId: manifest.id,
      data: <String, Object?>{
        'source': sourcePath,
        'target': targetPath,
      },
    );
    if (sourcePath == targetPath ||
        path.isWithin(sourcePath, targetPath) ||
        path.isWithin(targetPath, sourcePath)) {
      _diag.mark(
        'install.copyPlan.rejectedSelfInstall',
        pluginId: manifest.id,
        data: <String, Object?>{
          'source': sourcePath,
          'target': targetPath,
        },
      );
      throw StateError('Cannot install a plugin over itself');
    }

    final backup = Directory(
      '${target.path}.rollback_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (await target.exists()) {
      _diag.mark(
        'install.backup.rename.start',
        pluginId: manifest.id,
        data: <String, Object?>{
          'target': target.path,
          'backup': backup.path,
        },
      );
      await target.rename(backup.path);
      _diag.mark(
        'install.backup.rename.done',
        pluginId: manifest.id,
        data: <String, Object?>{
          'backup': backup.path,
        },
      );
    }

    try {
      _diag.mark(
        'install.copy.start',
        pluginId: manifest.id,
        data: <String, Object?>{
          'source': sourceDirectory.path,
          'target': target.path,
        },
      );
      await _copyDirectory(sourceDirectory, target);
      if (await backup.exists()) {
        _diag.mark(
          'install.backup.delete.start',
          pluginId: manifest.id,
          data: <String, Object?>{'backup': backup.path},
        );
        await backup.delete(recursive: true);
        _diag.mark(
          'install.backup.delete.done',
          pluginId: manifest.id,
          data: <String, Object?>{'backup': backup.path},
        );
      }
      _diag.mark(
        'install.copy.done',
        pluginId: manifest.id,
        data: <String, Object?>{'target': target.path},
      );
    } catch (e, stackTrace) {
      _diag.error(
        'install.copy.error',
        e,
        pluginId: manifest.id,
        stackTrace: stackTrace,
        data: <String, Object?>{
          'source': sourceDirectory.path,
          'target': target.path,
          'backup': backup.path,
        },
      );
      if (await target.exists()) {
        _diag.mark(
          'install.rollback.deletePartial.start',
          pluginId: manifest.id,
          data: <String, Object?>{'target': target.path},
        );
        await target.delete(recursive: true);
        _diag.mark(
          'install.rollback.deletePartial.done',
          pluginId: manifest.id,
          data: <String, Object?>{'target': target.path},
        );
      }
      if (await backup.exists()) {
        _diag.mark(
          'install.rollback.restore.start',
          pluginId: manifest.id,
          data: <String, Object?>{
            'backup': backup.path,
            'target': target.path,
          },
        );
        await backup.rename(target.path);
        _diag.mark(
          'install.rollback.restore.done',
          pluginId: manifest.id,
          data: <String, Object?>{'target': target.path},
        );
      }
      rethrow;
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    _diag.mark('install.copyDirectory.create', data: <String, Object?>{
      'source': source.path,
      'target': target.path,
    });
    await target.create(recursive: true);
    await for (final entity
        in source.list(recursive: false, followLinks: false)) {
      final name = path.basename(entity.path);
      final targetPath = path.join(target.path, name);
      if (entity is Directory) {
        _diag.mark('install.copyDirectory.enter', data: <String, Object?>{
          'source': entity.path,
          'target': targetPath,
        });
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        int? size;
        try {
          size = await entity.length();
        } catch (_) {
          size = null;
        }
        _diag.mark('install.copyFile.start', data: <String, Object?>{
          'source': entity.path,
          'target': targetPath,
          'bytes': size,
        });
        await entity.copy(targetPath);
        _diag.mark('install.copyFile.done', data: <String, Object?>{
          'target': targetPath,
          'bytes': size,
        });
      }
    }
  }

  Future<void> uninstallPlugin(String pluginId) async {
    try {
      _diag.mark('uninstall.start', pluginId: pluginId);
      await ensureInitialized();
      final plugin = getPlugin(pluginId);
      if (plugin == null) {
        _diag.mark('uninstall.missing', pluginId: pluginId);
        return;
      }

      _diag.mark(
        'uninstall.pluginFound',
        pluginId: pluginId,
        data: <String, Object?>{
          'directory': plugin.directory,
          'state': plugin.state.name,
          'enabled': plugin.enabled,
        },
      );
      _enabledState.remove(pluginId);
      await _saveState();
      await _settlePluginUiBeforeFileMutation(pluginId);
      final directory = Directory(plugin.directory);
      final exists = await directory.exists();
      _diag.mark(
        'uninstall.directory.checked',
        pluginId: pluginId,
        data: <String, Object?>{
          'directory': plugin.directory,
          'exists': exists,
        },
      );
      if (exists) {
        _diag.mark(
          'uninstall.directory.delete.start',
          pluginId: pluginId,
          data: <String, Object?>{'directory': plugin.directory},
        );
        await directory.delete(recursive: true);
        _diag.mark(
          'uninstall.directory.delete.done',
          pluginId: pluginId,
          data: <String, Object?>{'directory': plugin.directory},
        );
      }
      _logger.info('Plugin', 'Uninstalled plugin: $pluginId');
      _diag.mark('uninstall.done', pluginId: pluginId);
    } catch (e, stackTrace) {
      _diag.error(
        'uninstall.error',
        e,
        pluginId: pluginId,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _settlePluginUiBeforeFileMutation(String pluginId) async {
    final hadPlugin = _plugins.any((installed) => installed.id == pluginId);
    if (!hadPlugin) {
      _diag.mark('ui.settle.noPlugin', pluginId: pluginId);
      return;
    }

    _diag.mark('ui.settle.start', pluginId: pluginId, data: <String, Object?>{
      'pluginsBefore': _plugins.map((plugin) => plugin.id).toList(),
    });
    _plugins.removeWhere((installed) => installed.id == pluginId);
    _scheduleNotify();
    _diag.mark('ui.settle.removedFromList',
        pluginId: pluginId,
        data: <String, Object?>{
          'pluginsAfter': _plugins.map((plugin) => plugin.id).toList(),
        });

    // Let Flutter dispose plugin-owned pages/icons before removing or
    // replacing files. notifyListeners runs at the end of this frame, then the
    // dependent widgets are actually rebuilt/disposed on the following frame.
    // Deleting the directory during that teardown can crash inside
    // flutter_windows.dll on Windows.
    _diag.mark('ui.settle.waitFrame1.start', pluginId: pluginId);
    await WidgetsBinding.instance.endOfFrame;
    _diag.mark('ui.settle.waitFrame1.done', pluginId: pluginId);
    _diag.mark('ui.settle.waitFrame2.start', pluginId: pluginId);
    await WidgetsBinding.instance.endOfFrame;
    _diag.mark('ui.settle.waitFrame2.done', pluginId: pluginId);
    _diag.mark('ui.settle.delay.start', pluginId: pluginId);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _diag.mark('ui.settle.done', pluginId: pluginId);
  }

  /// Schedule notifyListeners at the next safe UI point.
  /// This prevents crashes where install/uninstall triggers a full widget
  /// tree rebuild (MyApp → HomeScreen → IndexedStack) while the calling
  /// widget (PluginStorePage._runAction) is still mid-await.
  bool _notifyScheduled = false;
  Timer? _notifyDelayTimer;
  void _scheduleNotify({Duration delay = Duration.zero}) {
    if (_notifyScheduled) {
      _diag.mark('notify.schedule.skippedPending');
      return;
    }
    _notifyScheduled = true;

    void fireNotify(String mode) {
      _notifyScheduled = false;
      _diag.mark('notify.fire', data: <String, Object?>{
        'delayMs': delay.inMilliseconds,
        'mode': mode,
      });
      notifyListeners();
    }

    void notifyWhenSafe() {
      final binding = SchedulerBinding.instance;
      final phase = binding.schedulerPhase;
      _diag.mark('notify.schedule.safePoint', data: <String, Object?>{
        'delayMs': delay.inMilliseconds,
        'schedulerPhase': phase.name,
      });

      if (phase == SchedulerPhase.idle) {
        scheduleMicrotask(() => fireNotify('microtask'));
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        fireNotify('postFrame');
      });
      binding.ensureVisualUpdate();
    }

    void scheduleAfterDelay() {
      if (delay > Duration.zero) {
        _diag.mark('notify.schedule.delay', data: <String, Object?>{
          'delayMs': delay.inMilliseconds,
        });
        _notifyDelayTimer?.cancel();
        _notifyDelayTimer = Timer(delay, () {
          _notifyDelayTimer = null;
          notifyWhenSafe();
        });
        return;
      }

      notifyWhenSafe();
    }

    scheduleAfterDelay();
  }

  @override
  void dispose() {
    _notifyDelayTimer?.cancel();
    _notifyDelayTimer = null;
    super.dispose();
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
