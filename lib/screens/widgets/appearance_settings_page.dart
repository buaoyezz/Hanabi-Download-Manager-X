import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ffi' hide Size;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'dart:ui';
import '../../widgets/settings_components.dart';
import '../../services/font_service.dart';
import '../../services/window_effect_service.dart';
import '../../services/client_config_service.dart';
import '../../services/notification_settings_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../widgets/animated_notifications.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  // 字体设置
  String _selectedFont = 'system'; // 'system' 表示使用系统默认字体
  List<String> _availableFonts = ['system'];
  bool _loadingFonts = true;
  
  // UI 设置
  bool _segmentsDefaultExpanded = false;
  int _segmentsMaxVisible = 5;
  String _segmentsDisplayMode = 'merged'; // 'merged' (合并) 或 'list' (列表)

  // 通知设置
  bool _notificationEnabled = true;
  String _notificationColorScheme = 'fluent2';
  String _notificationPosition = 'topRight';
  String _performanceMode = 'performance';  // 性能模式

  // 屏幕尺寸
  double _screenWidth = 1920.0;
  double _screenHeight = 1080.0;
  bool _loadingScreenSize = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAvailableFonts();
    _loadScreenSize();
  }
  
  Future<void> _loadScreenSize() async {
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      if (mounted) {
        setState(() {
          _screenWidth = primaryDisplay.size.width;
          _screenHeight = primaryDisplay.size.height;
          _loadingScreenSize = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading screen size: $e');
      if (mounted) {
        setState(() {
          _loadingScreenSize = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationSettings = NotificationSettingsService();

    if (mounted) {
      final fontService = context.read<FontService>();
      setState(() {
        _selectedFont = fontService.selectedFont;
        _segmentsDefaultExpanded = prefs.getBool('segments_default_expanded') ?? false;
        _segmentsMaxVisible = prefs.getInt('segments_max_visible') ?? 5;
        _segmentsDisplayMode = prefs.getString('segments_display_mode') ?? 'merged';

        // 加载通知设置
        _notificationEnabled = notificationSettings.enabled;
        _notificationColorScheme = notificationSettings.colorScheme.name;
        _notificationPosition = notificationSettings.position.name;
        _performanceMode = notificationSettings.performanceMode.name;
      });
    }
  }

  Future<void> _loadAvailableFonts() async {
    setState(() => _loadingFonts = true);
    
    try {
      // 获取系统字体列表
      final systemFonts = await _getSystemFonts();
      
      // 获取自定义字体列表
      final fontService = context.read<FontService>();
      final customFonts = fontService.customFonts.keys.toList();
      
      if (mounted) {
        setState(() {
          _availableFonts = ['system', ...systemFonts, ...customFonts];
          _loadingFonts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fonts: $e');
      if (mounted) {
        setState(() {
          _availableFonts = ['system'];
          _loadingFonts = false;
        });
      }
    }
  }

  Future<List<String>> _getSystemFonts() async {
    if (!Platform.isWindows) {
      return [];
    }

    try {
      // 使用 Win32 API 读取注册表中的字体
      final fontsKey = HKEY_LOCAL_MACHINE;
      final subKey = r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';
      
      final fontNames = <String>{};
      
      // 打开注册表键
      final phkResult = calloc<HKEY>();
      final subKeyPtr = subKey.toNativeUtf16();
      final result = RegOpenKeyEx(
        fontsKey,
        subKeyPtr,
        0,
        KEY_READ,
        phkResult,
      );
      
      if (result == ERROR_SUCCESS) {
        final hKey = phkResult.value;
        
        // 枚举所有值
        var index = 0;
        while (true) {
          final valueName = wsalloc(256);
          final valueNameSize = calloc<DWORD>()..value = 256;
          
          final enumResult = RegEnumValue(
            hKey,
            index,
            valueName,
            valueNameSize,
            nullptr,
            nullptr,
            nullptr,
            nullptr,
          );
          
          if (enumResult == ERROR_SUCCESS) {
            String fontName = valueName.toDartString();
            
            // 移除常见的后缀
            fontName = fontName
                .replaceAll(RegExp(r'\s*\(TrueType\)$'), '')
                .replaceAll(RegExp(r'\s*\(OpenType\)$'), '')
                .replaceAll(RegExp(r'\s*\(All res\)$'), '')
                .replaceAll(RegExp(r'\s*&.*$'), '') // 移除 & 及之后的内容
                .trim();
            
            if (fontName.isNotEmpty) {
              fontNames.add(fontName);
            }
            
            index++;
          } else {
            break;
          }
          
          calloc.free(valueName);
          calloc.free(valueNameSize);
        }
        
        RegCloseKey(hKey);
      }
      
      calloc.free(subKeyPtr);
      calloc.free(phkResult);
      
      // 转换为列表并排序
      final sortedFonts = fontNames.toList()..sort();
      
      return sortedFonts;
    } catch (e) {
      debugPrint('Error reading system fonts: $e');
      // 如果读取失败，返回常见字体列表
      return [
        'Microsoft YaHei',
        'Microsoft YaHei UI',
        'SimSun',
        'SimHei',
        'KaiTi',
        'FangSong',
        'Arial',
        'Segoe UI',
        'Calibri',
        'Consolas',
        'Courier New',
        'Times New Roman',
        'Verdana',
        'Tahoma',
        'Georgia',
      ];
    }
  }

  Future<void> _saveFontSetting(String font) async {
    final fontService = context.read<FontService>();
    await fontService.setFont(font);
    setState(() => _selectedFont = font);
    
    // 显示提示字体已应用
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('字体已更改'),
          content: Text('新字体已应用到整个应用'),
          severity: InfoBarSeverity.success,
        ),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _saveSegmentsExpandedSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('segments_default_expanded', value);
    setState(() => _segmentsDefaultExpanded = value);
  }

  Future<void> _saveSegmentsMaxVisibleSetting(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('segments_max_visible', value);
    setState(() => _segmentsMaxVisible = value);
  }
  
  Future<void> _saveSegmentsDisplayMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('segments_display_mode', value);
    setState(() => _segmentsDisplayMode = value);
  }
  
  // 通知设置保存方法
  Future<void> _saveNotificationEnabled(bool value) async {
    final notificationSettings = NotificationSettingsService();
    await notificationSettings.setEnabled(value);
    setState(() => _notificationEnabled = value);
  }
  
  Future<void> _saveNotificationColorScheme(String value) async {
    final notificationSettings = NotificationSettingsService();
    final scheme = NotificationColorScheme.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationColorScheme.fluent2,
    );
    await notificationSettings.setColorScheme(scheme);
    setState(() => _notificationColorScheme = value);
  }

  Future<void> _saveNotificationPosition(String value) async {
    final notificationSettings = NotificationSettingsService();
    final position = NotificationPosition.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationPosition.topRight,
    );
    await notificationSettings.setPosition(position);
    setState(() => _notificationPosition = value);
  }

  Future<void> _savePerformanceMode(String value) async {
    final notificationSettings = NotificationSettingsService();
    final mode = NotificationPerformanceMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationPerformanceMode.performance,
    );
    await notificationSettings.setPerformanceMode(mode);
    setState(() => _performanceMode = value);
  }

  String _getNotificationColorSchemeName(String scheme) {
    switch (scheme) {
      case 'defaultScheme':
        return '跟随主题';
      case 'light':
        return '浅色系';
      case 'dark':
        return '深色系';
      case 'fluent2':
        return 'Fluent 2 色系（推荐）';
      default:
        return '未知';
    }
  }
  
  String _getNotificationPositionName(String position) {
    switch (position) {
      case 'topRight':
        return '右上角（标题栏下方）';
      case 'bottomRight':
        return '右下角';
      default:
        return '未知';
    }
  }

  String _getPerformanceModeName(String mode) {
    switch (mode) {
      case 'quality':
        return '高质量（完整毛玻璃效果）';
      case 'balanced':
        return '平衡（轻度毛玻璃）';
      case 'performance':
        return '性能优先（无毛玻璃，推荐）';
      default:
        return '未知';
    }
  }

  void _showTestNotification() {
    final notificationManager = NotificationManager.of(context);
    if (notificationManager != null) {
      notificationManager.showSuccess(
        '测试通知',
        message: '这是一条测试通知消息',
      );
    }
  }
  
  // 通知配色预览框
  Widget _buildNotificationPreview(BuildContext context) {
    final notificationSettings = NotificationSettingsService();
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(CustomIcons.FluentIcons.preview,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              '配色预览',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgLayer1.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              _buildPreviewNotificationCard(
                context,
                title: '成功通知',
                message: '操作已成功完成',
                icon: CustomIcons.FluentIcons.completed_solid,
                color: notificationSettings.getSuccessColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: '警告通知',
                message: '请注意此操作的影响',
                icon: CustomIcons.FluentIcons.warning,
                color: notificationSettings.getWarningColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: '错误通知',
                message: '操作失败，请重试',
                icon: CustomIcons.FluentIcons.status_error_full,
                color: notificationSettings.getErrorColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: '信息通知',
                message: '这是一条提示信息',
                icon: CustomIcons.FluentIcons.info,
                color: notificationSettings.getInfoColor(isDark),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 预览通知卡片（静态展示）
  Widget _buildPreviewNotificationCard(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final notificationSettings = NotificationSettingsService();
    final cardColor = notificationSettings.getCardColor(isDark);
    final textPrimary = notificationSettings.getTextPrimaryColor(isDark);
    final textSecondary = notificationSettings.getTextSecondaryColor(isDark);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 图标
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          icon,
                          size: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: FluentTheme.of(context)
                                  .typography.bodyStrong?.copyWith(
                                color: textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message,
                              style: FluentTheme.of(context)
                                  .typography.body?.copyWith(
                                color: textSecondary,
                                fontSize: 11,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 关闭按钮
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.bgLayer2.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(CustomIcons.FluentIcons.chrome_close,
                          size: 10,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 进度条
                Container(
                  height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.6, // 静态显示 60% 进度
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _importCustomFont() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        dialogTitle: '选择字体文件',
      );

      if (result != null && result.files.single.path != null) {
        final fontPath = result.files.single.path!;
        
        if (mounted) {
          // 显示加载提示
          displayInfoBar(
            context,
            builder: (context, close) => const InfoBar(
              title: Text('正在导入字体...'),
              content: Text('请稍候'),
              severity: InfoBarSeverity.info,
            ),
            duration: const Duration(seconds: 2),
          );
        }

        final fontService = context.read<FontService>();
        final success = await fontService.addCustomFont(fontPath);

        if (mounted) {
          if (success) {
            // 重新加载字体列表
            await _loadAvailableFonts();
            
            displayInfoBar(
              context,
              builder: (context, close) => const InfoBar(
                title: Text('导入成功'),
                content: Text('字体已成功导入'),
                severity: InfoBarSeverity.success,
              ),
              duration: const Duration(seconds: 3),
            );
          } else {
            displayInfoBar(
              context,
              builder: (context, close) => const InfoBar(
                title: Text('导入失败'),
                content: Text('无法导入字体文件，请检查文件格式'),
                severity: InfoBarSeverity.error,
              ),
              duration: const Duration(seconds: 3),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing font: $e');
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('导入失败'),
            content: Text('发生错误: $e'),
            severity: InfoBarSeverity.error,
            action: Button(
              child: const Text('复制错误'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: e.toString()));
              },
            ),
          ),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _removeCustomFont(String fontName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除字体 "$fontName" 吗？'),
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

    if (confirmed == true) {
      final fontService = context.read<FontService>();
      final success = await fontService.removeCustomFont(fontName);

      if (mounted) {
        if (success) {
          await _loadAvailableFonts();
          displayInfoBar(
            context,
            builder: (context, close) => const InfoBar(
              title: Text('删除成功'),
              content: Text('字体已删除'),
              severity: InfoBarSeverity.success,
            ),
            duration: const Duration(seconds: 2),
          );
        } else {
          displayInfoBar(
            context,
            builder: (context, close) => const InfoBar(
              title: Text('删除失败'),
              content: Text('无法删除字体'),
              severity: InfoBarSeverity.error,
            ),
            duration: const Duration(seconds: 2),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('AppearanceSettingsPage');

    final windowEffect = context.watch<WindowEffectService>();
    final alpha = windowEffect.alpha;
    final clientConfig = context.watch<ClientConfigService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        
        // 窗口大小设置
        _buildSection(
          context,
          title: '窗口大小',
          icon: CustomIcons.FluentIcons.full_screen,
          children: [
            _buildWindowSizeSettings(context, clientConfig),
          ],
        ),
        const SizedBox(height: 24),
        
        // UI 缩放设置
        _buildSection(
          context,
          title: 'UI 缩放',
          icon: CustomIcons.FluentIcons.font_size,
          children: [
            _buildSettingItem(
              context,
              title: '界面缩放比例',
              subtitle: '调整整个应用的UI缩放，适配高分辨率屏幕 (50%-200%)',
              trailing: SizedBox(
                width: 250,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: clientConfig.getWindowScaleFactor(),
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        label: '${(clientConfig.getWindowScaleFactor() * 100).toInt()}%',
                        onChanged: (value) async {
                          await clientConfig.setWindowScaleFactor(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${(clientConfig.getWindowScaleFactor() * 100).toInt()}%',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Button(
                    onPressed: () async {
                      await clientConfig.setWindowScaleFactor(1.0);
                      if (mounted) {
                        displayInfoBar(
                          context,
                          builder: (context, close) => const InfoBar(
                            title: Text('已重置'),
                            content: Text('UI缩放已重置为100%'),
                            severity: InfoBarSeverity.info,
                          ),
                          duration: const Duration(seconds: 2),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.refresh, size: 14),
                        SizedBox(width: 6),
                        Text('重置为100%'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Button(
                    onPressed: () async {
                      await clientConfig.setWindowScaleFactor(1.25);
                      if (mounted) {
                        displayInfoBar(
                          context,
                          builder: (context, close) => const InfoBar(
                            title: Text('已应用'),
                            content: Text('UI缩放已设为125% (推荐4K屏幕)'),
                            severity: InfoBarSeverity.success,
                          ),
                          duration: const Duration(seconds: 2),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.full_screen, size: 14),
                        SizedBox(width: 6),
                        Text('4K推荐 (125%)'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 16,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '调整此设置可以让应用在高分辨率屏幕上显示更清晰。4K屏幕推荐125%-150%',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // 字体设置
        _buildSection(
          context,
          title: '字体',
          icon: CustomIcons.FluentIcons.font,
          children: [
            _buildSettingItem(
              context,
              title: '应用字体',
              subtitle: _selectedFont == 'system' ? '使用系统默认字体' : '当前字体: $_selectedFont',
              trailing: _loadingFonts
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : SizedBox(
                      width: 250,
                      child: Button(
                        onPressed: () => _showFontPickerDialog(context),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedFont == 'system' ? '系统默认' : _selectedFont,
                                style: _selectedFont == 'system' 
                                    ? null 
                                    : TextStyle(fontFamily: _selectedFont),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(CustomIcons.FluentIcons.chevron_down, size: 12),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Button(
                    onPressed: _importCustomFont,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.add, size: 14),
                        const SizedBox(width: 6),
                        const Text('导入字体'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Consumer<FontService>(
                    builder: (context, fontService, child) {
                      final canDelete = _selectedFont != 'system' && 
                                       fontService.isCustomFont(_selectedFont);
                      return Button(
                        onPressed: canDelete ? () => _removeCustomFont(_selectedFont) : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.delete, size: 14),
                            const SizedBox(width: 6),
                            const Text('删除当前字体'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 16,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '支持导入 .ttf 和 .otf 格式的字体文件',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // 窗口效果
        _buildSection(
          context,
          title: '窗口效果',
          icon: CustomIcons.FluentIcons.color,
          children: [
            _buildSettingItem(
              context,
              title: '启用窗口特效',
              subtitle: windowEffect.effectEnabled
                  ? '已启用亚克力/模糊效果（可能影响性能）'
                  : '已禁用窗口特效（性能优先）',
              trailing: ToggleSwitch(
                checked: windowEffect.effectEnabled,
                onChanged: (value) async {
                  await windowEffect.setEffectEnabled(value);
                  if (mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      value ? '窗口特效已启用' : '窗口特效已禁用',
                      message: value
                          ? '亚克力效果已开启，可能会影响性能'
                          : '已切换到纯色背景，性能更佳',
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: windowEffect.effectEnabled ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: !windowEffect.effectEnabled,
                child: _buildSettingItem(
                  context,
                  title: '亚克力透明度',
                  subtitle: '调整窗口背景的透明度 (0-255，值越小越透明)',
                  trailing: SizedBox(
                    width: 250,
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: alpha.toDouble(),
                            min: 0,
                            max: 255,
                            divisions: 255,
                            label: alpha.toString(),
                            onChanged: (v) async {
                              await windowEffect.setAlpha(v.toInt());
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$alpha',
                            style: FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: windowEffect.effectEnabled
                    ? Colors.orange.withValues(alpha: 0.1)
                    : AppTheme.statusSuccess.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: windowEffect.effectEnabled
                      ? Colors.orange.withValues(alpha: 0.3)
                      : AppTheme.statusSuccess.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    windowEffect.effectEnabled
                        ? CustomIcons.FluentIcons.warning
                        : CustomIcons.FluentIcons.completed_solid,
                    size: 16,
                    color: windowEffect.effectEnabled
                        ? Colors.orange
                        : AppTheme.statusSuccess,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      windowEffect.effectEnabled
                          ? '亚克力效果会消耗额外的GPU资源，如果感觉卡顿可以关闭此选项'
                          : '窗口特效已关闭，应用将使用纯色背景以获得最佳性能',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: windowEffect.effectEnabled
                            ? Colors.orange
                            : AppTheme.statusSuccess,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // 侧边栏设置
        _buildSection(
          context,
          title: '侧边栏',
          icon: CustomIcons.FluentIcons.side_panel,
          children: [
            _buildSettingItem(
              context,
              title: '默认展开状态',
              subtitle: '应用启动时侧边栏的默认状态',
              trailing: ComboBox<bool>(
                value: clientConfig.getSidebarDefaultExpanded(),
                items: const [
                  ComboBoxItem(value: true, child: Text('展开')),
                  ComboBoxItem(value: false, child: Text('收缩')),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await clientConfig.setSidebarDefaultExpanded(value);
                    if (mounted) {
                      displayInfoBar(
                        context,
                        builder: (context, close) => InfoBar(
                          title: const Text('设置已保存'),
                          content: Text('侧边栏默认状态已设为${value ? "展开" : "收缩"}'),
                          severity: InfoBarSeverity.success,
                        ),
                        duration: const Duration(seconds: 2),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // 通知设置
        _buildSection(
          context,
          title: '通知',
          icon: CustomIcons.FluentIcons.ringer,
          children: [
            _buildSettingItem(
              context,
              title: '启用通知',
              subtitle: '显示下载完成、错误等通知',
              trailing: ToggleSwitch(
                checked: _notificationEnabled,
                onChanged: (value) => _saveNotificationEnabled(value),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: '配色方案',
              subtitle: _getNotificationColorSchemeName(_notificationColorScheme),
              trailing: ComboBox<String>(
                value: _notificationColorScheme,
                items: const [
                  ComboBoxItem(value: 'defaultScheme', child: Text('默认配色')),
                  ComboBoxItem(value: 'light', child: Text('浅色系')),
                  ComboBoxItem(value: 'dark', child: Text('深色系')),
                  ComboBoxItem(value: 'fluent2', child: Text('Fluent 2 色系')),
                ],
                onChanged: (value) {
                  if (value != null) _saveNotificationColorScheme(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: '显示位置',
              subtitle: _getNotificationPositionName(_notificationPosition),
              trailing: ComboBox<String>(
                value: _notificationPosition,
                items: const [
                  ComboBoxItem(value: 'topRight', child: Text('右上角')),
                  ComboBoxItem(value: 'bottomRight', child: Text('右下角')),
                ],
                onChanged: (value) {
                  if (value != null) _saveNotificationPosition(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: '渲染性能模式',
              subtitle: _getPerformanceModeName(_performanceMode),
              trailing: ComboBox<String>(
                value: _performanceMode,
                items: const [
                  ComboBoxItem(value: 'performance', child: Text('性能优先')),
                  ComboBoxItem(value: 'balanced', child: Text('平衡')),
                  ComboBoxItem(value: 'quality', child: Text('高质量')),
                ],
                onChanged: (value) {
                  if (value != null) _savePerformanceMode(value);
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 16,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '毛玻璃效果会影响动画流畅度。如果感觉卡顿，建议选择"性能优先"模式',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: '预览通知',
              subtitle: '点击按钮预览当前配色效果',
              trailing: Button(
                onPressed: _showTestNotification,
                child: const Text('预览'),
              ),
            ),
            const SizedBox(height: 16),
            // 配色预览框
            _buildNotificationPreview(context),
          ],
        ),
        const SizedBox(height: 24),
        
        // 下载列表显示
        _buildSection(
          context,
          title: '下载列表显示',
          icon: CustomIcons.FluentIcons.list,
          children: [
            _buildSettingItem(
              context,
              title: '分段进度显示模式',
              subtitle: _getSegmentsDisplayModeDescription(_segmentsDisplayMode),
              trailing: ComboBox<String>(
                value: _segmentsDisplayMode,
                items: const [
                  ComboBoxItem(value: 'none', child: Text('简洁模式')),
                  ComboBoxItem(value: 'merged', child: Text('合并进度条')),
                  ComboBoxItem(value: 'list', child: Text('分段列表')),
                ],
                onChanged: (value) {
                  if (value != null) _saveSegmentsDisplayMode(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            // 列表模式的额外设置
            Opacity(
              opacity: _segmentsDisplayMode == 'list' ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: _segmentsDisplayMode != 'list',
                child: _buildSettingItem(
                  context,
                  title: '默认展开分段信息',
                  subtitle: '下载任务的分段进度默认展开显示',
                  trailing: ToggleSwitch(
                    checked: _segmentsDefaultExpanded,
                    onChanged: (value) => _saveSegmentsExpandedSetting(value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: _segmentsDisplayMode == 'list' ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: _segmentsDisplayMode != 'list',
                child: _buildSettingItem(
                  context,
                  title: '默认显示分段数量',
                  subtitle: '展开时默认显示的分段数量 (1-32)',
                  trailing: SizedBox(
                    width: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _segmentsMaxVisible.toDouble(),
                            min: 1,
                            max: 32,
                            divisions: 31,
                            label: _segmentsMaxVisible.toString(),
                            onChanged: (value) {
                              _saveSegmentsMaxVisibleSetting(value.toInt());
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '$_segmentsMaxVisible',
                            style: FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWindowSizeSettings(BuildContext context, ClientConfigService config) {
    final rememberSize = config.getWindowRememberSize();
    final defaultWidth = config.getWindowDefaultWidth();
    final defaultHeight = config.getWindowDefaultHeight();
    // 直接获取当前窗口大小（每次构建时都获取最新值）
    final currentWidth = appWindow.size.width;
    final currentHeight = appWindow.size.height;
    
    // 使用缓存的屏幕尺寸
    final maxWidth = _screenWidth;
    final maxHeight = _screenHeight;
    
    // 确保默认值不超过屏幕大小
    final safeDefaultWidth = defaultWidth.clamp(600.0, maxWidth);
    final safeDefaultHeight = defaultHeight.clamp(400.0, maxHeight);
    
    // 如果还在加载屏幕尺寸，显示加载指示器
    if (_loadingScreenSize) {
      return const Center(
        child: ProgressRing(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingItem(
          context,
          title: '记忆窗口大小',
          subtitle: rememberSize 
              ? '启动时使用上次关闭时的窗口大小'
              : '启动时使用默认窗口大小',
          trailing: ToggleSwitch(
            checked: rememberSize,
            onChanged: (value) async {
              await config.setWindowRememberSize(value);
            },
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: rememberSize ? 0.5 : 1.0,
          child: IgnorePointer(
            ignoring: rememberSize,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingItem(
                  context,
                  title: '默认窗口宽度',
                  subtitle: '启动时的默认宽度 (600-${maxWidth.toInt()})',
                  trailing: SizedBox(
                    width: 250,
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: safeDefaultWidth,
                            min: 600,
                            max: maxWidth,
                            divisions: ((maxWidth - 600) / 10).toInt(),
                            label: safeDefaultWidth.toInt().toString(),
                            onChanged: (value) async {
                              await config.setWindowDefaultWidth(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${safeDefaultWidth.toInt()}',
                            style: FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingItem(
                  context,
                  title: '默认窗口高度',
                  subtitle: '启动时的默认高度 (400-${maxHeight.toInt()})',
                  trailing: SizedBox(
                    width: 250,
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: safeDefaultHeight,
                            min: 400,
                            max: maxHeight,
                            divisions: ((maxHeight - 400) / 10).toInt(),
                            label: safeDefaultHeight.toInt().toString(),
                            onChanged: (value) async {
                              await config.setWindowDefaultHeight(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${safeDefaultHeight.toInt()}',
                            style: FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        onPressed: () async {
                          // 确保不超过屏幕大小
                          final safeWidth = currentWidth.clamp(600.0, maxWidth);
                          final safeHeight = currentHeight.clamp(400.0, maxHeight);
                          
                          // 同时更新默认大小和当前保存的大小
                          await config.setWindowDefaultWidth(safeWidth);
                          await config.setWindowDefaultHeight(safeHeight);
                          await config.setWindowWidth(safeWidth);
                          await config.setWindowHeight(safeHeight);
                          
                          if (mounted) {
                            displayInfoBar(
                              context,
                              builder: (context, close) => InfoBar(
                                title: const Text('已保存'),
                                content: Text('当前窗口大小已设为默认大小 (${safeWidth.toInt()}×${safeHeight.toInt()})'),
                                severity: InfoBarSeverity.success,
                              ),
                              duration: const Duration(seconds: 2),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.save, size: 14),
                            const SizedBox(width: 6),
                            Text('使用当前大小 (${currentWidth.toInt()}×${currentHeight.toInt()})'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Button(
                        onPressed: () async {
                          // 同时重置默认大小和当前保存的大小
                          await config.setWindowDefaultWidth(889.0);
                          await config.setWindowDefaultHeight(586.0);
                          await config.setWindowWidth(889.0);
                          await config.setWindowHeight(586.0);
                          
                          if (mounted) {
                            displayInfoBar(
                              context,
                              builder: (context, close) => const InfoBar(
                                title: Text('已重置'),
                                content: Text('默认窗口大小已重置为 889×586'),
                                severity: InfoBarSeverity.info,
                              ),
                              duration: const Duration(seconds: 2),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.refresh, size: 14),
                            SizedBox(width: 6),
                            Text('重置为默认'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 立即应用默认大小按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final targetWidth = safeDefaultWidth.clamp(600.0, maxWidth);
                      final targetHeight = safeDefaultHeight.clamp(400.0, maxHeight);
                      appWindow.size = Size(targetWidth, targetHeight);
                      displayInfoBar(
                        context,
                        builder: (context, close) => InfoBar(
                          title: const Text('已应用'),
                          content: Text('窗口大小已调整为 ${targetWidth.toInt()}×${targetHeight.toInt()}'),
                          severity: InfoBarSeverity.success,
                        ),
                        duration: const Duration(seconds: 2),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.full_screen, size: 14),
                        const SizedBox(width: 6),
                        Text('立即应用默认大小 (${safeDefaultWidth.toInt()}×${safeDefaultHeight.toInt()})'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.info,
                size: 16,
                color: FluentTheme.of(context).accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rememberSize 
                      ? '当前启用记忆模式，应用会记住上次关闭时的窗口大小'
                      : '当前使用默认大小模式，每次启动都会使用设定的默认大小',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSegmentsDisplayModeDescription(String mode) {
    switch (mode) {
      case 'none':
        return '简洁模式：不显示分段信息';
      case 'merged':
        return '合并模式：所有分段合并在一个进度条中显示';
      case 'list':
        return '列表模式：每个分段单独一行显示';
      default:
        return '';
    }
  }



  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return SettingsSection(
      title: title,
      icon: icon,
      children: children,
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return SettingsItem(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  /// 显示字体选择对话框（带搜索功能）
  Future<void> _showFontPickerDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _FontPickerDialog(
        availableFonts: _availableFonts,
        selectedFont: _selectedFont,
      ),
    );

    if (result != null && result != _selectedFont) {
      _saveFontSetting(result);
    }
  }
}

/// 字体选择对话框（带搜索功能）
class _FontPickerDialog extends StatefulWidget {
  final List<String> availableFonts;
  final String selectedFont;

  const _FontPickerDialog({
    required this.availableFonts,
    required this.selectedFont,
  });

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  final _searchController = TextEditingController();
  late List<String> _filteredFonts;
  String? _hoveredFont;

  @override
  void initState() {
    super.initState();
    _filteredFonts = widget.availableFonts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFonts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFonts = widget.availableFonts;
      } else {
        _filteredFonts = widget.availableFonts
            .where((font) => font.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('选择字体'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索框
          TextBox(
            controller: _searchController,
            placeholder: '搜索字体...',
            prefix: Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CustomIcons.FluentIcons.searchIcon, size: 16),
            ),
            suffix: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(CustomIcons.FluentIcons.clear, size: 14),
                    onPressed: () {
                      _searchController.clear();
                      _filterFonts('');
                    },
                  )
                : null,
            onChanged: _filterFonts,
          ),
          const SizedBox(height: 12),
          // 字体数量提示
          Row(
            children: [
              Text(
                '共 ${_filteredFonts.length} 个字体',
                style: FluentTheme.of(context).typography.caption,
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '(已过滤)',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: FluentTheme.of(context).accentColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // 字体列表
          Expanded(
            child: _filteredFonts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.searchIcon, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          '没有找到匹配的字体',
                          style: FluentTheme.of(context).typography.body,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFonts.length,
                    itemBuilder: (context, index) {
                      final font = _filteredFonts[index];
                      final isSelected = font == widget.selectedFont;
                      final isHovered = font == _hoveredFont;
                      
                      return MouseRegion(
                        onEnter: (_) => setState(() => _hoveredFont = font),
                        onExit: (_) => setState(() => _hoveredFont = null),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, font),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.2)
                                  : isHovered
                                      ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: isSelected
                                  ? Border.all(
                                      color: FluentTheme.of(context).accentColor.withValues(alpha: 0.5),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Icon(
                                      CustomIcons.FluentIcons.check_mark,
                                      size: 14,
                                      color: FluentTheme.of(context).accentColor,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    font == 'system' ? '系统默认' : font,
                                    style: font == 'system'
                                        ? FluentTheme.of(context).typography.body
                                        : FluentTheme.of(context).typography.body?.copyWith(
                                            fontFamily: font,
                                          ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (font == 'system')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '推荐',
                                      style: FluentTheme.of(context).typography.caption?.copyWith(
                                        color: FluentTheme.of(context).accentColor,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
