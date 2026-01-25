import 'dart:io';
import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';
import '../../services/client_config_service.dart';
import '../../models/download_task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/file_icon_widget.dart';
import '../../widgets/animated_card.dart';

// 自定义分类
class CustomCategory {
  final String name;
  final List<String> extensions;

  CustomCategory({
    required this.name,
    required this.extensions,
  });

  bool matches(String fileName) {
    final ext = fileName.toLowerCase().substring(fileName.lastIndexOf('.'));
    return extensions.contains(ext);
  }
}

// 文件类型枚举
enum FileCategory {
  all('所有下载', FluentIcons.folder, []),
  video('视频', FluentIcons.video, ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg']),
  audio('音频', FluentIcons.music_note, ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a', '.ape']),
  archive('压缩包', FluentIcons.archive, ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.iso']),
  document('文档', FluentIcons.document, ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.md', '.rtf']),
  program('程序', FluentIcons.app_icon_default, ['.exe', '.msi', '.apk', '.dmg', '.deb', '.rpm', '.appimage']),
  other('杂项', FluentIcons.more, []);

  final String label;
  final IconData icon;
  final List<String> extensions;

  const FileCategory(this.label, this.icon, this.extensions);

  static FileCategory fromFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    
    // 如果没有扩展名或扩展名在开头，返回 other
    if (dotIndex == -1 || dotIndex == 0 || dotIndex == fileName.length - 1) {
      return FileCategory.other;
    }
    
    final ext = fileName.toLowerCase().substring(dotIndex);
    
    for (final category in FileCategory.values) {
      if (category == FileCategory.all || category == FileCategory.other) continue;
      if (category.extensions.contains(ext)) {
        return category;
      }
    }
    
    return FileCategory.other;
  }
}

class CompletedList extends StatefulWidget {
  const CompletedList({super.key});

  @override
  State<CompletedList> createState() => _CompletedListState();
}

class _CompletedListState extends State<CompletedList> {
  int _currentTabIndex = 0;
  List<CustomCategory> _customCategories = [];
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCustomCategories() {
    final configService = context.read<ClientConfigService>();
    final categoriesData = configService.getCustomCategories();
    setState(() {
      _customCategories = categoriesData.map((data) {
        return CustomCategory(
          name: data['name'] as String,
          extensions: (data['extensions'] as List).cast<String>(),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Consumer<IntegratedDownloadService>(
        builder: (context, downloadService, child) {
          final completedTasks = downloadService.tasks
              .where((t) => t.status == DownloadStatus.completed)
              .toList();

          // 按完成时间排序，最新的在前面
          completedTasks.sort((a, b) {
            if (a.endTime == null && b.endTime == null) return 0;
            if (a.endTime == null) return 1;
            if (b.endTime == null) return -1;
            return b.endTime!.compareTo(a.endTime!);
          });

          if (completedTasks.isEmpty) {
            return _buildEmptyState(context);
          }

          // 按预定义类型分组
          final tasksByCategory = <FileCategory, List<DownloadTask>>{};
          for (final task in completedTasks) {
            final category = FileCategory.fromFileName(task.fileName);
            tasksByCategory.putIfAbsent(category, () => []).add(task);
          }

          // 按自定义类型分组
          final customTasksByIndex = <int, List<DownloadTask>>{};
          for (var i = 0; i < _customCategories.length; i++) {
            final category = _customCategories[i];
            final tasks = completedTasks.where((task) => category.matches(task.fileName)).toList();
            if (tasks.isNotEmpty) {
              customTasksByIndex[i] = tasks;
            }
          }

          // 构建标签列表（只包含有文件的分类）
          final tabs = <FileCategory>[FileCategory.all];
          for (final category in FileCategory.values) {
            if (category != FileCategory.all && tasksByCategory.containsKey(category)) {
              tabs.add(category);
            }
          }

          // 确保当前索引有效
          final totalTabs = tabs.length + _customCategories.length;
          if (_currentTabIndex >= totalTabs) {
            _currentTabIndex = 0;
          }

          // 获取当前显示的任务列表
          List<DownloadTask> currentTasks;
          if (_currentTabIndex < tabs.length) {
            // 预定义分类
            final currentCategory = tabs[_currentTabIndex];
            currentTasks = currentCategory == FileCategory.all
                ? completedTasks
                : (tasksByCategory[currentCategory] ?? []);
          } else {
            // 自定义分类
            final customIndex = _currentTabIndex - tabs.length;
            currentTasks = customTasksByIndex[customIndex] ?? [];
          }

          // 应用搜索过滤
          if (_searchQuery.isNotEmpty) {
            currentTasks = currentTasks.where((t) => 
              t.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.url.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
          }

          return Column(
            children: [
              _buildHeader(context, completedTasks.length),
              _buildTabBar(context, tabs, tasksByCategory, customTasksByIndex, completedTasks.length),
              Expanded(
                child: currentTasks.isEmpty
                    ? _buildNoResultsState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: currentTasks.length,
                        itemBuilder: (context, index) {
                          final task = currentTasks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CompletedTaskCard(task: task),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    if (!_showSearch) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.search, size: 14, color: AppTheme.accentLight),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _searchController,
              placeholder: '搜索已完成的文件...',
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: WidgetStateProperty.all(const BoxDecoration()),
              style: FluentTheme.of(context).typography.body?.copyWith(fontSize: 13),
              autofocus: true,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(FluentIcons.clear, size: 12),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
              ),
            ),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 14),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _showSearch = false;
                _searchQuery = '';
              });
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.search_issue,
            size: 64,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配的文件',
            style: FluentTheme.of(context).typography.subtitle?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试修改搜索条件',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(
    BuildContext context,
    List<FileCategory> tabs,
    Map<FileCategory, List<DownloadTask>> tasksByCategory,
    Map<int, List<DownloadTask>> customTasksByIndex,
    int totalCount,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 预定义分类
                      ...tabs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value;
                        final count = category == FileCategory.all
                            ? totalCount
                            : (tasksByCategory[category]?.length ?? 0);
                        final isSelected = _currentTabIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _TabButton(
                            icon: category.icon,
                            label: category.label,
                            count: count,
                            isSelected: isSelected,
                            onTap: () => setState(() => _currentTabIndex = index),
                          ),
                        );
                      }),
                      // 自定义分类
                      ..._customCategories.asMap().entries.map((entry) {
                        final customIndex = entry.key;
                        final category = entry.value;
                        final tabIndex = tabs.length + customIndex;
                        final count = customTasksByIndex[customIndex]?.length ?? 0;
                        final isSelected = _currentTabIndex == tabIndex;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _CustomTabButton(
                            icon: FluentIcons.tag,
                            label: category.name,
                            count: count,
                            isSelected: isSelected,
                            onTap: () => setState(() => _currentTabIndex = tabIndex),
                            onDelete: () => _deleteCustomCategory(customIndex),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 搜索按钮
              IconButton(
                icon: Icon(
                  _showSearch ? FluentIcons.search : FluentIcons.search,
                  size: 14,
                  color: _showSearch ? AppTheme.accentLight : AppTheme.textSecondary,
                ),
                onPressed: () => setState(() => _showSearch = !_showSearch),
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(const EdgeInsets.all(8)),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (_showSearch) {
                      return AppTheme.accentPrimary.withValues(alpha: 0.1);
                    }
                    if (states.isHovered) {
                      return AppTheme.bgLayer2.withValues(alpha: 0.5);
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
              const SizedBox(width: 4),
              // 新建自定义分类按钮
              IconButton(
                icon: const Icon(FluentIcons.add, size: 14, color: AppTheme.textSecondary),
                onPressed: _showCreateCategoryDialog,
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(const EdgeInsets.all(8)),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.isHovered) {
                      return AppTheme.bgLayer2.withValues(alpha: 0.5);
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
            ],
          ),
        ),
        // 搜索栏（展开时显示）
        if (_showSearch) _buildSearchBar(context),
      ],
    );
  }

  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();
    final extensionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('创建自定义分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('分类名称'),
            const SizedBox(height: 8),
            TextBox(
              controller: nameController,
              placeholder: '例如：图片',
            ),
            const SizedBox(height: 16),
            const Text('文件扩展名'),
            const SizedBox(height: 8),
            TextBox(
              controller: extensionsController,
              placeholder: '例如：.jpg,.png,.gif（用逗号分隔）',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Text(
                '提示：扩展名需要包含点号，多个扩展名用逗号分隔',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final extensionsText = extensionsController.text.trim();
              
              if (name.isEmpty || extensionsText.isEmpty) {
                displayInfoBar(
                  context,
                  builder: (context, close) => const InfoBar(
                    title: Text('输入错误'),
                    content: Text('请填写完整信息'),
                    severity: InfoBarSeverity.warning,
                  ),
                );
                return;
              }

              final extensions = extensionsText
                  .split(',')
                  .map((e) => e.trim().toLowerCase())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (extensions.isEmpty) {
                displayInfoBar(
                  context,
                  builder: (context, close) => const InfoBar(
                    title: Text('输入错误'),
                    content: Text('请输入有效的扩展名'),
                    severity: InfoBarSeverity.warning,
                  ),
                );
                return;
              }

              // 保存自定义分类到配置
              final configService = context.read<ClientConfigService>();
              await configService.addCustomCategory(name, extensions);
              
              // 重新加载分类
              _loadCustomCategories();
              
              Navigator.pop(context);
              
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('创建成功'),
                  content: Text('已创建分类：$name'),
                  severity: InfoBarSeverity.success,
                ),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomCategory(int index) {
    final category = _customCategories[index];
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除自定义分类 "${category.name}" 吗？'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: () async {
              final configService = context.read<ClientConfigService>();
              await configService.removeCustomCategory(index);
              
              // 重新加载分类
              _loadCustomCategories();
              
              // 如果当前选中的是被删除的分类，切换到"所有下载"
              final totalPredefinedTabs = FileCategory.values.length;
              if (_currentTabIndex >= totalPredefinedTabs) {
                final customIndex = _currentTabIndex - totalPredefinedTabs;
                if (customIndex >= index) {
                  setState(() => _currentTabIndex = 0);
                }
              }
              
              Navigator.pop(context);
              
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('删除成功'),
                  content: Text('已删除分类：${category.name}'),
                  severity: InfoBarSeverity.success,
                ),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.statusSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              FluentIcons.completed,
              size: 14,
              color: AppTheme.statusSuccess,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '已完成',
            style: FluentTheme.of(context).typography.body?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.statusSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            ),
            child: Text(
              '$count',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.statusSuccess,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          Button(
            onPressed: () async {
              final folder = Directory("${Platform.environment['USERPROFILE']}\\Downloads").path;
              final target = folder.replaceAll('/', '\\');
              await Process.run('explorer', [target]);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.folder_open, size: 12),
                SizedBox(width: 6),
                Text('打开文件夹', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.statusSuccess.withValues(alpha: 0.3 * value),
                          blurRadius: 60 * value,
                          spreadRadius: 10 * value,
                        ),
                      ],
                    ),
                    child: Icon(
                      FluentIcons.completed,
                      size: 40,
                      color: AppTheme.statusSuccess.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: Text(
                      '暂无已完成任务',
                      style: FluentTheme.of(context).typography.subtitle?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: Text(
                      '完成的下载任务将显示在这里',
                      style: FluentTheme.of(context).typography.body?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
      ),
    );
  }
}

class _CompletedTaskCard extends StatefulWidget {
  final DownloadTask task;

  const _CompletedTaskCard({required this.task});

  @override
  State<_CompletedTaskCard> createState() => _CompletedTaskCardState();
}

class _CompletedTaskCardState extends State<_CompletedTaskCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<IntegratedDownloadService>();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.85),
      hoverColor: AppTheme.surfaceCard.withValues(alpha: 0.95),
      borderColor: AppTheme.borderSubtle,
      hoverBorderColor: AppTheme.statusSuccess.withValues(alpha: 0.4),
      borderRadius: AppTheme.radiusLg,
      enableGlowAnimation: true,
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 14),
              Expanded(child: _buildTaskInfo()),
              const SizedBox(width: 12),
              _buildActions(downloadService),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildStatistics(),
            ),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                FluentIcons.chart,
                size: 14,
                color: AppTheme.accentPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                '下载统计',
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatsGrid(),
        ],
      ),
    );
  }
  
