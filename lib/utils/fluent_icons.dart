import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Fluent System Icons - 动态解析版本
/// 从 FluentSystemIcons-Regular.json 动态加载图标
class FluentIcons {
  FluentIcons._();

  static const _kFontFam = 'FluentSystemIcons';
  static const String? _kFontPkg = null;

  // 图标映射缓存
  static Map<String, int>? _iconMap;
  static bool _isLoading = false;
  static bool _isLoaded = false;

  /// 初始化图标映射（从 JSON 加载）
  static Future<void> initialize() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    try {
      final String jsonString = await rootBundle
          .loadString('assets/font/FluentSystemIcons-Regular.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _iconMap = {};
      jsonData.forEach((key, value) {
        if (value is int) {
          // 存储原始完整名字
          _iconMap![key] = value;

          // 同时存储简化名字（移除 "ic_fluent_" 前缀和 "_regular" 后缀）
          String cleanName =
              key.replaceFirst('ic_fluent_', '').replaceFirst('_regular', '');
          if (cleanName != key) {
            _iconMap![cleanName] = value;
          }
        }
      });

      _isLoaded = true;
    } catch (_) {
    } finally {
      _isLoading = false;
    }
  }

  /// 根据名字获取图标（动态查找）
  ///
  /// 使用方法：
  /// ```dart
  /// Icon(FluentIcons.getIcon('arrow_download_24'))
  /// Icon(FluentIcons.getIcon('settings_24'))
  /// Icon(FluentIcons.getIcon('checkmark_circle_20'))
  /// ```
  static IconData getIcon(String name, {int? fallbackCode}) {
    if (_iconMap == null) {
      return IconData(
        fallbackCode ?? 61697, // 默认图标
        fontFamily: _kFontFam,
        fontPackage: _kFontPkg,
      );
    }

    final code = _iconMap![name];
    if (code == null) {
      return IconData(
        fallbackCode ?? 61697,
        fontFamily: _kFontFam,
        fontPackage: _kFontPkg,
      );
    }

    return IconData(code, fontFamily: _kFontFam, fontPackage: _kFontPkg);
  }

  /// 搜索图标（模糊匹配）
  ///
  /// 使用方法：
  /// ```dart
  /// final results = FluentIcons.search('download');
  /// // 返回: ['arrow_download_16', 'arrow_download_20', 'arrow_download_24', ...]
  /// ```
  static List<String> search(String keyword) {
    if (_iconMap == null) return [];

    final lowerKeyword = keyword.toLowerCase();
    return _iconMap!.keys
        .where((name) => name.toLowerCase().contains(lowerKeyword))
        .toList()
      ..sort();
  }

  /// 获取所有可用的图标名称
  static List<String> getAllIconNames() {
    return _iconMap?.keys.toList() ?? [];
  }

  // ============================================
  // 常用图标别名（向后兼容）
  // ============================================
  // 这些静态 getter 保持不变，以确保现有代码不会中断
  // 它们会在首次访问时动态加载对应的图标

  // 窗口控制图标
  static IconData get arrow_maximize_20 => getIcon('maximize_20');
  static IconData get arrow_maximize_24 => getIcon('maximize_24');
  static IconData get maximize_20 => arrow_maximize_20;
  static IconData get maximize_24 => arrow_maximize_24;

  static IconData get arrowMinimize20 =>
      getIcon('ic_fluent_full_screen_minimize_20_regular');
  static IconData get arrowMinimize24 =>
      getIcon('ic_fluent_full_screen_minimize_24_regular');

  static IconData get minimize_20 => arrowMinimize20;
  static IconData get minimize_24 => arrowMinimize24;

  static IconData get dismiss_20 => getIcon('dismiss_20');
  static IconData get dismiss_24 => getIcon('dismiss_24');

  static IconData get subtract_20 => getIcon('subtract_20');
  static IconData get subtract_24 => getIcon('subtract_24');

  // 导航图标（侧边栏）
  static IconData get arrow_download_20 => getIcon('arrow_download_20');
  static IconData get arrow_download_24 => getIcon('arrow_download_24');
  static IconData get download => arrow_download_24;

  static IconData get checkmark_circle_20 => getIcon('checkmark_circle_20');
  static IconData get checkmark_circle_24 => getIcon('checkmark_circle_24');
  static IconData get completed => checkmark_circle_24;

