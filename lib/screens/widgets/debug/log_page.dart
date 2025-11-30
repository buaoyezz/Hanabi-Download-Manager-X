import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../services/app_logger_service.dart';
import '../../../widgets/folder_picker_dialog.dart';

class LogDisplayItem {
  final List<LogEntry> logs; // 这里的 logs 是模式 (pattern)
  final List<List<LogEntry>>? repeatedLogs; // 存储所有重复的日志组 (包括第一次)
  int count;
  bool isExpanded;

  LogDisplayItem(this.logs, {
    this.count = 1, 
    this.isExpanded = false,
    this.repeatedLogs,
  });
  
  LogEntry get primaryLog => logs.first;
  
  // 生成唯一ID用于状态保持
  String get id => '${primaryLog.timestamp.millisecondsSinceEpoch}_${primaryLog.message.hashCode}';
}

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  LogLevel? _filterLevel;
  String? _filterSource; // null = 全部, 'Kernel' = 内核, 'App' = 应用
  String _searchQuery = '';
  bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();
  
  // 正则表达式用于匹配和移除日志前缀 (YYYY-MM-DD HH:mm:ss,SSS - Source - LEVEL - )
  final RegExp _logPrefixRegex = RegExp(r'^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2},\d{3}\s-\s.*?\s-\s[A-Z]+\s-\s');
  // 正则表达式用于匹配端口号 (例如 port = 12345, port: 12345) 
  final RegExp _portRegex = RegExp(r'(port\s*[:=]?\s*)\d+', caseSensitive: false);
  // 记录已展开的日志组ID
  final Set<String> _expandedGroupIds = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    return msg.replaceAll(_portRegex, r'\1<PORT>');
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FluentTheme.of(context).accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                FluentIcons.text_document,
                size: 16,
                color: FluentTheme.of(context).accentColor,
              ),
            ),
            const SizedBox(width: 12),
            const Text('日志'),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.filter),
              label: Text(_filterLevel == null ? '级别:全部' : '级别:${_filterLevel!.name.toUpperCase()}'),
              onPressed: () => _showFilterMenu(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.source),
              label: Text(_filterSource == null ? '来源:全部' : '来源:$_filterSource'),
              onPressed: () => _showSourceFilterMenu(context),
            ),
            CommandBarButton(
              icon: Icon(_autoScroll ? FluentIcons.chevron_down : FluentIcons.pause),
              label: Text(_autoScroll ? '自动滚动' : '已暂停'),
              onPressed: () {
                setState(() {
                  _autoScroll = !_autoScroll;
                });
              },
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.save),
              label: const Text('导出'),
              onPressed: () => _exportLogs(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.clear),
              label: const Text('清空'),
              onPressed: () {
                context.read<AppLoggerService>().clear();
              },
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextBox(
              placeholder: '搜索日志...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(FluentIcons.search, size: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // 日志列表
          Expanded(
            child: Consumer<AppLoggerService>(
              builder: (context, logger, child) {
                var logs = logger.logs;

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
                  logs = logs.where((log) {
                    return log.message.toLowerCase().contains(_searchQuery) ||
                        log.source.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (logs.isEmpty) {
                  return const Center(
                    child: Text('暂无日志'),
                  );
                }

                final groupedLogs = _groupLogs(logs);

                // 自动滚动到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groupedLogs.length,
                  itemBuilder: (context, index) {
                    final item = groupedLogs[index];
                    return _buildLogEntry(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(BuildContext context, LogDisplayItem item) {
    final controller = FlyoutController();

    return FlyoutTarget(
      controller: controller,
      child: GestureDetector(
        onSecondaryTapUp: (details) {
          controller.showFlyout(
            position: details.globalPosition,
            builder: (context) {
              return MenuFlyout(
                items: [
                  MenuFlyoutItem(
                    leading: const Icon(FluentIcons.copy),
                    text: const Text('复制日志'),
                    onPressed: () {
                      final buffer = StringBuffer();
                      for (var log in item.logs) {
                        buffer.write('[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}');
                        if (item.count > 1) {
                          buffer.write(' (x${item.count})');
                        }
                        buffer.writeln();
                      }
                      Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < item.logs.length; i++) ...[
                    if (i > 0) 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Divider(
                          style: DividerThemeData(
                            horizontalMargin: const EdgeInsets.symmetric(horizontal: 0),
                            thickness: 1,
                            decoration: BoxDecoration(
                              color: FluentTheme.of(context).resources.dividerStrokeColorDefault.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    _buildSingleLogRow(context, item.logs[i]),
                  ],
                  
                  // 展开的重复日志列表
                  if (item.isExpanded && item.count > 1) ...[
                    const SizedBox(height: 8),
                    Divider(
                      style: DividerThemeData(
                        horizontalMargin: const EdgeInsets.symmetric(horizontal: 0),
                        thickness: 1,
                        decoration: BoxDecoration(
                          color: FluentTheme.of(context).resources.dividerStrokeColorDefault.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 这里我们需要生成所有重复的日志
                    // item.logs 是模式 (pattern)，重复了 item.count 次
                    // 我们已经显示了一次 pattern，所以还要显示 count - 1 次
                    // 为了性能，如果 count 很大，我们只显示前 50 条或者分页？
                    // 用户要求 "展开看被缩起来的重复日志"，假设数量不是无限大
                    // 但为了安全，我们使用 ListView 或者简单的 Column
                    // 注意：这里是在 ListView item 内部，嵌套 ListView 会有问题，除非 shrinkWrap
                    // 但最好直接用 Column
                    
                    // 由于 pattern 可能包含多行，我们需要循环
                    if (item.repeatedLogs != null)
                      for (int k = 1; k < item.repeatedLogs!.length; k++) ...[
                         // 跳过第0组（因为已经显示在主条目了）
                         // 显示第 k 组日志
                         for (var log in item.repeatedLogs![k]) ...[
                           _buildSingleLogRow(context, log, isExpandedItem: true),
                           const SizedBox(height: 4),
                         ]
                      ],
                  ],
                ],
              ),
              
              // 重复次数计数 (显示在右上角)
              if (item.count > 1)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 展开/收起按钮
                      IconButton(
                        icon: Icon(
                          item.isExpanded ? FluentIcons.chevron_up : FluentIcons.chevron_down,
                          size: 12,
                          color: FluentTheme.of(context).accentColor,
                        ),
                        onPressed: () {
                          setState(() {
                            if (item.isExpanded) {
                              _expandedGroupIds.remove(item.id);
                            } else {
                              _expandedGroupIds.add(item.id);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FluentTheme.of(context).accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FluentTheme.of(context).accentColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'x${item.count}',
                          style: TextStyle(
                            color: FluentTheme.of(context).accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier New',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleLogRow(BuildContext context, LogEntry log, {bool isExpandedItem = false}) {
    Color levelColor;
    IconData levelIcon;

    switch (log.level) {
      case LogLevel.debug:
        levelColor = Colors.grey;
        levelIcon = FluentIcons.info;
        break;
      case LogLevel.info:
        levelColor = Colors.blue;
        levelIcon = FluentIcons.info;
        break;
      case LogLevel.warning:
        levelColor = Colors.orange;
        levelIcon = FluentIcons.warning;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        levelIcon = FluentIcons.error_badge;
        break;
    }
    
    // 使用标准化后的消息进行显示
    final displayMessage = _stripLogPrefix(log.message);

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间
        SizedBox(
          width: 70,
          child: Text(
            log.formattedTime,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: Colors.white.withOpacity(isExpandedItem ? 0.3 : 0.5),
                  fontFamily: 'Courier New',
                ),
          ),
        ),
        const SizedBox(width: 12),

        // 级别图标
        Icon(
          levelIcon,
          size: 16,
          color: isExpandedItem ? levelColor.withOpacity(0.7) : levelColor,
        ),
        const SizedBox(width: 8),

        // 级别文本
        SizedBox(
          width: 60,
          child: Text(
            log.levelString,
            style: TextStyle(
              color: isExpandedItem ? levelColor.withOpacity(0.7) : levelColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'Courier New',
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 来源
        SizedBox(
          width: 120,
          child: Text(
            log.source,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: Colors.white.withOpacity(isExpandedItem ? 0.5 : 0.7),
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),

        // 消息
        Expanded(
          child: Text(
            displayMessage,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: isExpandedItem ? FluentTheme.of(context).typography.body?.color?.withOpacity(0.8) : null,
            ),
          ),
        ),
      ],
    );

    // 为展开的子项添加独立的右键复制菜单
    if (isExpandedItem) {
      final controller = FlyoutController();
      return FlyoutTarget(
        controller: controller,
        child: GestureDetector(
          onSecondaryTapUp: (details) {
            controller.showFlyout(
              position: details.globalPosition,
              builder: (context) {
                return MenuFlyout(
                  items: [
                    MenuFlyoutItem(
                      leading: const Icon(FluentIcons.copy),
                      text: const Text('复制此条日志'),
                      onPressed: () {
                        final text = '[${log.formattedTime}] [${log.levelString}] [${log.source}] ${log.message}';
                        Clipboard.setData(ClipboardData(text: text));
                        Navigator.pop(context);
                      },
                    ),
                  ],
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            color: Colors.transparent, // 确保点击区域有效
            child: content,
          ),
        ),
      );
    }

    return content;
  }

  void _showFilterMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('筛选日志级别'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioButton(
              checked: _filterLevel == null,
              onChanged: (value) {
                setState(() {
                  _filterLevel = null;
                });
                Navigator.pop(context);
              },
              content: const Text('全部'),
            ),
            const SizedBox(height: 8),
            RadioButton(
              checked: _filterLevel == LogLevel.debug,
              onChanged: (value) {
                setState(() {
                  _filterLevel = LogLevel.debug;
                });
                Navigator.pop(context);
              },
              content: const Text('DEBUG'),
            ),
            const SizedBox(height: 8),
            RadioButton(
              checked: _filterLevel == LogLevel.info,
              onChanged: (value) {
                setState(() {
                  _filterLevel = LogLevel.info;
                });
                Navigator.pop(context);
              },
              content: const Text('INFO'),
            ),
            const SizedBox(height: 8),
            RadioButton(
              checked: _filterLevel == LogLevel.warning,
              onChanged: (value) {
                setState(() {
                  _filterLevel = LogLevel.warning;
                });
                Navigator.pop(context);
              },
              content: const Text('WARNING'),
            ),
            const SizedBox(height: 8),
            RadioButton(
              checked: _filterLevel == LogLevel.error,
              onChanged: (value) {
                setState(() {
                  _filterLevel = LogLevel.error;
                });
                Navigator.pop(context);
              },
              content: const Text('ERROR'),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showSourceFilterMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('筛选日志来源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioButton(
              checked: _filterSource == null,
              onChanged: (value) {
                setState(() {
                  _filterSource = null;
                });
                Navigator.pop(context);
              },
              content: const Text('全部'),
            ),
            const SizedBox(height: 8),
            RadioButton(
              checked: _filterSource == 'Kernel',
              onChanged: (value) {
                setState(() {
                  _filterSource = 'Kernel';
                });
                Navigator.pop(context);
              },
              content: const Text('Kernel (下载核心)'),
            ),
            const SizedBox(height: 8),
            RadioButton(
              checked: _filterSource == 'App',
              onChanged: (value) {
                setState(() {
                  _filterSource = 'App';
                });
                Navigator.pop(context);
              },
              content: const Text('App (应用程序)'),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
