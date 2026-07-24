import 'package:fluent_ui/fluent_ui.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/quick_path_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/fluent_icons.dart' as CustomIcons;
import 'smooth_scroll_wrapper.dart';

enum FileSystemPickerMode {
  directory,
  file,
}

class FolderPickerDialog extends StatefulWidget {
  final String initialPath;
  final FileSystemPickerMode mode;

  /// Enables toggle-style selection of several files in the current folder.
  ///
  /// File mode returns a [String] when this is false and a `List<String>` when
  /// it is true. Directory mode always returns a [String].
  final bool allowMultiple;
  final List<String> allowedExtensions;
  final String? title;
  final String? selectButtonLabel;
  final String? emptyMessage;

  const FolderPickerDialog({
    super.key,
    required this.initialPath,
    this.mode = FileSystemPickerMode.directory,
    this.allowMultiple = false,
    this.allowedExtensions = const <String>[],
    this.title,
    this.selectButtonLabel,
    this.emptyMessage,
  }) : assert(
          !allowMultiple || mode == FileSystemPickerMode.file,
          'Multiple selection is only available in file mode.',
        );

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late String _currentPath;
  List<FileSystemEntity> _items = [];
  bool _loading = true; // 初始为 true，等待路径初始化
  String? _error;
  final Set<String> _selectedFilePaths = <String>{};
  final TextEditingController _pathController = TextEditingController();
  late final Set<String> _allowedExtensions;
  List<String> _drives = const <String>[];
  final List<String> _navigationHistory = <String>[];
  int _navigationHistoryIndex = -1;
  int _loadRequestId = 0;

