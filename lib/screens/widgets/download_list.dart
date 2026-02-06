import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/integrated_download_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../models/download_task.dart' show DownloadTask, DownloadStatus, SegmentInfo;
import '../../theme/app_theme.dart';
import '../../widgets/file_icon_widget.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
import '../../widgets/animated_notifications.dart';

class DownloadList extends StatefulWidget {
  const DownloadList({super.key});

  @override
  State<DownloadList> createState() => _DownloadListState();
}

class _DownloadListState extends State<DownloadList> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DownloadStatus? _filterStatus;
  String _sortOrder = 'newest'; // 'newest' 或 'oldest'

  @override
  void initState() {
    super.initState();
    _loadSortOrder();
  }

  Future<void> _loadSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final sortOrder = prefs.getString('task_sort_order') ?? 'newest';
    if (mounted) {
      setState(() => _sortOrder = sortOrder);
    }
  }

  Future<void> _saveSortOrder(String order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('task_sort_order', order);
    setState(() => _sortOrder = order);
  }

  void _applySorting(List<DownloadTask> tasks) {
    tasks.sort((a, b) {
      // 直接使用 createdAt 字段进行排序
      if (_sortOrder == 'newest') {
        return b.createdAt.compareTo(a.createdAt); // 最新的在最上面
      } else {
        return a.createdAt.compareTo(b.createdAt); // 最旧的在最上面
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('DownloadList');

    return ColoredBox(
      color: Colors.transparent,
      // 优化：使用 Selector 监听任务列表变化
      child: Selector<IntegratedDownloadService, List<DownloadTask>>(
        selector: (_, service) => service.tasks,
        shouldRebuild: (previous, next) {
          // 任务数量变化
          if (previous.length != next.length) return true;

          for (int i = 0; i < previous.length; i++) {
            // 任务 ID 变化
            if (previous[i].id != next[i].id) return true;
            // 状态变化（如从下载中变为完成）
            if (previous[i].status != next[i].status) return true;
            // 进度变化（修复：下载中任务的进度更新）
            if (previous[i].status == DownloadStatus.downloading ||
                next[i].status == DownloadStatus.downloading) {
              // 进度变化超过 0.1% 才重建，避免过于频繁
              if ((previous[i].progress - next[i].progress).abs() > 0.001) return true;
              // 速度变化也需要更新
              if (previous[i].speed != next[i].speed) return true;
            }
          }
          return false;
        },
        builder: (context, tasks, child) {
          final downloadService = context.read<IntegratedDownloadService>();

          var activeTasks = tasks
              .where((t) => t.status != DownloadStatus.completed)
              .toList();

          // 应用搜索过滤
          if (_searchQuery.isNotEmpty) {
            activeTasks = activeTasks.where((t) => 
              t.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.url.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
          }

          // 应用状态过滤
          if (_filterStatus != null) {
            activeTasks = activeTasks.where((t) => t.status == _filterStatus).toList();
          }
          
          // 应用排序 - 直接使用 createdAt 字段
          activeTasks.sort((a, b) {
            if (_sortOrder == 'newest') {
              return b.createdAt.compareTo(a.createdAt); // 最新的在最上面
            } else {
              return a.createdAt.compareTo(b.createdAt); // 最旧的在最上面
            }
          });

          if (activeTasks.isEmpty && _searchQuery.isNotEmpty || _filterStatus != null) {
            return _buildNoResultsState(context);
          }
          
          if (activeTasks.isEmpty) {
            return _buildEmptyState(context);
          }

        // 计算总体统计
        final downloadingTasks = activeTasks.where((t) => t.status == DownloadStatus.downloading).toList();
        final totalSpeed = downloadingTasks.fold<double>(0, (sum, t) => sum + (t.speed ?? 0));
        final totalSegments = downloadingTasks.fold<int>(0, (sum, t) => sum + (t.segments?.length ?? 0));

        return Column(
          children: [
            // 顶部工具栏：搜索和筛选按钮
            _buildToolbar(context),
            // 搜索和筛选栏（展开时显示）
            _buildSearchBar(context, downloadService),
            // 下载统计栏
            if (downloadingTasks.isNotEmpty)
              _buildStatsBar(context, downloadingTasks.length, totalSpeed, totalSegments),
            // 任务列表
            Expanded(
              child: SmoothListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: activeTasks.length,
                      // 性能优化：增加缓存区域，预加载更多项目减少滚动时的创建销毁
                      cacheExtent: 500,
                      // 添加 addRepaintBoundaries 优化重绘
                      addRepaintBoundaries: true,
                      // 添加 addAutomaticKeepAlives 保持状态
                      addAutomaticKeepAlives: false,
                      // 平滑滚动配置 - 使用快速响应模式
                      config: SmoothScrollConfig.fast,
                      itemBuilder: (context, index) {
                        final task = activeTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          // 使用 RepaintBoundary 隔离每个卡片的重绘
                          child: RepaintBoundary(
                            child: _DownloadTaskCard(
                              key: ValueKey(task.id),
                              task: task,
                            ),
                          ),
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

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // 搜索按钮
          IconButton(
            icon: Icon(
              CustomIcons.FluentIcons.searchIcon,
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
          const SizedBox(width: 8),
          // 筛选按钮
          IconButton(
            icon: Icon(
              CustomIcons.FluentIcons.filter,
              size: 14,
              color: _filterStatus != null ? AppTheme.accentLight : AppTheme.textSecondary,
            ),
            onPressed: () => _showFilterDialog(context),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(8)),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (_filterStatus != null) {
                  return AppTheme.accentPrimary.withValues(alpha: 0.1);
                }
                if (states.isHovered) {
                  return AppTheme.bgLayer2.withValues(alpha: 0.5);
                }
                return Colors.transparent;
              }),
            ),
          ),
          const SizedBox(width: 8),
          // 排序按钮
          IconButton(
            icon: Icon(
              _sortOrder == 'newest' ? CustomIcons.FluentIcons.sort_down : CustomIcons.FluentIcons.sort_up,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            onPressed: () => _showSortDialog(context),
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
          const Spacer(),
          // 显示当前筛选状态
          if (_filterStatus != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                border: Border.all(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getStatusFilterText(_filterStatus!),
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.accentLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _filterStatus = null),
                    child: Icon(CustomIcons.FluentIcons.chrome_close,
                      size: 10,
                      color: AppTheme.accentLight,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusFilterText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.pending:
        return '等待中';
      case DownloadStatus.failed:
        return '失败';
      case DownloadStatus.merging:
        return '合并中';
      default:
        return '全部';
    }
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('筛选下载任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择要显示的任务状态：'),
            const SizedBox(height: 16),
            _buildFilterOption(context, null, '全部状态', CustomIcons.FluentIcons.list),
            _buildFilterOption(context, DownloadStatus.downloading, '下载中', CustomIcons.FluentIcons.download),
            _buildFilterOption(context, DownloadStatus.paused, '已暂停', CustomIcons.FluentIcons.pause),
            _buildFilterOption(context, DownloadStatus.pending, '等待中', CustomIcons.FluentIcons.clock),
            _buildFilterOption(context, DownloadStatus.failed, '失败', CustomIcons.FluentIcons.error_badge),
            _buildFilterOption(context, DownloadStatus.merging, '合并中', CustomIcons.FluentIcons.processing),
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

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('排序方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择任务排列顺序：'),
            const SizedBox(height: 16),
            _buildSortOption(context, 'newest', '最新在前', CustomIcons.FluentIcons.sort_down, '新添加的任务显示在最上面'),
            _buildSortOption(context, 'oldest', '最旧在前', CustomIcons.FluentIcons.sort_up, '最早添加的任务显示在最上面'),
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

  Widget _buildSortOption(BuildContext context, String value, String label, IconData icon, String description) {
    final isSelected = _sortOrder == value;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          _saveSortOrder(value);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.accentPrimary.withValues(alpha: 0.1)
                : AppTheme.bgLayer2.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentPrimary.withValues(alpha: 0.5)
                  : AppTheme.borderSubtle.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.accentLight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: FluentTheme.of(context).typography.body?.copyWith(
                        color: isSelected ? AppTheme.accentLight : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(CustomIcons.FluentIcons.check_mark,
                  size: 16,
                  color: AppTheme.accentLight,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(BuildContext context, DownloadStatus? status, String label, IconData icon) {
    final isSelected = _filterStatus == status;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _filterStatus = status);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.accentPrimary.withValues(alpha: 0.1)
                : AppTheme.bgLayer2.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentPrimary.withValues(alpha: 0.5)
                  : AppTheme.borderSubtle.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppTheme.accentLight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  color: isSelected ? AppTheme.accentLight : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(CustomIcons.FluentIcons.check_mark,
                  size: 14,
                  color: AppTheme.accentLight,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, IntegratedDownloadService downloadService) {
    // 只在搜索展开时显示
    if (!_showSearch) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
          Icon(CustomIcons.FluentIcons.searchIcon, size: 14, color: AppTheme.accentLight),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _searchController,
              placeholder: '搜索文件名或链接...',
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: WidgetStateProperty.all(const BoxDecoration()),
              style: FluentTheme.of(context).typography.body?.copyWith(fontSize: 13),
              autofocus: true,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(CustomIcons.FluentIcons.clear, size: 12),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
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
            CustomIcons.FluentIcons.search_issue,
            size: 64,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配的下载任务',
            style: FluentTheme.of(context).typography.subtitle?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试修改搜索条件或筛选器',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsBar(BuildContext context, int activeCount, double totalSpeed, int totalSegments) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // 活跃任务数
          _buildStatItem(
            context,
            icon: CustomIcons.FluentIcons.download,
            label: '下载中',
            value: '$activeCount',
            color: AppTheme.accentPrimary,
          ),
          _buildDivider(),
          // 总速度
          _buildStatItem(
            context,
            icon: CustomIcons.FluentIcons.speed_high,
            label: '总速度',
            value: _formatSpeed(totalSpeed),
            color: AppTheme.accentLight,
          ),
          _buildDivider(),
          // 活跃分段
          _buildStatItem(
            context,
            icon: CustomIcons.FluentIcons.split_object,
            label: '活跃分段',
            value: '$totalSegments',
            color: AppTheme.statusSuccess,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: color,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppTheme.borderSubtle,
    );
  }
  
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
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
                          color: AppTheme.accentPrimary.withValues(alpha: 0.3 * value),
                          blurRadius: 60 * value,
                          spreadRadius: 10 * value,
                        ),
                      ],
                    ),
                    child: Icon(
                      CustomIcons.FluentIcons.download,
                      size: 40,
                      color: AppTheme.accentPrimary.withValues(alpha: 0.6),
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
                      '暂无下载任务',
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
                      '点击右上角"新建"按钮开始下载',
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

class _DownloadTaskCard extends StatefulWidget {
  final DownloadTask task;

  const _DownloadTaskCard({super.key, required this.task});

  @override
  State<_DownloadTaskCard> createState() => _DownloadTaskCardState();
}

class _DownloadTaskCardState extends State<_DownloadTaskCard> {
  bool _isSegmentsExpanded = false;
  bool _showAllSegments = false;
  int _maxVisibleSegments = 5;
  String _segmentsDisplayMode = 'merged'; // 'merged' (合并) 或 'list' (列表)

  @override
  void initState() {
    super.initState();
    _loadSegmentsExpandedSetting();
  }
  
  Future<void> _loadSegmentsExpandedSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultExpanded = prefs.getBool('segments_default_expanded') ?? false;
    final maxVisible = prefs.getInt('segments_max_visible') ?? 5;
    final displayMode = prefs.getString('segments_display_mode') ?? 'merged';
    if (mounted) {
      setState(() {
        _isSegmentsExpanded = defaultExpanded;
        _maxVisibleSegments = maxVisible;
        _segmentsDisplayMode = displayMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('DownloadTaskCard');

    final downloadService = context.read<IntegratedDownloadService>();
    final isActive = widget.task.status == DownloadStatus.downloading;

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.85),
      hoverColor: AppTheme.surfaceCard.withValues(alpha: 0.95),
      borderColor: isActive 
          ? AppTheme.accentPrimary.withValues(alpha: 0.3)
          : AppTheme.borderSubtle,
      hoverBorderColor: AppTheme.accentPrimary.withValues(alpha: 0.5),
      borderRadius: AppTheme.radiusLg,
      enableScaleAnimation: false,
      enableGlowAnimation: isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(downloadService),
          const SizedBox(height: 16),
          _buildProgressSection(),
          if (widget.task.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 14),
            _buildSpeedInfo(),
          ],
          if (widget.task.status == DownloadStatus.failed && widget.task.error != null) ...[
            const SizedBox(height: 14),
            _buildErrorInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(IntegratedDownloadService service) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 文件图标
        FileIconWidget(
          fileName: widget.task.fileName,
          filePath: widget.task.filePath,
          size: 44,
        ),
        const SizedBox(width: 14),
        // 文件信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 文件名 + 状态指示器
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.task.fileName,
                      style: FluentTheme.of(context).typography.body?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusIndicator(),
                ],
              ),
              const SizedBox(height: 6),
              // URL + 文件大小
              Row(
                children: [
                  Expanded(child: _buildUrlWithCopy()),
                  if (widget.task.fileSize != null && widget.task.fileSize! > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLayer2.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatBytes(widget.task.fileSize!),
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 操作按钮
        _buildActionButtons(service),
      ],
    );
  }
  
  // 状态指示器（简化版，无动画）
  Widget _buildStatusIndicator() {
    final color = _getStatusColor();
    
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.surfaceCard,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildUrlWithCopy() {
    return _HoverableUrl(
      url: widget.task.url,
      onTap: _copyUrlToClipboard,
    );
  }

  Future<void> _copyUrlToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.task.url));
      if (mounted) {
        // 显示复制成功的提示
        NotificationManager.of(context)?.showSuccess('复制成功', message: '链接已复制到剪贴板');
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError('复制失败', message: '无法复制链接: $e');
      }
    }
  }

  Widget _buildStatusChip() {
    final color = _getStatusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        _getStatusText(),
        style: FluentTheme.of(context).typography.caption?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildActionButtons(IntegratedDownloadService service) {
    final isMerging = widget.task.status == DownloadStatus.merging;
    final hasRetryableSegments = widget.task.hasRetryableSegments;
    final isFailed = widget.task.status == DownloadStatus.failed;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMerging && (widget.task.status == DownloadStatus.pending ||
            widget.task.status == DownloadStatus.paused))
          _ActionButton(
            icon: CustomIcons.FluentIcons.play,
            color: AppTheme.statusSuccess,
            onPressed: () => service.startTask(widget.task.id),
            tooltip: '开始',
          ),
        if (!isMerging && widget.task.status == DownloadStatus.downloading)
          _ActionButton(
            icon: CustomIcons.FluentIcons.pause,
            color: AppTheme.statusWarning,
            onPressed: () => service.pauseTask(widget.task.id),
            tooltip: '暂停',
          ),
        // 添加间距
        if (!isMerging && (widget.task.status == DownloadStatus.pending ||
            widget.task.status == DownloadStatus.paused ||
            widget.task.status == DownloadStatus.downloading))
          const SizedBox(width: 6),
        // 重试失败分段按钮 - 显示在删除按钮左边
        if (!isMerging && (hasRetryableSegments || isFailed)) ...[
          _ActionButton(
            icon: CustomIcons.FluentIcons.refresh,
            color: AppTheme.accentLight,
            onPressed: () => service.retryFailedSegments(widget.task.id),
            tooltip: hasRetryableSegments ? '重试失败分段' : '重新下载',
          ),
          const SizedBox(width: 6),
        ],
        if (!isMerging)
          _ActionButton(
            icon: CustomIcons.FluentIcons.delete,
            color: AppTheme.statusError,
            onPressed: () => _confirmDelete(service),
            tooltip: '删除',
          ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final isUnknownSize = (widget.task.fileSize == null || widget.task.fileSize == 0) && 
                          widget.task.status == DownloadStatus.downloading;
    final isMerging = widget.task.status == DownloadStatus.merging;
    final progress = widget.task.progress.clamp(0.0, 1.0);
    
    // 合并状态：特殊布局
    if (isMerging) {
      return Row(
        children: [
          // 左侧加载圈圈
          const SizedBox(
            width: 16,
            height: 16,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          // 文字
          Text(
            '正在校验和合并数据',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.accentPrimary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          // 中间短进度条
          SizedBox(
            width: 120,
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              child: const ProgressBar(strokeWidth: 6),
            ),
          ),
          const SizedBox(width: 12),
          // 右侧百分比
          Text(
            '${(progress * 100).toStringAsFixed(1)}%',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.accentLight,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    
    // 正常下载状态
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 进度信息行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左侧：已下载/总大小
            if (!isUnknownSize && widget.task.fileSize != null && widget.task.fileSize! > 0)
              Text(
                '${_formatBytes((widget.task.fileSize! * progress).round())} / ${_formatBytes(widget.task.fileSize!)}',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                '计算文件大小中...',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            
            // 右侧：百分比
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              ),
              child: Text(
                isUnknownSize
                    ? '计算中'
                    : '${(progress * 100).toStringAsFixed(1)}%',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentLight,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 10),

        // 进度条 - 优化：移除boxShadow提升性能
        Stack(
          children: [
            // 背景轨道
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.bgLayer2.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              ),
            ),
            // 进度填充
            if (!isUnknownSize)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.accentPrimary,
                        AppTheme.accentLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                child: const SizedBox(
                  height: 8,
                  child: ProgressBar(strokeWidth: 8),
                ),
              ),
          ],
        ),
        
        // 分段进度（如果有）
        if (widget.task.segments != null && widget.task.segments!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildSegmentsProgress(),
        ],
      ],
    );
  }

  Widget _buildSegmentsProgress() {
    final segments = widget.task.segments!;
    
    // 简洁模式：不显示分段信息
    if (_segmentsDisplayMode == 'none') {
      return const SizedBox.shrink();
    }
    
    // 合并进度条模式
    if (_segmentsDisplayMode == 'merged') {
      return _buildMergedSegmentsBar(segments);
    }
    
    // 列表模式
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isSegmentsExpanded = !_isSegmentsExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CustomIcons.FluentIcons.split_object,
                  size: 12,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '分段下载 (${segments.length})',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isSegmentsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CustomIcons.FluentIcons.chevron_down,
                    size: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildSegmentsList(segments),
          crossFadeState: _isSegmentsExpanded 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
  
  /// 合并分段进度条
  Widget _buildMergedSegmentsBar(List<SegmentInfo> segments) {
    final totalSize = widget.task.fileSize ?? 0;
    if (totalSize == 0) return const SizedBox.shrink();
    
    // 统计分段状态
    final completedCount = segments.where((s) => s.status == 'completed').length;
    final downloadingCount = segments.where((s) => s.status == 'downloading').length;
    final failedCount = segments.where((s) => s.status == 'failed').length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分段信息标题
        Row(
          children: [
            Icon(
              CustomIcons.FluentIcons.split_object,
              size: 12,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              '分段下载',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            // 分段状态统计
            _buildSegmentStatusBadge(completedCount, AppTheme.statusSuccess, '完成'),
            const SizedBox(width: 4),
            _buildSegmentStatusBadge(downloadingCount, AppTheme.accentPrimary, '下载'),
            if (failedCount > 0) ...[
              const SizedBox(width: 4),
              _buildSegmentStatusBadge(failedCount, AppTheme.statusError, '失败'),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // 简约现代的进度条
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.bgLayer1.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              painter: _FlatSegmentProgressPainter(
                segments: segments,
                totalSize: totalSize,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 分段数量提示
        Row(
          children: [
            Expanded(
              child: Text(
                '${segments.length} 个分段 · $completedCount 完成 · $downloadingCount 下载中' +
                (failedCount > 0 ? ' · $failedCount 失败' : ''),
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
            // 快速重试按钮
            if (failedCount > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.read<IntegratedDownloadService>().retryFailedSegments(widget.task.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.accentLight.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CustomIcons.FluentIcons.refresh,
                        size: 8,
                        color: AppTheme.accentLight,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '重试',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.accentLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
  
  Widget _buildSegmentStatusBadge(int count, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count$label',
        style: FluentTheme.of(context).typography.caption?.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSegmentsList(List<SegmentInfo> segments) {
    final visibleSegments = _showAllSegments 
        ? segments 
        : segments.take(_maxVisibleSegments).toList();
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          ...visibleSegments.map((segment) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildSegmentRow(segment),
          )),
          if (segments.length > _maxVisibleSegments)
            _buildShowMoreButton(segments.length),
        ],
      ),
    );
  }

  Widget _buildSegmentRow(SegmentInfo segment) {
    final downloadService = context.read<IntegratedDownloadService>();
    
    // 根据分段状态选择颜色
    Color statusColor;
    switch (segment.status) {
      case 'downloading':
        statusColor = AppTheme.accentPrimary;
        break;
      case 'completed':
        statusColor = AppTheme.statusSuccess;
        break;
      case 'failed':
        statusColor = AppTheme.statusError;
        break;
      case 'paused':
        statusColor = AppTheme.statusWarning;
        break;
      default:
        statusColor = AppTheme.textTertiary;
    }
    
    return Row(
      children: [
        // 分段编号和状态指示器
        Container(
          width: 60,
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '分段 ${segment.index + 1}',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ProgressBar(
            value: segment.progress,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(width: 8),
        // 状态文本
        SizedBox(
          width: 35,
          child: Text(
            segment.statusText,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: statusColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Text(
            '${_formatBytes(segment.downloadedBytes)}/${_formatBytes(segment.endByte - segment.startByte)}',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 9,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 55,
          child: Text(
            _formatSpeed(segment.speed),
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: segment.speed > 0 ? AppTheme.accentLight : AppTheme.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        // 重试次数显示
        if (segment.retryCount > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.statusWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '重试${segment.retryCount}',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.statusWarning,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        // 单个分段重试按钮
        if (segment.canRetry) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => downloadService.retrySegment(widget.task.id, segment.index),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.accentLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: AppTheme.accentLight.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Icon(
                CustomIcons.FluentIcons.refresh,
                size: 8,
                color: AppTheme.accentLight,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShowMoreButton(int totalCount) {
    return GestureDetector(
      onTap: () => setState(() => _showAllSegments = !_showAllSegments),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showAllSegments ? CustomIcons.FluentIcons.chevron_up_small : CustomIcons.FluentIcons.chevron_down_small,
              size: 12,
              color: AppTheme.accentLight,
            ),
            const SizedBox(width: 6),
            Text(
              _showAllSegments 
                  ? '收起'
                  : '显示全部 ${totalCount - _maxVisibleSegments} 个',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.accentLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  Widget _buildSpeedInfo() {
    final isUnknownSize = widget.task.fileSize == null || widget.task.fileSize == 0;
    final segmentCount = widget.task.segments?.length ?? 0;
    final activeSegments = widget.task.segments?.where((s) => s.isDownloading).length ?? 0;
    final speed = widget.task.speed ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          // 速度显示器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CustomIcons.FluentIcons.speed_high,
                  size: 14,
                  color: AppTheme.accentLight,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatSpeed(speed),
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.accentLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 分段信息
          if (segmentCount > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgLayer2.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CustomIcons.FluentIcons.split_object,
                    size: 11,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$activeSegments/$segmentCount',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // 剩余时间
          if (!isUnknownSize && widget.task.remainingTime != null && widget.task.remainingTime!.inSeconds > 0) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CustomIcons.FluentIcons.clock,
                  size: 11,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.task.formattedRemainingTime,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          
          // 分隔线
          Container(
            width: 1,
            height: 16,
            color: AppTheme.borderSubtle.withValues(alpha: 0.5),
          ),
          
          const SizedBox(width: 8),
          
          // 已下载/总大小
          Expanded(
            child: Text(
              isUnknownSize
                  ? '${widget.task.formattedDownloadedSize} / 未知'
                  : '${widget.task.formattedDownloadedSize} / ${widget.task.formattedFileSize}',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorInfo() {
    final downloadService = context.read<IntegratedDownloadService>();
    final hasRetryableSegments = widget.task.hasRetryableSegments;
    final failedCount = widget.task.failedSegments.length;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.error_badge,
                size: 16,
                color: AppTheme.statusError,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下载失败',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.statusError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.task.error!,
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.statusError.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 分段失败信息和重试按钮
          if (hasRetryableSegments) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.accentLight.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 12,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$failedCount 个分段失败，可以尝试重新下载',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.accentLight,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => downloadService.retryFailedSegments(widget.task.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.accentLight.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CustomIcons.FluentIcons.refresh,
                            size: 10,
                            color: AppTheme.accentLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '重试',
                            style: FluentTheme.of(context).typography.caption?.copyWith(
                              color: AppTheme.accentLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
    );
  }

  void _confirmDelete(IntegratedDownloadService service) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务 "${widget.task.fileName}" 吗？'),
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
  Color _getStatusColor() {
    switch (widget.task.status) {
      case DownloadStatus.pending:
        return AppTheme.statusWarning;
      case DownloadStatus.downloading:
        return AppTheme.accentPrimary;
      case DownloadStatus.paused:
        return AppTheme.textTertiary;
      case DownloadStatus.completed:
        return AppTheme.statusSuccess;
      case DownloadStatus.failed:
        return AppTheme.statusError;
      case DownloadStatus.merging:
        return AppTheme.accentLight;
    }
  }

  String _getStatusText() {
    switch (widget.task.status) {
      case DownloadStatus.pending:
        return '等待中';
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '失败';
      case DownloadStatus.merging:
        return '合并中';
    }
  }
}

/// 现代简约风格分段进度条绘制器
class _FlatSegmentProgressPainter extends CustomPainter {
  final List<SegmentInfo> segments;
  final int totalSize;
  
  _FlatSegmentProgressPainter({
    required this.segments,
    required this.totalSize,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (totalSize == 0 || segments.isEmpty) return;
    
    final width = size.width;
    final height = size.height;
    
    // 绘制每个分段
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final startRatio = segment.startByte / totalSize;
      final endRatio = segment.endByte / totalSize;
      final segmentWidth = (endRatio - startRatio) * width;
      final startX = startRatio * width;
      
      // 计算分段内的进度
      final segmentSize = segment.endByte - segment.startByte;
      double progressRatio = 0.0;
      if (segmentSize > 0) {
        progressRatio = (segment.downloadedBytes / segmentSize).clamp(0.0, 1.0);
      }
      final progressWidth = (segmentWidth * progressRatio).clamp(0.0, segmentWidth);
      
      // 选择颜色
      Color color;
      switch (segment.status) {
        case 'completed':
          color = AppTheme.statusSuccess;
          break;
        case 'downloading':
          color = AppTheme.accentPrimary;
          break;
        case 'failed':
          color = AppTheme.statusError;
          break;
        case 'paused':
          color = AppTheme.statusWarning;
          break;
        default:
          color = AppTheme.textTertiary.withValues(alpha: 0.15);
      }
      
      // 绘制已下载部分 - 使用精确的像素对齐
      if (progressWidth > 0) {
        final progressPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = false; // 禁用抗锯齿，确保像素完美对齐
        
        canvas.drawRect(
          Rect.fromLTWH(startX, 0, progressWidth, height),
          progressPaint,
        );
      }
      
      // 只在非完成分段之间绘制分割线
      if (i < segments.length - 1) {
        final nextSegment = segments[i + 1];
        
        // 两个分段都是完成状态时，不显示分割线
        if (segment.status == 'completed' && nextSegment.status == 'completed') {
          continue;
        }
        
        // 其他情况显示分割线
        final gapX = startX + segmentWidth;
        final gapPaint = Paint()
          ..color = AppTheme.bgLayer2.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..isAntiAlias = false; // 禁用抗锯齿
        
        canvas.drawLine(
          Offset(gapX, 0),
          Offset(gapX, height),
          gapPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant _FlatSegmentProgressPainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length) return true;
    if (oldDelegate.totalSize != totalSize) return true;
    
    for (int i = 0; i < segments.length; i++) {
      final oldSeg = oldDelegate.segments[i];
      final newSeg = segments[i];
      
      if (oldSeg.status != newSeg.status) return true;
      
      final segmentSize = newSeg.endByte - newSeg.startByte;
      if (segmentSize > 0) {
        final oldProgress = oldSeg.downloadedBytes / segmentSize;
        final newProgress = newSeg.downloadedBytes / segmentSize;
        if ((newProgress - oldProgress).abs() > 0.001) return true;
      }
    }
    
    return false;
  }
}

/// 增强版分段进度条绘制器 - 带渐变和动画效果（备用）
class _EnhancedSegmentProgressPainter extends CustomPainter {
  final List<SegmentInfo> segments;
  final int totalSize;
  
  _EnhancedSegmentProgressPainter({
    required this.segments,
    required this.totalSize,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (totalSize == 0 || segments.isEmpty) return;
    
    final width = size.width;
    final height = size.height;
    
    // 背景渐变
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppTheme.bgLayer1.withValues(alpha: 0.5),
        AppTheme.bgLayer1,
      ],
    );
    final bgPaint = Paint()
      ..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);
    
    // 绘制每个分段
    for (final segment in segments) {
      final startRatio = segment.startByte / totalSize;
      final endRatio = segment.endByte / totalSize;
      final segmentWidth = (endRatio - startRatio) * width;
      final startX = startRatio * width;
      
      // 计算分段内的进度
      final segmentSize = segment.endByte - segment.startByte;
      double progressRatio = 0.0;
      if (segmentSize > 0) {
        progressRatio = (segment.downloadedBytes / segmentSize).clamp(0.0, 1.0);
      }
      final progressWidth = (segmentWidth * progressRatio).clamp(0.0, segmentWidth);
      
      // 选择颜色和效果
      Color baseColor;
      bool useGradient = false;
      bool useGlow = false;
      
      switch (segment.status) {
        case 'completed':
          baseColor = AppTheme.statusSuccess;
          useGradient = true;
          break;
        case 'downloading':
          baseColor = AppTheme.accentPrimary;
          useGradient = true;
          useGlow = true;
          break;
        case 'failed':
          baseColor = AppTheme.statusError;
          useGradient = true;
          break;
        case 'paused':
          baseColor = AppTheme.statusWarning;
          break;
        default:
          baseColor = AppTheme.textTertiary.withValues(alpha: 0.2);
      }
      
      // 绘制已下载部分
      if (progressWidth > 0) {
        final progressRect = Rect.fromLTWH(startX, 0, progressWidth, height);
        
        // 发光效果（仅用于下载中的分段）
        if (useGlow) {
          final glowPaint = Paint()
            ..color = baseColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
            ..style = PaintingStyle.fill;
          canvas.drawRect(progressRect, glowPaint);
        }
        
        // 主体渐变
        if (useGradient) {
          final gradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              baseColor.withValues(alpha: 0.9),
              baseColor,
              baseColor.withValues(alpha: 0.95),
            ],
            stops: const [0.0, 0.5, 1.0],
          );
          final progressPaint = Paint()
            ..shader = gradient.createShader(progressRect)
            ..style = PaintingStyle.fill;
          canvas.drawRect(progressRect, progressPaint);
          
          // 顶部高光
          final highlightGradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.4],
          );
          final highlightPaint = Paint()
            ..shader = highlightGradient.createShader(
              Rect.fromLTWH(startX, 0, progressWidth, height * 0.5),
            )
            ..style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromLTWH(startX, 0, progressWidth, height * 0.5),
            highlightPaint,
          );
        } else {
          // 纯色填充
          final progressPaint = Paint()
            ..color = baseColor
            ..style = PaintingStyle.fill;
          canvas.drawRect(progressRect, progressPaint);
        }
        
        // 下载中的分段：添加动画指示器（右边缘渐变）
        if (segment.status == 'downloading' && progressWidth < segmentWidth) {
          final edgeGradient = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              baseColor.withValues(alpha: 0.0),
              baseColor.withValues(alpha: 0.4),
              baseColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          );
          final edgeWidth = 8.0;
          final edgePaint = Paint()
            ..shader = edgeGradient.createShader(
              Rect.fromLTWH(
                startX + progressWidth - edgeWidth / 2,
                0,
                edgeWidth,
                height,
              ),
            )
            ..style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromLTWH(
              startX + progressWidth - edgeWidth / 2,
              0,
              edgeWidth,
              height,
            ),
            edgePaint,
          );
        }
      }
      
      // 绘制分段边界线（更精致）
      if (segments.length > 1 && segment.index < segments.length - 1) {
        final borderPaint = Paint()
          ..color = AppTheme.borderSubtle.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        
        // 绘制垂直分隔线
        final lineX = startX + segmentWidth;
        canvas.drawLine(
          Offset(lineX, height * 0.15),
          Offset(lineX, height * 0.85),
          borderPaint,
        );
      }
    }
    
    // 顶部和底部边缘增强
    final topEdgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawLine(
      const Offset(0, 0.5),
      Offset(width, 0.5),
      topEdgePaint,
    );
    
    final bottomEdgePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, height - 0.5),
      Offset(width, height - 0.5),
      bottomEdgePaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant _EnhancedSegmentProgressPainter oldDelegate) {
    // 检查分段数量或总大小变化
    if (oldDelegate.segments.length != segments.length) return true;
    if (oldDelegate.totalSize != totalSize) return true;
    
    // 检查实质性进度或状态变化
    for (int i = 0; i < segments.length; i++) {
      final oldSeg = oldDelegate.segments[i];
      final newSeg = segments[i];
      
      // 状态变化
      if (oldSeg.status != newSeg.status) return true;
      
      // 进度变化超过 0.1%
      final segmentSize = newSeg.endByte - newSeg.startByte;
      if (segmentSize > 0) {
        final oldProgress = oldSeg.downloadedBytes / segmentSize;
        final newProgress = newSeg.downloadedBytes / segmentSize;
        if ((newProgress - oldProgress).abs() > 0.001) return true;
      }
    }
    
    return false;
  }
}

/// 操作按钮组件
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 32,
            height: 32,
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
              size: 14,
              color: _isHovered ? widget.color : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 可悬停的URL组件，支持hover动画
class _HoverableUrl extends StatefulWidget {
  final String url;
  final VoidCallback onTap;

  const _HoverableUrl({
    required this.url,
    required this.onTap,
  });

  @override
  State<_HoverableUrl> createState() => _HoverableUrlState();
}

class _HoverableUrlState extends State<_HoverableUrl> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: '点击复制链接',
          child: Text(
            widget.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 11,
              decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
              decorationColor: AppTheme.textTertiary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

