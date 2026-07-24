import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  try {
    final options = _parseArgs(args);
    final pluginsListDir = _requireOption(options, 'plugins-list-dir');
    final pluginsDataDir = _requireOption(options, 'plugins-data-dir');
    final packagesDir = _requireOption(options, 'packages-dir');
    final output = _requireOption(options, 'output');
    final packageBaseUrl = options['package-base-url']?.trim() ?? '';
    final channel = options['channel']?.trim().isNotEmpty == true
        ? options['channel']!.trim()
        : 'stable';

    final sourceFiles = Directory(pluginsListDir)
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .where((file) => !p.basename(file.path).endsWith('.example.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final entries = <Map<String, dynamic>>[];
    for (final sourceFile in sourceFiles) {
      final source = PluginSource.fromJson(
        _readJsonObject(sourceFile),
        sourceFile.path,
      );
      final manifestPath = p.join(pluginsDataDir, source.id, 'plugin.json');
      final manifestFile = File(manifestPath);
      if (!manifestFile.existsSync()) {
        stderr.writeln(
            'Skip ${source.id}: plugin.json not found in plugins-data');
        continue;
      }

      final manifest = PluginManifestDoc.fromJson(
        _readJsonObject(manifestFile),
        manifestFile.path,
      );
      if (manifest.id != source.id) {
        throw StateError(
          'Plugin id mismatch for ${source.id}: manifest=${manifest.id}',
        );
      }

      final packageFileName =
          '${manifest.id}-${manifest.version}.hanabi-plugin.zip';
      final packageFile = File(p.join(packagesDir, packageFileName));
      final packageExists = packageFile.existsSync();
      final packageHash = packageExists
          ? sha256.convert(packageFile.readAsBytesSync()).toString()
          : '';

      final reviewStatus = source.reviewStatus == 'published' && !packageExists
          ? 'draft'
          : source.reviewStatus;
      final downloadUrl = packageExists && packageBaseUrl.isNotEmpty
          ? '${packageBaseUrl.replaceAll(RegExp(r'/+$'), '')}/$packageFileName'
          : '';

      entries.add({
        'manifestVersion': manifest.manifestVersion,
        'apiVersion': manifest.apiVersion,
        'id': manifest.id,
        'name': manifest.name,
        'version': manifest.version,
        'description': manifest.description,
        'author': manifest.author,
        'category': manifest.category,
        'downloadUrl': downloadUrl,
        'hash': packageHash.isEmpty ? '' : 'sha256:$packageHash',
        if (manifest.minAppVersion != null &&
            manifest.minAppVersion!.trim().isNotEmpty)
          'minAppVersion': manifest.minAppVersion,
        if (manifest.maxAppVersion != null &&
            manifest.maxAppVersion!.trim().isNotEmpty)
          'maxAppVersion': manifest.maxAppVersion,
        'channel': source.channel,
        'capabilities': manifest.capabilities,
        if (manifest.intentSchemes.isNotEmpty)
          'intentSchemes': manifest.intentSchemes,
        if (manifest.permissions.isNotEmpty)
          'permissions': manifest.permissions,
        'reviewStatus': reviewStatus,
        'source': {
          'repo': source.repo,
          'branch': source.branch,
          'pluginPath': source.pluginPath,
          if (source.submitter != null && source.submitter!.isNotEmpty)
            'submitter': source.submitter,
        },
      });
    }

    entries.sort(
      (left, right) => (left['id'] as String).compareTo(right['id'] as String),
    );

    final result = {
      'channel': channel,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'plugins': entries,
    };

    final outputFile = File(output);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(result),
    );
    stdout.writeln('Plugin market index written: ${outputFile.path}');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (!arg.startsWith('--')) {
      continue;
    }
    final key = arg.substring(2);
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      result[key] = 'true';
      continue;
    }
    result[key] = args[index + 1];
    index++;
  }
  return result;
}

