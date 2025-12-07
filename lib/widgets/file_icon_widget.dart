import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List, kDebugMode;
import 'package:fluent_ui/fluent_ui.dart' show FluentIcons;
import '../services/file_icon_service.dart';
import '../theme/app_theme.dart';

/// 文件图标组件
/// 显示 Windows 系统真实的文件类型图标
class FileIconWidget extends StatefulWidget {
  final String fileName;
  final String? filePath;
  final double size;
  
  const FileIconWidget({
    super.key,
    required this.fileName,
    this.filePath,
    this.size = 32,
  });

  @override
  State<FileIconWidget> createState() => _FileIconWidgetState();
}

class _FileIconWidgetState extends State<FileIconWidget> {
  final FileIconService _iconService = FileIconService();
  Uint8List? _iconData;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  @override
  void didUpdateWidget(FileIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileName != widget.fileName || oldWidget.filePath != widget.filePath) {
      _loadIcon();
    }
  }

  Future<void> _loadIcon() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      Uint8List? iconData;
      
      // 如果有文件路径，优先从文件获取图标
      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        iconData = await _iconService.getIconFromFile(widget.filePath!);
      }
      
      // 如果没有获取到，尝试从扩展名获取
      if (iconData == null) {
        final ext = _getExtension(widget.fileName);
        if (ext.isNotEmpty) {
          iconData = await _iconService.getIconByExtension(ext);
        }
      }

      if (mounted) {
        setState(() {
          _iconData = iconData;
          _loading = false;
          _hasError = iconData == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  String _getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在加载或出错，显示默认图标
    if (_loading || _hasError || _iconData == null) {
      return _buildFallbackIcon();
    }

    // 显示系统图标
    // 注意：从 FileIconService 返回的是原始 RGBA 数据，不是 PNG
    // 我们需要使用 RawImage 或者先解码
    return Image.memory(
      _iconData!,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('图标显示错误: $error');
        return _buildFallbackIcon();
      },
    );
  }
  
  void debugPrint(String message) {
    if (kDebugMode) {
      print('[FileIconWidget] $message');
    }
  }

  /// 构建后备图标（使用 Fluent Icons）
  Widget _buildFallbackIcon() {
    final icon = _getFallbackIcon(widget.fileName);
    final color = _getFallbackColor(widget.fileName);
    
    return Icon(
      icon,
      size: widget.size,
      color: color,
    );
  }

  /// 根据文件扩展名获取后备图标
  IconData _getFallbackIcon(String fileName) {
    final ext = _getExtension(fileName);
    
    // 视频文件
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'rmvb', 'rm', '3gp', 'ts'].contains(ext)) {
      return FluentIcons.video;
    }
    
    // 音频文件
    if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a', 'ape', 'alac'].contains(ext)) {
      return FluentIcons.music_note;
    }
    
    // 图片文件
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico', 'tiff', 'psd', 'raw'].contains(ext)) {
      return FluentIcons.photo2;
    }
    
    // 文档文件
    if (['doc', 'docx', 'pdf', 'txt', 'rtf', 'odt'].contains(ext)) {
      return FluentIcons.document;
    }
    
    // 表格文件
    if (['xls', 'xlsx', 'csv', 'ods'].contains(ext)) {
      return FluentIcons.excel_document;
    }
    
    // 演示文件
    if (['ppt', 'pptx', 'odp'].contains(ext)) {
      return FluentIcons.presentation;
    }
    
    // 压缩文件
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso'].contains(ext)) {
      return FluentIcons.archive;
    }
    
    // 可执行文件
    if (['exe', 'msi', 'dmg', 'app', 'deb', 'rpm', 'apk'].contains(ext)) {
      return FluentIcons.app_icon_default;
    }
    
    // 代码文件
    if (['js', 'ts', 'py', 'java', 'c', 'cpp', 'h', 'cs', 'go', 'rs', 'rb', 'php', 'html', 'css', 'json', 'xml', 'yaml', 'yml', 'dart', 'kt', 'swift'].contains(ext)) {
      return FluentIcons.code;
    }
    
    // 字体文件
    if (['ttf', 'otf', 'woff', 'woff2', 'eot'].contains(ext)) {
      return FluentIcons.font;
    }
    
    // 数据库文件
    if (['db', 'sqlite', 'sql', 'mdb'].contains(ext)) {
      return FluentIcons.database;
    }
    
    // 默认文件图标
    return FluentIcons.document;
  }
  
  /// 根据文件扩展名获取后备颜色
  Color _getFallbackColor(String fileName) {
    final ext = _getExtension(fileName);
    
    // 视频文件 - 紫色
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'rmvb', 'rm', '3gp', 'ts'].contains(ext)) {
      return const Color(0xFF9C27B0);
    }
    
    // 音频文件 - 橙色
    if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a', 'ape', 'alac'].contains(ext)) {
      return const Color(0xFFFF9800);
    }
    
    // 图片文件 - 青色
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico', 'tiff', 'psd', 'raw'].contains(ext)) {
      return const Color(0xFF00BCD4);
    }
    
    // 文档文件 - 蓝色
    if (['doc', 'docx', 'pdf', 'txt', 'rtf', 'odt'].contains(ext)) {
      return const Color(0xFF2196F3);
    }
    
    // 表格文件 - 绿色
    if (['xls', 'xlsx', 'csv', 'ods'].contains(ext)) {
      return const Color(0xFF4CAF50);
    }
    
    // 演示文件 - 红橙色
    if (['ppt', 'pptx', 'odp'].contains(ext)) {
      return const Color(0xFFFF5722);
    }
    
    // 压缩文件 - 棕色
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso'].contains(ext)) {
      return const Color(0xFF795548);
    }
    
    // 可执行文件 - 深蓝色
    if (['exe', 'msi', 'dmg', 'app', 'deb', 'rpm', 'apk'].contains(ext)) {
      return const Color(0xFF3F51B5);
    }
    
    // 代码文件 - 粉色
    if (['js', 'ts', 'py', 'java', 'c', 'cpp', 'h', 'cs', 'go', 'rs', 'rb', 'php', 'html', 'css', 'json', 'xml', 'yaml', 'yml', 'dart', 'kt', 'swift'].contains(ext)) {
      return const Color(0xFFE91E63);
    }
    
    // 默认 - 灰色
    return AppTheme.textSecondary;
  }
}
