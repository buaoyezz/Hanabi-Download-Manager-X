import 'dart:io';
import 'animated_notifications.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/app_logger_service.dart';
import '../utils/fluent_icons.dart' as CustomIcons;
import '../l10n/app_localizations.dart';
import 'smooth_scroll_wrapper.dart';

/// 临时文件信息
class TempFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modifiedTime;
  final double? progress; // 如果能解析出进度信息
  bool isSelected;

  TempFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modifiedTime,
    this.progress,
    this.isSelected = false,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get timeFormatted {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(modifiedTime);
  }
}

/// 临时文件清理对话框
class TempFilesDialog extends StatefulWidget {
  final String downloadPath;

  const TempFilesDialog({
    super.key,
    required this.downloadPath,
  });

  @override
  State<TempFilesDialog> createState() => _TempFilesDialogState();
}

class _TempFilesDialogState extends State<TempFilesDialog> {
  List<TempFileInfo> _tempFiles = [];
  bool _loading = true;
  bool _selectAll = false;
  String _sortBy = 'name'; // name, size, time
  bool _sortAscending = true;
  bool _includeTempDirs = true; // 是否包含临时目录中的文件

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 延迟执行，避免在 build 过程中调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanTempFiles();
    });
  }

  Future<void> _scanTempFiles() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final logger = AppLoggerService();

    try {
      final dir = Directory(widget.downloadPath);
      // 使用 debugPrint 代替 logger.info，避免触发 notifyListeners
      debugPrint('开始扫描临时文件: ${widget.downloadPath}');

      if (!await dir.exists()) {
        logger.warning('App', '下载目录不存在: ${widget.downloadPath}');
        setState(() => _loading = false);
        return;
      }

      final List<TempFileInfo> tempFiles = [];

      // 支持多种临时文件扩展名和模式
      final tempExtensions = [
        '.temp',
        '.tmp',
        '.download',
        '.crdownload', // Chrome
        '.partial', // Firefox
        '.!ut', // uTorrent
      ];

      // 支持分段文件模式（如 .part0, .part1, .part123）
      final partFilePattern = RegExp(r'\.part\d+$', caseSensitive: false);

      // 临时目录模式（如 xxx_temp, xxx_temp_2）
      final tempDirPattern = RegExp(r'_temp(_\d+)?$', caseSensitive: false);

      logger.info(
          'App', '扫描临时文件扩展名: ${tempExtensions.join(", ")} 和 .partN 分段文件');
      if (_includeTempDirs) {
        logger.info('App', '同时扫描临时目录: *_temp, *_temp_N');
      }

      // 递归扫描目录（包括子目录）
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final parentDir =
              entity.parent.path.split(Platform.pathSeparator).last;

          // 检查是否在临时目录中
          final isInTempDir =
              _includeTempDirs && tempDirPattern.hasMatch(parentDir);

          // 检查是否是临时文件
          final isTempFile =
              tempExtensions.any((ext) => fileName.endsWith(ext)) ||
                  partFilePattern.hasMatch(fileName) ||
                  isInTempDir;

          if (isTempFile) {
            try {
              final stat = await entity.stat();

              // 尝试解析进度信息
              double? progress;

              // 尝试从文件名解析进度（某些下载器会在文件名中包含进度）
              final progressMatch = RegExp(r'(\d+)%').firstMatch(fileName);
              if (progressMatch != null) {
                final progressValue = double.tryParse(progressMatch.group(1)!);
                if (progressValue != null) {
                  progress = progressValue / 100;
                }
              }

              // 尝试从 .progress 文件读取
              if (progress == null) {
                final progressFile = File('${entity.path}.progress');
                if (await progressFile.exists()) {
                  try {
                    final content = await progressFile.readAsString();
                    progress = double.tryParse(content);
                  } catch (_) {}
                }
              }

              tempFiles.add(TempFileInfo(
                path: entity.path,
                name: fileName,
                size: stat.size,
                modifiedTime: stat.modified,
                progress: progress,
              ));

              logger.debug('App', '找到临时文件: $fileName (${stat.size} bytes)');
            } catch (e) {
              logger.warning('App', '无法读取文件信息: ${entity.path}, 错误: $e');
            }
          }
        }
      }

      logger.info('App', '扫描完成，找到 ${tempFiles.length} 个临时文件');

      if (mounted) {
        setState(() {
          _tempFiles = tempFiles;
          _loading = false;
        });
        _sortFiles();
      }
    } catch (e) {
      logger.error('App', '扫描临时文件失败: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _sortFiles() {
    setState(() {
      switch (_sortBy) {
        case 'name':
          _tempFiles.sort((a, b) => _sortAscending
              ? a.name.compareTo(b.name)
              : b.name.compareTo(a.name));
          break;
        case 'size':
          _tempFiles.sort((a, b) => _sortAscending
              ? a.size.compareTo(b.size)
              : b.size.compareTo(a.size));
          break;
        case 'time':
          _tempFiles.sort((a, b) => _sortAscending
              ? a.modifiedTime.compareTo(b.modifiedTime)
              : b.modifiedTime.compareTo(a.modifiedTime));
          break;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      for (var file in _tempFiles) {
        file.isSelected = _selectAll;
      }
    });
  }

  Future<void> _deleteSelected() async {
    final t = AppLocalizations.of(context)!;
    final selected = _tempFiles.where((f) => f.isSelected).toList();
    if (selected.isEmpty) return;

    final logger = AppLoggerService();
    final totalSize = selected.fold<int>(0, (sum, f) => sum + f.size);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text(t.tempFilesDeleteConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tempFilesDeleteConfirmMessage(selected.length)),
            const SizedBox(height: 8),
            Text(
              t.tempFilesDeleteTotalSize(_formatSize(totalSize)),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.statusWarning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(CustomIcons.FluentIcons.warning,
                      size: 16, color: AppTheme.statusWarning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.tempFilesDeleteWarning,
                      style: TextStyle(
                          color: AppTheme.statusWarning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.tempFilesCancelButton),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.tempFilesDeleteButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    logger.info('App', '开始删除 ${selected.length} 个临时文件');
    int successCount = 0;
    int failedCount = 0;

    for (final file in selected) {
      try {
        logger.debug('App', '删除文件: ${file.path}');
        await File(file.path).delete();

        // 同时删除可能存在的 .progress 文件
        final progressFile = File('${file.path}.progress');
        if (await progressFile.exists()) {
          await progressFile.delete();
          logger.debug('App', '删除进度文件: ${progressFile.path}');
        }

        successCount++;
        logger.info('App', '成功删除: ${file.name}');
      } catch (e) {
        failedCount++;
        logger.error('App', '删除失败: ${file.path}, 错误: $e');
      }
    }

    logger.info('App', '删除完成: 成功 $successCount, 失败 $failedCount');

    if (mounted) {
      if (failedCount > 0) {
        NotificationManager.of(context)?.showWarning(
          t.tempFilesDeleteDoneTitle,
          message: t.tempFilesDeleteDoneWithFailures(successCount, failedCount),
        );
      } else {
        NotificationManager.of(context)?.showSuccess(
          t.tempFilesDeleteDoneTitle,
          message: t.tempFilesDeleteDoneSuccess(successCount),
        );
      }
      await _scanTempFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final selectedCount = _tempFiles.where((f) => f.isSelected).length;
    final totalSize = _tempFiles.fold<int>(0, (sum, f) => sum + f.size);
    final selectedSize = _tempFiles
        .where((f) => f.isSelected)
        .fold<int>(0, (sum, f) => sum + f.size);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(CustomIcons.FluentIcons.delete, size: 20),
              const SizedBox(width: 12),
              Text(t.tempFilesDialogTitle),
              const Spacer(),
              if (!_loading)
                IconButton(
                  icon: Icon(CustomIcons.FluentIcons.refresh, size: 16),
                  onPressed: _scanTempFiles,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.tempFilesDialogScanPath(widget.downloadPath),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 统计信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                _buildStatChip(
                  t.tempFilesStatFiles,
                  '${_tempFiles.length}',
                  CustomIcons.FluentIcons.document,
                  AppTheme.accentPrimary,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  t.tempFilesStatTotalSize,
                  _formatSize(totalSize),
                  CustomIcons.FluentIcons.hard_drive,
                  AppTheme.statusInfo,
                ),
                const SizedBox(width: 12),
                if (selectedCount > 0)
                  _buildStatChip(
                    t.tempFilesStatSelected,
                    '$selectedCount (${_formatSize(selectedSize)})',
                    CustomIcons.FluentIcons.checkbox_composite,
                    AppTheme.statusWarning,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                Icon(CustomIcons.FluentIcons.info,
                    size: 12, color: AppTheme.accentLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.tempFilesSupportedFormats,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 工具栏
          Row(
            children: [
              Checkbox(
                checked: _selectAll,
                onChanged: (_) => _toggleSelectAll(),
                content: Text(t.tempFilesSelectAll),
              ),
              const SizedBox(width: 12),
              Checkbox(
                checked: _includeTempDirs,
                onChanged: (v) {
                  setState(() => _includeTempDirs = v ?? true);
                  _scanTempFiles();
                },
                content: Text(t.tempFilesIncludeTempDirs),
              ),
              const Spacer(),
              Text(t.tempFilesSortLabel,
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              ComboBox<String>(
                value: _sortBy,
                items: [
                  ComboBoxItem(value: 'name', child: Text(t.tempFilesSortName)),
                  ComboBoxItem(value: 'size', child: Text(t.tempFilesSortSize)),
                  ComboBoxItem(value: 'time', child: Text(t.tempFilesSortTime)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sortBy = value);
                    _sortFiles();
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _sortAscending
                      ? CustomIcons.FluentIcons.sort_up
                      : CustomIcons.FluentIcons.sort_down,
                  size: 16,
                ),
                onPressed: () {
                  setState(() => _sortAscending = !_sortAscending);
                  _sortFiles();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 文件列表
          Expanded(
            child: _loading
                ? const Center(child: ProgressRing())
                : _tempFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CustomIcons.FluentIcons.completed,
                              size: 48,
                              color: AppTheme.statusSuccess,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t.tempFilesEmpty,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : SmoothListView.builder(
                        config: SmoothScrollConfig.fast,
                        itemCount: _tempFiles.length,
                        itemBuilder: (context, index) {
                          final file = _tempFiles[index];
                          return _buildFileItem(file);
                        },
                      ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: Text(t.tempFilesCloseButton),
        ),
        if (selectedCount > 0)
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: _deleteSelected,
            child: Text(t.tempFilesDeleteSelected(selectedCount)),
          ),
      ],
    );
  }

  Widget _buildStatChip(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(TempFileInfo file) {
    // 计算相对路径
    final relativePath = file.path
        .replaceFirst(widget.downloadPath, '')
        .replaceFirst(Platform.pathSeparator, '');
    final isInSubDir = relativePath.contains(Platform.pathSeparator);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: file.isSelected
            ? AppTheme.accentPrimary.withValues(alpha: 0.1)
            : AppTheme.cardBackground(darkAlpha: 0.5, lightAlpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: file.isSelected
              ? AppTheme.accentPrimary.withValues(alpha: 0.5)
              : AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            checked: file.isSelected,
            onChanged: (_) {
              setState(() => file.isSelected = !file.isSelected);
            },
          ),
          const SizedBox(width: 12),
          Icon(
            isInSubDir
                ? CustomIcons.FluentIcons.folder_open
                : CustomIcons.FluentIcons.document,
            size: 16,
            color: isInSubDir ? AppTheme.statusWarning : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isInSubDir)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      relativePath.substring(
                          0, relativePath.lastIndexOf(Platform.pathSeparator)),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (file.progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: ProgressBar(
                            value: file.progress! * 100,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(file.progress! * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              file.sizeFormatted,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: 'Courier New',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              file.timeFormatted,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