  static IconData get document_20 => getIcon('document_20');
  static IconData get document_24 => getIcon('document_24');
  static IconData get text_document => document_24;
  static IconData get document => document_24;

  static IconData get heart_pulse_20 => getIcon('heart_pulse_20');
  static IconData get heart_pulse_24 => getIcon('heart_pulse_24');
  static IconData get health => heart_pulse_24;

  static IconData get globe_20 => getIcon('globe_20');
  static IconData get globe_24 => getIcon('globe_24');
  static IconData get globe => globe_24;

  static IconData get people_20 => getIcon('people_20');
  static IconData get people_24 => getIcon('people_24');
  static IconData get people => people_24;

  static IconData get settings_20 => getIcon('settings_20');
  static IconData get settings_24 => getIcon('settings_24');
  static IconData get settings => settings_24;

  static IconData get info_20 => getIcon('info_20');
  static IconData get info_24 => getIcon('info_24');
  static IconData get info => info_24;

  static IconData get navigation_20 => getIcon('navigation_20');
  static IconData get navigation_24 => getIcon('navigation_24');
  static IconData get global_nav_button => navigation_24;

  // 操作图标
  static IconData get add_20 => getIcon('add_20');
  static IconData get add_24 => getIcon('add_24');
  static IconData get add => add_24;

  static IconData get arrow_sync_20 => getIcon('arrow_sync_20');
  static IconData get arrow_sync_24 => getIcon('arrow_sync_24');
  static IconData get refresh => arrow_sync_24;

  static IconData get delete_20 => getIcon('delete_20');
  static IconData get delete_24 => getIcon('delete_24');
  static IconData get delete => delete_24;

  static IconData get warning_20 => getIcon('warning_20');
  static IconData get warning_24 => getIcon('warning_24');
  static IconData get warning => warning_24;

  // 文件和文件夹图标
  static IconData get folder_20 => getIcon('folder_20');
  static IconData get folder_24 => getIcon('folder_24');
  static IconData get folder => folder_24;

  static IconData get folder_open_20 => getIcon('folder_open_20');
  static IconData get folder_open_24 => getIcon('folder_open_24');
  static IconData get folder_open => folder_open_24;

  static IconData get hard_drive_20 => getIcon('hard_drive_20');
  static IconData get hard_drive_24 => getIcon('hard_drive_24');
  static IconData get hard_drive => hard_drive_24;

  // 箭头和方向图标
  static IconData get arrow_up_20 => getIcon('arrow_up_20');
  static IconData get arrow_up_24 => getIcon('arrow_up_24');
  static IconData get up => arrow_up_24;

  static IconData get chevron_right_20 => getIcon('chevron_right_20');
  static IconData get chevron_right_24 => getIcon('chevron_right_24');
  static IconData get chevron_right => chevron_right_24;

  static IconData get chevron_down_20 => getIcon('chevron_down_20');
  static IconData get chevron_down_24 => getIcon('chevron_down_24');
  static IconData get chevron_down => chevron_down_24;

  static IconData get chevron_up_20 => getIcon('chevron_up_20');
  static IconData get chevron_up_24 => getIcon('chevron_up_24');
  static IconData get chevron_up => chevron_up_24;

  static IconData get chevron_up_small => chevron_up_20;
  static IconData get chevron_down_small => chevron_down_20;

  // 其他常用图标
  static IconData get checkmark_20 => getIcon('checkmark_20');
  static IconData get checkmark_24 => getIcon('checkmark_24');
  static IconData get checkmark => checkmark_24;
  static IconData get check_mark => checkmark_24;

  static IconData get error_circle_20 => getIcon('error_circle_20');
  static IconData get error_circle_24 => getIcon('error_circle_24');
  static IconData get error => error_circle_24;
  static IconData get error_badge => error_circle_24;

  static IconData get link_20 => getIcon('link_20');
  static IconData get link_24 => getIcon('link_24');
  static IconData get link => link_24;

  static IconData get arrow_maximize_vertical_20 =>
      getIcon('arrow_maximize_vertical_20');
  static IconData get arrow_maximize_vertical_24 =>
      getIcon('arrow_maximize_vertical_24');
  static IconData get chrome_restore => arrow_maximize_vertical_24;

  static IconData get chrome_minimize => subtract_24;
  static IconData get chrome_close => dismiss_24;

  static IconData get status_circle_checkmark => checkmark_circle_24;

