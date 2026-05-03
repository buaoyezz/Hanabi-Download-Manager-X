using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Hanabi.Updater.Core;

public sealed class UpdateEngine
{
    private readonly UpdaterArguments _arguments;

    public UpdateEngine(UpdaterArguments arguments)
    {
        _arguments = arguments;
    }

    public async Task RunAsync(IProgress<UpdateProgress> progress, CancellationToken cancellationToken)
    {
        var appPath = new FileInfo(_arguments.AppPath);
        var appDirectory = appPath.Directory ?? throw new DirectoryNotFoundException("无法定位主程序目录");
        if (!appDirectory.Exists)
        {
            appDirectory.Create();
        }

        var sessionRoot = Directory.CreateTempSubdirectory("hanabi_update_");
        var extractDirectory = Directory.CreateDirectory(Path.Combine(sessionRoot.FullName, "package"));
        var backupDirectory = Directory.CreateDirectory(Path.Combine(sessionRoot.FullName, "backup"));

        try
        {
            progress.Report(new UpdateProgress(
                UpdateStage.Preparing,
                2,
                "准备更新",
                BuildTargetText(),
                "正在检查更新参数和文件结构"));

            var zipPath = _arguments.ZipPath;
            if (string.IsNullOrWhiteSpace(zipPath) || !File.Exists(zipPath))
            {
                zipPath = Path.Combine(sessionRoot.FullName, "download.zip");
                await DownloadLatestReleaseAsync(zipPath, progress, cancellationToken);
            }

            if (_arguments.WaitPid > 0)
            {
                await WaitForProcessExitAsync(_arguments.WaitPid, progress, cancellationToken);
            }

            cancellationToken.ThrowIfCancellationRequested();

            ExtractPackage(zipPath, extractDirectory.FullName, progress, cancellationToken);

            cancellationToken.ThrowIfCancellationRequested();

            var sourceDirectory = FindSourceDirectory(extractDirectory.FullName);
            ApplyPackage(sourceDirectory, appDirectory.FullName, backupDirectory.FullName, progress);

            progress.Report(new UpdateProgress(
                UpdateStage.Cleaning,
                94,
                "清理临时文件",
                "正在清理更新过程中产生的临时文件",
                "清理下载包和安装缓存"));

            TryDeleteFile(zipPath);

            progress.Report(new UpdateProgress(
                UpdateStage.Launching,
                98,
                "启动新版本",
                "正在为您打开全新的版本！",
                appPath.Name));

            LaunchApp(appPath.FullName, appDirectory.FullName);

            progress.Report(new UpdateProgress(
                UpdateStage.Completed,
                100,
                "更新完成",
                "已成功安装新版本",
                "您现在可以安全的关闭此程序"));
        }
        catch
        {
            RestoreBackup(backupDirectory.FullName, appDirectory.FullName);
            throw;
        }
        finally
        {
            TryDeleteDirectory(sessionRoot.FullName);
        }
    }

    private string BuildTargetText()
    {
        return string.IsNullOrWhiteSpace(_arguments.TargetVersion)
            ? "正在安装下载好的新版本"
            : $"正在安装 {_arguments.TargetVersion}";
    }

    private async Task DownloadLatestReleaseAsync(string destination, IProgress<UpdateProgress> progress, CancellationToken cancellationToken)
    {
        progress.Report(new UpdateProgress(
            UpdateStage.Downloading,
            5,
            "获取更新信息",
            "正在连接到服务器",
            "请求 GitHub Releases API"));

        using var client = new HttpClient(new HttpClientHandler
        {
            AllowAutoRedirect = true,
            UseProxy = true
        });
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("HanabiUpdater", "1.0"));
        
        var (downloadUrl, tagName) = await ResolveDownloadTargetAsync(client, cancellationToken);

        progress.Report(new UpdateProgress(
            UpdateStage.Downloading,
            5,
            "开始下载",
            $"正在下载版本 {tagName}",
            _arguments.SkipMirror ? "使用 GitHub 源直接下载" : "正在并发测试下载节点"));

        IReadOnlyList<string> rankedUrls;
        if (_arguments.SkipMirror)
        {
            rankedUrls = new[] { downloadUrl };
        }
        else
        {
            rankedUrls = await RankDownloadUrlCandidatesAsync(
                client,
                BuildDownloadUrlCandidates(downloadUrl),
                progress,
                cancellationToken);
        }

