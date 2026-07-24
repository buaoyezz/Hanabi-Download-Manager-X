using System.Diagnostics;
using System.IO.Compression;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace Hanabi.Updater.Core;

public sealed class UpdateEngine
{
    private const long DiskSpaceReserve = 64L * 1024 * 1024;
    private const long MaxExpandedPackageSize = 4L * 1024 * 1024 * 1024;
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
        var installationJournal = new InstallationJournal();
        var ownsDownloadedPackage = false;

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
                zipPath = await DownloadLatestReleaseAsync(progress, cancellationToken);
                ownsDownloadedPackage = true;
            }

            var packageInfo = InspectPackage(zipPath);
            EnsureDiskSpace(
                sessionRoot.FullName,
                checked(packageInfo.ExpandedSize * 2 + DiskSpaceReserve),
                "临时目录");
            EnsureDiskSpace(
                appDirectory.FullName,
                checked(packageInfo.ExpandedSize + DiskSpaceReserve),
                "安装目录");

            if (_arguments.WaitPid > 0)
            {
                await WaitForProcessExitAsync(_arguments.WaitPid, progress, cancellationToken);
            }

            cancellationToken.ThrowIfCancellationRequested();

            ExtractPackage(zipPath, extractDirectory.FullName, progress, cancellationToken);

            cancellationToken.ThrowIfCancellationRequested();

            var sourceDirectory = FindSourceDirectory(extractDirectory.FullName);
            ApplyPackage(
                sourceDirectory,
                appDirectory.FullName,
                backupDirectory.FullName,
                installationJournal,
                progress);
            CleanupReplacedFiles(installationJournal);

            progress.Report(new UpdateProgress(
                UpdateStage.Cleaning,
                94,
                "清理临时文件",
                "正在清理更新过程中产生的临时文件",
                "清理下载包和安装缓存"));

            if (ownsDownloadedPackage)
            {
                TryDeleteFile(zipPath);
            }

            progress.Report(new UpdateProgress(
                UpdateStage.Launching,
                98,
                "启动新版本",
                "正在为您打开全新的版本！",
                appPath.Name));

            var launchWarning = TryLaunchApp(appPath.FullName, appDirectory.FullName);

            progress.Report(new UpdateProgress(
                UpdateStage.Completed,
                100,
                "更新完成",
                "已成功安装新版本",
                launchWarning ?? "新版本已经启动，您现在可以安全关闭更新器"));
        }
        catch (Exception installError)
        {
            try
            {
                RestoreBackup(backupDirectory.FullName, appDirectory.FullName, installationJournal);
            }
            catch (Exception rollbackError)
            {
                throw new AggregateException(
                    "更新失败，且未能完整恢复原版本文件。请重新运行安装器进行修复。",
                    installError,
                    rollbackError);
            }

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

    private async Task<string> DownloadLatestReleaseAsync(
        IProgress<UpdateProgress> progress,
        CancellationToken cancellationToken)
    {
        progress.Report(new UpdateProgress(
            UpdateStage.Downloading,
            5,
            "获取更新信息",
            "正在连接到服务器",
            "请求 GitHub Releases API"));

        using var client = new HttpClient(new SocketsHttpHandler
        {
            AllowAutoRedirect = true,
            UseProxy = true,
            ConnectTimeout = TimeSpan.FromSeconds(15),
            MaxConnectionsPerServer = 8,
            PooledConnectionLifetime = TimeSpan.FromMinutes(5)
        })
        {
            // A complete package can legitimately take much longer than HttpClient's
            // 100 second default on a weak connection. Per-operation timeouts below
            // still detect dead connections.
            Timeout = Timeout.InfiniteTimeSpan
        };
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("HanabiUpdater", "1.0"));

        var (downloadUrl, tagName) = await ResolveDownloadTargetAsync(client, cancellationToken);
        var destination = BuildDownloadCachePath(downloadUrl);
        CleanupStaleDownloadCache(Path.GetDirectoryName(destination)!, destination);

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

        var downloader = new ResilientHttpDownloader(client);
        Exception? lastDownloadError = null;
        foreach (var candidateUrl in rankedUrls)
        {
            try
            {
                await DownloadPackageAsync(
                    downloader,
                    candidateUrl,
                    destination,
                    tagName,
                    progress,
                    cancellationToken);
                return destination;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                lastDownloadError = ex;
                if (ex is InvalidDataException)
                {
                    // Invalid content cannot be resumed safely from another node.
                    TryDeleteFile(destination);
                }
                progress.Report(new UpdateProgress(
                    UpdateStage.Downloading,
                    6,
                    "切换下载节点",
                    $"正在下载版本 {tagName}",
                    $"{new Uri(candidateUrl).Host} 暂时不可用，保留已下载内容并尝试下一节点"));
            }
        }

        throw new InvalidDataException(
            $"无法下载有效更新包：{lastDownloadError?.Message ?? "未知错误"}",
            lastDownloadError);
    }

    private static string BuildDownloadCachePath(string downloadUrl)
    {
        var cacheDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Hanabi",
            "UpdaterCache");
        Directory.CreateDirectory(cacheDirectory);

        var urlHash = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(downloadUrl)))[..16];
        return Path.Combine(cacheDirectory, $"{urlHash}.zip.part");
    }

    private static void CleanupStaleDownloadCache(string cacheDirectory, string activeFile)
    {
        try
        {
            var staleBefore = DateTime.UtcNow.AddDays(-14);
            foreach (var file in Directory.EnumerateFiles(cacheDirectory, "*.zip.part"))
            {
                if (!string.Equals(file, activeFile, StringComparison.OrdinalIgnoreCase) &&
                    File.GetLastWriteTimeUtc(file) < staleBefore)
                {
                    TryDeleteFile(file);
                }
            }
        }
        catch
        {
            // Cache maintenance must not prevent an update.
        }
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
            for (var attempt = 1; attempt <= 2; attempt++)
            {
                try
                {
                    using var apiRequest = new HttpRequestMessage(HttpMethod.Get, candidateUrl);
                    apiRequest.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
                    using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                    timeout.CancelAfter(TimeSpan.FromSeconds(15));
                    using var response = await client.SendAsync(apiRequest, timeout.Token);
                    response.EnsureSuccessStatusCode();
                    return await response.Content.ReadAsStringAsync(cancellationToken);
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    lastError = ex;
                    if (attempt < 2)
                    {
                        await Task.Delay(TimeSpan.FromMilliseconds(500), cancellationToken);
                    }
                }
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
        TimeSpan Latency,
        double BytesPerSecond,
        long SampledBytes,
        bool IsSuccessful,
        string? Error = null);

    private static async Task<IReadOnlyList<string>> RankDownloadUrlCandidatesAsync(
        HttpClient client,
        IReadOnlyList<string> candidates,
        IProgress<UpdateProgress> progress,
        CancellationToken cancellationToken)
    {
        progress.Report(new UpdateProgress(
            UpdateStage.Downloading,
            5,
            "正在选择下载节点",
            "正在测试各节点的实际传输速度",
            "可跳过测速并直接使用 GitHub 源",
            CanSkip: true));

        var probeTasks = candidates
            .Select((url, index) => ProbeDownloadUrlAsync(client, url, index, cancellationToken))
            .ToArray();

        var probes = await Task.WhenAll(probeTasks);
        var successful = probes
            .Where(probe => probe.IsSuccessful)
            .OrderByDescending(probe => probe.BytesPerSecond)
            .ThenBy(probe => probe.Latency)
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
                $"优先使用 {new Uri(fastest.Url).Host} · {FormatSpeed(fastest.BytesPerSecond)} · 延迟 {fastest.Latency.TotalMilliseconds:F0} ms"));
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
        const int sampleSize = 256 * 1024;
        var stopwatch = Stopwatch.StartNew();
        try
        {
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(TimeSpan.FromSeconds(6));

            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/octet-stream"));
            request.Headers.Range = new RangeHeaderValue(0, sampleSize - 1);

            using var response = await client.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cts.Token);
            response.EnsureSuccessStatusCode();
            var latency = stopwatch.Elapsed;

            await using var stream = await response.Content.ReadAsStreamAsync(cts.Token);
            var buffer = new byte[32 * 1024];
            var sampledBytes = 0L;
            while (sampledBytes < sampleSize)
            {
                var readSize = (int)Math.Min(buffer.Length, sampleSize - sampledBytes);
                var read = await stream.ReadAsync(buffer.AsMemory(0, readSize), cts.Token);
                if (read == 0)
                {
                    break;
                }

                sampledBytes += read;
            }

            stopwatch.Stop();
            var transferDuration = stopwatch.Elapsed - latency;
            var bytesPerSecond = transferDuration.TotalSeconds > 0
                ? sampledBytes / transferDuration.TotalSeconds
                : 0;

            return new DownloadUrlProbe(
                url,
                index,
                latency,
                bytesPerSecond,
                sampledBytes,
                IsSuccessful: sampledBytes > 0);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            return new DownloadUrlProbe(
                url,
                index,
                stopwatch.Elapsed,
                0,
                0,
                IsSuccessful: false,
                Error: ex.Message);
        }
    }

    private static async Task DownloadPackageAsync(
        ResilientHttpDownloader downloader,
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

        var transferProgress = new InlineProgress<DownloadTransferProgress>(transfer =>
        {
            var percent = transfer.TotalBytes is > 0
                ? 6 + (int)Math.Clamp(
                    transfer.BytesReceived * 44d / transfer.TotalBytes.Value,
                    0,
                    44)
                : 6;

            string detail;
            if (transfer.IsRetrying)
            {
                var delay = Math.Max(1, (int)Math.Ceiling(transfer.RetryDelay?.TotalSeconds ?? 1));
                detail = $"连接中断，{delay} 秒后自动续传 · 已保留 {FormatBytes(transfer.BytesReceived)} · 第 {transfer.Attempt + 1}/{transfer.MaxAttempts} 次尝试";
            }
            else
            {
                detail = BuildTransferDetail(transfer);
            }

            progress.Report(new UpdateProgress(
                UpdateStage.Downloading,
                percent,
                transfer.IsRetrying ? "网络波动，准备续传" : "正在下载更新",
                $"版本 {tagName} · {transfer.SourceHost}",
                detail,
                BytesReceived: transfer.BytesReceived,
                TotalBytes: transfer.TotalBytes,
                BytesPerSecond: transfer.BytesPerSecond,
                EstimatedRemaining: transfer.EstimatedRemaining,
                SourceHost: transfer.SourceHost,
                RetryAttempt: transfer.IsRetrying ? transfer.Attempt + 1 : transfer.Attempt));
        });

        await downloader.DownloadAsync(
            new Uri(url),
            destination,
            transferProgress,
            cancellationToken);

        ValidateDownloadedPackage(destination);
    }

    private static string BuildTransferDetail(DownloadTransferProgress transfer)
    {
        var downloaded = transfer.TotalBytes.HasValue
            ? $"{FormatBytes(transfer.BytesReceived)} / {FormatBytes(transfer.TotalBytes.Value)}"
            : FormatBytes(transfer.BytesReceived);
        var speed = transfer.BytesPerSecond > 0
            ? $" · {FormatSpeed(transfer.BytesPerSecond)}"
            : string.Empty;
        var remaining = transfer.EstimatedRemaining.HasValue
            ? $" · 剩余约 {FormatDuration(transfer.EstimatedRemaining.Value)}"
            : string.Empty;
        return $"{downloaded}{speed}{remaining}";
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        var value = (double)Math.Max(0, bytes);
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }

        return unit == 0 ? $"{value:F0} {units[unit]}" : $"{value:F1} {units[unit]}";
    }

    private static string FormatSpeed(double bytesPerSecond)
    {
        return $"{FormatBytes((long)Math.Max(0, bytesPerSecond))}/s";
    }

    private static string FormatDuration(TimeSpan duration)
    {
        if (duration.TotalHours >= 1)
        {
            return $"{(int)duration.TotalHours} 小时 {duration.Minutes} 分";
        }

        if (duration.TotalMinutes >= 1)
        {
            return $"{(int)duration.TotalMinutes} 分 {duration.Seconds} 秒";
        }

        return $"{Math.Max(1, (int)Math.Ceiling(duration.TotalSeconds))} 秒";
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
        _ = InspectPackage(zipPath);
    }

    private static PackageInfo InspectPackage(string zipPath)
    {
        try
        {
            using var archive = ZipFile.OpenRead(zipPath);
            var expandedSize = 0L;
            var hasAppExecutable = false;
            foreach (var entry in archive.Entries)
            {
                expandedSize = checked(expandedSize + entry.Length);
                if (string.Equals(
                    Path.GetFileName(entry.FullName),
                    "HanabiDownloadManagerX.exe",
                    StringComparison.OrdinalIgnoreCase))
                {
                    hasAppExecutable = true;
                }
            }

            if (!hasAppExecutable)
            {
                throw new InvalidDataException("下载到的 zip 不是 Hanabi 主程序安装包");
            }

            if (expandedSize <= 0)
            {
                throw new InvalidDataException("更新包中没有可安装文件");
            }

            if (expandedSize > MaxExpandedPackageSize)
            {
                throw new InvalidDataException("更新包解压后的体积异常，已停止安装");
            }

            return new PackageInfo(expandedSize);
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

    private static void EnsureDiskSpace(string path, long requiredBytes, string locationName)
    {
        try
        {
            var root = Path.GetPathRoot(Path.GetFullPath(path));
            if (string.IsNullOrWhiteSpace(root))
            {
                return;
            }

            var drive = new DriveInfo(root);
            if (!drive.IsReady || drive.AvailableFreeSpace >= requiredBytes)
            {
                return;
            }

            throw new IOException(
                $"{locationName}空间不足：至少需要 {FormatBytes(requiredBytes)}，当前可用 {FormatBytes(drive.AvailableFreeSpace)}。");
        }
        catch (Exception ex) when (ex is ArgumentException or UnauthorizedAccessException)
        {
            // Network and virtual paths do not always expose drive information.
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
                    throw new IOException(
                        "等待 Hanabi 关闭超时。请先关闭主程序和相关弹窗，然后点击重试。");
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
        InstallationJournal journal,
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
            else
            {
                journal.CreatedFiles.Add(destinationFile);
            }

            journal.TouchedFiles.Add(destinationFile);

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
        var stagedFile = destinationFile + $".hanabi-new-{Guid.NewGuid():N}";
        try
        {
            File.Copy(sourceFile, stagedFile, overwrite: false);
            if (!File.Exists(destinationFile))
            {
                File.Move(stagedFile, destinationFile);
                return;
            }

            try
            {
                File.Replace(stagedFile, destinationFile, null, ignoreMetadataErrors: true);
                return;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or PlatformNotSupportedException)
            {
                var oldFile = destinationFile + ".old";
                TryDeleteFile(oldFile);
                File.Move(destinationFile, oldFile);
                File.Move(stagedFile, destinationFile);
            }
        }
        finally
        {
            TryDeleteFile(stagedFile);
        }
    }

    private static void RestoreBackup(
        string backupDirectory,
        string appDirectory,
        InstallationJournal journal)
    {
        foreach (var createdFile in journal.CreatedFiles.AsEnumerable().Reverse())
        {
            if (File.Exists(createdFile))
            {
                File.Delete(createdFile);
            }
        }

        if (Directory.Exists(backupDirectory))
        {
            foreach (var backupFile in Directory.EnumerateFiles(backupDirectory, "*", SearchOption.AllDirectories))
            {
                var relativePath = Path.GetRelativePath(backupDirectory, backupFile);
                var destinationFile = Path.Combine(appDirectory, relativePath);
                Directory.CreateDirectory(Path.GetDirectoryName(destinationFile)!);
                File.Copy(backupFile, destinationFile, overwrite: true);
            }
        }

        foreach (var touchedFile in journal.TouchedFiles)
        {
            TryDeleteFile(touchedFile + ".old");
        }
    }

    private static void CleanupReplacedFiles(InstallationJournal journal)
    {
        foreach (var touchedFile in journal.TouchedFiles)
        {
            TryDeleteFile(touchedFile + ".old");
        }
    }

    private static string? TryLaunchApp(string appPath, string appDirectory)
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = appPath,
                WorkingDirectory = appDirectory,
                UseShellExecute = false
            };

            Process.Start(startInfo);
            return null;
        }
        catch (Exception ex)
        {
            return $"更新已安装，但未能自动启动新版本：{ex.Message}";
        }
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

    private sealed record PackageInfo(long ExpandedSize);

    private sealed class InstallationJournal
    {
        public List<string> CreatedFiles { get; } = [];

        public List<string> TouchedFiles { get; } = [];
    }

    private sealed class InlineProgress<T>(Action<T> callback) : IProgress<T>
    {
        public void Report(T value) => callback(value);
    }
}
