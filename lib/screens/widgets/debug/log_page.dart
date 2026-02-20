import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../services/app_logger_service.dart';
import '../../../services/download_failure_stats_service.dart';
import '../../../services/client_config_service.dart';
import '../../../widgets/folder_picker_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/fluent_icons.dart';

/// 自定义正则规则
class CustomRegexRule {
  final String name;
  final String pattern;
  final bool enabled;
  final Color? highlightColor;

  const CustomRegexRule({
    required this.name,
    required this.pattern,
    this.enabled = true,
    this.highlightColor,
  });

  CustomRegexRule copyWith({
    String? name,
    String? pattern,
    bool? enabled,
    Color? highlightColor,
  }) {
    return CustomRegexRule(
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      enabled: enabled ?? this.enabled,
      highlightColor: highlightColor ?? this.highlightColor,
    );
  }
}

/// 日志统计信息
class LogStats {
  final int total;
  final int debug;
  final int info;
  final int warning;
  final int error;
  final int groupedCount;

  const LogStats({
    this.total = 0,
    this.debug = 0,
    this.info = 0,
    this.warning = 0,
    this.error = 0,
    this.groupedCount = 0,
  });
}

class LogDisplayItem {
  final List<LogEntry> logs;
  final List<List<LogEntry>>? repeatedLogs;
  int count;
  bool isExpanded;
  bool isBookmarked;

  LogDisplayItem(this.logs, {
    this.count = 1, 
    this.isExpanded = false,
    this.repeatedLogs,
    this.isBookmarked = false,
  });
  
  LogEntry get primaryLog => logs.first;
  
