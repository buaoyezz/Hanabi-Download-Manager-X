import 'package:fluent_ui/fluent_ui.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

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
  bool _loading = false;
  String? _error;
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _pathController.text = _currentPath;
    _loadDirectory(_currentPath);
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
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => ContentDialog(
                title: const Text('创建失败'),
                content: const Text('文件夹已存在'),
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
        
        // 刷新当前目录
        await _loadDirectory(_currentPath);
        
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: const Text('创建成功'),
              content: Text('文件夹 "$result" 已创建'),
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

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
      title: const Text('选择文件夹'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 驱动器快速选择
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getDrives().map((drive) {
              return Button(
                onPressed: () => _navigateToPath(drive),
                child: Text(drive),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // 路径输入框和导航
          Row(
            children: [
              Button(
                onPressed: _navigateToParent,
                child: const Icon(FluentIcons.up, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextBox(
                  controller: _pathController,
                  placeholder: '输入路径或从下方选择',
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _loadDirectory(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () => _loadDirectory(_pathController.text),
                child: const Icon(FluentIcons.refresh, size: 16),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: _createNewFolder,
                child: const Icon(FluentIcons.add, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 文件夹列表
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: FluentTheme.of(context).resources.cardStrokeColorDefault,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _loading
                  ? const Center(child: ProgressRing())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FluentIcons.error,
                                  size: 32,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                '此文件夹为空',
                                style: FluentTheme.of(context).typography.body?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final name = _getFolderName(item.path);

                                return ListTile(
                                  leading: const Icon(FluentIcons.folder, size: 20),
                                  title: Text(name),
                                  onPressed: () => _navigateToPath(item.path),
                                );
                              },
                            ),
            ),
          ),
          const SizedBox(height: 12),

          // 当前选择提示
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  FluentIcons.info,
                  size: 16,
                  color: FluentTheme.of(context).accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '当前选择: $_currentPath',
                    style: FluentTheme.of(context).typography.caption,
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
          child: const Text('选择此文件夹'),
        ),
      ],
    );
  }
}
