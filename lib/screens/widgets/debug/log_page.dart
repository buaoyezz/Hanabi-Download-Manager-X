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
  
  // 内置正则表达式
  final RegExp _logPrefixRegex = RegExp(r'^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2},\d{3}\s-\s.*?\s-\s[A-Z]+\s-\s');
  final RegExp _portRegex = RegExp(r'(port\s*[:=]?\s*)\d+', caseSensitive: false);
  final RegExp _threadRegex = RegExp(r'(线程|Thread\s*)\d+', caseSensitive: false);
  final RegExp _segmentRegex = RegExp(r'(分段|Segment)\s*\d+', caseSensitive: false);
  final RegExp _taskIdRegex = RegExp(r'\b[a-f0-9]{16}\b');
  
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
            logs = logs.where((log) => log.source == _filterSource).toList();
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
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(
                            _useRegexSearch ? FluentIcons.code : FluentIcons.search,
                            size: 16,
                            color: _useRegexSearch ? AppTheme.accentPrimary : null,
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('.*'),
                      ),
                    ),
                  ],
                ),
              ),

              // 统计栏
              if (_showStats) _buildStatsBar(stats),

              // 快捷筛选标签
              _buildQuickFilters(),

              // 日志列表
              Expanded(
                child: logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.document, size: 48, color: AppTheme.textTertiary),
                          const SizedBox(height: 12),
                          Text('暂无日志', style: TextStyle(color: AppTheme.textSecondary)),
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

  Widget _buildStatsBar(LogStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildStatItem('总计', stats.total, AppTheme.textPrimary),
            _buildStatDivider(),
            _buildStatItem('DEBUG', stats.debug, const Color(0xFFB794F6)), // 淡紫色
            _buildStatDivider(),
            _buildStatItem('INFO', stats.info, Colors.blue),
            _buildStatDivider(),
            _buildStatItem('WARN', stats.warning, Colors.orange),
            _buildStatDivider(),
            _buildStatItem('ERROR', stats.error, Colors.red),
            const Spacer(),
            Text(
              '已归档 ${stats.groupedCount} 组',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return GestureDetector(
      onTap: () {
        if (label == '总计') {
          setState(() => _filterLevel = null);
        } else {
          final level = {
            'DEBUG': LogLevel.debug,
            'INFO': LogLevel.info,
            'WARN': LogLevel.warning,
            'ERROR': LogLevel.error,
          }[label];
          setState(() => _filterLevel = _filterLevel == level ? null : level);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier New',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.borderSubtle,
    );
  }

  Widget _buildQuickFilters() {
    final hasActiveFilters = _filterLevel != null || _filterSource != null || 
                             _startTime != null || _endTime != null || 
                             _bookmarkedIds.isNotEmpty;
    
    if (!hasActiveFilters) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (_filterLevel != null)
            _buildFilterChip(
              '级别: ${_filterLevel!.name.toUpperCase()}',
              () => setState(() => _filterLevel = null),
            ),
          if (_filterSource != null)
            _buildFilterChip(
              '来源: $_filterSource',
              () => setState(() => _filterSource = null),
            ),
          if (_startTime != null || _endTime != null)
            _buildFilterChip(
              '时间范围',
              () => setState(() { _startTime = null; _endTime = null; }),
            ),
          if (hasActiveFilters)
            Button(
              onPressed: () => setState(() {
                _filterLevel = null;
                _filterSource = null;
                _startTime = null;
                _endTime = null;
              }),
              child: const Text('清除全部'),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(FluentIcons.chrome_close, size: 10),
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
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isBookmarked 
                ? AppTheme.statusWarning.withValues(alpha: 0.5)
                : AppTheme.borderSubtle.withValues(alpha: 0.5),
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
                      height: 40,
                      decoration: BoxDecoration(
                        color: levelColor,
                        borderRadius: BorderRadius.circular(2),
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
                      children: [
                        // 书签按钮
                        IconButton(
                          icon: Icon(
                            isBookmarked ? FluentIcons.single_bookmark_solid : FluentIcons.single_bookmark,
                            size: 14,
                            color: isBookmarked ? AppTheme.statusWarning : AppTheme.textTertiary,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accentPrimary.withValues(alpha: 0.2),
                                    AppTheme.accentPrimary.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.isExpanded ? FluentIcons.chevron_up : FluentIcons.chevron_down,
                                    size: 10,
                                    color: AppTheme.accentLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'x${item.count}',
                                    style: const TextStyle(
                                      color: AppTheme.accentLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
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
                    color: AppTheme.bgLayer1.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.radiusMd),
                      bottomRight: Radius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '重复日志 (${item.count - 1} 条)',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      for (int k = 1; k < item.repeatedLogs!.length && k <= 50; k++)
                        for (var log in item.repeatedLogs![k])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildSingleLogRow(context, log, isExpandedItem: true),
                          ),
                      if (item.repeatedLogs!.length > 51)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '... 还有 ${item.repeatedLogs!.length - 51} 条',
                            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
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
    // 收集所有启用的规则的匹配
    final List<_HighlightMatch> matches = [];
    
    for (final rule in _customRules.where((r) => r.enabled)) {
      try {
        final regex = RegExp(rule.pattern, caseSensitive: false);
        for (final match in regex.allMatches(message)) {
          matches.add(_HighlightMatch(
            start: match.start,
            end: match.end,
            color: rule.highlightColor ?? AppTheme.accentLight,
          ));
        }
      } catch (_) {}
    }

    // 搜索高亮
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

    // 按位置排序并合并重叠
    matches.sort((a, b) => a.start.compareTo(b.start));
    
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
      
      spans.add(TextSpan(
        text: message.substring(match.start, match.end),
        style: TextStyle(
          color: match.isSearch ? Colors.black : match.color,
          backgroundColor: match.isSearch 
            ? match.color.withValues(alpha: 0.8)
            : match.color.withValues(alpha: 0.2),
          fontWeight: match.isSearch ? FontWeight.bold : null,
        ),
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
          title: const Text('正则高亮规则'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _customRules.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _customRules[i].highlightColor ?? AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_customRules[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '提示: 启用的规则会在日志消息中高亮匹配的内容\n配置已自动保存到 ~/.hdmx/config/client_config.json',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            Button(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
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
    if (_filterSource != null) logs = logs.where((l) => l.source == _filterSource).toList();
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

  _HighlightMatch({
    required this.start,
    required this.end,
    required this.color,
    this.isSearch = false,
  });
}
