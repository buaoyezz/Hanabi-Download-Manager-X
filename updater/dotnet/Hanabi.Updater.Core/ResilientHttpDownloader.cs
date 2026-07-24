using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;

namespace Hanabi.Updater.Core;

public sealed record ResilientDownloadOptions
{
    public int MaxAttempts { get; init; } = 5;

    public int BufferSize { get; init; } = 128 * 1024;

    public TimeSpan ResponseTimeout { get; init; } = TimeSpan.FromSeconds(20);

    public TimeSpan ReadTimeout { get; init; } = TimeSpan.FromSeconds(30);

    public TimeSpan BaseRetryDelay { get; init; } = TimeSpan.FromSeconds(1);

    public TimeSpan MaxRetryDelay { get; init; } = TimeSpan.FromSeconds(12);

    public TimeSpan ProgressInterval { get; init; } = TimeSpan.FromMilliseconds(250);
}

public sealed record DownloadTransferProgress(
    long BytesReceived,
    long? TotalBytes,
    double BytesPerSecond,
    TimeSpan? EstimatedRemaining,
    string SourceHost,
    int Attempt,
    int MaxAttempts,
    bool IsRetrying,
    TimeSpan? RetryDelay = null);

public sealed class ResilientHttpDownloader
{
    private readonly HttpClient _client;
    private readonly ResilientDownloadOptions _options;

    public ResilientHttpDownloader(HttpClient client, ResilientDownloadOptions? options = null)
    {
        _client = client ?? throw new ArgumentNullException(nameof(client));
        _options = options ?? new ResilientDownloadOptions();

        if (_options.MaxAttempts < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "MaxAttempts must be at least 1.");
        }

