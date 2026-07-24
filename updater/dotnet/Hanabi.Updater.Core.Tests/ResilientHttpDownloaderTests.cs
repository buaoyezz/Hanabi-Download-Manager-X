using System.Net;
using System.Net.Http.Headers;
using Hanabi.Updater.Core;
using Xunit;

namespace Hanabi.Updater.Core.Tests;

public sealed class ResilientHttpDownloaderTests
{
    [Fact]
    public async Task DownloadAsync_ResumesAfterInterruptedStream()
    {
        var payload = CreatePayload(420_000);
        var requestCount = 0;
        long resumedFrom = -1;
        string? ifRange = null;

        using var handler = new CallbackHandler(request =>
        {
            requestCount++;
            if (requestCount == 1)
            {
                Assert.Null(request.Headers.Range);
                var response = CreateResponse(
                    HttpStatusCode.OK,
                    new InterruptingMemoryStream(payload, 128_000));
                response.Headers.ETag = new EntityTagHeaderValue("\"release-v1\"");
                response.Content.Headers.ContentLength = payload.Length;
                return response;
            }

            resumedFrom = request.Headers.Range?.Ranges.Single().From ?? -1;
            ifRange = request.Headers.IfRange?.EntityTag?.Tag;
            Assert.InRange(resumedFrom, 1, payload.Length - 1);

            var remaining = payload[(int)resumedFrom..];
            var resumedResponse = CreateResponse(
                HttpStatusCode.PartialContent,
                new MemoryStream(remaining, writable: false));
            resumedResponse.Content.Headers.ContentRange = new ContentRangeHeaderValue(
                resumedFrom,
                payload.Length - 1,
                payload.Length);
            resumedResponse.Content.Headers.ContentLength = remaining.Length;
            return resumedResponse;
        });

        using var client = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
        var downloader = new ResilientHttpDownloader(client, FastTestOptions(MaxAttempts: 3));
        var destination = CreateTemporaryPath();

        try
        {
            await downloader.DownloadAsync(
                new Uri("https://x.zzbuaoye.net/latest/hdmx.zip"),
                destination,
                progress: null,
                CancellationToken.None);

            Assert.Equal(2, requestCount);
            Assert.True(resumedFrom >= 128_000);
            Assert.Equal("\"release-v1\"", ifRange);
            Assert.Equal(payload, await File.ReadAllBytesAsync(destination));
        }
        finally
        {
            File.Delete(destination);
        }
    }

    [Fact]
    public async Task DownloadAsync_ReplacesPartialFileWhenServerIgnoresRange()
    {
        var payload = CreatePayload(180_000);
        var partial = payload[..40_000];
        var destination = CreateTemporaryPath();
        await File.WriteAllBytesAsync(destination, partial);

        using var handler = new CallbackHandler(request =>
        {
            Assert.Equal(40_000, request.Headers.Range?.Ranges.Single().From);
            var response = CreateResponse(
                HttpStatusCode.OK,
                new MemoryStream(payload, writable: false));
            response.Content.Headers.ContentLength = payload.Length;
            return response;
        });

        using var client = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
        var downloader = new ResilientHttpDownloader(client, FastTestOptions(MaxAttempts: 1));

        try
        {
            await downloader.DownloadAsync(
                new Uri("https://x.zzbuaoye.net/latest/hdmx.zip"),
                destination,
                progress: null,
                CancellationToken.None);

            Assert.Equal(payload.Length, new FileInfo(destination).Length);
            Assert.Equal(payload, await File.ReadAllBytesAsync(destination));
        }
        finally
        {
            File.Delete(destination);
        }
    }

    [Fact]
    public async Task DownloadAsync_PreservesPartialFileAfterRetriesAreExhausted()
    {
        var payload = CreatePayload(160_000);
        using var handler = new CallbackHandler(_ =>
        {
            var response = CreateResponse(
                HttpStatusCode.OK,
                new InterruptingMemoryStream(payload, 48_000));
            response.Content.Headers.ContentLength = payload.Length;
            return response;
        });

        using var client = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
        var downloader = new ResilientHttpDownloader(client, FastTestOptions(MaxAttempts: 2));
        var destination = CreateTemporaryPath();

        try
        {
            await Assert.ThrowsAsync<HttpRequestException>(() => downloader.DownloadAsync(
                new Uri("https://x.zzbuaoye.net/latest/hdmx.zip"),
                destination,
                progress: null,
                CancellationToken.None));

            Assert.True(File.Exists(destination));
            Assert.InRange(new FileInfo(destination).Length, 48_000, payload.Length - 1);
        }
        finally
        {
            File.Delete(destination);
        }
    }

    private static ResilientDownloadOptions FastTestOptions(int MaxAttempts)
    {
        return new ResilientDownloadOptions
        {
            MaxAttempts = MaxAttempts,
            BufferSize = 8192,
            BaseRetryDelay = TimeSpan.Zero,
            MaxRetryDelay = TimeSpan.Zero,
            ResponseTimeout = TimeSpan.FromSeconds(2),
            ReadTimeout = TimeSpan.FromSeconds(2),
            ProgressInterval = TimeSpan.FromMilliseconds(1)
        };
    }

    private static HttpResponseMessage CreateResponse(HttpStatusCode statusCode, Stream stream)
    {
        return new HttpResponseMessage(statusCode)
        {
            Content = new StreamContent(stream)
        };
    }

    private static byte[] CreatePayload(int length)
    {
        var payload = new byte[length];
        for (var index = 0; index < payload.Length; index++)
        {
            payload[index] = (byte)(index * 31 % 251);
        }
        return payload;
    }

    private static string CreateTemporaryPath()
    {
        return Path.Combine(Path.GetTempPath(), $"hanabi-downloader-test-{Guid.NewGuid():N}.tmp");
    }

    private sealed class CallbackHandler(Func<HttpRequestMessage, HttpResponseMessage> callback)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.FromResult(callback(request));
        }
    }

    private sealed class InterruptingMemoryStream(byte[] buffer, long interruptAt)
        : MemoryStream(buffer, writable: false)
    {
        private bool _interrupted;

        public override ValueTask<int> ReadAsync(
            Memory<byte> destination,
            CancellationToken cancellationToken = default)
        {
            if (!_interrupted && Position >= interruptAt)
            {
                _interrupted = true;
                return ValueTask.FromException<int>(new IOException("Simulated connection loss."));
            }

            return base.ReadAsync(destination, cancellationToken);
        }
    }
}
