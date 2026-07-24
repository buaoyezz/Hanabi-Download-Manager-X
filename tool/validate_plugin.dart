import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:hanabi_download_manager_x/models/plugin_manifest.dart';

Future<void> main(List<String> arguments) async {
  final jsonOutput = arguments.contains('--json');
  final positional = arguments.where((argument) => !argument.startsWith('--'));
  if (positional.length != 1) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final input = positional.single;
  final inputType = await FileSystemEntity.type(input, followLinks: false);
  final manifestFile = inputType == FileSystemEntityType.directory
      ? File(path.join(input, 'plugin.json'))
      : File(input);
  final issues = <_ValidationIssue>[];
  PluginManifest? manifest;

  if (!await manifestFile.exists()) {
    issues.add(_ValidationIssue.error(
      'manifest.missing',
      '找不到 plugin.json：${manifestFile.path}',
    ));
  } else {
    try {
      manifest =
          PluginManifest.fromJsonString(await manifestFile.readAsString());
      for (final message in manifest.validate()) {
        issues.add(_ValidationIssue.error('manifest.invalid', message));
      }
      await _validateFiles(manifestFile.parent, manifest, issues);
      _addMetadataWarnings(manifest, issues);
    } on FormatException catch (error) {
      issues.add(_ValidationIssue.error('manifest.json', error.message));
    } catch (error) {
      issues.add(_ValidationIssue.error('manifest.read', error.toString()));
    }
  }

  final errors = issues.where((issue) => issue.level == 'error').length;
  final warnings = issues.length - errors;
  if (jsonOutput) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'valid': errors == 0,
      'pluginId': manifest?.id,
      'manifest': manifestFile.absolute.path,
      'summary': {'errors': errors, 'warnings': warnings},
      'issues': issues.map((issue) => issue.toJson()).toList(),
    }));
  } else {
    stdout.writeln('Hanabi 插件校验');
    stdout.writeln('清单：${manifestFile.absolute.path}');
    for (final issue in issues) {
      final label = issue.level == 'error' ? '错误' : '警告';
      stdout.writeln('[$label] ${issue.code}: ${issue.message}');
    }
    if (errors == 0) {
      stdout.writeln('通过：${manifest?.id ?? '插件'}（$warnings 个警告）');
    } else {
      stdout.writeln('失败：$errors 个错误，$warnings 个警告');
    }
  }
  exitCode = errors == 0 ? 0 : 1;
}

Future<void> _validateFiles(
  Directory pluginDirectory,
  PluginManifest manifest,
  List<_ValidationIssue> issues,
) async {
  final entry = File(path.join(pluginDirectory.path, manifest.entry));
  if (!await entry.exists()) {
    issues.add(_ValidationIssue.error(
      'entry.missing',
      '入口文件不存在：${manifest.entry}',
    ));
  }

  final icon = manifest.icon;
  if (icon != null && icon.isNotEmpty) {
    final iconFile = File(path.join(pluginDirectory.path, icon));
    if (!await iconFile.exists()) {
      issues.add(_ValidationIssue.error('icon.missing', '图标文件不存在：$icon'));
    }
  }

  final workingDirectory = manifest.runtime.workingDirectory;
  if (workingDirectory != null) {
    final directory =
        Directory(path.join(pluginDirectory.path, workingDirectory));
    if (!await directory.exists()) {
      issues.add(_ValidationIssue.error(
        'runtime.working_directory_missing',
        '运行目录不存在：$workingDirectory',
      ));
    }
  }

  final executable = manifest.runtime.executable;
  if (executable != null && path.isAbsolute(executable)) {
    issues.add(_ValidationIssue.warning(
      'runtime.absolute_executable',
      'runtime.executable 使用绝对路径，插件包将无法跨设备运行。',
    ));
  } else if (executable != null &&
      (executable.contains('/') || executable.contains('\\'))) {
    final executableFile = File(path.join(pluginDirectory.path, executable));
    if (!await executableFile.exists()) {
      issues.add(_ValidationIssue.error(
        'runtime.executable_missing',
        '插件内运行文件不存在：$executable',
      ));
    }
  }
}

void _addMetadataWarnings(
  PluginManifest manifest,
  List<_ValidationIssue> issues,
) {
  if (manifest.description.isEmpty) {
    issues.add(_ValidationIssue.warning(
      'metadata.description',
      '建议填写 description，便于用户理解插件用途。',
    ));
  }
  if (manifest.license == null) {
    issues.add(_ValidationIssue.warning(
      'metadata.license',
      '建议使用 license 声明 SPDX 许可证标识。',
    ));
  }
  if (manifest.repository == null) {
    issues.add(_ValidationIssue.warning(
      'metadata.repository',
      '建议填写 repository，便于审核与问题追踪。',
    ));
  }
}

void _printUsage() {
  stderr.writeln(
    '用法：dart run tool/validate_plugin.dart <插件目录或 plugin.json> [--json]',
  );
}

class _ValidationIssue {
  const _ValidationIssue(this.level, this.code, this.message);

  factory _ValidationIssue.error(String code, String message) =>
      _ValidationIssue('error', code, message);

  factory _ValidationIssue.warning(String code, String message) =>
      _ValidationIssue('warning', code, message);

  final String level;
  final String code;
  final String message;

  Map<String, String> toJson() => {
        'level': level,
        'code': code,
        'message': message,
      };
}