        if (_options.BufferSize < 8192)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "BufferSize must be at least 8192 bytes.");
        }
    }

    public async Task DownloadAsync(
        Uri source,
        string destination,
        IProgress<DownloadTransferProgress>? progress,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentException.ThrowIfNullOrWhiteSpace(destination);

        var fullDestination = Path.GetFullPath(destination);
        Directory.CreateDirectory(Path.GetDirectoryName(fullDestination)!);

        var state = new DownloadState();
        Exception? lastError = null;

        for (var attempt = 1; attempt <= _options.MaxAttempts; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            try
            {
                await DownloadAttemptAsync(
                    source,
                    fullDestination,
                    state,
                    attempt,
                    progress,
                    cancellationToken);
                return;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex) when (IsTransient(ex) && attempt < _options.MaxAttempts)
            {
                lastError = ex;
                var delay = CalculateRetryDelay(attempt, ex);
                var existingLength = File.Exists(fullDestination)
                    ? new FileInfo(fullDestination).Length
                    : 0;

                progress?.Report(new DownloadTransferProgress(
                    existingLength,
                    state.TotalBytes,
                    0,
                    null,
                    source.Host,
                    attempt,
                    _options.MaxAttempts,
                    IsRetrying: true,
                    delay));

                await Task.Delay(delay, cancellationToken);
            }
            catch (Exception ex)
            {
                lastError = ex;
                break;
            }
        }

        throw new HttpRequestException(
            $"Download from {source.Host} failed after {_options.MaxAttempts} attempts.",
            lastError);
    }

    private async Task DownloadAttemptAsync(
        Uri source,
        string destination,
        DownloadState state,
        int attempt,
        IProgress<DownloadTransferProgress>? progress,
        CancellationToken cancellationToken)
    {
        var existingLength = File.Exists(destination)
            ? new FileInfo(destination).Length
            : 0;

        using var request = new HttpRequestMessage(HttpMethod.Get, source);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/octet-stream"));
        if (existingLength > 0)
        {
            request.Headers.Range = new RangeHeaderValue(existingLength, null);
            if (state.EntityTag is not null)
            {
                request.Headers.IfRange = new RangeConditionHeaderValue(state.EntityTag);
            }
            else if (state.LastModified.HasValue)
            {
                request.Headers.IfRange = new RangeConditionHeaderValue(state.LastModified.Value);
            }
        }

        using var responseTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        responseTimeout.CancelAfter(_options.ResponseTimeout);

        HttpResponseMessage response;
        try
        {
            response = await _client.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                responseTimeout.Token);
            responseTimeout.CancelAfter(Timeout.InfiniteTimeSpan);
        }
        catch (OperationCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            throw new TimeoutException($"Timed out connecting to {source.Host}.", ex);
        }

        using (response)
        {
            if (response.StatusCode == HttpStatusCode.RequestedRangeNotSatisfiable &&
                existingLength > 0 &&
                response.Content.Headers.ContentRange?.Length == existingLength)
            {
                progress?.Report(new DownloadTransferProgress(
                    existingLength,
                    existingLength,
                    0,
                    TimeSpan.Zero,
                    source.Host,
                    attempt,
                    _options.MaxAttempts,
                    IsRetrying: false));
                return;
            }

            if (!response.IsSuccessStatusCode)
            {
                throw new HttpRequestException(
                    $"Server returned {(int)response.StatusCode} ({response.ReasonPhrase}).",
                    null,
                    response.StatusCode);
            }

            var isPartialResponse = response.StatusCode == HttpStatusCode.PartialContent;
            var responseOffset = response.Content.Headers.ContentRange?.From;
            var canAppend = existingLength > 0 &&
                isPartialResponse &&
                responseOffset == existingLength;

            if (!canAppend)
            {
                existingLength = 0;
            }

            var totalBytes = response.Content.Headers.ContentRange?.Length;
            if (!totalBytes.HasValue && response.Content.Headers.ContentLength is > 0)
            {
                totalBytes = existingLength + response.Content.Headers.ContentLength.Value;
            }

            state.TotalBytes = totalBytes ?? state.TotalBytes;
            if (response.Headers.ETag is { IsWeak: false } responseTag)
            {
                state.EntityTag = responseTag;
            }
            state.LastModified = response.Content.Headers.LastModified ?? state.LastModified;

            await using var contentStream = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var fileStream = new FileStream(
                destination,
                canAppend ? FileMode.Append : FileMode.Create,
                FileAccess.Write,
                FileShare.Read,
                _options.BufferSize,
                FileOptions.Asynchronous | FileOptions.SequentialScan);

            var totalReceived = existingLength;
            var attemptReceived = 0L;
            var speed = 0d;
            var transferWatch = Stopwatch.StartNew();
            var sampleWatch = Stopwatch.StartNew();
            var sampleBytes = 0L;
            var lastProgress = TimeSpan.Zero;
            var buffer = new byte[_options.BufferSize];

            progress?.Report(CreateProgress(
                totalReceived,
                totalBytes,
                speed,
                source.Host,
                attempt));

            while (true)
            {
                var read = await ReadWithTimeoutAsync(contentStream, buffer, cancellationToken);
                if (read == 0)
                {
                    break;
                }

                await fileStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                totalReceived += read;
                attemptReceived += read;
                sampleBytes += read;

                if (sampleWatch.Elapsed >= TimeSpan.FromMilliseconds(500))
                {
                    var currentSpeed = sampleBytes / sampleWatch.Elapsed.TotalSeconds;
                    speed = speed <= 0 ? currentSpeed : speed * 0.65 + currentSpeed * 0.35;
                    sampleBytes = 0;
                    sampleWatch.Restart();
                }

                if (transferWatch.Elapsed - lastProgress >= _options.ProgressInterval)
                {
                    if (speed <= 0 && transferWatch.Elapsed.TotalSeconds > 0)
                    {
                        speed = attemptReceived / transferWatch.Elapsed.TotalSeconds;
                    }

                    progress?.Report(CreateProgress(
                        totalReceived,
                        totalBytes,
                        speed,
                        source.Host,
                        attempt));
                    lastProgress = transferWatch.Elapsed;
                }
            }

            await fileStream.FlushAsync(cancellationToken);

            if (totalBytes.HasValue && totalReceived != totalBytes.Value)
            {
                throw new EndOfStreamException(
                    $"Connection ended at {totalReceived} of {totalBytes.Value} bytes.");
            }

            if (totalReceived <= 0)
            {
                throw new InvalidDataException("The downloaded file is empty.");
            }

            if (speed <= 0 && transferWatch.Elapsed.TotalSeconds > 0)
            {
                speed = attemptReceived / transferWatch.Elapsed.TotalSeconds;
            }

            progress?.Report(CreateProgress(
                totalReceived,
                totalBytes,
                speed,
                source.Host,
                attempt));

            return;
        }
    }

    private async Task<int> ReadWithTimeoutAsync(
        Stream stream,
        byte[] buffer,
        CancellationToken cancellationToken)
    {
        using var readTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        readTimeout.CancelAfter(_options.ReadTimeout);

        try
        {
            return await stream.ReadAsync(buffer, readTimeout.Token);
        }
        catch (OperationCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            throw new TimeoutException("The download stopped receiving data.", ex);
        }
    }

    private DownloadTransferProgress CreateProgress(
        long bytesReceived,
        long? totalBytes,
        double bytesPerSecond,
        string sourceHost,
        int attempt)
    {
        TimeSpan? estimatedRemaining = null;
        if (totalBytes.HasValue && bytesPerSecond > 1 && totalBytes.Value > bytesReceived)
        {
            estimatedRemaining = TimeSpan.FromSeconds(
                (totalBytes.Value - bytesReceived) / bytesPerSecond);
        }

        return new DownloadTransferProgress(
            bytesReceived,
            totalBytes,
            bytesPerSecond,
            estimatedRemaining,
            sourceHost,
            attempt,
            _options.MaxAttempts,
            IsRetrying: false);
    }

    private TimeSpan CalculateRetryDelay(int attempt, Exception exception)
    {
        if (exception is HttpRequestException { StatusCode: HttpStatusCode.TooManyRequests })
        {
            return _options.MaxRetryDelay;
        }

        var exponentialSeconds = _options.BaseRetryDelay.TotalSeconds * Math.Pow(2, attempt - 1);
        var jitter = Random.Shared.NextDouble() * 0.35 + 0.85;
        return TimeSpan.FromSeconds(Math.Min(
            _options.MaxRetryDelay.TotalSeconds,
            exponentialSeconds * jitter));
    }

    private static bool IsTransient(Exception exception)
    {
        return exception switch
        {
            TimeoutException => true,
            IOException => true,
            HttpRequestException { StatusCode: null } => true,
            HttpRequestException { StatusCode: HttpStatusCode.RequestTimeout } => true,
            HttpRequestException { StatusCode: HttpStatusCode.TooManyRequests } => true,
            HttpRequestException { StatusCode: >= HttpStatusCode.InternalServerError } => true,
            _ => false
        };
    }

    private sealed class DownloadState
    {
        public EntityTagHeaderValue? EntityTag { get; set; }

        public DateTimeOffset? LastModified { get; set; }

        public long? TotalBytes { get; set; }
    }
}