  Widget _buildStatsGrid() {
    final stats = [
      // 第一行：重要统计
      _StatItem(
        icon: FluentIcons.speed_high,
        label: '峰值速度',
        value: widget.task.formattedPeakSpeed,
        color: AppTheme.statusSuccess,
      ),
      _StatItem(
        icon: FluentIcons.timeline_progress,
        label: '平均速度',
        value: widget.task.formattedAverageSpeed,
        color: AppTheme.accentPrimary,
      ),
      _StatItem(
        icon: FluentIcons.clock,
        label: '用时',
        value: widget.task.formattedDuration,
        color: AppTheme.statusWarning,
      ),
      // 第二行：详细信息
      _StatItem(
        icon: FluentIcons.split,
        label: '分段数',
        value: '${widget.task.segmentCount ?? 0}',
        color: AppTheme.textSecondary,
      ),
      _StatItem(
        icon: FluentIcons.processing,
        label: '线程数',
        value: '${widget.task.threadCount ?? 0}',
        color: AppTheme.textSecondary,
      ),
      _StatItem(
        icon: FluentIcons.server,
        label: '下载核心',
        value: widget.task.downloadCore ?? 'NSF-X',
        color: AppTheme.textSecondary,
      ),
    ];
    
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats,
    );
  }

  Widget _buildStatusIcon() {
    // 使用系统文件图标组件
    return FileIconWidget(
      fileName: widget.task.fileName,
      filePath: widget.task.filePath,
      size: 32,
    );
  }

  Widget _buildTaskInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.task.fileName,
          style: FluentTheme.of(context).typography.body?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              FluentIcons.check_mark,
              size: 10,
              color: AppTheme.statusSuccess,
            ),
            const SizedBox(width: 4),
            Text(
              widget.task.formattedFileSize,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            if (widget.task.endTime != null) ...[
              Container(
                width: 1,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppTheme.borderSubtle,
              ),
              Text(
                _formatDate(widget.task.endTime!),
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActions(IntegratedDownloadService service) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: FluentIcons.play,
          label: '运行',
          color: AppTheme.accentPrimary,
          onPressed: () => _runFile(widget.task.filePath),
        ),
        const SizedBox(width: 6),
        _ActionButton(
          icon: FluentIcons.folder_open,
          label: '位置',
          color: AppTheme.textSecondary,
          onPressed: () => _openFileLocation(widget.task.filePath),
        ),
        const SizedBox(width: 6),
        _IconActionButton(
          icon: _isExpanded ? FluentIcons.chevron_up : FluentIcons.chevron_down,
          color: AppTheme.textSecondary,
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
        ),
        const SizedBox(width: 6),
        _IconActionButton(
          icon: FluentIcons.delete,
          color: AppTheme.statusError,
          onPressed: () => _confirmDelete(service),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    
    return '${date.month}/${date.day}';
  }

  void _runFile(String? filePath) async {
    if (filePath == null) {
      _showMessage('文件路径不存在');
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showMessage('文件不存在');
        return;
      }

      final safePath = filePath.replaceAll('/', '\\');
      await Process.start('cmd', ['/c', 'start', '', safePath], runInShell: true);
    } catch (e) {
      _showMessage('运行文件失败: $e');
    }
  }

  void _openFileLocation(String? filePath) async {
    if (filePath == null) {
      _showMessage('文件路径不存在');
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showMessage('文件不存在');
        return;
      }

      final safePath = filePath.replaceAll('/', '\\');
      await Process.run('explorer', ['/select,', safePath]);
    } catch (e) {
      _showMessage('打开文件位置失败: $e');
    }
  }

  void _showMessage(String message) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('提示'),
        content: Text(message),
        severity: InfoBarSeverity.warning,
        onClose: close,
      ),
    );
  }

  void _confirmDelete(IntegratedDownloadService service) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要从列表中删除 "${widget.task.fileName}" 吗？\n文件不会被删除。'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: () {
              service.removeTask(widget.task.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 带文字的操作按钮
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered 
                ? widget.color.withValues(alpha: 0.15)
                : AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _isHovered 
                  ? widget.color.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 12,
                color: _isHovered ? widget.color : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: _isHovered ? widget.color : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 纯图标操作按钮
class _IconActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _isHovered 
                ? widget.color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _isHovered 
                  ? widget.color.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 12,
            color: _isHovered ? widget.color : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}


