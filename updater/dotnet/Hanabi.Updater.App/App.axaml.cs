using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Avalonia.Platform;
using Avalonia.Threading;

namespace Hanabi.Updater.App;

public partial class App : Application
{
    private IPlatformSettings? _platformSettings;

    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        _platformSettings = PlatformSettings;
        if (_platformSettings is not null)
        {
            ApplySystemAccentColor(_platformSettings.GetColorValues());
            _platformSettings.ColorValuesChanged += OnColorValuesChanged;
        }

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var args = Environment.GetCommandLineArgs().Skip(1).ToArray();
            var launchProbe = args.Any(arg =>
                string.Equals(arg, "--launch-probe", StringComparison.OrdinalIgnoreCase));

            if (launchProbe)
            {
                desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;
                _ = new MainWindow();
                WriteReadyHandshake(args);
                Dispatcher.UIThread.Post(() => desktop.Shutdown(0));
            }
            else
            {
                desktop.MainWindow = new MainWindow();
                WriteReadyHandshake(args);
            }
        }

        base.OnFrameworkInitializationCompleted();
    }

    private void OnColorValuesChanged(object? sender, PlatformColorValues values)
    {
        Dispatcher.UIThread.Post(() => ApplySystemAccentColor(values));
    }

    private void ApplySystemAccentColor(PlatformColorValues values)
    {
        var accent = EnsureOpaque(values.AccentColor1);
        var accentHover = EnsureOpaque(values.AccentColor2);
        var foreground = RelativeLuminance(accent) > 0.52
            ? Colors.Black
            : Colors.White;

        Resources["AccentBrush"] = new SolidColorBrush(accent);
        Resources["AccentHoverBrush"] = new SolidColorBrush(accentHover);
        Resources["AccentSoftBrush"] = new SolidColorBrush(
            Color.FromArgb(46, accent.R, accent.G, accent.B));
        Resources["AccentForegroundBrush"] = new SolidColorBrush(foreground);
        Resources["ProgressFg"] = new SolidColorBrush(accent);
    }

    private static Color EnsureOpaque(Color color)
    {
        return Color.FromArgb(255, color.R, color.G, color.B);
    }

    private static double RelativeLuminance(Color color)
    {
        static double Linearize(byte channel)
        {
            var value = channel / 255d;
            return value <= 0.04045
                ? value / 12.92
                : Math.Pow((value + 0.055) / 1.055, 2.4);
        }

        return 0.2126 * Linearize(color.R) +
            0.7152 * Linearize(color.G) +
            0.0722 * Linearize(color.B);
    }

    private static void WriteReadyHandshake(IReadOnlyList<string> args)
    {
        var readyFile = ReadOption(args, "--ready-file");
        if (string.IsNullOrWhiteSpace(readyFile))
        {
            return;
        }

        var fullPath = Path.GetFullPath(readyFile);
        var directory = Path.GetDirectoryName(fullPath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }
        File.WriteAllText(
            fullPath,
            $"pid={Environment.ProcessId};ready={DateTimeOffset.UtcNow:O}");
    }

    private static string? ReadOption(IReadOnlyList<string> args, string name)
    {
        for (var index = 0; index < args.Count; index++)
        {
            var argument = args[index];
            if (argument.StartsWith(name + "=", StringComparison.OrdinalIgnoreCase))
            {
                return argument[(name.Length + 1)..];
            }
            if (string.Equals(argument, name, StringComparison.OrdinalIgnoreCase) &&
                index + 1 < args.Count)
            {
                return args[index + 1];
            }
        }
        return null;
    }
}
