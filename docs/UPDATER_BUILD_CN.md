# HDMX 安装器构建指南

>[!NOTE]
>源码位于 `updater/dotnet/Hanabi.Updater.App/`
>基于 .NET 10 + Avalonia 12

>[!IMPORTANT]
> ##### 前提条件
>- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
>- Windows 10/11 x64

## 构建

**懒人一键构建：**

```bat
updater\build.bat
```

该脚本自动执行 `dotnet build` + `dotnet publish`，一条命令出两个产物。

**分步手动构建：**

```powershell
# 1. 先编译确保无错误
dotnet build updater/dotnet/Hanabi.Updater.sln -c Release

# 2. 再发布
powershell -ExecutionPolicy Bypass -File updater/build_dotnet.ps1
```

脚本会产出两个版本：

### 1. Bundle 构建 (`updater/dist/`)

供主程序内嵌使用，NativeAOT 编译，但仍依赖原生 Skia DLL，所以以目录形式分发
> 因为这样拉起更快

```
updater/dist/
├── HanabiUpdater.exe       # NativeAOT 入口
├── av_libglesv2.dll        # Angle/Skia 依赖
├── libHarfBuzzSharp.dll    # Skia 文本渲染
├── libSkiaSharp.dll        # Skia 图形
└── ...
```

主程序构建时，`build_release.bat` 会将整个 `dist/` 目录复制到 `data/zzbuaoye_assets/updater/`。

### 2. 独立安装器 (`updater/standalone/`)

单文件自解压 EXE，用于独立分发。将 Avalonia/Skia 原生 DLL 嵌入 EXE 中，运行时自动提取。

**输出文件：`updater/standalone/HanabiDownloadManagerX_Setup.exe`**

## 构建流程

`build_dotnet.ps1` 分三步：

1. **清理** — 删除旧的 `dist/` 和 `standalone/`
2. **Bundle 构建** — `dotnet publish -c Release -r win-x64 --self-contained -p:PublishAot=true`
3. **Standalone 构建** — `dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true`
4. **重命名** — 将 standalone 的 `HanabiUpdater.exe` 改为 `HanabiDownloadManagerX_Setup.exe`

## 集成构建

`build_release.bat` 在第 1.5 步自动调用更新器构建：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File "updater\build_dotnet.ps1"
```

然后复制 `updater/dist/` 到 Flutter 构建产物的 `data/zzbuaoye_assets/updater/` 目录中。

可通过 `--copy-only` 跳过构建仅复制已有产物。
支持中英文切换(记得i18n)
