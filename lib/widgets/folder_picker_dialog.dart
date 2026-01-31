import 'package:fluent_ui/fluent_ui.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/quick_path_service.dart';

class FolderPickerDialog extends StatefulWidget {
  final String initialPath;

  const FolderPickerDialog({
    super.key,
    required this.initialPath,
  });

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late String _currentPath;
  List<FileSystemEntity> _items = [];
  bool _loading = true;  // 初始为 true，等待路径初始化
  String? _error;
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializePath();
  }

  Future<void> _initializePath() async {
    String pathToLoad = widget.initialPath;
    
    // 如果初始路径为空或无效，使用默认路径
    if (pathToLoad.isEmpty) {
      pathToLoad = _getDefaultPath();
    } else {
      // 检查路径是否存在
      final dir = Directory(pathToLoad);
      if (!await dir.exists()) {
        pathToLoad = _getDefaultPath();
      }
    }
    
    _currentPath = pathToLoad;
    _pathController.text = _currentPath;
    _loadDirectory(_currentPath);
  }

  String _getDefaultPath() {
    // 获取用户下载目录
    final home = Platform.environment['USERPROFILE'] ?? 
                 Platform.environment['HOME'] ?? 
                 'C:\\';
    final downloads = '$home\\Downloads';
    
    // 如果下载目录存在，使用它；否则使用用户目录
    if (Directory(downloads).existsSync()) {
      return downloads;
    } else if (Directory(home).existsSync()) {
      return home;
    }
    
    // 最后回退到 C 盘
    return 'C:\\';
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        setState(() {
          _error = '路径不存在';
          _loading = false;
        });
        return;
      }

      // 尝试列出目录内容，捕获权限错误
      List<FileSystemEntity> items;
      try {
        items = await dir.list().toList();
      } catch (e) {
        // 权限被拒绝或其他错误
        setState(() {
          _error = '无法访问此路径（权限不足）';
          _items = [];
          _currentPath = path;
          _pathController.text = path;
          _loading = false;
        });
        return;
      }

      // 只显示文件夹，并排序
      final folders = items
          .where((item) => item is Directory)
          .toList()
        ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      setState(() {
        _items = folders;
        _currentPath = path;
        _pathController.text = path;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '无法访问此路径: $e';
        _loading = false;
      });
    }
  }

  void _navigateToParent() {
    final dir = Directory(_currentPath);
    final parent = dir.parent;
    if (parent.path != _currentPath) {
      _loadDirectory(parent.path);
    }
  }

  void _navigateToPath(String path) {
    _loadDirectory(path);
  }

  String _getFolderName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  Future<void> _createNewFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('新建文件夹'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('在以下位置创建新文件夹：'),
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
              placeholder: '文件夹名称',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
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
                title: const Text('创建取消'),
                content: Text('文件夹 "$result" 已存在\n已自动选择到该文件夹'),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('确定'),
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
              title: const Text('创建成功'),
              content: Text('文件夹 "$result" 已创建并选择'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
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
              title: const Text('创建失败'),
              content: Text('无法创建文件夹: $e'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      }
    }

    controller.dispose();
  }

  List<String> _getDrives() {
    // Windows 驱动器列表
    final drives = <String>[];
    for (var letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      final drive = '$letter:\\';
      if (Directory(drive).existsSync()) {
        drives.add(drive);
      }
    }
    return drives;
  }

  Widget _buildDrivesAndQuickPaths(BuildContext context) {
    final quickPathService = context.watch<QuickPathService>();
    final quickPaths = quickPathService.quickPaths;
    final drives = _getDrives();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // 驱动器按钮
        ...drives.map((drive) {
          return _DriveButton(
            drive: drive,
            onPressed: () => _navigateToPath(drive),
          );
        }),
        
        // 快捷路径按钮
        ...quickPaths.map((quickPath) {
          return _QuickPathButton(
            quickPath: quickPath,
            onPressed: () => _navigateToPath(quickPath.path),
            onRemove: () => _removeQuickPath(context, quickPath.path),
          );
        }),
        
        // 添加快捷路径按钮
        _AddQuickPathButton(
          onPressed: () => _addQuickPath(context),
        ),
      ],
    );
  }

  Future<void> _addQuickPath(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('添加快捷路径'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将当前路径添加到快捷路径：'),
            const SizedBox(height: 8),
            Text(
              _currentPath,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '自定义名称（留空自动生成）：',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextBox(
              controller: controller,
              placeholder: '例如：我的项目',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'path': _currentPath,
              'name': controller.text,
            }),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final quickPathService = Provider.of<QuickPathService>(context, listen: false);
      final success = await quickPathService.addQuickPath(
        result['path']!,
        customName: result['name']!.isEmpty ? null : result['name'],
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: Text(success ? '添加成功' : '添加失败'),
            content: Text(success ? '快捷路径已添加' : '该路径已存在或无效'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
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
        title: const Text('删除快捷路径'),
        content: Text('确定要删除这个快捷路径吗？\n\n$pathStr'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final quickPathService = Provider.of<QuickPathService>(context, listen: false);
      await quickPathService.removeQuickPath(pathStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              FluentIcons.folder_open,
              size: 16,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 12),
          const Text('选择文件夹'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 驱动器和快捷路径（合并在一行）
          _buildDrivesAndQuickPaths(context),
          const SizedBox(height: 12),

          // 路径输入框和导航
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                _NavButton(
                  icon: FluentIcons.up,
                  onPressed: _navigateToParent,
                  tooltip: '上级目录',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    controller: _pathController,
                    placeholder: '输入路径或从下方选择',
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _loadDirectory(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _NavButton(
                  icon: FluentIcons.refresh,
                  onPressed: () => _loadDirectory(_pathController.text),
                  tooltip: '刷新',
                ),
                const SizedBox(width: 4),
                _NavButton(
                  icon: FluentIcons.add,
                  onPressed: _createNewFolder,
                  tooltip: '新建文件夹',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 文件夹列表
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                border: Border.all(color: AppTheme.borderSubtle),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: _loading
                    ? const Center(child: ProgressRing())
                    : _error != null
                        ? _buildErrorState()
                        : _items.isEmpty
                            ? _buildEmptyState(context)
                            : _buildFolderList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 当前选择提示
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary.withValues(alpha: 0.1),
                  AppTheme.accentPrimary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.accentPrimary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  FluentIcons.check_mark,
                  size: 14,
                  color: AppTheme.accentLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
          onPressed: () => Navigator.pop(context, _currentPath),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.check_mark, size: 12),
              SizedBox(width: 6),
              Text('选择'),
            ],
          ),
        ),
      ],
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
              child: const Icon(
                FluentIcons.error,
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
            FluentIcons.folder,
            size: 32,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            '此文件夹为空',
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList() {
    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final name = _getFolderName(item.path);
        return _FolderItem(
          name: name,
          onPressed: () => _navigateToPath(item.path),
        );
      },
    );
  }
}


/// 驱动器按钮
class _DriveButton extends StatefulWidget {
  final String drive;
  final VoidCallback onPressed;

  const _DriveButton({required this.drive, required this.onPressed});

  @override
  State<_DriveButton> createState() => _DriveButtonState();
}

class _DriveButtonState extends State<_DriveButton> {
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
            color: _isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.15) : AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.3) : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.hard_drive,
                size: 12,
                color: _isHovered ? AppTheme.accentLight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.drive,
                style: TextStyle(
                  fontSize: 11,
                  color: _isHovered ? AppTheme.accentLight : AppTheme.textSecondary,
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

/// 导航按钮
class _NavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _NavButton({required this.icon, required this.onPressed, required this.tooltip});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _isHovered ? AppTheme.accentLight : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 添加快捷路径按钮
class _AddQuickPathButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddQuickPathButton({required this.onPressed});

  @override
  State<_AddQuickPathButton> createState() => _AddQuickPathButtonState();
}

class _AddQuickPathButtonState extends State<_AddQuickPathButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '添加当前路径为快捷路径',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.2) : AppTheme.bgLayer2,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.4) : AppTheme.borderSubtle,
                width: _isHovered ? 1.5 : 1,
              ),
            ),
            child: Icon(
              FluentIcons.add,
              size: 12,
              color: _isHovered ? AppTheme.accentLight : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 快捷路径按钮
class _QuickPathButton extends StatefulWidget {
  final QuickPath quickPath;
  final VoidCallback onPressed;
  final VoidCallback onRemove;

  const _QuickPathButton({
    required this.quickPath,
    required this.onPressed,
    required this.onRemove,
  });

  @override
  State<_QuickPathButton> createState() => _QuickPathButtonState();
}

class _QuickPathButtonState extends State<_QuickPathButton> {
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
            color: _isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.15) : AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.3) : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.pinned_solid,
                size: 12,
                color: _isHovered ? AppTheme.accentLight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.quickPath.name,
                style: TextStyle(
                  fontSize: 11,
                  color: _isHovered ? AppTheme.accentLight : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isHovered) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    widget.onRemove();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.statusError.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(
                      FluentIcons.chrome_close,
                      size: 10,
                      color: AppTheme.statusError,
                    ),
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

/// 文件夹项
class _FolderItem extends StatefulWidget {
  final String name;
  final VoidCallback onPressed;

  const _FolderItem({required this.name, required this.onPressed});

  @override
  State<_FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<_FolderItem> {
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
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppTheme.bgLayer2 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.folder,
                size: 16,
                color: _isHovered ? AppTheme.statusWarning : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isHovered ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isHovered)
                const Icon(
                  FluentIcons.chevron_right,
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
