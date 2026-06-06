import os
import re

files_to_process = [
    'lib/screens/home_screen.dart',
    'lib/screens/widgets/appearance_settings_page.dart',
    'lib/screens/widgets/settings_page.dart',
    'lib/services/clipboard_listener_service.dart',
    'lib/services/popup_window_service.dart',
    'lib/services/system_tray_service.dart',
    'lib/widgets/tray_menu_window.dart'
]

def replace_in_file(filepath):
    if not os.path.exists(filepath):
        return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Imports
    content = content.replace("import 'package:bitsdojo_window/bitsdojo_window.dart';", "import 'package:window_manager/window_manager.dart';")
    
    # Simple methods
    content = content.replace('appWindow.minimize()', 'windowManager.minimize()')
    content = content.replace('appWindow.maximize()', 'windowManager.maximize()')
    content = content.replace('appWindow.restore()', 'windowManager.restore()')
    content = content.replace('appWindow.hide()', 'windowManager.hide()')
    content = content.replace('appWindow.show()', 'windowManager.show()')
    content = content.replace('appWindow.close()', 'windowManager.close()')
    
    # isVisible
    if 'appWindow.isVisible' in content:
        # If used in an if condition, we might need to handle async if not already handled
        # We will replace it with `await windowManager.isVisible()` and assume the function is async
        # (if not, dart analyze will tell us)
        content = content.replace('appWindow.isVisible', 'await windowManager.isVisible()')

    # sizes
    content = content.replace('appWindow.size.width', '(await windowManager.getSize()).width')
    content = content.replace('appWindow.size.height', '(await windowManager.getSize()).height')
    content = content.replace('appWindow.size = Size(targetWidth, targetHeight);', 'await windowManager.setSize(Size(targetWidth, targetHeight));')

    # MoveWindow
    content = content.replace('MoveWindow(', 'DragToMoveArea(')
    
    # WindowBorder
    # Since WindowBorder requires width and color, let's just replace it with a Container
    content = re.sub(r'WindowBorder\(\s*color:[^,]+,\s*width:[^,]+,\s*child:', 'Container(child:', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

for file in files_to_process:
    replace_in_file(file)

print('Refactored all bitsdojo references')
