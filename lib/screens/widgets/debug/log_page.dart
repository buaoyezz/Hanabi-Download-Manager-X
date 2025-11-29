import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../../services/app_logger_service.dart';

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

                // 自动滚动到底部
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogEntry(context, log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(BuildContext context, LogEntry log) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: FluentTheme.of(context).resources.cardStrokeColorDefault,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间
          SizedBox(
            width: 70,
            child: Text(
              log.formattedTime,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'Courier New',
                  ),
            ),
          ),
          const SizedBox(width: 12),

          // 级别图标
          Icon(
            levelIcon,
            size: 16,
            color: levelColor,
          ),
          const SizedBox(width: 8),

          // 级别文本
          SizedBox(
            width: 60,
            child: Text(
              log.levelString,
              style: TextStyle(
                color: levelColor,
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
                    color: Colors.white.withOpacity(0.7),
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // 消息
          Expanded(
            child: Text(
              log.message,
              style: FluentTheme.of(context).typography.body,
            ),
          ),
        ],
      ),
    );
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