        Exception? lastDownloadError = null;
        foreach (var candidateUrl in rankedUrls)
        {
            try
            {
                await DownloadPackageAsync(client, candidateUrl, destination, tagName, progress, cancellationToken);
                return;
            }
            catch (Exception ex)
            {
                lastDownloadError = ex;
                TryDeleteFile(destination);
                progress.Report(new UpdateProgress(
                    UpdateStage.Downloading,
                    6,
                    "切换下载节点",
                    $"正在下载版本 {tagName}",
                    $"节点 {new Uri(candidateUrl).Host} 失败，尝试下一个"));
            }
        }

        throw new InvalidDataException(
            $"无法下载有效更新包：{lastDownloadError?.Message ?? "未知错误"}",
            lastDownloadError);
    }

    private async Task<(string DownloadUrl, string TagName)> ResolveDownloadTargetAsync(
        HttpClient client,
        CancellationToken cancellationToken)
    {
        var targetVersion = NormalizeVersion(_arguments.TargetVersion);
        if (!string.IsNullOrWhiteSpace(_arguments.DownloadUrl))
        {
            return (_arguments.DownloadUrl, string.IsNullOrWhiteSpace(_arguments.TargetVersion)
                ? "Unknown"
                : _arguments.TargetVersion);
        }

        var json = await FetchReleasesJsonAsync(client, cancellationToken);
        var releases = JsonNode.Parse(json)?.AsArray();

        if (releases is null || releases.Count == 0)
        {
            throw new InvalidDataException("没有找到任何版本发布");
        }

        var targetRelease = SelectTargetRelease(releases, targetVersion);

        if (targetRelease is null)
        {
            throw new InvalidDataException("没有找到符合条件的版本");
        }

        var asset = SelectWindowsPackageAsset(targetRelease["assets"]?.AsArray());

        if (asset is null)
        {
            throw new InvalidDataException("在版本发布中未找到适用于 Windows 的 zip 安装包");
        }

        var downloadUrl = asset["browser_download_url"]?.GetValue<string>();
        if (string.IsNullOrWhiteSpace(downloadUrl))
        {
            throw new InvalidDataException("安装包下载地址为空");
        }

        var tagName = targetRelease["tag_name"]?.GetValue<string>() ?? "Unknown";
        return (downloadUrl, tagName);
    }

    private async Task<string> FetchReleasesJsonAsync(HttpClient client, CancellationToken cancellationToken)
    {
        const string apiUrl = "https://api.github.com/repos/buaoyezz/Hanabi-Download-Manager-X/releases";
        Exception? lastError = null;
        var candidates = _arguments.SkipMirror
            ? new[] { apiUrl }
            : BuildGitHubUrlCandidates(apiUrl);
        foreach (var candidateUrl in candidates)
        {
            try
            {
                using var apiRequest = new HttpRequestMessage(HttpMethod.Get, candidateUrl);
                apiRequest.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
                using var response = await client.SendAsync(apiRequest, cancellationToken);
                response.EnsureSuccessStatusCode();
                return await response.Content.ReadAsStringAsync(cancellationToken);
            }
            catch (Exception ex)
            {
                lastError = ex;
            }
        }

        throw new InvalidDataException(
            $"无法获取 GitHub Releases 信息：{lastError?.Message ?? "未知错误"}",
            lastError);
    }

    private JsonNode? SelectTargetRelease(JsonArray releases, string targetVersion)
    {
        if (!string.IsNullOrWhiteSpace(targetVersion))
        {
            var release = releases.FirstOrDefault(item =>
                NormalizeVersion(item?["tag_name"]?.GetValue<string>()) == targetVersion);
            if (release is null)
            {
                throw new InvalidDataException($"没有找到目标版本 {_arguments.TargetVersion}");
            }
            return release;
        }

        foreach (var release in releases)
        {
            var isPrerelease = release?["prerelease"]?.GetValue<bool>() ?? false;
            if (isPrerelease && !_arguments.AllowAlpha)
            {
                continue;
            }
            return release;
        }

        return null;
    }

    private static string NormalizeVersion(string? version)
    {
        return (version ?? string.Empty)
            .Trim()
            .Replace('。', '.')
            .Replace('．', '.')
            .TrimStart('v', 'V')
            .ToLowerInvariant();
    }

    private static IReadOnlyList<string> BuildGitHubUrlCandidates(string originalUrl)
    {
        var proxies = new[]
        {
            "",
            "https://mirror.ghproxy.com/",
            "https://ghproxy.net/",
            "https://moeyy.cn/gh-proxy/",
            "https://gh-proxy.com/"
        };
        return proxies
            .Select(proxy => proxy.Length == 0 ? originalUrl : proxy + originalUrl)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static IReadOnlyList<string> BuildDownloadUrlCandidates(string originalUrl)
    {
        return BuildGitHubUrlCandidates(originalUrl);
    }

    private sealed record DownloadUrlProbe(
        string Url,
        int Index,
        TimeSpan Elapsed,
        bool IsSuccessful,
        string? Error = null);

    private static async Task<IReadOnlyList<string>> RankDownloadUrlCandidatesAsync(
        HttpClient client,
        IReadOnlyList<string> candidates,
        IProgress<UpdateProgress> progress,
        CancellationToken cancellationToken)
    {
        var probeTasks = candidates
            .Select((url, index) => ProbeDownloadUrlAsync(client, url, index, cancellationToken))
            .ToArray();

        var probes = await Task.WhenAll(probeTasks);
        var successful = probes
            .Where(probe => probe.IsSuccessful)
            .OrderBy(probe => probe.Elapsed)
            .ThenBy(probe => probe.Index)
            .ToArray();

        var failed = probes
            .Where(probe => !probe.IsSuccessful)
            .OrderBy(probe => probe.Index)
            .ToArray();

        if (successful.Length > 0)
        {
            var fastest = successful[0];
            progress.Report(new UpdateProgress(
                UpdateStage.Downloading,
                6,
                "选择下载节点",
                "已完成节点测速",
                $"优先使用 {new Uri(fastest.Url).Host}，延迟 {fastest.Elapsed.TotalMilliseconds:F0} ms"));
        }
        else
        {
            progress.Report(new UpdateProgress(
                UpdateStage.Downloading,
                6,
                "选择下载节点",
                "节点测速未获得可用结果",
                "将按默认顺序继续尝试下载"));
        }

        return successful
            .Concat(failed)
            .Select(probe => probe.Url)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static async Task<DownloadUrlProbe> ProbeDownloadUrlAsync(
        HttpClient client,
        string url,
        int index,
        CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(TimeSpan.FromSeconds(4));

            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/octet-stream"));
            request.Headers.Range = new RangeHeaderValue(0, 0);

            using var response = await client.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cts.Token);
            response.EnsureSuccessStatusCode();
            stopwatch.Stop();

            return new DownloadUrlProbe(
                url,
                index,
                stopwatch.Elapsed,
                IsSuccessful: true);
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            return new DownloadUrlProbe(
                url,
                index,
                stopwatch.Elapsed,
                IsSuccessful: false,
                Error: ex.Message);
        }
    }

    private static async Task DownloadPackageAsync(
        HttpClient client,
        string url,
        string destination,
        string tagName,
        IProgress<UpdateProgress> progress,
        CancellationToken cancellationToken)
    {
        progress.Report(new UpdateProgress(
            UpdateStage.Downloading,
            6,
            "开始下载",
            $"正在下载版本 {tagName}",
            $"连接到 {new Uri(url).Host}"));

        using var downloadRequest = new HttpRequestMessage(HttpMethod.Get, url);
        downloadRequest.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/octet-stream"));
        using var downloadResponse = await client.SendAsync(downloadRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        downloadResponse.EnsureSuccessStatusCode();

        var totalBytes = downloadResponse.Content.Headers.ContentLength;
        if (totalBytes is <= 0)
        {
            totalBytes = null;
        }
        var totalRead = 0L;
        await using (var contentStream = await downloadResponse.Content.ReadAsStreamAsync(cancellationToken))
        await using (var fileStream = new FileStream(destination, FileMode.Create, FileAccess.Write, FileShare.None, 8192, true))
        {
            var buffer = new byte[8192];
            while (true)
            {
                var read = await contentStream.ReadAsync(buffer, cancellationToken);
                if (read == 0)
                {
                    break;
                }

                await fileStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                totalRead += read;
                if (totalBytes.HasValue)
                {
                    var percent = 6 + (int)(totalRead * 44d / totalBytes.Value); // 6% to 50%
                    progress.Report(new UpdateProgress(
                        UpdateStage.Downloading,
                        percent,
                        "正在下载更新",
                        $"正在下载版本 {tagName}",
                        $"已下载 {totalRead / 1024 / 1024.0:F1} MB / {totalBytes.Value / 1024 / 1024.0:F1} MB"));
                }
                else
                {
                    progress.Report(new UpdateProgress(
                        UpdateStage.Downloading,
                        6,
                        "正在下载更新",
                        $"正在下载版本 {tagName}",
                        $"已下载 {totalRead / 1024 / 1024.0:F1} MB"));
                }
            }
        }

        if (totalRead <= 0)
        {
            throw new InvalidDataException("下载到的更新包为空");
        }

        ValidateDownloadedPackage(destination);
    }

    private static JsonNode? SelectWindowsPackageAsset(JsonArray? assets)
    {
        if (assets is null)
        {
            return null;
        }

        var zipAssets = assets
            .Where(a => a?["name"]?.GetValue<string>()?.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) == true)
            .ToList();

        if (zipAssets.Count == 0)
        {
            return null;
        }

        static int Score(JsonNode? asset)
        {
            var name = asset?["name"]?.GetValue<string>() ?? string.Empty;
            var lower = name.ToLowerInvariant();

            if (lower.Contains("source") ||
                lower.Contains("chrome_extension") ||
                lower.Contains("firefox_extension") ||
                lower.Contains("extension"))
            {
                return -1000;
            }

            var score = 0;
            if (lower.Contains("hanabidownloadmanagerx")) score += 100;
            if (lower.Contains("release_latest")) score += 80;
            if (lower.Contains("windows") || lower.Contains("win64") || lower.Contains("win-x64")) score += 40;
            if (lower.Contains("alpha")) score += 10;
            if (lower.Contains("mac") || lower.Contains("darwin") || lower.Contains("linux") || lower.Contains("ubuntu")) score -= 200;

            var size = asset?["size"]?.GetValue<long>() ?? 0;
            if (size >= 10 * 1024 * 1024) score += 20;
            if (size is > 0 and < 1024 * 1024) score -= 50;

            return score;
        }

        return zipAssets
            .Select(asset => new { Asset = asset, Score = Score(asset) })
            .Where(candidate => candidate.Score > 0)
            .OrderByDescending(candidate => candidate.Score)
            .ThenByDescending(candidate => candidate.Asset?["size"]?.GetValue<long>() ?? 0)
            .FirstOrDefault()
            ?.Asset;
    }

    private static void ValidateDownloadedPackage(string zipPath)
    {
        try
        {
            using var archive = ZipFile.OpenRead(zipPath);
            var hasAppExecutable = archive.Entries.Any(entry =>
                string.Equals(Path.GetFileName(entry.FullName), "HanabiDownloadManagerX.exe", StringComparison.OrdinalIgnoreCase));
            if (!hasAppExecutable)
            {
                throw new InvalidDataException("下载到的 zip 不是 Hanabi 主程序安装包");
            }
        }
        catch (InvalidDataException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new InvalidDataException("下载到的更新包不是有效 zip 文件", ex);
        }
    }

    private static async Task WaitForProcessExitAsync(
        int pid,
        IProgress<UpdateProgress> progress,
        CancellationToken cancellationToken)
    {
        Process? process = null;
        try
        {
            process = Process.GetProcessById(pid);
        }
        catch (ArgumentException)
        {
            progress.Report(new UpdateProgress(
                UpdateStage.WaitingForAppExit,
                55,
                "等待主程序关闭",
                "主程序已经退出",
                "可以继续替换文件"));
            return;
        }

        using (process)
        {
            var timeout = TimeSpan.FromSeconds(45);
            var started = Stopwatch.StartNew();

            while (!process.HasExited)
            {
                cancellationToken.ThrowIfCancellationRequested();

                if (started.Elapsed >= timeout)
                {
                    progress.Report(new UpdateProgress(
                        UpdateStage.WaitingForAppExit,
                        55,
                        "等待主程序关闭",
                        "等待超时，将继续尝试更新",
                        "如果文件仍被占用，安装会自动回滚"));
                    return;
                }

                var percent = 50 + (int)Math.Min(5, started.Elapsed.TotalSeconds / timeout.TotalSeconds * 5);
                progress.Report(new UpdateProgress(
                    UpdateStage.WaitingForAppExit,
                    percent,
                    "等待主程序关闭",
                    "正在等待 Hanabi 退出以安全替换文件",
                    $"进程 {pid} 仍在退出中"));

                await Task.Delay(200, cancellationToken);
            }
        }

        progress.Report(new UpdateProgress(
            UpdateStage.WaitingForAppExit,
            55,
            "等待主程序关闭",
            "主程序已退出",
            "可以继续替换文件"));
    }

    private static void ExtractPackage(
        string zipPath,
        string extractDirectory,
        IProgress<UpdateProgress> progress,
        CancellationToken cancellationToken)
    {
        using var archive = ZipFile.OpenRead(zipPath);
        var entries = archive.Entries.Where(entry => !string.IsNullOrWhiteSpace(entry.Name)).ToArray();

        if (entries.Length == 0)
        {
            throw new InvalidDataException("更新包中没有可安装文件");
        }

        for (var index = 0; index < entries.Length; index++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var entry = entries[index];
            var destinationPath = GetSafeExtractPath(extractDirectory, entry.FullName);
            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
            entry.ExtractToFile(destinationPath, overwrite: true);

            var percent = 55 + (int)(20d * (index + 1) / entries.Length);
            progress.Report(new UpdateProgress(
                UpdateStage.Extracting,
                percent,
                "解压更新包",
                "正在准备新版本文件",
                entry.FullName));
        }
    }

    private static string GetSafeExtractPath(string extractDirectory, string entryName)
    {
        var destinationPath = Path.GetFullPath(Path.Combine(extractDirectory, entryName));
        var rootPath = Path.GetFullPath(extractDirectory);
        if (!rootPath.EndsWith(Path.DirectorySeparatorChar))
        {
            rootPath += Path.DirectorySeparatorChar;
        }

        if (!destinationPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException($"更新包包含非法路径: {entryName}");
        }

        return destinationPath;
    }

    private static string FindSourceDirectory(string extractDirectory)
    {
        var entries = Directory.EnumerateFileSystemEntries(extractDirectory)
            .Where(path => !Path.GetFileName(path).StartsWith(".", StringComparison.Ordinal))
            .ToArray();

        if (entries.Length == 1 && Directory.Exists(entries[0]))
        {
            return entries[0];
        }

        return extractDirectory;
    }

    private static void ApplyPackage(
        string sourceDirectory,
        string appDirectory,
        string backupDirectory,
        IProgress<UpdateProgress> progress)
    {
        var sourceFiles = Directory.EnumerateFiles(sourceDirectory, "*", SearchOption.AllDirectories).ToArray();

        if (sourceFiles.Length == 0)
        {
            throw new InvalidDataException("更新包中没有可安装文件");
        }

        for (var index = 0; index < sourceFiles.Length; index++)
        {
            var sourceFile = sourceFiles[index];
            var relativePath = Path.GetRelativePath(sourceDirectory, sourceFile);
            var destinationFile = Path.Combine(appDirectory, relativePath);
            var backupFile = Path.Combine(backupDirectory, relativePath);

            Directory.CreateDirectory(Path.GetDirectoryName(destinationFile)!);
            Directory.CreateDirectory(Path.GetDirectoryName(backupFile)!);

            if (File.Exists(destinationFile))
            {
                File.Copy(destinationFile, backupFile, overwrite: true);
            }

            ReplaceFile(sourceFile, destinationFile);

            var percent = 75 + (int)(19d * (index + 1) / sourceFiles.Length);
            progress.Report(new UpdateProgress(
                UpdateStage.Applying,
                percent,
                "安装新版本",
                "正在替换应用文件",
                relativePath));
        }
    }

    private static void ReplaceFile(string sourceFile, string destinationFile)
    {
        try
        {
            File.Copy(sourceFile, destinationFile, overwrite: true);
            return;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            var oldFile = destinationFile + ".old";
            TryDeleteFile(oldFile);
            File.Move(destinationFile, oldFile);
            File.Copy(sourceFile, destinationFile, overwrite: true);
        }
    }

    private static void RestoreBackup(string backupDirectory, string appDirectory)
    {
        if (!Directory.Exists(backupDirectory))
        {
            return;
        }

        foreach (var backupFile in Directory.EnumerateFiles(backupDirectory, "*", SearchOption.AllDirectories))
        {
            var relativePath = Path.GetRelativePath(backupDirectory, backupFile);
            var destinationFile = Path.Combine(appDirectory, relativePath);
            Directory.CreateDirectory(Path.GetDirectoryName(destinationFile)!);
            File.Copy(backupFile, destinationFile, overwrite: true);
        }
    }

    private static void LaunchApp(string appPath, string appDirectory)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = appPath,
            WorkingDirectory = appDirectory,
            UseShellExecute = false
        };

        Process.Start(startInfo);
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // Cleanup must not mask the install result.
        }
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path))
            {
                Directory.Delete(path, recursive: true);
            }
        }
        catch
        {
            // Cleanup must not mask the install result.
        }
    }
}
