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
    
    if (!await _tasksFile.exists()) return {};

    try {
      final content = await _tasksFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      
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
    await init();

    final json = <String, dynamic>{};
    for (final entry in tasks.entries) {
      json[entry.key] = _taskToJson(entry.value);
    }

    await _tasksFile.writeAsString(jsonEncode(json));
  }

  Future<NsfxConfig> loadConfig() async {
    await init();

    if (!await _configFile.exists()) return NsfxConfig();

    try {
      final content = await _configFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
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
    await init();
    await _configFile.writeAsString(jsonEncode(config.toJson()));
  }

  Future<void> clearAll() async {
    await init();
    
    if (await _tasksFile.exists()) {
      await _tasksFile.delete();
    }
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
    'segments': task.segments.map((s) => {
      'index': s.index,
      'startByte': s.startByte,
      'endByte': s.endByte,
      'downloadedBytes': s.downloadedBytes,
      'status': s.status.name,
      'retryCount': s.retryCount,
    }).toList(),
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
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      createdTime: json['createdTime'] != null ? DateTime.parse(json['createdTime']) : DateTime.now(),
      userAgent: json['userAgent'],
      referer: json['referer'],
      cookies: json['cookies'],
      headers: json['headers'] != null ? Map<String, String>.from(json['headers']) : null,
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