/// Tab 按钮组件
class _TabButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                : (_isHovered ? AppTheme.bgLayer2 : Colors.transparent),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.accentPrimary.withValues(alpha: 0.4)
                  : (_isHovered ? AppTheme.borderSubtle : Colors.transparent),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 12,
                color: widget.isSelected
                    ? AppTheme.accentPrimary
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected
                      ? AppTheme.accentPrimary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                      : AppTheme.bgLayer2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isSelected
                        ? AppTheme.accentPrimary
                        : AppTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 自定义分类 Tab 按钮组件（带删除功能）
class _CustomTabButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CustomTabButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_CustomTabButton> createState() => _CustomTabButtonState();
}

class _CustomTabButtonState extends State<_CustomTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                : (_isHovered ? AppTheme.bgLayer2 : Colors.transparent),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.accentPrimary.withValues(alpha: 0.4)
                  : (_isHovered ? AppTheme.borderSubtle : Colors.transparent),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 12,
                color: widget.isSelected
                    ? AppTheme.accentPrimary
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected
                      ? AppTheme.accentPrimary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                      : AppTheme.bgLayer2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isSelected
                        ? AppTheme.accentPrimary
                        : AppTheme.textTertiary,
                  ),
                ),
              ),
              if (_isHovered) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    widget.onDelete();
                  },
                  child: Icon(
                    FluentIcons.chrome_close,
                    size: 10,
                    color: AppTheme.statusError,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
