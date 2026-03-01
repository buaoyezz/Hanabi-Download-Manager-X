import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/task.dart';
import '../models/segment.dart';
import '../config/download_config.dart';

class TaskStorage {
  late final Directory _storageDir;
  late final Directory _oldStorageDir;
  bool _initialized = false;
  Future<void> _writeQueue = Future.value();

  Future<void> init() async {
    if (_initialized) return;

    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;

    // 新的存储目录：.hdmx/kernel
    _storageDir = Directory(path.join(home, '.hdmx', 'kernel'));

    // 旧的存储目录：.nsfx_kernel
    _oldStorageDir = Directory(path.join(home, '.nsfx_kernel'));

    // 检测并迁移老配置
    await _migrateOldConfigIfNeeded();

    // 确保新目录存在
    if (!await _storageDir.exists()) {
      await _storageDir.create(recursive: true);
    }

    // 进行崩溃恢复与残留文件清理
    await _recoverJsonFile(_tasksFile, label: 'tasks');
    await _recoverJsonFile(_configFile, label: 'config');

    _initialized = true;
  }

  /// 检测并迁移老配置
  Future<void> _migrateOldConfigIfNeeded() async {
    // 如果老目录不存在，无需迁移
    if (!await _oldStorageDir.exists()) {
      return;
    }

    print('[TaskStorage] 检测到旧配置目录: ${_oldStorageDir.path}');

    try {
      // 确保新目录存在
      if (!await _storageDir.exists()) {
        await _storageDir.create(recursive: true);
      }

      // 迁移文件列表
      final filesToMigrate = ['tasks.json', 'config.json'];
      int migratedCount = 0;

      for (final fileName in filesToMigrate) {
        final oldFile = File(path.join(_oldStorageDir.path, fileName));
        final newFile = File(path.join(_storageDir.path, fileName));

        // 如果老文件存在且新文件不存在，则迁移
        if (await oldFile.exists() && !await newFile.exists()) {
          await oldFile.copy(newFile.path);
          migratedCount++;
          print('[TaskStorage] 已迁移: $fileName');
        }
      }

      if (migratedCount > 0) {
        print('[TaskStorage] 成功迁移 $migratedCount 个配置文件');

        // 迁移完成后删除老目录
        try {
          await _oldStorageDir.delete(recursive: true);
          print('[TaskStorage] 已删除旧配置目录: ${_oldStorageDir.path}');
        } catch (e) {
          print('[TaskStorage] 删除旧配置目录失败: $e');
        }
      } else {
        print('[TaskStorage] 无需迁移配置文件');

        // 如果老目录为空，也尝试删除
        final oldFiles = await _oldStorageDir.list().toList();
        if (oldFiles.isEmpty) {
          try {
            await _oldStorageDir.delete(recursive: true);
            print('[TaskStorage] 已删除空的旧配置目录');
          } catch (e) {
            print('[TaskStorage] 删除空目录失败: $e');
          }
        }
      }
    } catch (e) {
      print('[TaskStorage] 配置迁移过程出错: $e');
      // 迁移失败不影响继续使用新目录
    }
  }

  File get _tasksFile => File(path.join(_storageDir.path, 'tasks.json'));
  File get _configFile => File(path.join(_storageDir.path, 'config.json'));