  static IconData get video_20 => getIcon('video_20');
  static IconData get video_24 => getIcon('video_24');
  static IconData get video => video_24;

  static IconData get music_note_2_20 => getIcon('music_note_2_20');
  static IconData get music_note_2_24 => getIcon('music_note_2_24');
  static IconData get music_note => music_note_2_24;

  static IconData get archive_20 => getIcon('archive_20');
  static IconData get archive_24 => getIcon('archive_24');
  static IconData get archive => archive_24;

  static IconData get apps_20 => getIcon('apps_20');
  static IconData get apps_24 => getIcon('apps_24');
  static IconData get app_icon_default => apps_24;

  static IconData get more_horizontal_20 => getIcon('more_horizontal_20');
  static IconData get more_horizontal_24 => getIcon('more_horizontal_24');
  static IconData get more => more_horizontal_24;

  static IconData get search_20 => getIcon('search_20');
  static IconData get search_24 => getIcon('search_24');
  static IconData get searchIcon => search_24; // 重命名以避免与 search() 方法冲突
  static IconData get search_issue => search_24;

  static IconData get filter_20 => getIcon('filter_20');
  static IconData get filter_24 => getIcon('filter_24');
  static IconData get filter => filter_24;

  static IconData get list_20 => getIcon('list_20');
  static IconData get list_24 => getIcon('list_24');
  static IconData get list => list_24;

  static IconData get pause_20 => getIcon('pause_20');
  static IconData get pause_24 => getIcon('pause_24');
  static IconData get pause => pause_24;

  static IconData get clock_20 => getIcon('clock_20');
  static IconData get clock_24 => getIcon('clock_24');
  static IconData get clock => clock_24;

  static IconData get play_20 => getIcon('play_20');
  static IconData get play_24 => getIcon('play_24');
  static IconData get play => play_24;

  static IconData get processing => settings_24;

  static IconData get split_vertical_20 => getIcon('split_vertical_20');
  static IconData get split_vertical_24 => getIcon('split_vertical_24');
  static IconData get split => split_vertical_24;
  static IconData get split_object => split_vertical_24;

  static IconData get top_speed_20 => getIcon('top_speed_20');
  static IconData get top_speed_24 => getIcon('top_speed_24');
  static IconData get speed_high => top_speed_24;

  static IconData get dismiss_circle_20 => getIcon('dismiss_circle_20');
  static IconData get dismiss_circle_24 => getIcon('dismiss_circle_24');
  static IconData get clear => dismiss_circle_24;

  static IconData get tag_20 => getIcon('tag_20');
  static IconData get tag_24 => getIcon('tag_24');
  static IconData get tag => tag_24;

  static IconData get data_bar_vertical_20 => getIcon('data_bar_vertical_20');
  static IconData get data_bar_vertical_24 => getIcon('data_bar_vertical_24');
  static IconData get chart => data_bar_vertical_24;

  static IconData get timeline_20 => getIcon('timeline_20');
  static IconData get timeline_24 => getIcon('timeline_24');
  static IconData get timeline_progress => timeline_24;

  static IconData get server_20 => getIcon('server_20');
  static IconData get server_24 => getIcon('server_24');
  static IconData get server => server_24;

  static IconData get pin_20 => getIcon('pin_20');
  static IconData get pin_24 => getIcon('pin_24');
  static IconData get pinned_solid => pin_24;

  static IconData get arrow_sort_20 => getIcon('arrow_sort_20');
  static IconData get arrow_sort_24 => getIcon('arrow_sort_24');
  static IconData get sort_up => arrow_sort_24;
  static IconData get sort_down => arrow_sort_24;

  static IconData get checkbox_checked_20 => getIcon('checkbox_checked_20');
  static IconData get checkbox_checked_24 => getIcon('checkbox_checked_24');
  static IconData get checkbox_composite => checkbox_checked_24;

  // 设置页面专用图标
  static IconData get paint_brush_20 => getIcon('paint_brush_20');
  static IconData get paint_brush_24 => getIcon('paint_brush_24');
  static IconData get color => paint_brush_24;

  static IconData get update_restore => arrow_sync_24;

  static IconData get power_20 => getIcon('power_20');
  static IconData get power_24 => getIcon('power_24');
  static IconData get power_button => power_24;

