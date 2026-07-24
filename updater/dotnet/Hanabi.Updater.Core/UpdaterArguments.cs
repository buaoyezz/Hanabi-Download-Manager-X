using System.Diagnostics;

namespace Hanabi.Updater.Core;

public sealed record UpdaterArguments(
    string AppPath,
    string? ZipPath,
    string? DownloadUrl,
    string AppName,
    int WaitPid,
    string TargetVersion,
    bool AllowAlpha,
    bool SkipMirror)
{
    public static ParseResult Parse(IEnumerable<string> args)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var pendingKey = string.Empty;

        foreach (var arg in args)
        {
            if (arg.StartsWith("--", StringComparison.Ordinal))
            {
                var parts = arg[2..].Split('=', 2);
                if (parts.Length == 2)
                {
                    values[parts[0]] = parts[1];
                }
                else
                {
                    pendingKey = parts[0];
                    values[pendingKey] = string.Empty;
                }
                continue;
            }

            if (pendingKey.Length == 0)
            {
                return ParseResult.Fail($"未知参数: {arg}");
            }

            values[pendingKey] = arg;
            pendingKey = string.Empty;
        }

        if (!values.TryGetValue("app-path", out var appPath) || string.IsNullOrWhiteSpace(appPath))
        {
            try
            {
                var processes = Process.GetProcessesByName("HanabiDownloadManagerX");
                if (processes.Length > 0 && processes[0].MainModule?.FileName is string exePath)
                {
                    appPath = exePath;
                }
            }
            catch { }

            if (string.IsNullOrWhiteSpace(appPath))
            {
                appPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Hanabi", "HanabiDownloadManagerX.exe");
            }
        }

        string? zipPath = null;
        if (values.TryGetValue("zip-path", out var zipArg) && !string.IsNullOrWhiteSpace(zipArg))
        {
            zipPath = Path.GetFullPath(zipArg);
        }
        else
        {
            var updateZip = Path.Combine(AppContext.BaseDirectory, "update.zip");
            var hanabiZip = Path.Combine(AppContext.BaseDirectory, "Hanabi.zip");

            if (File.Exists(updateZip))
            {
                zipPath = updateZip;
            }
            else if (File.Exists(hanabiZip))
            {
                zipPath = hanabiZip;
            }
            // If still null, UpdateEngine will handle the download.
        }

        values.TryGetValue("download-url", out var downloadUrl);
        if (string.IsNullOrWhiteSpace(downloadUrl))
        {
            downloadUrl = null;
        }

        var appName = values.GetValueOrDefault("app-name");
        if (string.IsNullOrWhiteSpace(appName))
        {
            appName = "Hanabi Download Manager X";
        }

        var targetVersion = values.GetValueOrDefault("version") ?? string.Empty;
        var waitPid = 0;
        if (values.TryGetValue("wait-pid", out var waitPidRaw) &&
            !string.IsNullOrWhiteSpace(waitPidRaw) &&
            !int.TryParse(waitPidRaw, out waitPid))
        {
            return ParseResult.Fail($"无效的 --wait-pid: {waitPidRaw}");
        }

        var allowAlpha = false;
        if (values.TryGetValue("alpha", out var alphaRaw))
        {
            allowAlpha = string.IsNullOrWhiteSpace(alphaRaw) ||
                bool.TryParse(alphaRaw, out var alphaResult) && alphaResult;
        }

        var skipMirror = values.ContainsKey("skip-mirror");

        return ParseResult.Ok(new UpdaterArguments(
            Path.GetFullPath(appPath),
            zipPath,
            downloadUrl,
            appName,
            waitPid,
            targetVersion,
            allowAlpha,
            skipMirror));
    }
}

public sealed record ParseResult(UpdaterArguments? Arguments, string? Error)
{
    public bool IsSuccess => Arguments is not null;

    public static ParseResult Ok(UpdaterArguments arguments) => new(arguments, null);

    public static ParseResult Fail(string error) => new(null, error);
}
