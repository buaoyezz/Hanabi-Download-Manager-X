import os

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:bitsdojo_window/bitsdojo_window.dart';", "import 'package:window_manager/window_manager.dart';")

start_idx = content.find('    doWhenWindowReady(() async {')
end_str = '    });\n  });\n}'
end_idx = content.find(end_str, start_idx)

if start_idx != -1 and end_idx != -1:
    end_idx += 7
    new_block = """    await windowManager.ensureInitialized();
    
    // 获取屏幕大小（使用 screen_retriever）
    double screenWidth = 1920.0;
    double screenHeight = 1080.0;
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      screenWidth = primaryDisplay.size.width;
      screenHeight = primaryDisplay.size.height;
      debugPrint('Screen size: $screenWidth x $screenHeight');

      // 根据屏幕分辨率自动设置缩放比例
      await clientConfig.autoSetScaleFactorByResolution(
          screenWidth, screenHeight);
    } catch (e) {
      debugPrint('Failed to get screen size: $e');
    }

    // 根据是否记忆大小来决定使用哪个尺寸
    Size initialSize;
    final rememberSize = clientConfig.getWindowRememberSize();
    final defaultWidth = clientConfig.getWindowDefaultWidth();
    final defaultHeight = clientConfig.getWindowDefaultHeight();

    if (rememberSize) {
      final savedWidth = clientConfig.getWindowWidth();
      final savedHeight = clientConfig.getWindowHeight();
      
      bool isOldConfig = false;
      if ((savedWidth == 1280.0 && savedHeight == 800.0) ||
          (savedWidth == 1200.0 && savedHeight == 800.0)) {
        isOldConfig = true;
      }

      double targetWidth = savedWidth;
      double targetHeight = savedHeight;

      if (isOldConfig) {
        targetWidth = defaultWidth;
        targetHeight = defaultHeight;
        await clientConfig.setWindowWidth(defaultWidth);
        await clientConfig.setWindowHeight(defaultHeight);
      }

      final safeWidth = targetWidth.clamp(600.0, screenWidth);
      final safeHeight = targetHeight.clamp(400.0, screenHeight);
      initialSize = Size(safeWidth, safeHeight);
    } else {
      final safeWidth = defaultWidth.clamp(600.0, screenWidth);
      final safeHeight = defaultHeight.clamp(400.0, screenHeight);
      initialSize = Size(safeWidth, safeHeight);
    }

    WindowOptions windowOptions = WindowOptions(
      size: initialSize,
      minimumSize: const Size(600, 400),
      center: true,
      title: "Hanabi Download ManagerX",
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (!isAutoStart) {
        await windowManager.show();
        await windowManager.focus();
      }
    });"""

    content = content[:start_idx] + new_block + content[end_idx:]

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