  AppLocalizations get t => AppLocalizations.of(context)!;
  bool get _selectsFiles => widget.mode == FileSystemPickerMode.file;
  bool get _hasFileSelection => _selectedFilePaths.isNotEmpty;
  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
            'zh',
          );

  String get _dialogTitle =>
      widget.title ??
      (_selectsFiles
          ? (_isChinese ? '选择文件' : 'Select file')
          : t.folderPickerTitle);

  String get _selectButtonLabel =>
      widget.selectButtonLabel ??
      (_selectsFiles
          ? (_isChinese ? '选择文件' : 'Select file')
          : t.folderPickerSelectButton);

  String get _emptyMessage =>
      widget.emptyMessage ??
      (_selectsFiles
          ? (_isChinese ? '此位置没有符合条件的文件' : 'No matching files here')
          : t.folderPickerEmptyMessage);

  String get _selectionSummary {
    if (!_selectsFiles) return _currentPath;
    if (!_hasFileSelection) {
      return widget.allowMultiple
          ? (_isChinese ? '请选择一个或多个文件' : 'Choose one or more files')
          : (_isChinese ? '请选择一个文件' : 'Choose a file');
    }
    if (widget.allowMultiple) {
      return _isChinese
          ? '已选择 ${_selectedFilePaths.length} 个文件'
          : '${_selectedFilePaths.length} files selected';
    }
    return _selectedFilePaths.first;
  }

  String get _effectiveSelectButtonLabel {
    if (!widget.allowMultiple) return _selectButtonLabel;
    return '$_selectButtonLabel (${_selectedFilePaths.length})';
  }

  @override
  void initState() {
    super.initState();
    _allowedExtensions = widget.allowedExtensions
        .map((value) => value.trim().toLowerCase().replaceFirst('.', ''))
        .where((value) => value.isNotEmpty)
        .toSet();
    _currentPath =
        widget.initialPath.isNotEmpty ? widget.initialPath : _getDefaultPath();
    _pathController.text = _currentPath;
    _initializePath();
    _loadDrives();
  }

  Future<void> _initializePath() async {
    var pathToLoad = _normalizeInputPath(widget.initialPath);

    // 如果初始路径为空或无效，使用默认路径
    if (pathToLoad.isEmpty) {
      pathToLoad = _getDefaultPath();
    } else if (_selectsFiles && await _fileExistsSafe(pathToLoad)) {
      if (_isFileAllowed(pathToLoad)) {
        _selectedFilePaths.add(
          path.normalize(File(pathToLoad).absolute.path),
        );
      }
      pathToLoad = path.dirname(File(pathToLoad).absolute.path);
    } else {
      // 检查路径是否存在
      if (!await _directoryExistsSafe(pathToLoad)) {
        final parentPath = path.dirname(File(pathToLoad).absolute.path);
        pathToLoad = _selectsFiles &&
                parentPath != pathToLoad &&
                await _directoryExistsSafe(parentPath)
            ? parentPath
            : _getDefaultPath();
      }
    }

    if (!mounted) return;
    _currentPath = pathToLoad;
    _pathController.text = _currentPath;
    _loadDirectory(_currentPath);
  }

  String _getDefaultPath() {
    // 获取用户下载目录
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        (Platform.isWindows ? 'C:\\' : Platform.pathSeparator);
    final downloads = path.join(home, 'Downloads');

    // 如果下载目录存在，使用它；否则使用用户目录
    if (_directoryExistsSafeSync(downloads)) {
      return downloads;
    } else if (_directoryExistsSafeSync(home)) {
      return home;
    }

    // 最后回退到当前平台的文件系统根目录
    return Platform.isWindows ? 'C:\\' : Platform.pathSeparator;
  }

  Future<bool> _directoryExistsSafe(String path) async {
    try {
      return await Directory(path).exists();
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> _fileExistsSafe(String filePath) async {
    try {
      return await File(filePath).exists();
    } on FileSystemException {
      return false;
    }
  }

  bool _directoryExistsSafeSync(String path) {
    try {
      return Directory(path).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<bool> _loadDirectory(
    String directoryPath, {
    bool recordHistory = true,
  }) async {
    final requestId = ++_loadRequestId;
    if (!mounted) return false;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        if (!mounted || requestId != _loadRequestId) return false;
        setState(() {
          _error = t.folderPickerErrorPathNotFound;
          _loading = false;
        });
        return false;
      }

      // 尝试列出目录内容，捕获权限错误
      List<FileSystemEntity> items;
      try {
        items = await dir.list().toList();
      } catch (e) {
        // 权限被拒绝或其他错误
        if (!mounted || requestId != _loadRequestId) return false;
        setState(() {
          _error = t.folderPickerErrorAccessDenied;
          _items = [];
          _currentPath = directoryPath;
          _pathController.text = directoryPath;
          _loading = false;
        });
        return false;
      }

      // 文件夹始终显示；文件模式再显示符合过滤条件的文件。
      final folders = items.whereType<Directory>().toList()
        ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      final files = _selectsFiles
          ? (items
              .whereType<File>()
              .where((item) => _isFileAllowed(item.path))
              .toList()
            ..sort(
              (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
            ))
          : const <File>[];
      final normalizedPath = path.normalize(dir.absolute.path);

      if (!mounted || requestId != _loadRequestId) return false;
      setState(() {
        _items = <FileSystemEntity>[...folders, ...files];
        _currentPath = normalizedPath;
        _pathController.text = normalizedPath;
        _selectedFilePaths.removeWhere(
          (selectedFilePath) =>
              !path.equals(path.dirname(selectedFilePath), normalizedPath) ||
              !files.any(
                (file) => path.equals(file.absolute.path, selectedFilePath),
              ),
        );
        if (recordHistory) {
          _recordNavigation(normalizedPath);
        }
        _loading = false;
      });
      return true;
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return false;
      setState(() {
        _error = t.folderPickerErrorAccessFailed(e.toString());
        _loading = false;
      });
      return false;
    }
  }

  void _recordNavigation(String directoryPath) {
    if (_navigationHistoryIndex >= 0 &&
        path.equals(
          _navigationHistory[_navigationHistoryIndex],
          directoryPath,
        )) {
      return;
    }
    if (_navigationHistoryIndex < _navigationHistory.length - 1) {
      _navigationHistory.removeRange(
        _navigationHistoryIndex + 1,
        _navigationHistory.length,
      );
    }
    _navigationHistory.add(directoryPath);
    _navigationHistoryIndex = _navigationHistory.length - 1;
  }

  Future<void> _navigateBack() async {
    if (_navigationHistoryIndex <= 0) return;
    final targetIndex = _navigationHistoryIndex - 1;
    final loaded = await _loadDirectory(
      _navigationHistory[targetIndex],
      recordHistory: false,
    );
    if (loaded && mounted) {
      setState(() => _navigationHistoryIndex = targetIndex);
    }
  }

  Future<void> _navigateForward() async {
    if (_navigationHistoryIndex >= _navigationHistory.length - 1) return;
    final targetIndex = _navigationHistoryIndex + 1;
    final loaded = await _loadDirectory(
      _navigationHistory[targetIndex],
      recordHistory: false,
    );
    if (loaded && mounted) {
      setState(() => _navigationHistoryIndex = targetIndex);
    }
  }

  void _navigateToParent() {
    final dir = Directory(_currentPath);
    final parent = dir.parent;
    if (!path.equals(parent.absolute.path, dir.absolute.path)) {
      _loadDirectory(parent.path);
    }
  }

  void _navigateToPath(String path) {
    _loadDirectory(path);
  }

  String _getEntityName(String entityPath) {
    final name = path.basename(entityPath);
    return name.isEmpty ? entityPath : name;
  }

  String _normalizeInputPath(String value) {
    var normalized = value.trim();
    if (normalized.length >= 2 &&
        normalized.startsWith('"') &&
        normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    return normalized;
  }

  bool _isFileAllowed(String filePath) {
    if (_allowedExtensions.isEmpty) return true;
    final extension =
        path.extension(filePath).toLowerCase().replaceFirst('.', '');
    return _allowedExtensions.contains(extension);
  }

  Future<void> _navigateFromInput(String value) async {
    final normalized = _normalizeInputPath(value);
    if (normalized.isEmpty) return;
    if (_selectsFiles && await _fileExistsSafe(normalized)) {
      if (!_isFileAllowed(normalized)) {
        if (!mounted) return;
        setState(() {
          _error = _isChinese
              ? '该文件类型不受当前选择器支持'
              : 'This file type is not supported by the current picker';
        });
        return;
      }
      final absoluteFilePath = path.normalize(File(normalized).absolute.path);
      await _loadDirectory(path.dirname(absoluteFilePath));
      if (!mounted) return;
      _selectFile(absoluteFilePath, toggle: false);
      return;
    }
    await _loadDirectory(normalized);
  }

  void _selectFile(String filePath, {bool toggle = true}) {
    final normalizedFilePath = path.normalize(File(filePath).absolute.path);
    setState(() {
      if (!widget.allowMultiple) {
        _selectedFilePaths
          ..clear()
          ..add(normalizedFilePath);
      } else if (!toggle || !_selectedFilePaths.contains(normalizedFilePath)) {
        _selectedFilePaths.add(normalizedFilePath);
      } else {
        _selectedFilePaths.remove(normalizedFilePath);
      }
      _error = null;
    });
  }

  void _confirmSelection() {
    if (!_selectsFiles) {
      Navigator.pop(context, _currentPath);
      return;
    }
    if (_selectedFilePaths.isEmpty) return;
    if (widget.allowMultiple) {
      Navigator.pop(
        context,
        List<String>.unmodifiable(_selectedFilePaths),
      );
    } else {
      Navigator.pop(context, _selectedFilePaths.first);
    }
  }

  void _clearSelection() {
    setState(_selectedFilePaths.clear);
  }

  Future<void> _createNewFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.folderPickerCreateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.folderPickerCreatePrompt),
            const SizedBox(height: 8),
            Text(
              _currentPath,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextBox(
              controller: controller,
              placeholder: t.folderPickerCreatePlaceholder,
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
            child: Text(t.folderPickerCreateButton),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final newFolderPath = path.join(_currentPath, result);
        final newFolder = Directory(newFolderPath);

        if (await newFolder.exists()) {
          // 文件夹已存在，导航到该文件夹
          await _loadDirectory(newFolderPath);

          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => ContentDialog(
                title: Text(t.folderPickerCreateExistsTitle),
                content: Text(t.folderPickerCreateExistsMessage(result)),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t.folderPickerConfirmButton),
                  ),
                ],
              ),
            );
          }
          return;
        }

        await newFolder.create(recursive: true);

        // 创建成功后，导航到新创建的文件夹
        await _loadDirectory(newFolderPath);

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: Text(t.folderPickerCreateSuccessTitle),
              content: Text(t.folderPickerCreateSuccessMessage(result)),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.folderPickerConfirmButton),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: Text(t.folderPickerCreateFailedTitle),
              content: Text(t.folderPickerCreateFailedMessage(e.toString())),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.folderPickerConfirmButton),
                ),
              ],
            ),
          );
        }
      }
    }

    controller.dispose();
  }

  Future<void> _loadDrives() async {
    if (!Platform.isWindows) return;
    final candidates = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        .split('')
        .map((letter) => '$letter:\\')
        .toList(growable: false);
    final checks = await Future.wait(
      candidates.map((drive) async {
        try {
          final exists = await Directory(drive)
              .exists()
              .timeout(const Duration(milliseconds: 500));
          return exists ? drive : null;
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _drives = checks.whereType<String>().toList(growable: false);
    });
  }

  Widget _buildSidebar(BuildContext context, {required bool compact}) {
    final quickPathService = context.watch<QuickPathService>();
    final quickPaths = quickPathService.quickPaths;
    return Container(
      width: compact ? 58 : 188,
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1,
        border: Border(
          right: BorderSide(color: AppTheme.borderDefault),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 6 : 8,
                10,
                compact ? 6 : 8,
                10,
              ),
              children: [
                _SidebarSectionLabel(
                  label: _isChinese ? '快速访问' : 'Quick access',
                  compact: compact,
                ),
                const SizedBox(height: 4),
                ...quickPaths.map(
                  (quickPath) => _SidebarItem(
                    icon: _quickPathIcon(quickPath),
                    label: quickPath.name,
                    compact: compact,
                    selected: path.equals(_currentPath, quickPath.path),
                    onPressed: () => _navigateToPath(quickPath.path),
                    onRemove: () => _removeQuickPath(context, quickPath.path),
                    removeTooltip: _isChinese ? '取消固定' : 'Unpin',
                  ),
                ),
                const SizedBox(height: 14),
                _SidebarSectionLabel(
                  label: _isChinese ? '此电脑' : 'This PC',
                  compact: compact,
                ),
                const SizedBox(height: 4),
                ..._drives.map(
                  (drive) => _SidebarItem(
                    icon: CustomIcons.FluentIcons.hard_drive,
                    label: drive,
                    compact: compact,
                    selected: path.equals(_currentPath, drive),
                    onPressed: () => _navigateToPath(drive),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: _SidebarItem(
              icon: CustomIcons.FluentIcons.pin_24,
              label: _isChinese ? '固定当前位置' : 'Pin current folder',
              compact: compact,
              onPressed: () => _addQuickPath(context),
            ),
          ),
        ],
      ),
    );
  }

  IconData _quickPathIcon(QuickPath quickPath) {
    final value = quickPath.name.trim().toLowerCase();
    if (value.contains('桌面') || value.contains('desktop')) {
      return CustomIcons.FluentIcons.desktop_24;
    }
    if (value.contains('文档') || value.contains('document')) {
      return CustomIcons.FluentIcons.document_24;
    }
    if (value.contains('下载') || value.contains('download')) {
      return CustomIcons.FluentIcons.download;
    }
    if (value.contains('图片') || value.contains('picture')) {
      return CustomIcons.FluentIcons.getIcon('image_24');
    }
    if (value.contains('视频') || value.contains('video')) {
      return CustomIcons.FluentIcons.video_24;
    }
    if (value.contains('音乐') || value.contains('music')) {
      return CustomIcons.FluentIcons.music_note_2_24;
    }
    return CustomIcons.FluentIcons.folder_24;
  }

  Future<void> _addQuickPath(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.folderPickerQuickPathAddTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.folderPickerQuickPathAddPrompt),
            const SizedBox(height: 8),
            Text(
              _currentPath,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.folderPickerQuickPathAddNameLabel,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextBox(
              controller: controller,
              placeholder: t.folderPickerQuickPathAddNamePlaceholder,
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
            onPressed: () => Navigator.pop(context, {
              'path': _currentPath,
              'name': controller.text,
            }),
            child: Text(t.folderPickerQuickPathAddButton),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final quickPathService =
          Provider.of<QuickPathService>(context, listen: false);
      final success = await quickPathService.addQuickPath(
        result['path']!,
        customName: result['name']!.isEmpty ? null : result['name'],
      );

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: Text(
              success
                  ? t.folderPickerQuickPathAddSuccessTitle
                  : t.folderPickerQuickPathAddFailedTitle,
            ),
            content: Text(
              success
                  ? t.folderPickerQuickPathAddSuccessMessage
                  : t.folderPickerQuickPathAddFailedMessage,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.folderPickerConfirmButton),
              ),
            ],
          ),
        );
      }
    }

    controller.dispose();
  }

  Future<void> _removeQuickPath(BuildContext context, String pathStr) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.folderPickerQuickPathRemoveTitle),
        content: Text(t.folderPickerQuickPathRemoveMessage(pathStr)),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.folderPickerCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.folderPickerQuickPathRemoveButton),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final quickPathService =
          Provider.of<QuickPathService>(context, listen: false);
      await quickPathService.removeQuickPath(pathStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 880, maxHeight: 650),
      style: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: AppTheme.bgLayer1,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.borderStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(20, 17, 20, 15),
        bodyPadding: EdgeInsets.zero,
        titleStyle: theme.typography.subtitle?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        actionsSpacing: 8,
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        actionsDecoration: BoxDecoration(
          color: AppTheme.bgLayer1,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppTheme.radiusXl),
          ),
          border: Border(
            top: BorderSide(color: AppTheme.borderDefault),
          ),
        ),
      ),
      title: Row(
        children: [
          Icon(
            _selectsFiles
                ? CustomIcons.FluentIcons.document_24
                : CustomIcons.FluentIcons.folder_open_24,
            size: 20,
            color: AppTheme.accentLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dialogTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 860,
        height: 500,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final showTypeColumn = constraints.maxWidth >= 620;
            return Container(
              color: AppTheme.bgBase,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(context, compact: compact),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCommandBar(compact: compact),
                        Expanded(
                          child: _buildFilePane(
                            context,
                            showTypeColumn: showTypeColumn,
                          ),
                        ),
                        _buildStatusBar(compact: compact),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              child: Button(
                onPressed: () => Navigator.pop(context),
                child: Text(t.folderPickerCancelButton),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 112),
              child: FilledButton(
                onPressed: _selectsFiles && !_hasFileSelection
                    ? null
                    : _confirmSelection,
                child: Text(_effectiveSelectButtonLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommandBar({required bool compact}) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderDefault),
        ),
      ),
      child: Row(
        children: [
          _CommandBarButton(
            icon: CustomIcons.FluentIcons.getIcon('arrow_left_20'),
            tooltip: _isChinese ? '后退' : 'Back',
            onPressed: _navigationHistoryIndex > 0 ? _navigateBack : null,
          ),
          _CommandBarButton(
            icon: CustomIcons.FluentIcons.getIcon('arrow_right_20'),
            tooltip: _isChinese ? '前进' : 'Forward',
            onPressed: _navigationHistoryIndex >= 0 &&
                    _navigationHistoryIndex < _navigationHistory.length - 1
                ? _navigateForward
                : null,
          ),
          _CommandBarButton(
            icon: CustomIcons.FluentIcons.arrow_up_20,
            tooltip: t.folderPickerNavUpTooltip,
            onPressed: _navigateToParent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextBox(
              controller: _pathController,
              placeholder: t.folderPickerPathPlaceholder,
              prefix: Padding(
                padding: const EdgeInsets.only(left: 9, right: 3),
                child: Icon(
                  CustomIcons.FluentIcons.folder_open_20,
                  size: 15,
                  color: AppTheme.textSecondary,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              style: const TextStyle(fontSize: 12),
              onSubmitted: _navigateFromInput,
            ),
          ),
          const SizedBox(width: 8),
          _CommandBarButton(
            icon: CustomIcons.FluentIcons.refresh,
            tooltip: t.folderPickerRefreshTooltip,
            onPressed: () => _loadDirectory(
              _currentPath,
              recordHistory: false,
            ),
          ),
          const SizedBox(width: 4),
          Button(
            onPressed: _createNewFolder,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.add_20, size: 15),
                if (!compact) ...[
                  const SizedBox(width: 7),
                  Text(_isChinese ? '新建文件夹' : 'New folder'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePane(
    BuildContext context, {
    required bool showTypeColumn,
  }) {
    return Container(
      color: AppTheme.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.only(
              left: 14,
              right: 14,
            ),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderDefault),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _isChinese ? '名称' : 'Name',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (showTypeColumn)
                  SizedBox(
                    width: 128,
                    child: Text(
                      _isChinese ? '类型' : 'Type',
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: ProgressRing())
                : _error != null
                    ? _buildErrorState()
                    : _items.isEmpty
                        ? _buildEmptyState(context)
                        : _buildItemList(showTypeColumn: showTypeColumn),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar({required bool compact}) {
    final extensions = _allowedExtensions.map((value) => '.$value').join(', ');
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1,
        border: Border(
          top: BorderSide(color: AppTheme.borderDefault),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasFileSelection
                ? CustomIcons.FluentIcons.checkmark_20
                : (_selectsFiles
                    ? CustomIcons.FluentIcons.document_20
                    : CustomIcons.FluentIcons.folder_20),
            size: 15,
            color: _hasFileSelection
                ? AppTheme.accentLight
                : AppTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectionSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          if (widget.allowMultiple && _hasFileSelection) ...[
            const SizedBox(width: 8),
            Button(
              onPressed: _clearSelection,
              child: Text(_isChinese ? '清除选择' : 'Clear selection'),
            ),
          ],
          if (!compact && _selectsFiles && extensions.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              '${_isChinese ? '文件类型' : 'File type'}: $extensions',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.statusError.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CustomIcons.FluentIcons.error,
                size: 24,
                color: AppTheme.statusError,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.statusError, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CustomIcons.FluentIcons.folder,
            size: 32,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            _emptyMessage,
            style: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList({required bool showTypeColumn}) {
    return SmoothListView.builder(
      config: SmoothScrollConfig.fast,
      padding: const EdgeInsets.symmetric(vertical: 3),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isDirectory = item is Directory;
        final normalizedItemPath = path.normalize(item.absolute.path);
        return _PickerItem(
          key: ValueKey<String>(normalizedItemPath),
          isDirectory: isDirectory,
          showSelectionCheckbox: widget.allowMultiple && !isDirectory,
          showTypeColumn: showTypeColumn,
          isSelected: !isDirectory &&
              _selectedFilePaths.any(
                (selectedPath) => path.equals(
                  selectedPath,
                  normalizedItemPath,
                ),
              ),
          name: _getEntityName(item.path),
          typeLabel: _entityTypeLabel(item),
          onPressed: () {
            if (isDirectory) {
              _navigateToPath(item.path);
            } else {
              _selectFile(item.path);
            }
          },
          onDoublePressed: isDirectory || widget.allowMultiple
              ? null
              : () {
                  _selectFile(item.path);
                  _confirmSelection();
                },
        );
      },
    );
  }

  String _entityTypeLabel(FileSystemEntity entity) {
    if (entity is Directory) {
      return _isChinese ? '文件夹' : 'File folder';
    }
    final extension = path.extension(entity.path).replaceFirst('.', '');
    if (extension.isEmpty) {
      return _isChinese ? '文件' : 'File';
    }
    return _isChinese
        ? '${extension.toUpperCase()} 文件'
        : '${extension.toUpperCase()} file';
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({
    required this.label,
    required this.compact,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(
            style: DividerThemeData(
                decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
        ))),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 3),
      child: Text(
        label,
        style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onPressed,
    this.selected = false,
    this.onRemove,
    this.removeTooltip,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                : _hovered
                    ? AppTheme.surfaceCardHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              if (widget.selected)
                Positioned(
                  left: widget.compact ? 0 : -10,
                  top: 9,
                  bottom: 9,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: widget.compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 16,
                        color: widget.selected
                            ? AppTheme.accentLight
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (!widget.compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.selected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_hovered && widget.onRemove != null)
                      Tooltip(
                        message: widget.removeTooltip ?? '',
                        child: GestureDetector(
                          onTap: widget.onRemove,
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Icon(
                              CustomIcons.FluentIcons.dismiss_20,
                              size: 13,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Tooltip(
      message: widget.compact ? widget.label : '',
      child: item,
    );
  }
}

class _CommandBarButton extends StatelessWidget {
  const _CommandBarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
      ),
    );
  }
}

/// 文件系统项目
class _PickerItem extends StatefulWidget {
  final String name;
  final String typeLabel;
  final bool isDirectory;
  final bool isSelected;
  final bool showSelectionCheckbox;
  final bool showTypeColumn;
  final VoidCallback onPressed;
  final VoidCallback? onDoublePressed;

  const _PickerItem({
    super.key,
    required this.name,
    required this.typeLabel,
    required this.isDirectory,
    required this.isSelected,
    required this.showSelectionCheckbox,
    required this.showTypeColumn,
    required this.onPressed,
    this.onDoublePressed,
  });

  @override
  State<_PickerItem> createState() => _PickerItemState();
}

class _PickerItemState extends State<_PickerItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        onDoubleTap: widget.onDoublePressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 39,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.accentPrimary.withValues(alpha: 0.22)
                : _isHovered
                    ? AppTheme.surfaceCardHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.showSelectionCheckbox) ...[
                Checkbox(
                  checked: widget.isSelected,
                  onChanged: (_) => widget.onPressed(),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                widget.isDirectory
                    ? CustomIcons.FluentIcons.folder
                    : CustomIcons.FluentIcons.document,
                size: 18,
                color: widget.isSelected
                    ? AppTheme.accentLight
                    : widget.isDirectory
                        ? const Color(0xFFFFC83D)
                        : AppTheme.textSecondary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontWeight:
                        widget.isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.showTypeColumn)
                SizedBox(
                  width: 128,
                  child: Text(
                    widget.typeLabel,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else if (widget.isDirectory && _isHovered)
                Icon(
                  CustomIcons.FluentIcons.chevron_right,
                  size: 12,
                  color: AppTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