  Future<Map<String, Task>> loadTasks() async {
    await init();

    final json = await _readJsonMapWithRecovery(_tasksFile, label: 'tasks');
    if (json == null) return {};

    try {
      final tasks = <String, Task>{};
      for (final entry in json.entries) {
        tasks[entry.key] = _taskFromJson(entry.value);
      }
      return tasks;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTasks(Map<String, Task> tasks) async {
    await _enqueueWrite(() async {
      await init();

      final json = <String, dynamic>{};
      for (final entry in tasks.entries) {
        json[entry.key] = _taskToJson(entry.value);
      }

      await _writeJsonAtomic(_tasksFile, json);
    });
  }

  Future<NsfxConfig> loadConfig() async {
    await init();
    final json = await _readJsonMapWithRecovery(_configFile, label: 'config');
    if (json == null) return NsfxConfig();

    try {
      final config = NsfxConfig.fromJson(json);

      // 确保 maxRetries 至少为 200（IDM 风格）
      // 旧配置可能保存了较小的值
      if (config.maxRetries < 200) {
        config.maxRetries = 200;
      }

      return config;
    } catch (_) {
      return NsfxConfig();
    }
  }

  Future<void> saveConfig(NsfxConfig config) async {
    await _enqueueWrite(() async {
      await init();
      await _writeJsonAtomic(_configFile, config.toJson());
    });
  }

  Future<void> clearAll() async {
    await init();

    if (await _tasksFile.exists()) {
      await _tasksFile.delete();
    }
    await _deleteIfExists(File('${_tasksFile.path}.tmp'));
    await _deleteIfExists(File('${_tasksFile.path}.bak'));
  }

  Future<void> _enqueueWrite(Future<void> Function() action) {
    _writeQueue = _writeQueue.then((_) => action()).catchError((_) {});
    return _writeQueue;
  }

  Future<void> _writeJsonAtomic(File target, Map<String, dynamic> json) async {
    final content = jsonEncode(json);
    await _writeFileAtomically(target, content);
  }

  Future<Map<String, dynamic>?> _readJsonMapWithRecovery(File target,
      {required String label}) async {
    final direct = await _tryReadJsonMap(target);
    if (direct != null) return direct;

    await _recoverJsonFile(target, label: label);
    return _tryReadJsonMap(target);
  }

  Future<Map<String, dynamic>?> _tryReadJsonMap(File file) async {
    try {
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final json = jsonDecode(content);
      if (json is Map<String, dynamic>) return json;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _recoverJsonFile(File target, {required String label}) async {
    final tmp = File('${target.path}.tmp');
    final bak = File('${target.path}.bak');

    final targetJson = await _tryReadJsonMap(target);
    if (targetJson != null) {
      // 如果主文件有效，清理残留 tmp
      await _deleteIfExists(tmp);
      return;
    }

    // 主文件无效或不存在，尝试使用 tmp
    final tmpJson = await _tryReadJsonMap(tmp);
    if (tmpJson != null) {
      await _replaceFile(tmp, target);
      print('[TaskStorage] Recovered $label from tmp');
      return;
    }

    // 尝试使用 bak
    final bakJson = await _tryReadJsonMap(bak);
    if (bakJson != null) {
      await _replaceFile(bak, target);
      print('[TaskStorage] Recovered $label from backup');
      return;
    }

    // 如果主文件存在但不可读，保留为 .corrupt
    if (await target.exists()) {
      final corruptPath = '${target.path}.corrupt';
      try {
        await target.rename(corruptPath);
        print('[TaskStorage] Moved corrupt $label to $corruptPath');
      } catch (_) {}
    }

    // 清理无效的 tmp
    await _deleteIfExists(tmp);
  }

  Future<void> _writeFileAtomically(File target, String content) async {
    final tmp = File('${target.path}.tmp');
    final bak = File('${target.path}.bak');

    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }

    await tmp.writeAsString(content, flush: true);

    // 尝试备份现有文件
    if (await target.exists()) {
      try {
        await _deleteIfExists(bak);
        await target.rename(bak.path);
      } catch (_) {
        try {
          await target.copy(bak.path);
        } catch (_) {}
      }
    }

    // 用临时文件替换
    try {
      await tmp.rename(target.path);
      return;
    } catch (_) {
      try {
        await tmp.copy(target.path);
        await _deleteIfExists(tmp);
        return;
      } catch (e) {
        // 如果写入失败且主文件不存在，尝试恢复备份
        if (!await target.exists() && await bak.exists()) {
          try {
            await bak.rename(target.path);
          } catch (_) {}
        }
        print('[TaskStorage] Failed to write file: $e');
      }
    }
  }

  Future<void> _replaceFile(File source, File target) async {
    try {
      await _deleteIfExists(target);
      await source.rename(target.path);
    } catch (_) {
      try {
        await source.copy(target.path);
      } finally {
        await _deleteIfExists(source);
      }
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Map<String, dynamic> _taskToJson(Task task) => {
        'id': task.id,
        'url': task.url,
        'filename': task.filename,
        'filepath': task.filepath,
        'status': task.status.name,
        'totalSize': task.totalSize,
        'downloadedSize': task.downloadedSize,
        'speed': task.speed,
        'progress': task.progress,
        'eta': task.eta,
        'errorMessage': task.errorMessage,
        'threadCount': task.threadCount,
        'peakSpeed': task.peakSpeed,
        'averageSpeed': task.averageSpeed,
        'startTime': task.startTime?.toIso8601String(),
        'endTime': task.endTime?.toIso8601String(),
        'createdTime': task.createdTime.toIso8601String(),
        'userAgent': task.userAgent,
        'referer': task.referer,
        'cookies': task.cookies,
        'headers': task.headers,
        'effectiveHttpVersionPolicy': task.effectiveHttpVersionPolicy,
        'negotiatedHttpVersion': task.negotiatedHttpVersion,
        'targetReachable': task.targetReachable,
        'segments': task.segments
            .map((s) => {
                  'index': s.index,
                  'startByte': s.startByte,
                  'endByte': s.endByte,
                  'downloadedBytes': s.downloadedBytes,
                  'status': s.status.name,
                  'retryCount': s.retryCount,
                })
            .toList(),
      };

  Task _taskFromJson(Map<String, dynamic> json) {
    final task = Task(
      id: json['id'],
      url: json['url'],
      filename: json['filename'],
      filepath: json['filepath'],
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      totalSize: json['totalSize'] ?? 0,
      downloadedSize: json['downloadedSize'] ?? 0,
      speed: (json['speed'] ?? 0).toDouble(),
      progress: (json['progress'] ?? 0).toDouble(),
      eta: json['eta'] ?? 0,
      errorMessage: json['errorMessage'],
      threadCount: json['threadCount'] ?? 1,
      peakSpeed: (json['peakSpeed'] ?? 0).toDouble(),
      averageSpeed: (json['averageSpeed'] ?? 0).toDouble(),
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      createdTime: json['createdTime'] != null
          ? DateTime.parse(json['createdTime'])
          : DateTime.now(),
      userAgent: json['userAgent'],
      referer: json['referer'],
      cookies: json['cookies'],
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'])
          : null,
      effectiveHttpVersionPolicy:
          json['effectiveHttpVersionPolicy']?.toString(),
      negotiatedHttpVersion: json['negotiatedHttpVersion']?.toString(),
      targetReachable: json['targetReachable'] as bool?,
    );

    if (json['segments'] != null) {
      for (final s in json['segments']) {
        task.segments.add(Segment(
          index: s['index'],
          startByte: s['startByte'],
          endByte: s['endByte'],
          downloadedBytes: s['downloadedBytes'] ?? 0,
          status: SegmentStatus.values.firstWhere(
            (e) => e.name == s['status'],
            orElse: () => SegmentStatus.pending,
          ),
          retryCount: s['retryCount'] ?? 0,
        ));
      }
    }

    return task;
  }
}
