"""
Tauri 图标生成脚本
使用 Pillow 将 logo.png 转换为 Tauri 需要的所有图标尺寸
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("Installing Pillow...")
    os.system("pip install Pillow")
    from PIL import Image

def generate_icons(source_path, output_dir):
    """生成 Tauri 需要的所有图标"""

    # 打开源图片
    img = Image.open(source_path)

    # 确保是 RGBA 模式
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    # 创建输出目录
    os.makedirs(output_dir, exist_ok=True)

    # PNG 图标尺寸
    png_sizes = {
        '32x32.png': 32,
        '128x128.png': 128,
        '128x128@2x.png': 256,
        'icon.png': 512,
        'Square30x30Logo.png': 30,
        'Square44x44Logo.png': 44,
        'Square71x71Logo.png': 71,
        'Square89x89Logo.png': 89,
        'Square107x107Logo.png': 107,
        'Square142x142Logo.png': 142,
        'Square150x150Logo.png': 150,
        'Square284x284Logo.png': 284,
        'Square310x310Logo.png': 310,
        'StoreLogo.png': 512,
    }

    # 生成 PNG 图标
    for filename, size in png_sizes.items():
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        output_path = os.path.join(output_dir, filename)
        resized.save(output_path, 'PNG')
        print(f"  + {filename} ({size}x{size})")

    # 生成 ICO 文件 (Windows)
    ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    ico_images = [img.resize(size, Image.Resampling.LANCZOS) for size in ico_sizes]
    ico_path = os.path.join(output_dir, 'icon.ico')
    ico_images[0].save(ico_path, format='ICO', sizes=ico_sizes)
    print(f"  + icon.ico (multi-size)")

    # 生成 ICNS 文件 (macOS) - 简化版，只保存为 PNG
    # 真正的 ICNS 需要额外的库，这里用 PNG 代替
    icns_path = os.path.join(output_dir, 'icon.icns')
    img_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
    img_512.save(icns_path, 'PNG')  # macOS 可以识别 PNG 格式的 icns
    print(f"  + icon.icns (512x512)")

    print(f"\nDone! Icons saved to: {output_dir}")

if __name__ == '__main__':
    # 源 logo 路径
    source = os.path.join(os.path.dirname(__file__), 'assets', 'logo', 'logo.png')

    # 输出目录
    output = os.path.join(os.path.dirname(__file__), 'hanabi-popup', 'src-tauri', 'icons')

    if len(sys.argv) > 1:
        source = sys.argv[1]

    print(f"Source: {source}")
    print(f"Output: {output}")
    print()

    if not os.path.exists(source):
        print(f"Error: Source file not found: {source}")
        sys.exit(1)

    generate_icons(source, output)