  static IconData get globe_shield_20 => getIcon('globe_shield_20');
  static IconData get globe_shield_24 => getIcon('globe_shield_24');
  static IconData get network_tower => globe_shield_24;

  static IconData get record_20 => getIcon('record_20');
  static IconData get record_24 => getIcon('record_24');
  static IconData get status_circle_inner => record_24;

  static IconData get globe_desktop_20 => getIcon('globe_desktop_20');
  static IconData get globe_desktop_24 => getIcon('globe_desktop_24');
  static IconData get edge_logo => globe_desktop_24;

  static IconData get code_20 => getIcon('code_20');
  static IconData get code_24 => getIcon('code_24');
  static IconData get code => code_24;

  static IconData get wrench_screwdriver_20 => getIcon('wrench_screwdriver_20');
  static IconData get wrench_screwdriver_24 => getIcon('wrench_screwdriver_24');
  static IconData get developer_tools => wrench_screwdriver_24;

  static IconData get tab_20 => getIcon('tab_20');
  static IconData get tab_24 => getIcon('tab_24');
  static IconData get page => tab_24;

  static IconData get alert_20 => getIcon('alert_20');
  static IconData get alert_24 => getIcon('alert_24');
  static IconData get ringer => alert_24;

  static IconData get lightbulb_20 => getIcon('lightbulb_20');
  static IconData get lightbulb_24 => getIcon('lightbulb_24');
  static IconData get lightbulb => lightbulb_24;

  static IconData get mail_20 => getIcon('mail_20');
  static IconData get mail_24 => getIcon('mail_24');
  static IconData get mail => mail_24;

  static IconData get desktop_20 => getIcon('desktop_20');
  static IconData get desktop_24 => getIcon('desktop_24');
  static IconData get system => desktop_24;

  static IconData get plug_disconnected_20 => getIcon('plug_disconnected_20');
  static IconData get plug_disconnected_24 => getIcon('plug_disconnected_24');
  static IconData get plug_disconnected => plug_disconnected_24;

  static IconData get completed_solid => checkmark_circle_24;
  static IconData get status_error_full => dismiss_circle_24;

  static IconData get eye_20 => getIcon('eye_20');
  static IconData get eye_24 => getIcon('eye_24');
  static IconData get preview => eye_24;

  static IconData get text_font_size_20 => getIcon('text_font_size_20');
  static IconData get text_font_size_24 => getIcon('text_font_size_24');
  static IconData get font_size => text_font_size_24;

  static IconData get full_screen_maximize_20 =>
      getIcon('full_screen_maximize_20');
  static IconData get full_screen_maximize_24 =>
      getIcon('full_screen_maximize_24');
  static IconData get full_screen => full_screen_maximize_24;

  static IconData get text_font_20 => getIcon('text_font_20');
  static IconData get text_font_24 => getIcon('text_font_24');
  static IconData get font => text_font_24;

  static IconData get panel_left_20 => getIcon('panel_left_20');
  static IconData get panel_left_24 => getIcon('panel_left_24');
  static IconData get side_panel => panel_left_24;

  static IconData get save_20 => getIcon('save_20');
  static IconData get save_24 => getIcon('save_24');
  static IconData get save => save_24;

  // 日志页面专用图标
  static IconData get bookmark_20 => getIcon('bookmark_20');
  static IconData get bookmark_24 => getIcon('bookmark_24');
  static IconData get bookmark => bookmark_24;
  static IconData get single_bookmark => bookmark_24;
  static IconData get single_bookmark_solid => bookmark_24;

  static IconData get copy_20 => getIcon('copy_20');
  static IconData get copy_24 => getIcon('copy_24');
  static IconData get copy => copy_24;

  static IconData get flash_auto_24 => getIcon('flash_auto_24');
  static IconData get lightning_bolt => flash_auto_24;

  static IconData get eye_off_20 => getIcon('eye_off_20');
  static IconData get eye_off_24 => getIcon('eye_off_24');
  static IconData get eye_off => eye_off_24;
  static IconData get hide3 => eye_off_24;

  static IconData get database_20 => getIcon('database_20');
  static IconData get database_24 => getIcon('database_24');
  static IconData get source => database_24;

  // 更新页面专用图标
  static IconData get box_edit_20 => getIcon('box_edit_20');
  static IconData get box_edit_24 => getIcon('box_edit_24');
  static IconData get box_edit => box_edit_24;
  static IconData get product_release => box_edit_24;
}
