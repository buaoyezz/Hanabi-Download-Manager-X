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
import '../../widgets/settings_components.dart';
import '../../services/font_service.dart';
import '../../services/window_effect_service.dart';
import '../../services/client_config_service.dart';

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
    if (mounted) {
      final fontService = context.read<FontService>();
      setState(() {
        _selectedFont = fontService.selectedFont;
        _segmentsDefaultExpanded = prefs.getBool('segments_default_expanded') ?? false;
        _segmentsMaxVisible = prefs.getInt('segments_max_visible') ?? 5;
        _segmentsDisplayMode = prefs.getString('segments_display_mode') ?? 'merged';
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
          icon: FluentIcons.full_screen,
          children: [
            _buildWindowSizeSettings(context, clientConfig),
          ],
        ),
        const SizedBox(height: 24),
        
        // 字体设置
        _buildSection(
          context,
          title: '字体',
          icon: FluentIcons.font,
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
                      child: ComboBox<String>(
                        value: _selectedFont,
                        isExpanded: true,
                        items: _availableFonts.map((font) {
                          return ComboBoxItem(
                            value: font,
                            child: Text(
                              font == 'system' ? '系统默认' : font,
                              style: font == 'system' 
                                  ? null 
                                  : TextStyle(fontFamily: font),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _saveFontSetting(value);
                          }
                        },
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
                        const Icon(FluentIcons.add, size: 14),
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
                            const Icon(FluentIcons.delete, size: 14),
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
                    FluentIcons.info,
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
          icon: FluentIcons.color,
          children: [
            _buildSettingItem(
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
          ],
        ),
        const SizedBox(height: 24),
        
        // 侧边栏设置
        _buildSection(
          context,
          title: '侧边栏',
          icon: FluentIcons.side_panel,
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
        
        // 下载列表显示
        _buildSection(
          context,
          title: '下载列表显示',
          icon: FluentIcons.list,
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
                            const Icon(FluentIcons.save, size: 14),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.refresh, size: 14),
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
                        const Icon(FluentIcons.full_screen, size: 14),
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
                FluentIcons.info,
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
}
