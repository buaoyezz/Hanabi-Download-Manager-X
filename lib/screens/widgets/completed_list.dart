import 'dart:io';
import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/integrated_download_service.dart';
import '../../services/client_config_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../models/download_task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/file_icon_widget.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
import '../../widgets/animated_notifications.dart';
import '../../widgets/folder_picker_dialog.dart';

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
  all,
  video,
  audio,
  archive,
  document,
  program,
  other;

  String label(AppLocalizations t) {
    switch (this) {
      case FileCategory.all:
        return t.completedCategoryAll;
      case FileCategory.video:
        return t.completedCategoryVideo;
      case FileCategory.audio:
        return t.completedCategoryAudio;
      case FileCategory.archive:
        return t.completedCategoryArchive;
      case FileCategory.document:
        return t.completedCategoryDocument;
      case FileCategory.program:
        return t.completedCategoryProgram;
      case FileCategory.other:
        return t.completedCategoryOther;
    }
  }

  IconData get icon {
    switch (this) {
      case FileCategory.all:
        return CustomIcons.FluentIcons.folder;
      case FileCategory.video:
        return CustomIcons.FluentIcons.video;
      case FileCategory.audio:
        return CustomIcons.FluentIcons.music_note;
      case FileCategory.archive:
        return CustomIcons.FluentIcons.archive;
      case FileCategory.document:
        return CustomIcons.FluentIcons.document;
      case FileCategory.program:
        return CustomIcons.FluentIcons.app_icon_default;
      case FileCategory.other:
        return CustomIcons.FluentIcons.more;
    }
  }

  List<String> get extensions {
    switch (this) {
      case FileCategory.all:
        return [];
      case FileCategory.video:
        return ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg'];
      case FileCategory.audio:
        return ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a', '.ape'];
      case FileCategory.archive:
        return ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.iso'];
      case FileCategory.document:
        return ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.md', '.rtf'];
      case FileCategory.program:
        return ['.exe', '.msi', '.apk', '.dmg', '.deb', '.rpm', '.appimage'];
      case FileCategory.other:
        return [];
    }
  }

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
  AppLocalizations get t => AppLocalizations.of(context)!;

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
    _customCategories = categoriesData.map((data) {
      return CustomCategory(
        name: data['name'] as String,
        extensions: (data['extensions'] as List).cast<String>(),
      );
    }).toList();
    // 只在 widget 已经构建过后才 setState
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('CompletedList');

    return ColoredBox(
      color: Colors.transparent,
      // 优化：使用 Selector 只监听已完成任务，避免下载中任务进度更新触发重建
      child: Selector<IntegratedDownloadService, List<DownloadTask>>(
        selector: (_, service) => service.tasks
            .where((t) => t.status == DownloadStatus.completed)
            .toList(),
        shouldRebuild: (previous, next) {
          if (previous.length != next.length) return true;
          for (int i = 0; i < previous.length; i++) {
            if (previous[i].id != next[i].id) return true;
          }
          return false;
        },
        builder: (context, completedTasks, child) {
          final hasLoaded = context.select<IntegratedDownloadService, bool>((s) => s.hasLoadedOnce);

          // 按完成时间排序，最新的在前面
          completedTasks.sort((a, b) {
            if (a.endTime == null && b.endTime == null) return 0;
            if (a.endTime == null) return 1;
            if (b.endTime == null) return -1;
            return b.endTime!.compareTo(a.endTime!);
          });

          if (completedTasks.isEmpty) {
            if (!hasLoaded) {
              return _buildLoadingState(context);
            }
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
              _buildBatchActionsBar(context, currentTasks),
              Expanded(
                child: currentTasks.isEmpty
                    ? _buildNoResultsState(context)
                    : SmoothListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: currentTasks.length,
                        // 性能优化：增加缓存区域
                        cacheExtent: 500,
                        addRepaintBoundaries: true,
                        addAutomaticKeepAlives: false,
                        // 平滑滚动配置 - 使用快速响应模式
                        config: SmoothScrollConfig.fast,
                        itemBuilder: (context, index) {
                          final task = currentTasks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RepaintBoundary(
                              child: _CompletedTaskCard(
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
          Icon(CustomIcons.FluentIcons.searchIcon, size: 14, color: AppTheme.accentLight),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _searchController,
              placeholder: t.completedSearchPlaceholder,
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
          IconButton(
            icon: Icon(CustomIcons.FluentIcons.chrome_close, size: 14),
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
            CustomIcons.FluentIcons.search_issue,
            size: 64,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            t.completedNoResultsTitle,
            style: FluentTheme.of(context).typography.subtitle?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.completedNoResultsSubtitle,
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
                            label: category.label(t),
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
                            icon: CustomIcons.FluentIcons.tag,
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
                  _showSearch ? CustomIcons.FluentIcons.searchIcon : CustomIcons.FluentIcons.searchIcon,
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
                icon: Icon(CustomIcons.FluentIcons.add, size: 14, color: AppTheme.textSecondary),
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
        title: Text(t.completedCreateCategoryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.completedCreateCategoryNameLabel),
            const SizedBox(height: 8),
            TextBox(
              controller: nameController,
              placeholder: t.completedCreateCategoryNamePlaceholder,
            ),
            const SizedBox(height: 16),
            Text(t.completedCreateCategoryExtensionsLabel),
            const SizedBox(height: 8),
            TextBox(
              controller: extensionsController,
              placeholder: t.completedCreateCategoryExtensionsPlaceholder,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                t.completedCreateCategoryHint,
                style: const TextStyle(
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
            child: Text(t.completedCancelButton),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final extensionsText = extensionsController.text.trim();
              
              if (name.isEmpty || extensionsText.isEmpty) {
                NotificationManager.of(context)?.showWarning(
                  t.completedCreateCategoryInputErrorTitle,
                  message: t.completedCreateCategoryInputErrorMessage,
                );
                return;
              }

              final extensions = extensionsText
                  .split(',')
                  .map((e) => e.trim().toLowerCase())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (extensions.isEmpty) {
                NotificationManager.of(context)?.showWarning(
                  t.completedCreateCategoryInputErrorTitle,
                  message: t.completedCreateCategoryInvalidExtMessage,
                );
                return;
              }

              // 保存自定义分类到配置
              final configService = context.read<ClientConfigService>();
              await configService.addCustomCategory(name, extensions);

              // 重新加载分类
              _loadCustomCategories();

              if (!context.mounted) return;
              Navigator.pop(context);

              NotificationManager.of(context)?.showSuccess(
                  t.completedCreateCategorySuccessTitle,
                  message: t.completedCreateCategorySuccessMessage(name),
                );
            },
            child: Text(t.completedCreateButton),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionsBar(BuildContext context, List<DownloadTask> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();

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
          Icon(CustomIcons.FluentIcons.list,
            size: 14,
            color: AppTheme.accentLight,
          ),
          const SizedBox(width: 8),
          Text(
            t.completedBatchActionsLabel(tasks.length),
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Button(
            onPressed: () => _batchRenameTasks(tasks),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.getIcon('edit_20'), size: 12),
                const SizedBox(width: 6),
                Text(t.completedBatchRenameButton, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Button(
            onPressed: () => _batchMoveTasks(tasks),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.folder_open, size: 12),
                const SizedBox(width: 6),
                Text(t.completedBatchMoveButton, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _batchMoveTasks(List<DownloadTask> tasks) async {
    if (tasks.isEmpty) return;

    final useNewKernel = context.read<ClientConfigService>()
        .getBool('kernel.use_new_kernel', defaultValue: true);
    if (!useNewKernel) {
      NotificationManager.of(context)?.showWarning(
        t.completedBatchMoveUnavailableTitle,
        message: t.completedBatchMoveUnavailableMessage,
      );
      return;
    }

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

    final service = context.read<IntegratedDownloadService>();
    int success = 0;
    int failed = 0;

    for (final task in tasks) {
      final ok = await service.moveTaskFile(task.id, selectedPath);
      if (ok) {
        success++;
      } else {
        failed++;
      }
    }

    if (!mounted) return;

    if (failed == 0) {
      NotificationManager.of(context)?.showSuccess(
        t.completedBatchMoveSuccessTitle,
        message: t.completedBatchMoveSuccessMessage(success),
      );
    } else {
      NotificationManager.of(context)?.showWarning(
        t.completedBatchMoveSuccessTitle,
        message: t.completedBatchMovePartialMessage(success, failed),
      );
    }
  }

  Future<void> _batchRenameTasks(List<DownloadTask> tasks) async {
    if (tasks.isEmpty) return;

    final useNewKernel = context.read<ClientConfigService>()
        .getBool('kernel.use_new_kernel', defaultValue: true);
    if (!useNewKernel) {
      NotificationManager.of(context)?.showWarning(
        t.completedBatchRenameUnavailableTitle,
        message: t.completedBatchRenameUnavailableMessage,
      );
      return;
    }

    final prefixController = TextEditingController();
    final suffixController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.completedBatchRenameTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.completedBatchRenameHint),
            const SizedBox(height: 12),
            Text(t.completedBatchRenamePrefixLabel),
            const SizedBox(height: 6),
            TextBox(
              controller: prefixController,
              placeholder: t.completedBatchRenamePrefixPlaceholder,
            ),
            const SizedBox(height: 12),
            Text(t.completedBatchRenameSuffixLabel),
            const SizedBox(height: 6),
            TextBox(
              controller: suffixController,
              placeholder: t.completedBatchRenameSuffixPlaceholder,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.folderPickerCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.folderPickerConfirmButton),
          ),
        ],
      ),
    );

    final prefix = prefixController.text.trim();
    final suffix = suffixController.text.trim();
    prefixController.dispose();
    suffixController.dispose();

    if (confirmed != true) return;
    if (prefix.isEmpty && suffix.isEmpty) {
      if (mounted) {
        NotificationManager.of(context)?.showWarning(
          t.completedBatchRenameTitle,
          message: t.completedBatchRenameEmptyWarningMessage,
        );
      }
      return;
    }

    final service = context.read<IntegratedDownloadService>();
    int success = 0;
    int failed = 0;

    for (final task in tasks) {
      final newName = _applyPrefixSuffix(task.fileName, prefix, suffix);
      final ok = await service.renameTaskFile(task.id, newName);
      if (ok) {
        success++;
      } else {
        failed++;
      }
    }

    if (!mounted) return;

    if (failed == 0) {
      NotificationManager.of(context)?.showSuccess(
        t.completedBatchRenameSuccessTitle,
        message: t.completedBatchRenameSuccessMessage(success),
      );
    } else {
      NotificationManager.of(context)?.showWarning(
        t.completedBatchRenameSuccessTitle,
        message: t.completedBatchRenamePartialMessage(success, failed),
      );
    }
  }

  String _applyPrefixSuffix(String fileName, String prefix, String suffix) {
    final dotIndex = fileName.lastIndexOf('.');
    final hasExt = dotIndex > 0 && dotIndex < fileName.length - 1;
    final base = hasExt ? fileName.substring(0, dotIndex) : fileName;
    final ext = hasExt ? fileName.substring(dotIndex) : '';
    return '$prefix$base$suffix$ext';
  }

  void _deleteCustomCategory(int index) {
    final category = _customCategories[index];
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.completedConfirmDeleteTitle),
        content: Text(t.completedDeleteCategoryMessage(category.name)),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: Text(t.completedCancelButton),
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

              if (!context.mounted) return;
              Navigator.pop(context);

              NotificationManager.of(context)?.showSuccess(
                  t.completedDeleteCategorySuccessTitle,
                  message: t.completedDeleteCategorySuccessMessage(category.name),
                );
            },
            child: Text(t.completedDeleteButton),
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
              CustomIcons.FluentIcons.completed,
              size: 14,
              color: AppTheme.statusSuccess,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            t.completedHeaderTitle,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.folder_open, size: 12),
                SizedBox(width: 6),
                Text(t.completedOpenFolderButton, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: ProgressRing(
              strokeWidth: 3,
              activeColor: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.loadingTasks,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.loadingTasksHint,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
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
                  child: Icon(
                    CustomIcons.FluentIcons.completed,
                    size: 40,
                    color: AppTheme.statusSuccess.withValues(alpha: 0.6),
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
                      t.completedEmptyTitle,
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
                      t.completedEmptySubtitle,
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

  const _CompletedTaskCard({super.key, required this.task});

  @override
  State<_CompletedTaskCard> createState() => _CompletedTaskCardState();
}

class _CompletedTaskCardState extends State<_CompletedTaskCard> {
  bool _isExpanded = false;
  AppLocalizations get t => AppLocalizations.of(context)!;

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
              Icon(CustomIcons.FluentIcons.chart,
                size: 14,
                color: AppTheme.accentPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                t.completedStatsTitle,
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
        icon: CustomIcons.FluentIcons.speed_high,
        label: t.completedStatsPeakSpeed,
        value: widget.task.formattedPeakSpeed,
        color: AppTheme.statusSuccess,
      ),
      _StatItem(
        icon: CustomIcons.FluentIcons.timeline_progress,
        label: t.completedStatsAverageSpeed,
        value: widget.task.formattedAverageSpeed,
        color: AppTheme.accentPrimary,
      ),
      _StatItem(
        icon: CustomIcons.FluentIcons.clock,
        label: t.completedStatsDuration,
        value: widget.task.formattedDuration,
        color: AppTheme.statusWarning,
      ),
      // 第二行：详细信息
      _StatItem(
        icon: CustomIcons.FluentIcons.split,
        label: t.completedStatsSegments,
        value: '${widget.task.segmentCount ?? 0}',
        color: AppTheme.textSecondary,
      ),
      _StatItem(
        icon: CustomIcons.FluentIcons.processing,
        label: t.completedStatsThreads,
        value: '${widget.task.threadCount ?? 0}',
        color: AppTheme.textSecondary,
      ),
      _StatItem(
        icon: CustomIcons.FluentIcons.server,
        label: t.completedStatsCore,
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
    final tags = context.watch<ClientConfigService>().getTaskTags(widget.task.id);
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
              CustomIcons.FluentIcons.check_mark,
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
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  border: Border.all(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  tag,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.accentLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(IntegratedDownloadService service) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: CustomIcons.FluentIcons.play,
          label: t.completedActionRun,
          color: AppTheme.accentPrimary,
          onPressed: () => _runFile(widget.task.filePath),
        ),
        const SizedBox(width: 6),
        _ActionButton(
          icon: CustomIcons.FluentIcons.folder_open,
          label: t.completedActionLocation,
          color: AppTheme.textSecondary,
          onPressed: () => _openFileLocation(widget.task.filePath),
        ),
        const SizedBox(width: 6),
        _IconActionButton(
          icon: CustomIcons.FluentIcons.tag,
          color: AppTheme.accentLight,
          onPressed: _editTags,
        ),
        const SizedBox(width: 6),
        _IconActionButton(
          icon: _isExpanded ? CustomIcons.FluentIcons.chevron_up : CustomIcons.FluentIcons.chevron_down,
          color: AppTheme.textSecondary,
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
        ),
        const SizedBox(width: 6),
        _IconActionButton(
          icon: CustomIcons.FluentIcons.delete,
          color: AppTheme.statusError,
          onPressed: () => _confirmDelete(service),
        ),
      ],
    );
  }

  Future<void> _editTags() async {
    final config = context.read<ClientConfigService>();
    final existing = config.getTaskTags(widget.task.id);
    final controller = TextEditingController(text: existing.join(', '));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.tagEditTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tagEditSubtitle),
            const SizedBox(height: 8),
            TextBox(
              controller: controller,
              placeholder: t.tagEditPlaceholder,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: Text(t.folderPickerCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(t.folderPickerConfirmButton),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null) {
      final tags = result
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await config.setTaskTags(widget.task.id, tags);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return t.completedTimeJustNow;
    if (diff.inHours < 1) return t.completedTimeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return t.completedTimeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return t.completedTimeDaysAgo(diff.inDays);
    
    return t.completedTimeMonthDay(date.month, date.day);
  }

  void _runFile(String? filePath) async {
    if (filePath == null) {
      _showMessage(t.completedFilePathMissingMessage);
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showMessage(t.completedFileNotFoundMessage);
        return;
      }

      final safePath = filePath.replaceAll('/', '\\');
      await Process.start('cmd', ['/c', 'start', '', safePath], runInShell: true);
    } catch (e) {
      _showMessage(t.completedRunFileFailedMessage(e));
    }
  }

  void _openFileLocation(String? filePath) async {
    if (filePath == null) {
      _showMessage(t.completedFilePathMissingMessage);
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showMessage(t.completedFileNotFoundMessage);
        return;
      }

      final safePath = filePath.replaceAll('/', '\\');
      await Process.run('explorer', ['/select,', safePath]);
    } catch (e) {
      _showMessage(t.completedOpenFileLocationFailedMessage(e));
    }
  }

  void _showMessage(String message) {
    NotificationManager.of(context)?.showWarning(
      t.completedHintTitle,
      message: message,
    );
  }

  void _confirmDelete(IntegratedDownloadService service) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        final t = AppLocalizations.of(dialogContext)!;
        return ContentDialog(
          title: Row(
            children: [
              Icon(CustomIcons.FluentIcons.delete, size: 18, color: AppTheme.statusError),
              const SizedBox(width: 8),
              Text(t.completedConfirmDeleteTitle),
            ],
          ),
          content: Text(t.completedDeleteTaskMessage(widget.task.fileName)),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CustomIcons.FluentIcons.chrome_close, size: 12),
                  const SizedBox(width: 6),
                  Text(t.completedCancelButton),
                ],
              ),
            ),
            Button(
              onPressed: () {
                service.removeTask(widget.task.id);
                Navigator.pop(dialogContext);
                if (!mounted) return;
                NotificationManager.of(this.context)?.showSuccess(
                  t.completedRemoveSuccessTitle,
                  message: t.completedRemoveSuccessMessage,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CustomIcons.FluentIcons.list, size: 12),
                  const SizedBox(width: 6),
                  Text(t.completedRemoveButton),
                ],
              ),
            ),
            FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (!mounted) return;
                await _deleteWithFile(service);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CustomIcons.FluentIcons.delete, size: 12, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(t.completedDeleteButton),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWithFile(IntegratedDownloadService service) async {
    final filePath = widget.task.filePath;
    if (filePath != null) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          if (mounted) {
            NotificationManager.of(context)?.showSuccess(
              t.completedDeleteSuccessTitle,
              message: t.completedDeleteFileSuccessMessage(widget.task.fileName),
            );
          }
        } else {
          if (mounted) {
            NotificationManager.of(context)?.showWarning(
              t.completedFileNotFoundTitle,
              message: t.completedFileNotFoundMessage,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          NotificationManager.of(context)?.showError(
            t.completedDeleteFailedTitle,
            message: t.completedDeleteFailedMessage(e),
          );
        }
      }
    }
    service.removeTask(widget.task.id);
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
        child: Container(
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
        child: Container(
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

class _TabButtonState extends State<_TabButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_TabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
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

class _CustomTabButtonState extends State<_CustomTabButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_CustomTabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
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
                    CustomIcons.FluentIcons.chrome_close,
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
