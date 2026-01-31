import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../services/app_logger_service.dart';
import '../../../services/client_config_service.dart';
import '../../../widgets/folder_picker_dialog.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

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
  String _searchQuery = '';
  bool _autoScroll = true;
  bool _useRegexSearch = false;
  bool _showStats = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  // 内置正则表达式（用于去重）
  final RegExp _logPrefixRegex = RegExp(r'^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2},\d{3}\s-\s.*?\s-\s[A-Z]+\s-\s');
  final RegExp _portRegex = RegExp(r'(port\s*[:=]?\s*)\d+', caseSensitive: false);
  final RegExp _threadRegex = RegExp(r'(线程|Thread\s*)\d+', caseSensitive: false);
  final RegExp _segmentRegex = RegExp(r'(分段|Segment)\s*\d+', caseSensitive: false);
  final RegExp _taskIdRegex = RegExp(r'\b[a-f0-9]{16}\b');
  
  // 内置高亮规则（始终启用）
  static final List<_BuiltinHighlightRule> _builtinRules = [
    // URL 高亮
    _BuiltinHighlightRule(
      name: 'URL',
      pattern: r'https?://[^\s<>"{}|\\^`\[\]]+',
      color: const Color(0xFF60CDFF),
      type: _HighlightType.url,
    ),
    // 文件路径 (Windows)
    _BuiltinHighlightRule(
      name: '文件路径',
      pattern: r'[A-Za-z]:\\[^\s<>"{}|*?]+',
      color: const Color(0xFF89D185),
      type: _HighlightType.path,
    ),
    // 文件路径 (Unix)
    _BuiltinHighlightRule(
      name: '文件路径',
      pattern: r'(?<!\w)/(?:[\w.-]+/)+[\w.-]+',
      color: const Color(0xFF89D185),
      type: _HighlightType.path,
    ),
    // IP 地址
    _BuiltinHighlightRule(
      name: 'IP地址',
      pattern: r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(?::\d+)?\b',
      color: const Color(0xFFDCDCAA),
      type: _HighlightType.ip,
    ),
    // 数字（带单位）
    _BuiltinHighlightRule(
      name: '数值',
      pattern: r'\b\d+(?:\.\d+)?\s*(?:KB|MB|GB|TB|B|ms|s|%)\b',
      color: const Color(0xFFB5CEA8),
      type: _HighlightType.number,
    ),
    // 任务ID / Hash
    _BuiltinHighlightRule(
      name: 'ID/Hash',
      pattern: r'\b[a-f0-9]{8,32}\b',
      color: const Color(0xFFCE9178),
      type: _HighlightType.id,
    ),
    // 错误关键词
    _BuiltinHighlightRule(
      name: '错误',
      pattern: r'\b(?:error|failed|failure|exception|错误|失败)\b',
      color: const Color(0xFFFF6B6B),
      type: _HighlightType.error,
    ),
    // 成功关键词
    _BuiltinHighlightRule(
      name: '成功',
      pattern: r'\b(?:success|completed|done|成功|完成)\b',
      color: const Color(0xFF6CCB5F),
      type: _HighlightType.success,
    ),
    // 警告关键词
    _BuiltinHighlightRule(
      name: '警告',
      pattern: r'\b(?:warning|warn|注意|警告)\b',
      color: const Color(0xFFFFB900),
      type: _HighlightType.warning,
    ),
    // HTTP 方法
    _BuiltinHighlightRule(
      name: 'HTTP方法',
      pattern: r'\b(?:GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\b',
      color: const Color(0xFF569CD6),
      type: _HighlightType.httpMethod,
    ),
    // HTTP 状态码
    _BuiltinHighlightRule(
      name: 'HTTP状态码',
      pattern: r'\b[1-5]\d{2}\b',
      color: const Color(0xFFD7BA7D),
      type: _HighlightType.httpStatus,
    ),
    // 时间戳
    _BuiltinHighlightRule(
      name: '时间',
      pattern: r'\b\d{2}:\d{2}:\d{2}(?:[.,]\d{3})?\b',
      color: const Color(0xFF9CDCFE),
      type: _HighlightType.time,
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
  };
  
  // 状态管理
  final Set<String> _expandedGroupIds = {};
  final Set<String> _bookmarkedIds = {};
  
  // 自定义正则规则（从配置加载）
  List<CustomRegexRule> _customRules = [];
  
  // 时间范围筛选
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = context.read<ClientConfigService>();
    final rules = config.getLogRegexRules();
    
    setState(() {
      _customRules = rules.map((r) => CustomRegexRule(
        name: r['name'] as String,
        pattern: r['pattern'] as String,
        enabled: r['enabled'] as bool? ?? true,
        highlightColor: Color(r['color'] as int? ?? 0xFF60CDFF),
      )).toList();
      
      _showStats = config.getLogShowStats();
      _autoScroll = config.getLogAutoScroll();
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
    return msg;
  }

  List<LogDisplayItem> _groupLogs(List<LogEntry> logs) {
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
            
            // 使用标准化后的消息进行比较
            final originalMsg = _normalizeForDedup(original.message);
            final candidateMsg = _normalizeForDedup(candidate.message);
            
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
              title: const Text('导出成功'),
              content: Text('日志已保存至:\n${file.path}'),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
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
              title: const Text('导出失败'),
              content: Text('无法保存日志: $e'),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
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
              child: const Icon(FluentIcons.text_document, size: 18, color: AppTheme.accentLight),
            ),
            const SizedBox(width: 14),
            const Text('日志'),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.filter),
              label: Text(_filterLevel == null ? '级别' : _filterLevel!.name.toUpperCase()),
              onPressed: () => _showFilterMenu(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.source),
              label: Text(_filterSource ?? '来源'),
              onPressed: () => _showSourceFilterMenu(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.clock),
              label: Text(_startTime != null || _endTime != null ? '时间 ✓' : '时间'),
              onPressed: () => _showTimeRangeDialog(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.code),
              label: const Text('正则规则'),
              onPressed: () => _showRegexRulesDialog(context),
            ),
          ],
          secondaryItems: [
            CommandBarButton(
              icon: Icon(_autoScroll ? FluentIcons.chevron_down : FluentIcons.pause),
              label: Text(_autoScroll ? '自动滚动: 开' : '自动滚动: 关'),
              onPressed: () {
                setState(() => _autoScroll = !_autoScroll);
                context.read<ClientConfigService>().setLogAutoScroll(_autoScroll);
              },
            ),
            CommandBarButton(
              icon: Icon(_showStats ? FluentIcons.chart : FluentIcons.hide3),
              label: Text(_showStats ? '统计: 显示' : '统计: 隐藏'),
              onPressed: () {
                setState(() => _showStats = !_showStats);
                context.read<ClientConfigService>().setLogShowStats(_showStats);
              },
            ),
            const CommandBarSeparator(),
            CommandBarButton(
              icon: const Icon(FluentIcons.save),
              label: const Text('导出日志'),
              onPressed: () => _exportLogs(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.archive),
              label: const Text('归档日志'),
              onPressed: () => _showArchiveDialog(context),
            ),
            const CommandBarSeparator(),
            CommandBarButton(
              icon: const Icon(FluentIcons.clear),
              label: const Text('清空日志'),
              onPressed: () => _showClearConfirmDialog(context),
            ),
          ],
        ),
      ),
      content: Consumer<AppLoggerService>(
        builder: (context, logger, child) {
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
          if (_filterSource != null) {
            if (_filterSource == 'Kernel') {
              // Kernel 类别包含所有下载核心相关的来源（Kernel, NSFX, NSFX-HTTP 等）
              logs = logs.where((log) => log.source != 'App').toList();
            } else if (_filterSource == 'App') {
              // App 只匹配精确的 App 来源
              logs = logs.where((log) => log.source == 'App').toList();
            } else {
              // 其他情况精确匹配
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

          final groupedLogs = _groupLogs(logs);
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
                        placeholder: _useRegexSearch ? '输入正则表达式...' : '搜索日志...',
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            _useRegexSearch ? FluentIcons.code : FluentIcons.search,
                            size: 14,
                            color: _searchQuery.isNotEmpty 
                              ? AppTheme.accentLight 
                              : AppTheme.textTertiary,
                          ),
                        ),
                        suffix: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(FluentIcons.clear, size: 12),
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
                            '暂无日志',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '日志将在此处显示',
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
                  _buildStatChip('总计', stats.total, AppTheme.textSecondary, isTotal: true),
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
                      '${stats.groupedCount} 组',
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
                            Text('清除', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
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

  String _formatTimeRange() {
    if (_startTime != null && _endTime != null) {
      return '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')} - ${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}';
    } else if (_startTime != null) {
      final diff = DateTime.now().difference(_startTime!);
      if (diff.inMinutes < 60) return '最近 ${diff.inMinutes} 分钟';
      return '最近 ${diff.inHours} 小时';
    }
    return '时间范围';
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
                '条',
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

  // 保留旧方法以兼容，但不再使用
  Widget _buildQuickFilters() {
    return const SizedBox.shrink();
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
                              '重复 ${item.count - 1} 次',
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
                            '... 还有 ${item.repeatedLogs!.length - 51} 条',
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
          leading: const Icon(FluentIcons.copy),
          text: const Text('复制日志'),
          onPressed: () {
            final buffer = StringBuffer();
            for (var log in item.logs) {
              buffer.writeln('[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}');
            }
            if (item.count > 1) buffer.writeln('(重复 ${item.count} 次)');
            Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
            Navigator.pop(ctx);
          },
        ),
        MenuFlyoutItem(
          leading: Icon(_bookmarkedIds.contains(item.id) 
            ? FluentIcons.single_bookmark_solid 
            : FluentIcons.single_bookmark),
          text: Text(_bookmarkedIds.contains(item.id) ? '取消书签' : '添加书签'),
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
          leading: const Icon(FluentIcons.filter),
          text: Text('筛选: ${item.primaryLog.levelString}'),
          onPressed: () {
            setState(() => _filterLevel = item.primaryLog.level);
            Navigator.pop(ctx);
          },
        ),
        MenuFlyoutItem(
          leading: const Icon(FluentIcons.source),
          text: Text('筛选: ${item.primaryLog.source}'),
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
                    leading: const Icon(FluentIcons.copy),
                    text: const Text('复制此条'),
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
        title: const Text('筛选日志级别'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              (null, '全部', AppTheme.textPrimary),
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
          Button(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _showSourceFilterMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('筛选日志来源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [(null, '全部'), ('Kernel', 'Kernel (下载核心)'), ('App', 'App (应用程序)')])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioButton(
                  checked: _filterSource == item.$1,
                  onChanged: (_) {
                    setState(() => _filterSource = item.$1);
                    Navigator.pop(ctx);
                  },
                  content: Text(item.$2),
                ),
              ),
          ],
        ),
        actions: [
          Button(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
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
          title: const Text('时间范围筛选'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('快捷选择:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in [
                    ('最近1小时', const Duration(hours: 1)),
                    ('最近30分钟', const Duration(minutes: 30)),
                    ('最近10分钟', const Duration(minutes: 10)),
                    ('最近5分钟', const Duration(minutes: 5)),
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
                        const Text('开始时间:'),
                        const SizedBox(height: 4),
                        Text(
                          tempStart?.toString().substring(0, 19) ?? '未设置',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('结束时间:'),
                        const SizedBox(height: 4),
                        Text(
                          tempEnd?.toString().substring(0, 19) ?? '现在',
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
              child: const Text('清除'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _startTime = tempStart;
                  _endTime = tempEnd;
                });
                Navigator.pop(ctx);
              },
              child: const Text('应用'),
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
          title: const Text('高亮规则管理'),
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
                      const Text('内置规则', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      const Text('自定义规则', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Button(
                        onPressed: () => _showAddCustomRuleDialog(ctx, setDialogState),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.add, size: 12),
                            SizedBox(width: 4),
                            Text('添加'),
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
                          '暂无自定义规则',
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
                        Text('颜色图例', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _buildLegendItem('URL', const Color(0xFF60CDFF)),
                            _buildLegendItem('路径', const Color(0xFF89D185)),
                            _buildLegendItem('IP', const Color(0xFFDCDCAA)),
                            _buildLegendItem('数值', const Color(0xFFB5CEA8)),
                            _buildLegendItem('错误', const Color(0xFFFF6B6B)),
                            _buildLegendItem('成功', const Color(0xFF6CCB5F)),
                            _buildLegendItem('警告', const Color(0xFFFFB900)),
                            _buildLegendItem('HTTP', const Color(0xFF569CD6)),
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
            Button(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
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
          title: const Text('添加自定义规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('规则名称'),
              const SizedBox(height: 4),
              TextBox(
                controller: nameController,
                placeholder: '例如: 任务ID',
              ),
              const SizedBox(height: 12),
              const Text('正则表达式'),
              const SizedBox(height: 4),
              TextBox(
                controller: patternController,
                placeholder: r'例如: \b[a-f0-9]{16}\b',
                style: const TextStyle(fontFamily: 'Courier New'),
              ),
              const SizedBox(height: 12),
              const Text('高亮颜色'),
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
            Button(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
                        title: const Text('正则表达式无效'),
                        content: Text('错误: $e'),
                        actions: [
                          Button(onPressed: () => Navigator.pop(c), child: const Text('确定')),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('添加'),
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
        title: const Text('归档日志'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择归档选项:'),
            const SizedBox(height: 12),
            Button(
              onPressed: () {
                Navigator.pop(ctx);
                _exportLogs(context);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.save, size: 16),
                  SizedBox(width: 8),
                  Text('导出全部日志'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Button(
              onPressed: () {
                Navigator.pop(ctx);
                _exportFilteredLogs(context);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.filter, size: 16),
                  SizedBox(width: 8),
                  Text('导出当前筛选结果'),
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
                  const Icon(FluentIcons.single_bookmark, size: 16),
                  const SizedBox(width: 8),
                  Text('导出书签日志 (${_bookmarkedIds.length})'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有日志吗？此操作不可撤销。'),
        actions: [
          Button(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
            child: const Text('清空'),
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
        buffer.writeln('# 日志导出 - $timestamp');
        buffer.writeln('# 总计: ${logs.length} 条');
        buffer.writeln('');
        
        for (var log in logs) {
          buffer.writeln('[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}');
        }
        
        await file.writeAsString(buffer.toString());
        
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => ContentDialog(
              title: const Text('导出成功'),
              content: Text('已保存 ${logs.length} 条日志至:\n${file.path}'),
              actions: [
                Button(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => ContentDialog(
              title: const Text('导出失败'),
              content: Text('错误: $e'),
              actions: [
                Button(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
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