String _requireOption(Map<String, String> options, String key) {
  final value = options[key]?.trim();
  if (value == null || value.isEmpty) {
    throw ArgumentError('Missing required option: --$key');
  }
  return value;
}

Map<String, dynamic> _readJsonObject(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    throw FormatException('Expected JSON object: ${file.path}');
  }
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

class PluginSource {
  PluginSource({
    required this.id,
    required this.repo,
    required this.branch,
    required this.pluginPath,
    required this.channel,
    required this.reviewStatus,
    required this.sourceFile,
    this.submitter,
  });

  final String id;
  final String repo;
  final String branch;
  final String pluginPath;
  final String channel;
  final String reviewStatus;
  final String sourceFile;
  final String? submitter;

  factory PluginSource.fromJson(Map<String, dynamic> json, String sourceFile) {
    final id = json['id']?.toString().trim() ?? '';
    final repo = json['repo']?.toString().trim() ?? '';
    final branch = json['branch']?.toString().trim().isNotEmpty == true
        ? json['branch']!.toString().trim()
        : 'main';
    final pluginPath = json['pluginPath']?.toString().trim().isNotEmpty == true
        ? json['pluginPath']!.toString().trim()
        : '.';
    final channel = json['channel']?.toString().trim().isNotEmpty == true
        ? json['channel']!.toString().trim()
        : 'stable';
    final reviewStatus =
        json['reviewStatus']?.toString().trim().isNotEmpty == true
            ? json['reviewStatus']!.toString().trim()
            : 'draft';
    if (id.isEmpty || repo.isEmpty) {
      throw FormatException('Invalid plugin source declaration: $sourceFile');
    }
    return PluginSource(
      id: id,
      repo: repo,
      branch: branch,
      pluginPath: pluginPath,
      channel: channel,
      reviewStatus: reviewStatus,
      sourceFile: sourceFile,
      submitter: json['submitter']?.toString().trim(),
    );
  }
}

class PluginManifestDoc {
  PluginManifestDoc({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.category,
    required this.capabilities,
    required this.manifestVersion,
    required this.apiVersion,
    required this.intentSchemes,
    required this.permissions,
    this.minAppVersion,
    this.maxAppVersion,
  });

  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String category;
  final List<String> capabilities;
  final int manifestVersion;
  final String apiVersion;
  final List<String> intentSchemes;
  final List<String> permissions;
  final String? minAppVersion;
  final String? maxAppVersion;

  factory PluginManifestDoc.fromJson(
    Map<String, dynamic> json,
    String sourceFile,
  ) {
    final capabilities = (json['capabilities'] is List)
        ? (json['capabilities'] as List)
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final intentSchemes = (json['intentSchemes'] is List)
        ? (json['intentSchemes'] as List)
            .map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final permissionsRaw = json['permissions'];
    final permissions = permissionsRaw is List
        ? permissionsRaw
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : permissionsRaw is Map
            ? permissionsRaw.entries
                .where((entry) => entry.value == true)
                .map((entry) => entry.key.toString())
                .toList(growable: false)
            : const <String>[];
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final version = json['version']?.toString().trim() ?? '';
    final author = json['author']?.toString().trim() ?? '';
    if (id.isEmpty ||
        name.isEmpty ||
        version.isEmpty ||
        author.isEmpty ||
        capabilities.isEmpty) {
      throw FormatException('Invalid plugin manifest: $sourceFile');
    }
    return PluginManifestDoc(
      id: id,
      name: name,
      version: version,
      author: author,
      description: json['description']?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? 'other',
      capabilities: capabilities,
      manifestVersion: _parseInt(json['manifestVersion'], 1),
      apiVersion: json['apiVersion']?.toString().trim().isNotEmpty == true
          ? json['apiVersion']!.toString().trim()
          : '1.0',
      intentSchemes: intentSchemes,
      permissions: permissions,
      minAppVersion: json['minAppVersion']?.toString().trim(),
      maxAppVersion: json['maxAppVersion']?.toString().trim(),
    );
  }
}

int _parseInt(Object? value, int fallback) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
