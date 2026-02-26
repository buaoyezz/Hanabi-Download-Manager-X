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
import '../../services/localization_service.dart';
import '../../l10n/app_localizations.dart';
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
  bool _showSpeedChart = true;
  bool _showChartFrost = true;
  String _chartPosition = 'mid'; // 'low' | 'mid' | 'high'
  String _chartColor = 'blue';

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
        _showSpeedChart = prefs.getBool('show_speed_chart') ?? true;
        _showChartFrost = prefs.getBool('show_chart_frost') ?? true;
        _chartPosition = prefs.getString('chart_position') ?? 'mid';
        _chartColor = prefs.getString('chart_color') ?? 'blue';

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
      final t = AppLocalizations.of(context)!;
      NotificationManager.of(context)?.showSuccess(
        t.appearanceFontChangedTitle,
        message: t.appearanceFontChangedMessage,
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

  Future<void> _saveShowSpeedChart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_speed_chart', value);
    setState(() => _showSpeedChart = value);
  }

  Future<void> _saveShowChartFrost(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_chart_frost', value);
    setState(() => _showChartFrost = value);
  }

  Future<void> _saveChartPosition(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_position', value);
    setState(() => _chartPosition = value);
  }

  Future<void> _saveChartColor(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_color', value);
    setState(() => _chartColor = value);
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

  String _getNotificationColorSchemeName(String scheme, AppLocalizations t) {
    switch (scheme) {
      case 'defaultScheme':
        return t.appearanceNotificationSchemeSystem;
      case 'light':
        return t.appearanceNotificationSchemeLight;
      case 'dark':
        return t.appearanceNotificationSchemeDark;
      case 'fluent2':
        return t.appearanceNotificationSchemeFluent2;
      default:
        return t.appearanceNotificationSchemeUnknown;
    }
  }
  
  String _getNotificationPositionName(String position, AppLocalizations t) {
    switch (position) {
      case 'topRight':
        return t.appearanceNotificationPositionTopRight;
      case 'bottomRight':
        return t.appearanceNotificationPositionBottomRight;
      default:
        return t.appearanceNotificationPositionUnknown;
    }
  }

  String _getPerformanceModeName(String mode, AppLocalizations t) {
    switch (mode) {
      case 'quality':
        return t.appearancePerformanceModeQuality;
      case 'balanced':
        return t.appearancePerformanceModeBalanced;
      case 'performance':
        return t.appearancePerformanceModePerformance;
      default:
        return t.appearancePerformanceModeUnknown;
    }
  }

  void _showTestNotification() {
    final notificationManager = NotificationManager.of(context);
    if (notificationManager != null) {
      final t = AppLocalizations.of(context)!;
      notificationManager.showSuccess(
        t.appearanceNotificationTestTitle,
        message: t.appearanceNotificationTestMessage,
      );
    }
  }
  
  // 通知配色预览框
  Widget _buildNotificationPreview(BuildContext context) {
    final notificationSettings = NotificationSettingsService();
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context)!;
    
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
              t.appearanceNotificationPreviewTitle,
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
                title: t.appearanceNotificationPreviewSuccessTitle,
                message: t.appearanceNotificationPreviewSuccessMessage,
                icon: CustomIcons.FluentIcons.completed_solid,
                color: notificationSettings.getSuccessColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: t.appearanceNotificationPreviewWarningTitle,
                message: t.appearanceNotificationPreviewWarningMessage,
                icon: CustomIcons.FluentIcons.warning,
                color: notificationSettings.getWarningColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: t.appearanceNotificationPreviewErrorTitle,
                message: t.appearanceNotificationPreviewErrorMessage,
                icon: CustomIcons.FluentIcons.status_error_full,
                color: notificationSettings.getErrorColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: t.appearanceNotificationPreviewInfoTitle,
                message: t.appearanceNotificationPreviewInfoMessage,
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
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
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
      final t = AppLocalizations.of(context)!;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        dialogTitle: t.appearanceFontImportDialogTitle,
      );

      if (result != null && result.files.single.path != null) {
        final fontPath = result.files.single.path!;
        
        if (mounted) {
          // 显示加载提示
          NotificationManager.of(context)?.showInfo(
            t.appearanceFontImportingTitle,
            message: t.appearanceFontImportingMessage,
          );
        }

        final fontService = context.read<FontService>();
        final success = await fontService.addCustomFont(fontPath);

        if (mounted) {
          if (success) {
            // 重新加载字体列表
            await _loadAvailableFonts();
            
            NotificationManager.of(context)?.showSuccess(
              t.appearanceFontImportSuccessTitle,
              message: t.appearanceFontImportSuccessMessage,
            );
          } else {
            NotificationManager.of(context)?.showError(
              t.appearanceFontImportFailedTitle,
              message: t.appearanceFontImportFailedMessage,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing font: $e');
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showError(
          t.appearanceFontImportFailedTitle,
          message: t.appearanceFontImportFailedWithErrorMessage(e.toString()),
        );
        Clipboard.setData(ClipboardData(text: e.toString()));
      }
    }
  }

  Future<void> _removeCustomFont(String fontName) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.appearanceFontDeleteConfirmTitle),
        content: Text(t.appearanceFontDeleteConfirmMessage(fontName)),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.appearanceFontDeleteCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.appearanceFontDeleteConfirmButton),
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
          NotificationManager.of(context)?.showSuccess(
            t.appearanceFontDeleteSuccessTitle,
            message: t.appearanceFontDeleteSuccessMessage,
          );
        } else {
          NotificationManager.of(context)?.showError(
            t.appearanceFontDeleteFailedTitle,
            message: t.appearanceFontDeleteFailedMessage,
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
    final localizationService = context.watch<LocalizationService>();
    final t = AppLocalizations.of(context)!;

    final packs = [...localizationService.languagePacks]
      ..sort((a, b) => a.localeTag.compareTo(b.localeTag));
    final languageLabels = <String, String>{
      'system': t.appearanceLanguageSystem,
      'zh': t.appearanceLanguageChinese,
      'en': t.appearanceLanguageEnglish,
    };
    for (final pack in packs) {
      if (languageLabels.containsKey(pack.localeTag)) continue;
      final name = (pack.name ?? '').trim();
      final label = name.isEmpty ? pack.localeTag : name;
      languageLabels[pack.localeTag] = label;
    }
    final languagePreference = localizationService.languagePreference;
    final selectedLanguage = languageLabels.containsKey(languagePreference)
        ? languagePreference
        : 'system';
    final langDir = '${clientConfig.baseDir}${Platform.pathSeparator}lang';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        
        // 窗口大小设置
        _buildSection(
          context,
          title: t.appearanceWindowSizeSection,
          icon: CustomIcons.FluentIcons.full_screen,
          children: [
            _buildWindowSizeSettings(context, clientConfig),
          ],
        ),
        const SizedBox(height: 24),
        
        // UI 缩放设置
        _buildSection(
          context,
          title: t.appearanceUiScaleSection,
          icon: CustomIcons.FluentIcons.font_size,
          children: [
            _buildSettingItem(
              context,
              title: t.appearanceUiScaleTitle,
              subtitle: t.appearanceUiScaleSubtitle,
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
                        NotificationManager.of(context)?.showInfo(
                          t.appearanceUiScaleResetTitle,
                          message: t.appearanceUiScaleResetMessage,
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.refresh, size: 14),
                        SizedBox(width: 6),
                        Text(t.appearanceUiScaleResetButton),
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
                        NotificationManager.of(context)?.showSuccess(
                          t.appearanceUiScaleApplyTitle,
                          message: t.appearanceUiScaleApplyMessage,
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.full_screen, size: 14),
                        SizedBox(width: 6),
                        Text(t.appearanceUiScale4kButton),
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
                      t.appearanceUiScaleHint,
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

        // 语言设置
        _buildSection(
          context,
          title: t.appearanceSectionLanguage,
          icon: CustomIcons.FluentIcons.globe,
          children: [
            _buildSettingItem(
              context,
              title: t.appearanceLanguageTitle,
              subtitle: t.appearanceLanguageSubtitle,
              trailing: SizedBox(
                width: 250,
                child: ComboBox<String>(
                  value: selectedLanguage,
                  items: languageLabels.entries
                      .map(
                        (entry) => ComboBoxItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    await localizationService.setLanguagePreference(value);
                    if (mounted) {
                      // Wait for the next frame to ensure the new locale is applied
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (!mounted) return;
                      
                      // Get the new localization after language switch
                      final newT = AppLocalizations.of(context)!;
                      NotificationManager.of(context)?.showSuccess(
                        newT.appearanceLanguageSwitchedTitle,
                        message: value == 'system'
                            ? newT.appearanceLanguageSwitchedSystem
                            : newT.appearanceLanguageSwitchedTo(languageLabels[value] ?? value),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.appearanceLanguagePacksTitle,
              subtitle: t.appearanceLanguagePacksSubtitle(langDir),
              trailing: SizedBox(
                width: 250,
                child: Button(
                  onPressed: () async {
                    await localizationService.reloadLanguagePacks();
                    if (mounted) {
                      NotificationManager.of(context)?.showSuccess(
                        t.appearanceLanguagePacksRefreshedTitle,
                        message: t.appearanceLanguagePacksRefreshedMessage(
                          localizationService.languagePacks.length,
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CustomIcons.FluentIcons.refresh, size: 14),
                      const SizedBox(width: 6),
                      Text(t.appearanceLanguageRefreshButton),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.developerOpenL10nFolderTitle,
              subtitle: t.developerOpenL10nFolderSubtitle,
              trailing: SizedBox(
                width: 250,
                child: Button(
                  onPressed: () async {
                    try {
                      final dir = Directory(langDir);
                      if (!await dir.exists()) {
                        await dir.create(recursive: true);
                      }
                      await Process.run('explorer', [langDir]);
                    } catch (e) {
                      if (mounted) {
                        NotificationManager.of(context)?.showError(
                          t.developerOpenL10nFolderFailedTitle,
                          message: t.developerOpenL10nFolderFailedMessage(e.toString()),
                        );
                      }
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CustomIcons.FluentIcons.folder_open, size: 14),
                      const SizedBox(width: 6),
                      Text(t.developerOpenL10nFolderTitle),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // 字体设置
        _buildSection(
          context,
          title: t.appearanceFontSection,
          icon: CustomIcons.FluentIcons.font,
          children: [
            _buildSettingItem(
              context,
              title: t.appearanceFontTitle,
              subtitle: _selectedFont == 'system'
                  ? t.appearanceFontSystemSubtitle
                  : t.appearanceFontCurrentSubtitle(_selectedFont),
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
                                _selectedFont == 'system'
                                    ? t.appearanceFontSystemLabel
                                    : _selectedFont,
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
                        Text(t.appearanceFontImportButton),
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
                            Text(t.appearanceFontDeleteButton),
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
                      t.appearanceFontHint,
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
          title: t.appearanceWindowEffectsSection,
          icon: CustomIcons.FluentIcons.color,
          children: [
            _buildSettingItem(
              context,
              title: t.appearanceWindowEffectsEnableTitle,
              subtitle: windowEffect.effectEnabled
                  ? t.appearanceWindowEffectsEnabledSubtitle
                  : t.appearanceWindowEffectsDisabledSubtitle,
              trailing: ToggleSwitch(
                checked: windowEffect.effectEnabled,
                onChanged: (value) async {
                  await windowEffect.setEffectEnabled(value);
                  if (mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      value
                          ? t.appearanceWindowEffectsEnabledTitle
                          : t.appearanceWindowEffectsDisabledTitle,
                      message: value
                          ? t.appearanceWindowEffectsEnabledMessage
                          : t.appearanceWindowEffectsDisabledMessage,
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
                  title: t.appearanceWindowEffectsTypeTitle,
                  subtitle: _getEffectModeDescription(windowEffect.effectMode, t),
                  trailing: ComboBox<String>(
                    value: windowEffect.effectMode,
                    items: [
                      ComboBoxItem(
                        value: 'acrylic',
                        child: Text(t.appearanceWindowEffectAcrylic),
                      ),
                      ComboBoxItem(
                        value: 'blur',
                        child: Text(t.appearanceWindowEffectBlur),
                      ),
                      // Mica 选项仅在 Win11 上显示
                      if (windowEffect.isWindows11) ...[
                        ComboBoxItem(
                          value: 'mica_main',
                          child: Text(t.appearanceWindowEffectMica),
                        ),
                        ComboBoxItem(
                          value: 'mica_transient',
                          child: Text(t.appearanceWindowEffectMicaAlt),
                        ),
                      ],
                    ],
                    onChanged: (value) async {
                      if (value != null) {
                        await windowEffect.setEffectMode(value);
                        if (mounted) {
                          NotificationManager.of(context)?.showSuccess(
                            t.appearanceWindowEffectSwitchedTitle,
                            message: _getEffectModeDescription(value, t),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: windowEffect.effectEnabled && !windowEffect.isMicaEffect ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: !windowEffect.effectEnabled || windowEffect.isMicaEffect,
                child: _buildSettingItem(
                  context,
                  title: t.appearanceWindowEffectsAcrylicOpacityTitle,
                  subtitle: windowEffect.isMicaEffect
                      ? t.appearanceWindowEffectsAcrylicOpacityMicaHint
                      : t.appearanceWindowEffectsAcrylicOpacityHint,
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
            // Win10: suspend effect during drag (only show on Win10 with effect enabled)
            if (!windowEffect.isWindows11 && windowEffect.effectEnabled) ...[
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                title: t.appearanceWindowEffectsDragSuspendTitle,
                subtitle: windowEffect.dragSuspend
                    ? t.appearanceWindowEffectsDragSuspendEnabledSubtitle
                    : t.appearanceWindowEffectsDragSuspendDisabledSubtitle,
                trailing: ToggleSwitch(
                  checked: windowEffect.dragSuspend,
                  onChanged: (value) async {
                    await windowEffect.setDragSuspend(value);
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: windowEffect.isMicaEffect
                    ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                    : windowEffect.effectEnabled
                        ? Colors.orange.withValues(alpha: 0.1)
                        : AppTheme.statusSuccess.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: windowEffect.isMicaEffect
                      ? FluentTheme.of(context).accentColor.withValues(alpha: 0.3)
                      : windowEffect.effectEnabled
                          ? Colors.orange.withValues(alpha: 0.3)
                          : AppTheme.statusSuccess.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    windowEffect.isMicaEffect
                        ? CustomIcons.FluentIcons.info
                        : windowEffect.effectEnabled
                            ? CustomIcons.FluentIcons.warning
                            : CustomIcons.FluentIcons.completed_solid,
                    size: 16,
                    color: windowEffect.isMicaEffect
                        ? FluentTheme.of(context).accentColor
                        : windowEffect.effectEnabled
                            ? Colors.orange
                            : AppTheme.statusSuccess,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      windowEffect.isMicaEffect
                          ? t.appearanceWindowEffectsMicaHint
                          : windowEffect.effectEnabled
                              ? t.appearanceWindowEffectsAcrylicHint
                              : t.appearanceWindowEffectsDisabledHint,
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: windowEffect.isMicaEffect
                            ? FluentTheme.of(context).accentColor
                            : windowEffect.effectEnabled
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
          title: t.appearanceSidebarSection,
          icon: CustomIcons.FluentIcons.side_panel,
          children: [
            _buildSettingItem(
              context,
              title: t.appearanceSidebarDefaultTitle,
              subtitle: t.appearanceSidebarDefaultSubtitle,
              trailing: ComboBox<bool>(
                value: clientConfig.getSidebarDefaultExpanded(),
                items: [
                  ComboBoxItem(value: true, child: Text(t.appearanceSidebarExpandedLabel)),
                  ComboBoxItem(value: false, child: Text(t.appearanceSidebarCollapsedLabel)),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await clientConfig.setSidebarDefaultExpanded(value);
                    if (mounted) {
                      final label = value ? t.appearanceSidebarExpandedLabel : t.appearanceSidebarCollapsedLabel;
                      NotificationManager.of(context)?.showSuccess(
                        t.appearanceSidebarSavedTitle,
                        message: t.appearanceSidebarSavedMessage(label),
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
          title: t.appearanceNotificationSection,
          icon: CustomIcons.FluentIcons.ringer,
          children: [
            _buildSettingItem(
              context,
              title: t.appearanceNotificationEnableTitle,
              subtitle: t.appearanceNotificationEnableSubtitle,
              trailing: ToggleSwitch(
                checked: _notificationEnabled,
                onChanged: (value) => _saveNotificationEnabled(value),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.appearanceNotificationSchemeTitle,
              subtitle: _getNotificationColorSchemeName(_notificationColorScheme, t),
              trailing: ComboBox<String>(
                value: _notificationColorScheme,
                items: [
                  ComboBoxItem(
                    value: 'defaultScheme',
                    child: Text(t.appearanceNotificationSchemeDefaultOption),
                  ),
                  ComboBoxItem(
                    value: 'light',
                    child: Text(t.appearanceNotificationSchemeLightOption),
                  ),
                  ComboBoxItem(
                    value: 'dark',
                    child: Text(t.appearanceNotificationSchemeDarkOption),
                  ),
                  ComboBoxItem(
                    value: 'fluent2',
                    child: Text(t.appearanceNotificationSchemeFluent2Option),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _saveNotificationColorScheme(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.appearanceNotificationPositionTitle,
              subtitle: _getNotificationPositionName(_notificationPosition, t),
              trailing: ComboBox<String>(
                value: _notificationPosition,
                items: [
                  ComboBoxItem(
                    value: 'topRight',
                    child: Text(t.appearanceNotificationPositionTopRightOption),
                  ),
                  ComboBoxItem(
                    value: 'bottomRight',
                    child: Text(t.appearanceNotificationPositionBottomRightOption),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _saveNotificationPosition(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.appearanceNotificationPerformanceTitle,
              subtitle: _getPerformanceModeName(_performanceMode, t),
              trailing: ComboBox<String>(
                value: _performanceMode,
                items: [
                  ComboBoxItem(
                    value: 'performance',
                    child: Text(t.appearanceNotificationPerformanceOptionPerformance),
                  ),
                  ComboBoxItem(
                    value: 'balanced',
                    child: Text(t.appearanceNotificationPerformanceOptionBalanced),
                  ),
                  ComboBoxItem(
                    value: 'quality',
                    child: Text(t.appearanceNotificationPerformanceOptionQuality),
                  ),
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
                      t.appearanceNotificationPerformanceHint,
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
              title: t.appearanceNotificationPreviewButtonTitle,
              subtitle: t.appearanceNotificationPreviewButtonSubtitle,
              trailing: Button(
                onPressed: _showTestNotification,
                child: Text(t.appearanceNotificationPreviewButton),
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
          title: t.appearanceDownloadListSection,
          icon: CustomIcons.FluentIcons.list,
          children: [
            _buildSettingItem(
              context,
              title: t.appearanceSegmentsModeTitle,
              subtitle: _getSegmentsDisplayModeDescription(_segmentsDisplayMode, t),
              trailing: ComboBox<String>(
                value: _segmentsDisplayMode,
                items: [
                  ComboBoxItem(
                    value: 'none',
                    child: Text(t.appearanceSegmentsModeNoneOption),
                  ),
                  ComboBoxItem(
                    value: 'merged',
                    child: Text(t.appearanceSegmentsModeMergedOption),
                  ),
                  ComboBoxItem(
                    value: 'list',
                    child: Text(t.appearanceSegmentsModeListOption),
                  ),
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
                  title: t.appearanceSegmentsDefaultExpandedTitle,
                  subtitle: t.appearanceSegmentsDefaultExpandedSubtitle,
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
                  title: t.appearanceSegmentsMaxVisibleTitle,
                  subtitle: t.appearanceSegmentsMaxVisibleSubtitle,
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
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.appearanceSpeedChartTitle,
              subtitle: t.appearanceSpeedChartSubtitle,
              trailing: ToggleSwitch(
                checked: _showSpeedChart,
                onChanged: (value) => _saveShowSpeedChart(value),
              ),
            ),
            // 速度曲线子设置（仅在开启时显示）
            if (_showSpeedChart) ...[
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                title: t.appearanceChartFrostTitle,
                subtitle: t.appearanceChartFrostSubtitle,
                trailing: ToggleSwitch(
                  checked: _showChartFrost,
                  onChanged: (value) => _saveShowChartFrost(value),
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                title: t.appearanceChartPositionTitle,
                subtitle: t.appearanceChartPositionSubtitle,
                trailing: ComboBox<String>(
                  value: _chartPosition,
                  items: [
                    ComboBoxItem(value: 'low', child: Text(t.appearanceChartPositionLow)),
                    ComboBoxItem(value: 'mid', child: Text(t.appearanceChartPositionMid)),
                    ComboBoxItem(value: 'high', child: Text(t.appearanceChartPositionHigh)),
                  ],
                  onChanged: (value) {
                    if (value != null) _saveChartPosition(value);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                title: t.appearanceChartColorTitle,
                subtitle: t.appearanceChartColorSubtitle,
                trailing: ComboBox<String>(
                  value: _chartColor,
                  items: [
                    ComboBoxItem(value: 'blue', child: _buildColorOption(const Color(0xFF0078D4), t.appearanceChartColorBlue)),
                    ComboBoxItem(value: 'cyan', child: _buildColorOption(const Color(0xFF60CDFF), t.appearanceChartColorCyan)),
                    ComboBoxItem(value: 'purple', child: _buildColorOption(const Color(0xFF8B5CF6), t.appearanceChartColorPurple)),
                    ComboBoxItem(value: 'green', child: _buildColorOption(const Color(0xFF10B981), t.appearanceChartColorGreen)),
                    ComboBoxItem(value: 'pink', child: _buildColorOption(const Color(0xFFEC4899), t.appearanceChartColorPink)),
                    ComboBoxItem(value: 'orange', child: _buildColorOption(const Color(0xFFF97316), t.appearanceChartColorOrange)),
                  ],
                  onChanged: (value) {
                    if (value != null) _saveChartColor(value);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildWindowSizeSettings(BuildContext context, ClientConfigService config) {
    final t = AppLocalizations.of(context)!;
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
          title: t.appearanceWindowRememberTitle,
          subtitle: rememberSize 
              ? t.appearanceWindowRememberSubtitleOn
              : t.appearanceWindowRememberSubtitleOff,
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
                  title: t.appearanceWindowDefaultWidthTitle,
                  subtitle: t.appearanceWindowDefaultWidthSubtitle(maxWidth.toInt()),
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
                  title: t.appearanceWindowDefaultHeightTitle,
                  subtitle: t.appearanceWindowDefaultHeightSubtitle(maxHeight.toInt()),
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
                            NotificationManager.of(context)?.showSuccess(
                              t.appearanceWindowSaveTitle,
                              message: t.appearanceWindowSaveMessage(
                                safeWidth.toInt(),
                                safeHeight.toInt(),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.save, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              t.appearanceWindowSaveButton(
                                currentWidth.toInt(),
                                currentHeight.toInt(),
                              ),
                            ),
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
                            NotificationManager.of(context)?.showInfo(
                              t.appearanceWindowResetTitle,
                              message: t.appearanceWindowResetMessage,
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.refresh, size: 14),
                            SizedBox(width: 6),
                            Text(t.appearanceWindowResetButton),
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
                      NotificationManager.of(context)?.showSuccess(
                        t.appearanceWindowApplyTitle,
                        message: t.appearanceWindowApplyMessage(
                          targetWidth.toInt(),
                          targetHeight.toInt(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.full_screen, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          t.appearanceWindowApplyButton(
                            safeDefaultWidth.toInt(),
                            safeDefaultHeight.toInt(),
                          ),
                        ),
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
                      ? t.appearanceWindowRememberHintOn
                      : t.appearanceWindowRememberHintOff,
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

  String _getSegmentsDisplayModeDescription(String mode, AppLocalizations t) {
    switch (mode) {
      case 'none':
        return t.appearanceSegmentsModeNoneDescription;
      case 'merged':
        return t.appearanceSegmentsModeMergedDescription;
      case 'list':
        return t.appearanceSegmentsModeListDescription;
      default:
        return '';
    }
  }

  String _getEffectModeDescription(String mode, AppLocalizations t) {
    switch (mode) {
      case 'none':
        return t.appearanceEffectNone;
      case 'blur':
        return t.appearanceEffectBlur;
      case 'acrylic':
        return t.appearanceEffectAcrylic;
      case 'mica_main':
        return t.appearanceEffectMica;
      case 'mica_transient':
        return t.appearanceEffectMicaAlt;
      default:
        return t.appearanceEffectUnknown;
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

  Widget _buildColorOption(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
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
    final t = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _FontPickerDialog(
        availableFonts: _availableFonts,
        selectedFont: _selectedFont,
        t: t,
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
  final AppLocalizations t;

  const _FontPickerDialog({
    required this.availableFonts,
    required this.selectedFont,
    required this.t,
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
      title: Text(widget.t.appearanceFontPickerTitle),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索框
          TextBox(
            controller: _searchController,
            placeholder: widget.t.appearanceFontPickerSearchPlaceholder,
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
                widget.t.appearanceFontPickerCount(_filteredFonts.length),
                style: FluentTheme.of(context).typography.caption,
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  widget.t.appearanceFontPickerFilteredLabel,
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
                          widget.t.appearanceFontPickerEmpty,
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
                                    font == 'system'
                                        ? widget.t.appearanceFontSystemLabel
                                        : font,
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
                                      widget.t.appearanceFontPickerRecommended,
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
          child: Text(widget.t.appearanceFontPickerCancel),
        ),
      ],
    );
  }
}