  String get id => '${primaryLog.timestamp.millisecondsSinceEpoch}_${primaryLog.message.hashCode}';
}

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  LogLevel? _filterLevel;
  String? _filterSource;
  Set<String> _filterTags = {};
  String _searchQuery = '';
  bool _autoScroll = true;
  bool _useRegexSearch = false;
  bool _showStats = true;
  bool _showFailureStats = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  // 内置正则表达式（用于去重）
  final RegExp _logPrefixRegex = RegExp(r'^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}[.,]\d{3}\s-\s.*?\s-\s[A-Z]+\s-\s');
  final RegExp _portRegex = RegExp(r'(port\s*[:=]?\s*)\d+', caseSensitive: false);
  final RegExp _threadRegex = RegExp(r'(线程|Thread\s*)\d+', caseSensitive: false);
  final RegExp _segmentRegex = RegExp(r'(分段|[Ss]egment)\s*#?\d+', caseSensitive: false);
  final RegExp _taskIdRegex = RegExp(r'\b[a-f0-9]{16,32}\b');
  final RegExp _progressRegex = RegExp(r'\b\d+(\.\d+)?%');
  final RegExp _speedRegex = RegExp(r'\b\d+(\.\d+)?\s*(KB|MB|GB|B)/s\b', caseSensitive: false);
  final RegExp _sizeRegex = RegExp(r'\b\d+(\.\d+)?\s*(KB|MB|GB|TB|B)\b', caseSensitive: false);
  final RegExp _timestampRegex = RegExp(r'\b\d{2}:\d{2}:\d{2}([.,]\d{3})?\b');
  final RegExp _pidRegex = RegExp(r'(PID|pid)[:=\s]*\d+');
  final RegExp _attemptRegex = RegExp(r'(attempt|尝试)\s*\d+(/\d+)?', caseSensitive: false);
  final RegExp _durationRegex = RegExp(r'\b\d+(\.\d+)?\s*(ms|s|秒|毫秒)\b', caseSensitive: false);
  final RegExp _windowSizeRegex = RegExp(r'\b\d+x\d+\b');
  
  // 内置高亮规则（始终启用）
  List<_BuiltinHighlightRule> get _builtinRules => [
    // URL 高亮
    _BuiltinHighlightRule(
      name: t.logRuleUrl,
      pattern: r'https?://[^\s<>"{}|\\^`\[\]]+',
      color: const Color(0xFF60CDFF),
      type: _HighlightType.url,
    ),
    // 文件路径 (Windows)
    _BuiltinHighlightRule(
      name: t.logRuleFilePath,
      pattern: r'[A-Za-z]:\\[^\s<>"{}|*?]+',
      color: const Color(0xFF89D185),
      type: _HighlightType.path,
    ),
    // 文件路径 (Unix)
    _BuiltinHighlightRule(
      name: t.logRuleFilePath,
      pattern: r'(?<!\w)/(?:[\w.-]+/)+[\w.-]+',
      color: const Color(0xFF89D185),
      type: _HighlightType.path,
    ),
    // IP 地址（含端口）
    _BuiltinHighlightRule(
      name: t.logRuleIpAddress,
      pattern: r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(?::\d{1,5})?\b',
      color: const Color(0xFFDCDCAA),
      type: _HighlightType.ip,
    ),
    // 数值（带单位：大小、速度、时间、百分比）
    _BuiltinHighlightRule(
      name: t.logRuleNumber,
      pattern: r'\b\d+(?:\.\d+)?\s*(?:KB/s|MB/s|GB/s|KB|MB|GB|TB|B|ms|s|秒|毫秒|%)\b',
      color: const Color(0xFFB5CEA8),
      type: _HighlightType.number,
    ),
    // 任务ID / Hash
    _BuiltinHighlightRule(
      name: t.logRuleIdHash,
      pattern: r'\b[a-f0-9]{8,32}\b',
      color: const Color(0xFFCE9178),
      type: _HighlightType.id,
    ),
    // 错误关键词
    _BuiltinHighlightRule(
      name: t.logRuleError,
      pattern: r'\b(?:error|failed|failure|exception|critical|fatal|crash|panic|错误|失败|异常|崩溃)\b',
      color: const Color(0xFFFF6B6B),
      type: _HighlightType.error,
    ),
    // 成功关键词
    _BuiltinHighlightRule(
      name: t.logRuleSuccess,
      pattern: r'\b(?:success(?:ful(?:ly)?)?|completed|done|passed|healthy|ok|成功|完成|通过|健康)\b',
      color: const Color(0xFF6CCB5F),
      type: _HighlightType.success,
    ),
    // 警告关键词
    _BuiltinHighlightRule(
      name: t.logRuleWarning,
      pattern: r'\b(?:warning|warn|timeout|retry|retrying|注意|警告|超时|重试)\b',
      color: const Color(0xFFFFB900),
      type: _HighlightType.warning,
    ),
    // HTTP 方法
    _BuiltinHighlightRule(
      name: t.logRuleHttpMethod,
      pattern: r'\b(?:GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\b',
      color: const Color(0xFF569CD6),
      type: _HighlightType.httpMethod,
    ),
    // HTTP 状态码（仅在上下文中匹配，避免误匹配普通数字）
    _BuiltinHighlightRule(
      name: t.logRuleHttpStatus,
      pattern: r'(?:status|HTTP|响应)\s*[:=]?\s*[1-5]\d{2}\b',
      color: const Color(0xFFD7BA7D),
      type: _HighlightType.httpStatus,
    ),
    // 时间戳
    _BuiltinHighlightRule(
      name: t.logRuleTime,
      pattern: r'\b\d{2}:\d{2}:\d{2}(?:[.,]\d{3})?\b',
      color: const Color(0xFF9CDCFE),
      type: _HighlightType.time,
    ),
    // 步骤指示器 [1/4] [2/4] 等
    _BuiltinHighlightRule(
      name: t.logRuleStep,
      pattern: r'\[\d+/\d+\]',
      color: const Color(0xFFD4A0FF),
      type: _HighlightType.step,
    ),
    // 进程 PID
    _BuiltinHighlightRule(
      name: t.logRulePid,
      pattern: r'\bPID[:=\s]*\d+\b',
      color: const Color(0xFF9CDCFE),
      type: _HighlightType.pid,
    ),
    // 键值对 key=value / key: value（限制 key 长度避免回溯）
    _BuiltinHighlightRule(
      name: t.logRuleKeyValue,
      pattern: r'\b\w{1,30}\s*=\s*(?:"[^"]{0,100}"|\S{1,100})',
      color: const Color(0xFFCE9178),
      type: _HighlightType.keyValue,
    ),
  ];
  
  // 内置规则启用状态
  final Map<_HighlightType, bool> _builtinRuleEnabled = {
    _HighlightType.url: true,
    _HighlightType.path: true,
    _HighlightType.ip: true,
    _HighlightType.number: true,
    _HighlightType.id: false, // 默认关闭，避免太多高亮
    _HighlightType.error: true,
    _HighlightType.success: true,
    _HighlightType.warning: true,
    _HighlightType.httpMethod: true,
    _HighlightType.httpStatus: false, // 默认关闭
    _HighlightType.time: false, // 默认关闭
    _HighlightType.step: true,
    _HighlightType.pid: false, // 默认关闭
    _HighlightType.keyValue: false, // 默认关闭，避免太多高亮
  };
  
  // 状态管理
  final Set<String> _expandedGroupIds = {};
  final Set<String> _bookmarkedIds = {};
  
  // 去重归一化缓存（message hashCode -> normalized string）
  final Map<int, String> _dedupCache = {};
  int _dedupCacheVersion = -1;
  
  // 自定义正则规则（从配置加载）
  List<CustomRegexRule> _customRules = [];
  
  // 时间范围筛选
  DateTime? _startTime;
  DateTime? _endTime;

  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = context.read<ClientConfigService>();
    final rules = config.getLogRegexRules();
    final builtinStates = config.getLogBuiltinRuleStates();
    
    setState(() {
      _customRules = rules.map((r) => CustomRegexRule(
        name: r['name'] as String,
        pattern: r['pattern'] as String,
        enabled: r['enabled'] as bool? ?? true,
        highlightColor: Color(r['color'] as int? ?? 0xFF60CDFF),
      )).toList();
      
      _showStats = config.getLogShowStats();
      _showFailureStats = config.getLogShowFailureStats();
      _autoScroll = config.getLogAutoScroll();
      
      // 恢复内置规则启用状态
      for (final entry in builtinStates.entries) {
        try {
          final type = _HighlightType.values.firstWhere(
            (t) => t.name == entry.key,
            orElse: () => _HighlightType.custom,
          );
          if (type != _HighlightType.custom) {
            _builtinRuleEnabled[type] = entry.value;
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _saveRegexRules() async {
    final config = context.read<ClientConfigService>();
    final rules = _customRules.map((r) => {
      'name': r.name,
      'pattern': r.pattern,
      'enabled': r.enabled,
      'color': r.highlightColor?.value ?? 0xFF60CDFF,
    }).toList();
    
    await config.saveLogRegexRules(rules);
  }

  Future<void> _saveBuiltinRuleStates() async {
    final config = context.read<ClientConfigService>();
    final states = <String, bool>{};
    for (final entry in _builtinRuleEnabled.entries) {
      states[entry.key.name] = entry.value;
    }
    await config.saveLogBuiltinRuleStates(states);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  // 计算日志统计
  LogStats _calculateStats(List<LogEntry> logs, List<LogDisplayItem> grouped) {
    int debug = 0, info = 0, warning = 0, error = 0;
    for (var log in logs) {
      switch (log.level) {
        case LogLevel.debug: debug++; break;
        case LogLevel.info: info++; break;
        case LogLevel.warning: warning++; break;
        case LogLevel.error: error++; break;
      }
    }
    return LogStats(
      total: logs.length,
      debug: debug,
      info: info,
      warning: warning,
      error: error,
      groupedCount: grouped.length,
    );
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _stripLogPrefix(String message) {
    return message.replaceFirst(_logPrefixRegex, '').trim();
  }

  String _cachedNormalizeForDedup(LogEntry entry, int logVersion) {
    // 版本变化时清空缓存
    if (_dedupCacheVersion != logVersion) {
      _dedupCache.clear();
      _dedupCacheVersion = logVersion;
    }
    final key = entry.message.hashCode ^ entry.source.hashCode;
    return _dedupCache.putIfAbsent(key, () => _normalizeForDedup(entry.message));
  }

  String _normalizeForDedup(String message) {
    String msg = _stripLogPrefix(message);
    // 替换端口号
    msg = msg.replaceAll(_portRegex, r'\1<PORT>');
    // 替换线程编号
    msg = msg.replaceAll(_threadRegex, r'\1<N>');
    // 替换分段编号
    msg = msg.replaceAll(_segmentRegex, r'\1<N>');
    // 替换任务ID
    msg = msg.replaceAll(_taskIdRegex, '<TASK_ID>');
    // 替换进度百分比
    msg = msg.replaceAll(_progressRegex, '<PROGRESS>');
    // 替换下载速度（必须在文件大小之前，否则 KB/s 会被匹配为 KB）
    msg = msg.replaceAll(_speedRegex, '<SPEED>');
    // 替换耗时（必须在文件大小之前，否则 s 会被匹配）
    msg = msg.replaceAll(_durationRegex, '<DURATION>');
    // 替换文件大小
    msg = msg.replaceAll(_sizeRegex, '<SIZE>');
    // 替换时间戳
    msg = msg.replaceAll(_timestampRegex, '<TIME>');
    // 替换 PID
    msg = msg.replaceAll(_pidRegex, 'PID:<N>');
    // 替换尝试次数
    msg = msg.replaceAll(_attemptRegex, r'\1 <N>');
    // 替换窗口尺寸
    msg = msg.replaceAll(_windowSizeRegex, '<WxH>');
    return msg;
  }

  List<LogDisplayItem> _groupLogs(List<LogEntry> logs, int logVersion) {
    if (logs.isEmpty) return [];
    
    final List<LogDisplayItem> grouped = [];
    int i = 0;
    
    while (i < logs.length) {
      int bestPatternLength = 0;
      int bestRepeatCount = 1;

      // 尝试查找重复模式，长度从1到5
      for (int len = 1; len <= 5 && i + len <= logs.length; len++) {
        // 检查当前长度为len的模式是否重复
        int currentCount = 1;
        int checkIndex = i + len;
        
        while (checkIndex + len <= logs.length) {
          bool matches = true;
          for (int k = 0; k < len; k++) {
            final original = logs[i + k];
            final candidate = logs[checkIndex + k];
            
            // 使用缓存的标准化消息进行比较
            final originalMsg = _cachedNormalizeForDedup(original, logVersion);
            final candidateMsg = _cachedNormalizeForDedup(candidate, logVersion);
            
            if (originalMsg != candidateMsg ||
                original.level != candidate.level ||
                original.source != candidate.source) {
              matches = false;
              break;
            }
          }
          
          if (matches) {
            currentCount++;
            checkIndex += len;
          } else {
            break;
          }
        }
        
        if (currentCount > 1) {
           int currentTotalLen = len * currentCount;
           int bestTotalLen = bestPatternLength * bestRepeatCount;
           
           if (currentTotalLen > bestTotalLen) {
             bestPatternLength = len;
             bestRepeatCount = currentCount;
           }
        }
      }
      
      if (bestPatternLength > 0) {
        // 发现重复模式
        final patternLogs = logs.sublist(i, i + bestPatternLength);
        
        // 收集所有重复的日志组
        List<List<LogEntry>> allRepeatedGroups = [];
        for (int k = 0; k < bestRepeatCount; k++) {
          int startIndex = i + k * bestPatternLength;
          allRepeatedGroups.add(logs.sublist(startIndex, startIndex + bestPatternLength));
        }
        
        final item = LogDisplayItem(
          patternLogs, 
          count: bestRepeatCount,
          repeatedLogs: allRepeatedGroups,
        );
        item.isExpanded = _expandedGroupIds.contains(item.id);
        grouped.add(item);
        i += bestPatternLength * bestRepeatCount;
      } else {
        // 无重复
        grouped.add(LogDisplayItem([logs[i]], count: 1));
        i++;
      }
    }
    
    return grouped;
  }

  Future<void> _exportLogs(BuildContext context) async {
    String initialPath = 'C:\\';
    try {
      initialPath = Directory.current.path;
    } catch (_) {}

    final selectedPath = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => FolderPickerDialog(
        initialPath: initialPath,
      ),
    );

    if (selectedPath != null && mounted) {
      try {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
        final file = File('$selectedPath\\log_export_$timestamp.txt');
        
        final logs = context.read<AppLoggerService>().logs;
        final buffer = StringBuffer();
        for (var log in logs) {
          buffer.writeln('[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}');
        }
        
        await file.writeAsString(buffer.toString());
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: Text(t.logExportSuccessTitle),
              content: Text(t.logExportSavedMessage(file.path)),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.logDialogOk),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: Text(t.logExportFailedTitle),
              content: Text(t.logExportFailedMessage(e)),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.logDialogOk),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _exportDiagnostics(BuildContext context) async {
    String initialPath = 'C:\\';
    try {
      initialPath = Directory.current.path;
    } catch (_) {}

    final selectedPath = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => FolderPickerDialog(
        initialPath: initialPath,
      ),
    );

    if (selectedPath == null || !mounted) return;

    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final exportRoot = Directory(p.join(selectedPath, 'hanabi_diagnostics_$timestamp'));
      final configDir = Directory(p.join(exportRoot.path, 'config'));
      final logsDir = Directory(p.join(exportRoot.path, 'logs'));

      await configDir.create(recursive: true);
      await logsDir.create(recursive: true);

      // 导出配置
      final config = context.read<ClientConfigService>();
      await config.exportAllConfigs(configDir.path);

      // 额外导出内核配置（如存在）
      final kernelConfigFile = File(p.join(config.baseDir, 'kernel', 'config.json'));
      if (await kernelConfigFile.exists()) {
        await kernelConfigFile.copy(p.join(configDir.path, 'kernel_config.json'));
      }

      // 导出日志文件
      final docsDir = await getApplicationDocumentsDirectory();
      final logDir = Directory(p.join(docsDir.path, 'HanabiDownloadManagerX', 'logs'));
      if (await logDir.exists()) {
        await for (final entity in logDir.list()) {
          if (entity is File) {
            final name = p.basename(entity.path);
            await entity.copy(p.join(logsDir.path, name));
          }
        }
      } else {
        final placeholder = File(p.join(logsDir.path, 'no_logs.txt'));
        await placeholder.writeAsString('No log files found.');
      }

      // 生成摘要
      final failureStats = context.read<DownloadFailureStatsService>();
      final summary = StringBuffer()
        ..writeln('Hanabi Download Manager X Diagnostics')
        ..writeln('Export Time: $timestamp')
        ..writeln('Total Failures: ${failureStats.totalFailures}');

      if (failureStats.reasonCounts.isNotEmpty) {
        summary.writeln('Failure Reasons:');
        final sorted = failureStats.reasonCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sorted) {
          final label = _localizedReason(entry.key);
          summary.writeln('- $label: ${entry.value}');
        }
      }

      await File(p.join(exportRoot.path, 'summary.txt')).writeAsString(summary.toString());

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: Text(t.logExportSuccessTitle),
            content: Text(t.logDiagnosticsSavedMessage(exportRoot.path)),
            actions: [
              Button(
                onPressed: () => Navigator.pop(context),
                child: Text(t.logDialogOk),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: Text(t.logExportFailedTitle),
            content: Text(t.logDiagnosticsExportFailedMessage(e)),
            actions: [
              Button(
                onPressed: () => Navigator.pop(context),
                child: Text(t.logDialogOk),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentPrimary.withValues(alpha: 0.2),
                    AppTheme.accentPrimary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(FluentIcons.text_document, size: 18, color: AppTheme.accentLight),
            ),
            const SizedBox(width: 14),
            Text(t.logPageTitle),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: Icon(FluentIcons.filter),
              label: Text(_filterLevel == null ? t.logFilterLevelLabel : _filterLevel!.name.toUpperCase()),
              onPressed: () => _showFilterMenu(context),
            ),
            CommandBarButton(
              icon: Icon(FluentIcons.source),
              label: Text(_filterTags.isNotEmpty 
                ? _filterTags.length == 1 ? _filterTags.first : t.logFilterTagCount(_filterTags.length)
                : _filterSource ?? t.logFilterSourceLabel),
              onPressed: () => _showSourceFilterMenu(context),
            ),
            CommandBarButton(
              icon: Icon(FluentIcons.clock),
              label: Text(_startTime != null || _endTime != null ? t.logFilterTimeSelectedLabel : t.logFilterTimeLabel),
              onPressed: () => _showTimeRangeDialog(context),
            ),
            CommandBarButton(
              icon: Icon(FluentIcons.code),
              label: Text(t.logRegexRulesButton),
              onPressed: () => _showRegexRulesDialog(context),
            ),
          ],
          secondaryItems: [
            CommandBarButton(
              icon: Icon(_autoScroll ? FluentIcons.chevron_down : FluentIcons.pause),
              label: Text(_autoScroll ? t.logAutoScrollOn : t.logAutoScrollOff),
              onPressed: () {
                setState(() => _autoScroll = !_autoScroll);
                context.read<ClientConfigService>().setLogAutoScroll(_autoScroll);
              },
            ),
            CommandBarButton(
              icon: Icon(_showStats ? FluentIcons.chart : FluentIcons.hide3),
              label: Text(_showStats ? t.logStatsShow : t.logStatsHide),
              onPressed: () {
                setState(() => _showStats = !_showStats);
                context.read<ClientConfigService>().setLogShowStats(_showStats);
              },
            ),
            CommandBarButton(
              icon: Icon(_showFailureStats ? FluentIcons.warning : FluentIcons.hide3),
              label: Text(_showFailureStats ? t.logFailureStatsShow : t.logFailureStatsHide),
              onPressed: () {
                setState(() => _showFailureStats = !_showFailureStats);
                context.read<ClientConfigService>().setLogShowFailureStats(_showFailureStats);
              },
            ),
            const CommandBarSeparator(),
            CommandBarButton(
              icon: Icon(FluentIcons.save),
              label: Text(t.logExportLogsButton),
              onPressed: () => _exportLogs(context),
            ),
            CommandBarButton(
              icon: Icon(FluentIcons.folder_open),
              label: Text(t.logExportDiagnosticsButton),
              onPressed: () => _exportDiagnostics(context),
            ),
            CommandBarButton(
              icon: Icon(FluentIcons.archive),
              label: Text(t.logArchiveButton),
              onPressed: () => _showArchiveDialog(context),
            ),
            const CommandBarSeparator(),
            CommandBarButton(
              icon: Icon(FluentIcons.clear),
              label: Text(t.logClearButton),
              onPressed: () => _showClearConfirmDialog(context),
            ),
          ],
        ),
      ),
      content: Consumer2<AppLoggerService, DownloadFailureStatsService>(
        builder: (context, logger, failureStats, child) {
          var logs = logger.logs;

          // 应用时间范围过滤
          if (_startTime != null) {
            logs = logs.where((log) => log.timestamp.isAfter(_startTime!)).toList();
          }
          if (_endTime != null) {
            logs = logs.where((log) => log.timestamp.isBefore(_endTime!)).toList();
          }

          // 应用级别过滤
          if (_filterLevel != null) {
            logs = logs.where((log) => log.level == _filterLevel).toList();
          }

          // 应用来源过滤
          if (_filterTags.isNotEmpty) {
            // 精确匹配选中的 tag
            logs = logs.where((log) => _filterTags.contains(log.source)).toList();
          } else if (_filterSource != null) {
            // 分类标签定义（与对话框保持一致）
            const appTagNames = {'App', 'Update', 'PopupTest'};
            const systemTagNames = {'Console', 'Zone'};
            if (_filterSource == 'Kernel') {
              logs = logs.where((log) => 
                !appTagNames.contains(log.source) && !systemTagNames.contains(log.source)
              ).toList();
            } else if (_filterSource == 'App') {
              logs = logs.where((log) => appTagNames.contains(log.source)).toList();
            } else if (_filterSource == 'System') {
              logs = logs.where((log) => systemTagNames.contains(log.source)).toList();
            } else {
              logs = logs.where((log) => log.source == _filterSource).toList();
            }
          }

          // 应用搜索
          if (_searchQuery.isNotEmpty) {
            if (_useRegexSearch) {
              try {
                final regex = RegExp(_searchQuery, caseSensitive: false);
                logs = logs.where((log) => regex.hasMatch(log.message) || regex.hasMatch(log.source)).toList();
              } catch (_) {
                // 正则无效时回退到普通搜索
                logs = logs.where((log) =>
                  log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  log.source.toLowerCase().contains(_searchQuery.toLowerCase())
                ).toList();
              }
            } else {
              logs = logs.where((log) =>
                log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                log.source.toLowerCase().contains(_searchQuery.toLowerCase())
              ).toList();
            }
          }

          final groupedLogs = _groupLogs(logs, logger.version);
          final stats = _calculateStats(logs, groupedLogs);

          // 自动滚动
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

          return Column(
            children: [
              // 搜索栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: _searchController,
                        placeholder: _useRegexSearch ? t.logSearchPlaceholderRegex : t.logSearchPlaceholder,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            _useRegexSearch ? FluentIcons.code : FluentIcons.searchIcon,
                            size: 14,
                            color: _searchQuery.isNotEmpty 
                              ? AppTheme.accentLight 
                              : AppTheme.textTertiary,
                          ),
                        ),
                        suffix: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(FluentIcons.clear, size: 12),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ToggleButton(
                      checked: _useRegexSearch,
                      onChanged: (v) => setState(() => _useRegexSearch = v),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          '.*',
                          style: TextStyle(
                            fontFamily: 'Courier New',
                            fontWeight: FontWeight.w600,
                            color: _useRegexSearch ? AppTheme.accentLight : AppTheme.textTertiary,
                          ),
                        ),
                      ),
                          ),
                        ],
                      ),
                    ),

              // 统一信息栏（统计 + 筛选标签）
              if (_showStats) _buildInfoBar(stats),

              // 下载失败统计
              if (_showStats && _showFailureStats) _buildFailureStatsBar(failureStats),

              // 日志列表
              Expanded(
                child: logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.bgLayer2.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              FluentIcons.document,
                              size: 28,
                              color: AppTheme.textTertiary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t.logEmptyTitle,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.logEmptySubtitle,
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: groupedLogs.length,
                      itemBuilder: (context, index) => _buildLogEntry(context, groupedLogs[index]),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建统一的信息栏（统计 + 筛选标签整合）
  Widget _buildInfoBar(LogStats stats) {
    final hasActiveFilters = _filterLevel != null || _filterSource != null || 
                             _filterTags.isNotEmpty ||
                             _startTime != null || _endTime != null;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: hasActiveFilters 
              ? AppTheme.accentPrimary.withValues(alpha: 0.3)
              : AppTheme.borderSubtle.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 统计行
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // 统计项
                  _buildStatChip(t.logStatTotal, stats.total, AppTheme.textSecondary, isTotal: true),
                  const SizedBox(width: 6),
                  _buildStatChip('D', stats.debug, const Color(0xFFB794F6), level: LogLevel.debug),
                  const SizedBox(width: 6),
                  _buildStatChip('I', stats.info, Colors.blue, level: LogLevel.info),
                  const SizedBox(width: 6),
                  _buildStatChip('W', stats.warning, Colors.orange, level: LogLevel.warning),
                  const SizedBox(width: 6),
                  _buildStatChip('E', stats.error, Colors.red, level: LogLevel.error),
                  const Spacer(),
                  // 归档信息
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLayer2.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      t.logGroupedCount(stats.groupedCount),
                      style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            // 筛选标签行（仅在有筛选时显示）
            if (hasActiveFilters) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Icon(FluentIcons.filter, size: 12, color: AppTheme.accentLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (_filterLevel != null)
                            _buildFilterTag(
                              _filterLevel!.name.toUpperCase(),
                              _getLevelColor(_filterLevel!),
                              () => setState(() => _filterLevel = null),
                            ),
                          if (_filterSource != null)
                            _buildFilterTag(
                              _filterSource!,
                              AppTheme.accentLight,
                              () => setState(() => _filterSource = null),
                            ),
                          if (_filterTags.isNotEmpty)
                            _buildFilterTag(
                              _filterTags.join(', '),
                              AppTheme.accentLight,
                              () => setState(() => _filterTags = {}),
                            ),
                          if (_startTime != null || _endTime != null)
                            _buildFilterTag(
                              _formatTimeRange(),
                              AppTheme.statusInfo,
                              () => setState(() { _startTime = null; _endTime = null; }),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _filterLevel = null;
                        _filterSource = null;
                        _filterTags = {};
                        _startTime = null;
                        _endTime = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bgLayer2.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.clear, size: 10, color: AppTheme.textTertiary),
                            const SizedBox(width: 4),
                            Text(t.logClearFiltersButton, style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFailureStatsBar(DownloadFailureStatsService stats) {
    final recent = stats.recentFailures;
    final counts = stats.reasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.borderSubtle.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Icon(FluentIcons.warning, size: 14, color: AppTheme.statusWarning),
                  const SizedBox(width: 8),
                  Text(
                    t.logFailureStatsTitle,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    t.logFailureStatsTotal(stats.totalFailures),
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (counts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: counts.take(8).map((entry) {
                    final label = _localizedReason(entry.key);
                    final color = _getReasonColor(entry.key);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Text(
                        '$label · ${entry.value}',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  t.logFailureStatsEmpty,
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: recent.map(_buildFailureRow).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureRow(DownloadFailureRecord record) {
    final reasonColor = _getReasonColor(record.reason);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatFailureTime(record.timestamp),
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: reasonColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: reasonColor.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Text(
                  _localizedReason(record.reason),
                  style: TextStyle(
                    color: reasonColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (record.rawError != null && record.rawError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                record.rawError!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _localizedReason(String reasonKey) {
    final parts = reasonKey.split(':');
    final type = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : 'unknown';
    final code = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final displayCode = code ?? '?';

    switch (type) {
      case 'unknown':
        return t.logFailureReasonUnknown;
      case 'auth':
        return t.logFailureReasonAuth(displayCode);
      case 'not_found':
        return t.logFailureReasonNotFound(displayCode);
      case 'range':
        return code == null ? t.logFailureReasonRange : t.logFailureReasonRangeWithCode(displayCode);
      case 'rate_limit':
        return t.logFailureReasonTooManyRequests(displayCode);
      case 'server':
        return t.logFailureReasonServerError(displayCode);
      case 'http':
        return t.logFailureReasonHttpError(displayCode);
      case 'timeout':
        return t.logFailureReasonTimeout;
      case 'connection':
        return t.logFailureReasonConnection;
      case 'dns':
        return t.logFailureReasonDns;
      case 'ssl':
        return t.logFailureReasonSsl;
      case 'checksum':
        return t.logFailureReasonChecksum;
      case 'disk':
        return t.logFailureReasonDisk;
      case 'other':
        return t.logFailureReasonOther;
      default:
        return reasonKey;
    }
  }

  Color _getReasonColor(String reasonKey) {
    final type = reasonKey.split(':').first;
    switch (type) {
      case 'auth':
      case 'not_found':
      case 'server':
      case 'http':
      case 'checksum':
      case 'disk':
        return AppTheme.statusError;
      case 'timeout':
      case 'connection':
      case 'dns':
      case 'range':
      case 'ssl':
        return AppTheme.statusWarning;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatFailureTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  String _formatTimeRange() {
    if (_startTime != null && _endTime != null) {
      return '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')} - ${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}';
    } else if (_startTime != null) {
      final diff = DateTime.now().difference(_startTime!);
      if (diff.inMinutes < 60) return t.logTimeRangeRecentMinutes(diff.inMinutes);
      return t.logTimeRangeRecentHours(diff.inHours);
    }
    return t.logTimeRangeLabel;
  }

  Widget _buildStatChip(String label, int count, Color color, {LogLevel? level, bool isTotal = false}) {
    final isSelected = level != null && _filterLevel == level;
    
    return GestureDetector(
      onTap: () {
        if (isTotal) {
          setState(() => _filterLevel = null);
        } else if (level != null) {
          setState(() => _filterLevel = _filterLevel == level ? null : level);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
            ? color.withValues(alpha: 0.25)
            : (count > 0 ? color.withValues(alpha: 0.1) : Colors.transparent),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: isSelected 
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1)
            : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTotal) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: count > 0 ? color : color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              isTotal ? '$count' : '$count',
              style: TextStyle(
                color: count > 0 ? color : AppTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Courier New',
              ),
            ),
            if (isTotal) ...[
              const SizedBox(width: 2),
              Text(
                t.logStatCountUnit,
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTag(String label, Color color, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(FluentIcons.chrome_close, size: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(BuildContext context, LogDisplayItem item) {
    final controller = FlyoutController();
    final isBookmarked = _bookmarkedIds.contains(item.id);
    final levelColor = _getLevelColor(item.primaryLog.level);

    return FlyoutTarget(
      controller: controller,
      child: GestureDetector(
        onSecondaryTapUp: (details) {
          controller.showFlyout(
            position: details.globalPosition,
            builder: (ctx) => _buildContextMenu(ctx, item),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isBookmarked 
                ? AppTheme.statusWarning.withValues(alpha: 0.4)
                : AppTheme.borderSubtle.withValues(alpha: 0.3),
              width: isBookmarked ? 1 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主日志条目
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 级别指示条
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: levelColor,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // 日志内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < item.logs.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            _buildSingleLogRow(context, item.logs[i]),
                          ],
                        ],
                      ),
                    ),
                    
                    // 右侧操作区
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 书签按钮
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            icon: Icon(
                              isBookmarked ? FluentIcons.single_bookmark_solid : FluentIcons.single_bookmark,
                              size: 12,
                              color: isBookmarked ? AppTheme.statusWarning : AppTheme.textTertiary.withValues(alpha: 0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                if (isBookmarked) {
                                  _bookmarkedIds.remove(item.id);
                                } else {
                                  _bookmarkedIds.add(item.id);
                                }
                              });
                            },
                          ),
                        ),
                        
                        // 重复计数
                        if (item.count > 1)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (item.isExpanded) {
                                  _expandedGroupIds.remove(item.id);
                                } else {
                                  _expandedGroupIds.add(item.id);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.accentPrimary.withValues(alpha: 0.25),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.isExpanded ? FluentIcons.chevron_up : FluentIcons.chevron_down,
                                    size: 8,
                                    color: AppTheme.accentLight,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '×${item.count}',
                                    style: const TextStyle(
                                      color: AppTheme.accentLight,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Courier New',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 展开的重复日志
              if (item.isExpanded && item.count > 1 && item.repeatedLogs != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(23, 0, 10, 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLayer1.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.radiusMd),
                      bottomRight: Radius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.textTertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.logRepeatedCount(item.count - 1),
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (int k = 1; k < item.repeatedLogs!.length && k <= 50; k++)
                        for (var log in item.repeatedLogs![k])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: _buildSingleLogRow(context, log, isExpandedItem: true),
                          ),
                      if (item.repeatedLogs!.length > 51)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            t.logRepeatedMore(item.repeatedLogs!.length - 51),
                            style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  MenuFlyout _buildContextMenu(BuildContext ctx, LogDisplayItem item) {
    return MenuFlyout(
      items: [
        MenuFlyoutItem(
          leading: Icon(FluentIcons.copy),
          text: Text(t.logContextCopy),
          onPressed: () {
            final buffer = StringBuffer();
            for (var log in item.logs) {
              buffer.writeln('[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}');
            }
            if (item.count > 1) buffer.writeln(t.logContextRepeated(item.count));
            Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
            Navigator.pop(ctx);
          },
        ),
        MenuFlyoutItem(
          leading: Icon(_bookmarkedIds.contains(item.id) 
            ? FluentIcons.single_bookmark_solid 
            : FluentIcons.single_bookmark),
          text: Text(_bookmarkedIds.contains(item.id) ? t.logContextRemoveBookmark : t.logContextAddBookmark),
          onPressed: () {
            setState(() {
              if (_bookmarkedIds.contains(item.id)) {
                _bookmarkedIds.remove(item.id);
              } else {
                _bookmarkedIds.add(item.id);
              }
            });
            Navigator.pop(ctx);
          },
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          leading: Icon(FluentIcons.filter),
          text: Text(t.logContextFilterLevel(item.primaryLog.levelString)),
          onPressed: () {
            setState(() => _filterLevel = item.primaryLog.level);
            Navigator.pop(ctx);
          },
        ),
        MenuFlyoutItem(
          leading: Icon(FluentIcons.source),
          text: Text(t.logContextFilterSource(item.primaryLog.source)),
          onPressed: () {
            setState(() => _filterSource = item.primaryLog.source);
            Navigator.pop(ctx);
          },
        ),
      ],
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return const Color(0xFFB794F6); // 淡紫色
      case LogLevel.info: return Colors.blue;
      case LogLevel.warning: return Colors.orange;
      case LogLevel.error: return Colors.red;
    }
  }

  Widget _buildSingleLogRow(BuildContext context, LogEntry log, {bool isExpandedItem = false}) {
    final levelColor = _getLevelColor(log.level);
    final displayMessage = _stripLogPrefix(log.message);
    final alpha = isExpandedItem ? 0.6 : 1.0;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间
        Text(
          log.formattedTime,
          style: TextStyle(
            color: AppTheme.textTertiary.withValues(alpha: alpha),
            fontSize: 11,
            fontFamily: 'Courier New',
          ),
        ),
        const SizedBox(width: 10),

        // 级别标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: levelColor.withValues(alpha: 0.15 * alpha),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            log.levelString,
            style: TextStyle(
              color: levelColor.withValues(alpha: alpha),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Courier New',
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 来源
        Container(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(
            log.source,
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: alpha),
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),

        // 消息（带高亮）
        Expanded(
          child: _buildHighlightedMessage(displayMessage, alpha),
        ),
      ],
    );

    if (isExpandedItem) {
      final controller = FlyoutController();
      return FlyoutTarget(
        controller: controller,
        child: GestureDetector(
          onSecondaryTapUp: (details) {
            controller.showFlyout(
              position: details.globalPosition,
              builder: (ctx) => MenuFlyout(
                items: [
                  MenuFlyoutItem(
                    leading: Icon(FluentIcons.copy),
                    text: Text(t.logContextCopySingle),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: '[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}',
                      ));
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            color: Colors.transparent,
            child: content,
          ),
        ),
      );
    }

    return content;
  }

  Widget _buildHighlightedMessage(String message, double alpha) {
    // 收集所有匹配
    final List<_HighlightMatch> matches = [];
    
    // 1. 内置规则高亮
    for (final rule in _builtinRules) {
      if (_builtinRuleEnabled[rule.type] != true) continue;
      try {
        final regex = RegExp(rule.pattern, caseSensitive: false);
        for (final match in regex.allMatches(message)) {
          matches.add(_HighlightMatch(
            start: match.start,
            end: match.end,
            color: rule.color,
            type: rule.type,
          ));
        }
      } catch (_) {}
    }
    
    // 2. 自定义规则高亮
    for (final rule in _customRules.where((r) => r.enabled)) {
      try {
        final regex = RegExp(rule.pattern, caseSensitive: false);
        for (final match in regex.allMatches(message)) {
          matches.add(_HighlightMatch(
            start: match.start,
            end: match.end,
            color: rule.highlightColor ?? AppTheme.accentLight,
            type: _HighlightType.custom,
          ));
        }
      } catch (_) {}
    }

    // 3. 搜索高亮（优先级最高）
    if (_searchQuery.isNotEmpty) {
      try {
        final searchRegex = _useRegexSearch 
          ? RegExp(_searchQuery, caseSensitive: false)
          : RegExp(RegExp.escape(_searchQuery), caseSensitive: false);
        for (final match in searchRegex.allMatches(message)) {
          matches.add(_HighlightMatch(
            start: match.start,
            end: match.end,
            color: AppTheme.statusWarning,
            isSearch: true,
          ));
        }
      } catch (_) {}
    }

    if (matches.isEmpty) {
      return Text(
        message,
        style: TextStyle(
          color: AppTheme.textPrimary.withValues(alpha: alpha),
          fontSize: 12,
        ),
      );
    }

    // 限制匹配数量，防止极端情况下的性能问题
    if (matches.length > 50) {
      matches.removeRange(50, matches.length);
    }

    // 按位置排序，搜索匹配优先
    matches.sort((a, b) {
      if (a.start != b.start) return a.start.compareTo(b.start);
      // 搜索匹配优先
      if (a.isSearch && !b.isSearch) return -1;
      if (!a.isSearch && b.isSearch) return 1;
      return 0;
    });
    
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start < lastEnd) continue; // 跳过重叠
      
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: message.substring(lastEnd, match.start),
          style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: alpha)),
        ));
      }
      
      // 根据类型决定样式
      TextStyle highlightStyle;
      if (match.isSearch) {
        // 搜索高亮：黄色背景，黑色文字
        highlightStyle = TextStyle(
          color: Colors.black,
          backgroundColor: match.color.withValues(alpha: 0.85),
          fontWeight: FontWeight.bold,
        );
      } else if (match.type == _HighlightType.error) {
        // 错误：红色背景
        highlightStyle = TextStyle(
          color: match.color,
          backgroundColor: match.color.withValues(alpha: 0.15),
          fontWeight: FontWeight.w600,
        );
      } else if (match.type == _HighlightType.success) {
        // 成功：绿色背景
        highlightStyle = TextStyle(
          color: match.color,
          backgroundColor: match.color.withValues(alpha: 0.15),
          fontWeight: FontWeight.w600,
        );
      } else if (match.type == _HighlightType.warning) {
        // 警告：橙色背景
        highlightStyle = TextStyle(
          color: match.color,
          backgroundColor: match.color.withValues(alpha: 0.15),
          fontWeight: FontWeight.w600,
        );
      } else if (match.type == _HighlightType.url) {
        // URL：下划线
        highlightStyle = TextStyle(
          color: match.color,
          decoration: TextDecoration.underline,
          decorationColor: match.color.withValues(alpha: 0.5),
        );
      } else if (match.type == _HighlightType.path) {
        // 路径：斜体
        highlightStyle = TextStyle(
          color: match.color,
          fontStyle: FontStyle.italic,
        );
      } else if (match.type == _HighlightType.step) {
        // 步骤指示器：加粗 + 背景
        highlightStyle = TextStyle(
          color: match.color,
          backgroundColor: match.color.withValues(alpha: 0.12),
          fontWeight: FontWeight.w700,
          fontFamily: 'Courier New',
        );
      } else if (match.type == _HighlightType.keyValue) {
        // 键值对：等宽字体
        highlightStyle = TextStyle(
          color: match.color,
          fontFamily: 'Courier New',
        );
      } else {
        // 默认：仅颜色
        highlightStyle = TextStyle(
          color: match.color,
        );
      }
      
      spans.add(TextSpan(
        text: message.substring(match.start, match.end),
        style: highlightStyle,
      ));
      lastEnd = match.end;
    }

    if (lastEnd < message.length) {
      spans.add(TextSpan(
        text: message.substring(lastEnd),
        style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: alpha)),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: spans,
      ),
    );
  }

  void _showFilterMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text(t.logFilterLevelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              (null, t.logFilterAllLabel, AppTheme.textPrimary),
              (LogLevel.debug, 'DEBUG', const Color(0xFFB794F6)), // 淡紫色
              (LogLevel.info, 'INFO', Colors.blue),
              (LogLevel.warning, 'WARNING', Colors.orange),
              (LogLevel.error, 'ERROR', Colors.red),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioButton(
                  checked: _filterLevel == item.$1,
                  onChanged: (_) {
                    setState(() => _filterLevel = item.$1);
                    Navigator.pop(ctx);
                  },
                  content: Row(
                    children: [
                      if (item.$1 != null)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: item.$3,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(item.$2),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          Button(onPressed: () => Navigator.pop(ctx), child: Text(t.logDialogClose)),
        ],
      ),
    );
  }

  void _showSourceFilterMenu(BuildContext context) {
    final logger = context.read<AppLoggerService>();
    // 从日志中动态收集所有 source 标签及其计数
    final sourceCounts = <String, int>{};
    for (final log in logger.logs) {
      sourceCounts[log.source] = (sourceCounts[log.source] ?? 0) + 1;
    }
    
    // 分类标签
    // App 类：应用程序逻辑
    const appTagNames = {'App', 'Update', 'PopupTest'};
    // 系统类：Flutter 框架 / Zone / Console 等
    const systemTagNames = {'Console', 'Zone'};
    // 其余归为 Kernel 类（下载核心）
    final kernelTags = sourceCounts.keys
        .where((s) => !appTagNames.contains(s) && !systemTagNames.contains(s))
        .toList()..sort();
    final appTags = sourceCounts.keys
        .where((s) => appTagNames.contains(s))
        .toList()..sort();
    final systemTags = sourceCounts.keys
        .where((s) => systemTagNames.contains(s))
        .toList()..sort();
    
    var tempFilterSource = _filterSource;
    var tempFilterTags = Set<String>.from(_filterTags);
    var kernelExpanded = false;
    var appExpanded = false;
    var systemExpanded = false;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isAll = tempFilterSource == null && tempFilterTags.isEmpty;
          final isKernelAll = tempFilterSource == 'Kernel' && tempFilterTags.isEmpty;
          final isAppAll = tempFilterSource == 'App' && tempFilterTags.isEmpty;
          final isSystemAll = tempFilterSource == 'System' && tempFilterTags.isEmpty;
          
          // 计算分类下选中的 tag 数
          final kernelSelectedCount = tempFilterTags.where((t) => kernelTags.contains(t)).length;
          final appSelectedCount = tempFilterTags.where((t) => appTags.contains(t)).length;
          final systemSelectedCount = tempFilterTags.where((t) => systemTags.contains(t)).length;
          
          Widget buildTagRow(String tag, int count) {
            final selected = tempFilterTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setDialogState(() {
                  tempFilterSource = null;
                  if (selected) {
                    tempFilterTags.remove(tag);
                  } else {
                    tempFilterTags.add(tag);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: selected 
                    ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      checked: selected,
                      onChanged: (checked) {
                        setDialogState(() {
                          tempFilterSource = null;
                          if (checked == true) {
                            tempFilterTags.add(tag);
                          } else {
                            tempFilterTags.remove(tag);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(tag, style: TextStyle(
                        fontSize: 13,
                        color: selected ? AppTheme.accentLight : AppTheme.textPrimary,
                      )),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLayer2.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          Widget buildCategoryHeader({
            required String title,
            required String subtitle,
            required int tagCount,
            required int selectedCount,
            required bool expanded,
            required bool isAllSelected,
            required VoidCallback onToggleExpand,
            required VoidCallback onSelectAll,
          }) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onToggleExpand,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAllSelected
                        ? AppTheme.accentPrimary.withValues(alpha: 0.1)
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          expanded ? FluentIcons.chevron_down : FluentIcons.chevron_right,
                          size: 12,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(title, style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isAllSelected ? AppTheme.accentLight : AppTheme.textPrimary,
                                  )),
                                  const SizedBox(width: 6),
                                  if (selectedCount > 0 && !isAllSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$selectedCount/$tagCount',
                                        style: TextStyle(fontSize: 10, color: AppTheme.accentLight),
                                      ),
                                    ),
                                ],
                              ),
                              Text(subtitle, style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              )),
                            ],
                          ),
                        ),
                        // 全选按钮
                        GestureDetector(
                          onTap: onSelectAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAllSelected
                                ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                                : AppTheme.bgLayer2.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              border: isAllSelected
                                ? Border.all(color: AppTheme.accentPrimary.withValues(alpha: 0.3))
                                : null,
                            ),
                            child: Text(
                              t.logFilterAllLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: isAllSelected ? AppTheme.accentLight : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          
          return ContentDialog(
            title: Text(t.logSourceFilterTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420, maxWidth: 340),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 全部
                    GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          tempFilterSource = null;
                          tempFilterTags.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isAll
                            ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Row(
                          children: [
                            RadioButton(
                              checked: isAll,
                              onChanged: (_) {
                                setDialogState(() {
                                  tempFilterSource = null;
                                  tempFilterTags.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(t.logFilterAllLabel, style: TextStyle(
                              fontSize: 13,
                              color: isAll ? AppTheme.accentLight : AppTheme.textPrimary,
                            )),
                            const Spacer(),
                            Text(t.logSourceTotalCount(sourceCounts.values.fold<int>(0, (a, b) => a + b)),
                              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    Divider(style: DividerThemeData(
                      decoration: BoxDecoration(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
                    )),
                    const SizedBox(height: 6),
                    
                    // Kernel 分类
                    buildCategoryHeader(
                      title: t.logSourceCategoryKernel,
                      subtitle: t.logSourceKernelSubtitle(kernelTags.length),
                      tagCount: kernelTags.length,
                      selectedCount: kernelSelectedCount,
                      expanded: kernelExpanded,
                      isAllSelected: isKernelAll,
                      onToggleExpand: () => setDialogState(() => kernelExpanded = !kernelExpanded),
                      onSelectAll: () {
                        setDialogState(() {
                          tempFilterSource = 'Kernel';
                          tempFilterTags.clear();
                        });
                      },
                    ),
                    // 展开的 tag 列表
                    if (kernelExpanded && kernelTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final tag in kernelTags)
                              buildTagRow(tag, sourceCounts[tag] ?? 0),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 6),
                    Divider(style: DividerThemeData(
                      decoration: BoxDecoration(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
                    )),
                    const SizedBox(height: 6),
                    
                    // App 分类
                    buildCategoryHeader(
                      title: t.logSourceCategoryApp,
                      subtitle: t.logSourceAppSubtitle(appTags.length),
                      tagCount: appTags.length,
                      selectedCount: appSelectedCount,
                      expanded: appExpanded,
                      isAllSelected: isAppAll,
                      onToggleExpand: () => setDialogState(() => appExpanded = !appExpanded),
                      onSelectAll: () {
                        setDialogState(() {
                          tempFilterSource = 'App';
                          tempFilterTags.clear();
                        });
                      },
                    ),
                    if (appExpanded && appTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final tag in appTags)
                              buildTagRow(tag, sourceCounts[tag] ?? 0),
                          ],
                        ),
                      ),
                    
                    // System 分类（仅在有系统标签时显示）
                    if (systemTags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Divider(style: DividerThemeData(
                        decoration: BoxDecoration(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
                      )),
                      const SizedBox(height: 6),
                      
                      buildCategoryHeader(
                        title: t.logSourceCategorySystem,
                        subtitle: t.logSourceSystemSubtitle(systemTags.length),
                        tagCount: systemTags.length,
                        selectedCount: systemSelectedCount,
                        expanded: systemExpanded,
                        isAllSelected: isSystemAll,
                        onToggleExpand: () => setDialogState(() => systemExpanded = !systemExpanded),
                        onSelectAll: () {
                          setDialogState(() {
                            tempFilterSource = 'System';
                            tempFilterTags.clear();
                          });
                        },
                      ),
                      if (systemExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 20, top: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final tag in systemTags)
                                buildTagRow(tag, sourceCounts[tag] ?? 0),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              Button(
                onPressed: () {
                  setState(() {
                    _filterSource = tempFilterSource;
                    _filterTags = tempFilterTags;
                  });
                  Navigator.pop(ctx);
                },
                child: Text(t.logDialogOk),
              ),
              Button(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t.logDialogCancel),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTimeRangeDialog(BuildContext context) {
    DateTime? tempStart = _startTime;
    DateTime? tempEnd = _endTime;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => ContentDialog(
          title: Text(t.logTimeRangeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.logTimeRangeQuickSelectLabel, style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in [
                    (t.logTimeRangePreset1Hour, const Duration(hours: 1)),
                    (t.logTimeRangePreset30Min, const Duration(minutes: 30)),
                    (t.logTimeRangePreset10Min, const Duration(minutes: 10)),
                    (t.logTimeRangePreset5Min, const Duration(minutes: 5)),
                  ])
                    Button(
                      onPressed: () {
                        setDialogState(() {
                          tempStart = DateTime.now().subtract(preset.$2);
                          tempEnd = null;
                        });
                      },
                      child: Text(preset.$1),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.logTimeRangeStartLabel),
                        const SizedBox(height: 4),
                        Text(
                          tempStart?.toString().substring(0, 19) ?? t.logTimeRangeNotSet,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.logTimeRangeEndLabel),
                        const SizedBox(height: 4),
                        Text(
                          tempEnd?.toString().substring(0, 19) ?? t.logTimeRangeNow,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () {
                setDialogState(() { tempStart = null; tempEnd = null; });
              },
              child: Text(t.logDialogClear),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _startTime = tempStart;
                  _endTime = tempEnd;
                });
                Navigator.pop(ctx);
              },
              child: Text(t.logDialogApply),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegexRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => ContentDialog(
          title: Text(t.logRulesDialogTitle),
          content: SizedBox(
            width: 450,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 内置规则
                  Row(
                    children: [
                      Icon(FluentIcons.lightning_bolt, size: 14, color: AppTheme.accentLight),
                      const SizedBox(width: 6),
                      Text(t.logRulesBuiltinTitle, style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final type in _HighlightType.values.where((t) => t != _HighlightType.custom))
                        _buildBuiltinRuleChip(type, setDialogState),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: AppTheme.borderSubtle.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  // 自定义规则
                  Row(
                    children: [
                      Icon(FluentIcons.code, size: 14, color: AppTheme.accentLight),
                      const SizedBox(width: 6),
                      Text(t.logRulesCustomTitle, style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Button(
                        onPressed: () => _showAddCustomRuleDialog(ctx, setDialogState),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.add, size: 12),
                            SizedBox(width: 4),
                            Text(t.logRulesAddButton),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_customRules.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLayer2.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Center(
                        child: Text(
                          t.logRulesCustomEmpty,
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    for (int i = 0; i < _customRules.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              checked: _customRules[i].enabled,
                              onChanged: (v) {
                                setDialogState(() {
                                  _customRules[i] = _customRules[i].copyWith(enabled: v);
                                });
                                setState(() {});
                                _saveRegexRules();
                              },
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _customRules[i].highlightColor ?? AppTheme.accentLight,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _customRules[i].name,
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _customRules[i].pattern,
                                    style: TextStyle(
                                      color: AppTheme.textTertiary,
                                      fontSize: 11,
                                      fontFamily: 'Courier New',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(FluentIcons.delete, size: 14, color: AppTheme.statusError),
                              onPressed: () {
                                setDialogState(() {
                                  _customRules.removeAt(i);
                                });
                                setState(() {});
                                _saveRegexRules();
                              },
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 12),
                  // 颜色图例
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLayer1.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.logRulesLegendTitle, style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _buildLegendItem(t.logRulesLegendUrl, const Color(0xFF60CDFF)),
                            _buildLegendItem(t.logRulesLegendPath, const Color(0xFF89D185)),
                            _buildLegendItem(t.logRulesLegendIp, const Color(0xFFDCDCAA)),
                            _buildLegendItem(t.logRulesLegendNumber, const Color(0xFFB5CEA8)),
                            _buildLegendItem(t.logRulesLegendError, const Color(0xFFFF6B6B)),
                            _buildLegendItem(t.logRulesLegendSuccess, const Color(0xFF6CCB5F)),
                            _buildLegendItem(t.logRulesLegendWarning, const Color(0xFFFFB900)),
                            _buildLegendItem(t.logRulesLegendHttp, const Color(0xFF569CD6)),
                            _buildLegendItem(t.logRulesLegendStep, const Color(0xFFD4A0FF)),
                            _buildLegendItem(t.logRulesLegendPid, const Color(0xFF9CDCFE)),
                            _buildLegendItem(t.logRulesLegendKeyValue, const Color(0xFFCE9178)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Button(onPressed: () => Navigator.pop(ctx), child: Text(t.logDialogClose)),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltinRuleChip(_HighlightType type, StateSetter setDialogState) {
    final rule = _builtinRules.firstWhere((r) => r.type == type, orElse: () => _builtinRules.first);
    final enabled = _builtinRuleEnabled[type] ?? false;
    
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          _builtinRuleEnabled[type] = !enabled;
        });
        setState(() {});
        _saveBuiltinRuleStates();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? rule.color.withValues(alpha: 0.2) : AppTheme.bgLayer2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? rule.color.withValues(alpha: 0.5) : AppTheme.borderSubtle.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: enabled ? rule.color : AppTheme.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              rule.name,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? rule.color : AppTheme.textTertiary,
                fontWeight: enabled ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  void _showAddCustomRuleDialog(BuildContext parentCtx, StateSetter parentSetState) {
    final nameController = TextEditingController();
    final patternController = TextEditingController();
    Color selectedColor = AppTheme.accentLight;
    
    final colors = [
      const Color(0xFF60CDFF),
      const Color(0xFF89D185),
      const Color(0xFFDCDCAA),
      const Color(0xFFB5CEA8),
      const Color(0xFFCE9178),
      const Color(0xFFB794F6),
      const Color(0xFFFF6B6B),
      const Color(0xFF6CCB5F),
      const Color(0xFFFFB900),
      const Color(0xFF569CD6),
    ];
    
    showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => ContentDialog(
          title: Text(t.logAddRuleTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.logAddRuleNameLabel),
              const SizedBox(height: 4),
              TextBox(
                controller: nameController,
                placeholder: t.logAddRuleNamePlaceholder,
              ),
              const SizedBox(height: 12),
              Text(t.logAddRulePatternLabel),
              const SizedBox(height: 4),
              TextBox(
                controller: patternController,
                placeholder: t.logAddRulePatternPlaceholder,
                style: const TextStyle(fontFamily: 'Courier New'),
              ),
              const SizedBox(height: 12),
              Text(t.logAddRuleColorLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in colors)
                    GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                          border: selectedColor == color
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                          boxShadow: selectedColor == color
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            Button(onPressed: () => Navigator.pop(ctx), child: Text(t.logDialogCancel)),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && patternController.text.isNotEmpty) {
                  // 验证正则表达式
                  try {
                    RegExp(patternController.text);
                    parentSetState(() {
                      _customRules.add(CustomRegexRule(
                        name: nameController.text,
                        pattern: patternController.text,
                        highlightColor: selectedColor,
                      ));
                    });
                    setState(() {});
                    _saveRegexRules();
                    Navigator.pop(ctx);
                  } catch (e) {
                    // 正则无效
                    showDialog(
                      context: ctx,
                      builder: (c) => ContentDialog(
                        title: Text(t.logAddRuleInvalidTitle),
                        content: Text(t.logAddRuleInvalidMessage(e)),
                        actions: [
                          Button(onPressed: () => Navigator.pop(c), child: Text(t.logDialogOk)),
                        ],
                      ),
                    );
                  }
                }
              },
              child: Text(t.logRulesAddButton),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text(t.logArchiveTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.logArchivePrompt),
            const SizedBox(height: 12),
            Button(
              onPressed: () {
                Navigator.pop(ctx);
                _exportLogs(context);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.save, size: 16),
                  SizedBox(width: 8),
                  Text(t.logArchiveExportAll),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Button(
              onPressed: () {
                Navigator.pop(ctx);
                _exportFilteredLogs(context);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.filter, size: 16),
                  SizedBox(width: 8),
                  Text(t.logArchiveExportFiltered),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Button(
              onPressed: () {
                Navigator.pop(ctx);
                _exportBookmarkedLogs(context);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.single_bookmark, size: 16),
                  const SizedBox(width: 8),
                  Text(t.logArchiveExportBookmarked(_bookmarkedIds.length)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(onPressed: () => Navigator.pop(ctx), child: Text(t.logDialogCancel)),
        ],
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text(t.logClearConfirmTitle),
        content: Text(t.logClearConfirmMessage),
        actions: [
          Button(onPressed: () => Navigator.pop(ctx), child: Text(t.logDialogCancel)),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: () {
              context.read<AppLoggerService>().clear();
              _bookmarkedIds.clear();
              _expandedGroupIds.clear();
              Navigator.pop(ctx);
            },
            child: Text(t.logClearConfirmButton),
          ),
        ],
      ),
    );
  }

  Future<void> _exportFilteredLogs(BuildContext context) async {
    final logger = context.read<AppLoggerService>();
    var logs = logger.logs;

    if (_startTime != null) logs = logs.where((l) => l.timestamp.isAfter(_startTime!)).toList();
    if (_endTime != null) logs = logs.where((l) => l.timestamp.isBefore(_endTime!)).toList();
    if (_filterLevel != null) logs = logs.where((l) => l.level == _filterLevel).toList();
    if (_filterSource != null) {
      if (_filterSource == 'Kernel') {
        // Kernel 类别包含所有下载核心相关的来源
        logs = logs.where((l) => l.source != 'App').toList();
      } else if (_filterSource == 'App') {
        logs = logs.where((l) => l.source == 'App').toList();
      } else {
        logs = logs.where((l) => l.source == _filterSource).toList();
      }
    }
    if (_searchQuery.isNotEmpty) {
      logs = logs.where((l) => l.message.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    await _doExport(context, logs, 'filtered');
  }

  Future<void> _exportBookmarkedLogs(BuildContext context) async {
    final logger = context.read<AppLoggerService>();
    final logs = logger.logs.where((l) {
      final id = '${l.timestamp.millisecondsSinceEpoch}_${l.message.hashCode}';
      return _bookmarkedIds.contains(id);
    }).toList();

    await _doExport(context, logs, 'bookmarked');
  }

  Future<void> _doExport(BuildContext context, List<LogEntry> logs, String suffix) async {
    String initialPath = 'C:\\';
    try { initialPath = Directory.current.path; } catch (_) {}

    final selectedPath = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FolderPickerDialog(initialPath: initialPath),
    );

    if (selectedPath != null && mounted) {
      try {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
        final file = File('$selectedPath\\log_${suffix}_$timestamp.txt');
        
        final buffer = StringBuffer();
        buffer.writeln(t.logExportFileHeader(timestamp));
        buffer.writeln(t.logExportFileTotal(logs.length));
        buffer.writeln('');
        
        for (var log in logs) {
          buffer.writeln('[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}');
        }
        
        await file.writeAsString(buffer.toString());
        
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => ContentDialog(
              title: Text(t.logExportSuccessTitle),
              content: Text(t.logExportSavedCountMessage(logs.length, file.path)),
              actions: [
                Button(onPressed: () => Navigator.pop(ctx), child: Text(t.logDialogOk)),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => ContentDialog(
              title: Text(t.logExportFailedTitle),
              content: Text(t.logExportErrorMessage(e)),
              actions: [
                Button(onPressed: () => Navigator.pop(ctx), child: Text(t.logDialogOk)),
              ],
            ),
          );
        }
      }
    }
  }
}

class _HighlightMatch {
  final int start;
  final int end;
  final Color color;
  final bool isSearch;
  final _HighlightType? type;

  _HighlightMatch({
    required this.start,
    required this.end,
    required this.color,
    this.isSearch = false,
    this.type,
  });
}

/// 高亮类型枚举
enum _HighlightType {
  url,
  path,
  ip,
  number,
  id,
  error,
  success,
  warning,
  httpMethod,
  httpStatus,
  time,
  step,
  pid,
  keyValue,
  custom,
}

/// 内置高亮规则
class _BuiltinHighlightRule {
  final String name;
  final String pattern;
  final Color color;
  final _HighlightType type;
  
  const _BuiltinHighlightRule({
    required this.name,
    required this.pattern,
    required this.color,
    required this.type,
  });
}
