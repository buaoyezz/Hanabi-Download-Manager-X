using System.IO.Compression;
using Hanabi.Updater.Core;
using Xunit;

namespace Hanabi.Updater.Core.Tests;

public sealed class UpdateEngineTests
{
    [Fact]
    public async Task RunAsync_InstallsLocalPackageWithoutDeletingIt()
    {
        var root = CreateTemporaryDirectory();
        var packagePath = Path.Combine(root, "local-update.zip");
        var appPath = Path.Combine(root, "app", "HanabiDownloadManagerX.exe");
        var executableBytes = "not-a-real-executable"u8.ToArray();
        CreatePackage(packagePath,
            ("HanabiDownloadManagerX.exe", executableBytes),
            ("data/version.txt", "2.0.0"u8.ToArray()));

        try
        {
            var engine = new UpdateEngine(CreateArguments(appPath, packagePath));
            var reports = new List<UpdateProgress>();

            await engine.RunAsync(
                new InlineProgress<UpdateProgress>(reports.Add),
                CancellationToken.None);

            Assert.True(File.Exists(packagePath));
            Assert.Equal(executableBytes, await File.ReadAllBytesAsync(appPath));
            Assert.Equal("2.0.0", await File.ReadAllTextAsync(
                Path.Combine(root, "app", "data", "version.txt")));
            Assert.Equal(UpdateStage.Completed, reports[^1].Stage);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task RunAsync_RestoresOldFilesAndRemovesNewFilesWhenApplyFails()
    {
        var root = CreateTemporaryDirectory();
        var packagePath = Path.Combine(root, "local-update.zip");
        var appDirectory = Path.Combine(root, "app");
        var appPath = Path.Combine(appDirectory, "HanabiDownloadManagerX.exe");
        var oldExecutable = "old-version"u8.ToArray();
        var newExecutable = "new-version"u8.ToArray();

        Directory.CreateDirectory(appDirectory);
        await File.WriteAllBytesAsync(appPath, oldExecutable);
        Directory.CreateDirectory(Path.Combine(appDirectory, "z-conflict"));
        CreatePackage(packagePath,
            ("HanabiDownloadManagerX.exe", newExecutable),
            ("new-file.txt", "new"u8.ToArray()),
            ("z-conflict", "cannot-replace-a-directory"u8.ToArray()));

        try
        {
            var engine = new UpdateEngine(CreateArguments(appPath, packagePath));

            await Assert.ThrowsAnyAsync<IOException>(() => engine.RunAsync(
                new InlineProgress<UpdateProgress>(_ => { }),
                CancellationToken.None));

            Assert.Equal(oldExecutable, await File.ReadAllBytesAsync(appPath));
            Assert.False(File.Exists(Path.Combine(appDirectory, "new-file.txt")));
            Assert.True(Directory.Exists(Path.Combine(appDirectory, "z-conflict")));
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    private static UpdaterArguments CreateArguments(string appPath, string packagePath)
    {
        return new UpdaterArguments(
            appPath,
            packagePath,
            DownloadUrl: null,
            AppName: "Hanabi Download Manager X",
            WaitPid: 0,
            TargetVersion: "test",
            AllowAlpha: false,
            SkipMirror: true);
    }

    private static void CreatePackage(
        string destination,
        params (string Name, byte[] Content)[] files)
    {
        using var archive = ZipFile.Open(destination, ZipArchiveMode.Create);
        foreach (var file in files)
        {
            var entry = archive.CreateEntry(file.Name, CompressionLevel.Fastest);
            using var stream = entry.Open();
            stream.Write(file.Content);
        }
    }

    private static string CreateTemporaryDirectory()
    {
        var path = Path.Combine(
            Path.GetTempPath(),
            $"hanabi-engine-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private sealed class InlineProgress<T>(Action<T> callback) : IProgress<T>
    {
        public void Report(T value) => callback(value);
    }
}
