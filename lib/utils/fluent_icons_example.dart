import 'package:flutter/material.dart';
import 'fluent_icons.dart';

/// FluentIcons 使用示例
/// 
/// 本文件展示了如何使用我们的FluentIcons，替换fluentui_icons包的示例调用代码
/// 本类提供了多种使用方法，都在下面了 
class FluentIconsExample {
  
  /// 方法 1: 使用预定义的别名（向后兼容）
  /// 这些别名会自动从 JSON 加载对应的图标
  static void usePreDefinedIcons() {
    // 直接使用静态 getter
    Icon(FluentIcons.download);
    Icon(FluentIcons.settings);
    Icon(FluentIcons.checkmark_circle_24);
    Icon(FluentIcons.folder);
    Icon(FluentIcons.delete);
  }
  
  /// 方法 2: 使用 getIcon() 动态获取任意图标
  /// 只需要知道图标名字，不需要记住数字代号
  static void useDynamicIcons() {
    // 使用图标名字直接获取
    Icon(FluentIcons.getIcon('arrow_download_24'));
    Icon(FluentIcons.getIcon('settings_20'));
    Icon(FluentIcons.getIcon('checkmark_circle_24'));
    
    // 可以使用 JSON 中的任何图标（9314 个图标）
    Icon(FluentIcons.getIcon('heart_24'));
    Icon(FluentIcons.getIcon('star_24'));
    Icon(FluentIcons.getIcon('calendar_24'));
    Icon(FluentIcons.getIcon('camera_24'));
    Icon(FluentIcons.getIcon('cloud_24'));
    
    // 如果图标不存在，会使用默认图标并打印警告
    Icon(FluentIcons.getIcon('non_existent_icon'));
    
    // 可以指定自定义的 fallback 图标代码
    Icon(FluentIcons.getIcon('non_existent_icon', fallbackCode: 61706));
  }
  
  /// 方法 3: 搜索图标
  /// 当你不确定图标的确切名字时，可以搜索
  static void searchIcons() {
    // 搜索包含 "download" 的所有图标
    final downloadIcons = FluentIcons.search('download');
    // 返回: ['arrow_download_16', 'arrow_download_20', 'arrow_download_24', ...]
    
    // 搜索包含 "heart" 的所有图标
    FluentIcons.search('heart');
    
    // 搜索包含 "calendar" 的所有图标
    FluentIcons.search('calendar');
    
    // 使用搜索结果
    for (final iconName in downloadIcons) {
      Icon(FluentIcons.getIcon(iconName));
    }
  }
  
  /// 方法 4: 获取所有可用图标
  static void getAllIcons() {
    final allIcons = FluentIcons.getAllIconNames();
    print('Total icons available: ${allIcons.length}');
    
    // 显示前 10 个图标
    for (final iconName in allIcons.take(10)) {
      print('Icon: $iconName');
    }
  }
  
  /// 实际使用示例：创建一个图标选择器
  static Widget buildIconPicker(Function(String) onIconSelected) {
    return Builder(
      builder: (context) {
        final searchController = TextEditingController();
        final searchResults = ValueNotifier<List<String>>([]);
        
        return Column(
          children: [
            // 搜索框
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: '搜索图标',
                hintText: '输入图标名字，如 download, heart, calendar',
              ),
              onChanged: (query) {
                if (query.isEmpty) {
                  searchResults.value = [];
                } else {
                  searchResults.value = FluentIcons.search(query);
                }
              },
            ),
            
            // 搜索结果
            Expanded(
              child: ValueListenableBuilder<List<String>>(
                valueListenable: searchResults,
                builder: (context, results, _) {
                  if (results.isEmpty) {
                    return const Center(
                      child: Text('输入关键词搜索图标'),
                    );
                  }
                  
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final iconName = results[index];
                      return InkWell(
                        onTap: () => onIconSelected(iconName),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FluentIcons.getIcon(iconName),
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              iconName,
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 常用图标分类
class CommonIcons {
  // 文件操作
  static const fileIcons = [
    'document_24',
    'folder_24',
    'folder_open_24',
    'archive_24',
    'document_pdf_24',
  ];
  
  // 媒体
  static const mediaIcons = [
    'video_24',
    'music_note_2_24',
    'image_24',
    'camera_24',
  ];
  
  // 操作
  static const actionIcons = [
    'add_24',
    'delete_24',
    'edit_24',
    'save_24',
    'copy_24',
    'cut_24',
    'paste_24',
  ];
  
  // 导航
  static const navigationIcons = [
    'arrow_left_24',
    'arrow_right_24',
    'arrow_up_24',
    'arrow_down_24',
    'chevron_left_24',
    'chevron_right_24',
    'chevron_up_24',
    'chevron_down_24',
  ];
  
  // 状态
  static const statusIcons = [
    'checkmark_circle_24',
    'error_circle_24',
    'warning_24',
    'info_24',
    'clock_24',
  ];
  
  // 社交
  static const socialIcons = [
    'people_24',
    'person_24',
    'mail_24',
    'chat_24',
    'heart_24',
    'star_24',
  ];
}
