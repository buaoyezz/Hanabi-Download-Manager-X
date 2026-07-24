using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Hanabi.NeoNSF;

internal sealed class NeoNsfEngine : IAsyncDisposable
{
    private const int BufferSize = 64 * 1024;
    private const long ParallelTransferThreshold = 8L * 1024 * 1024;
    private const long MinimumSegmentSize = 4L * 1024 * 1024;
    private static readonly TimeSpan ProgressInterval = TimeSpan.FromMilliseconds(250);

    private readonly ProtocolWriter _writer;
    private readonly HttpClientPool _clients = new();
    private readonly ConcurrentDictionary<string, TransferControl> _tasks = new();

    public NeoNsfEngine(ProtocolWriter writer)
    {
        _writer = writer;
    }

    public bool Enqueue(TransferSpec spec, out string? error)
    {
        error = null;
        var control = new TransferControl(spec);
        if (!_tasks.TryAdd(spec.TaskId, control))
        {
            error = "A task with the same ID already exists.";
            return false;
        }

        EmitAccepted(spec.TaskId);
        control.Execution = Task.Run(() => RunTransferAsync(control));
        return true;
    }

    public bool Pause(string taskId) => Stop(taskId, StopMode.Pause);

    public bool Cancel(string taskId, bool deletePartial) =>
        Stop(taskId, deletePartial ? StopMode.CancelAndDelete : StopMode.Cancel);

    public bool Resume(string taskId)
    {
        if (!_tasks.TryGetValue(taskId, out var control) || control.State != TransferState.Paused)
        {
            return false;
        }
        control.Cancellation.Dispose();
        control.Cancellation = new CancellationTokenSource();
        control.StopMode = StopMode.None;
        control.State = TransferState.Pending;
        control.Execution = Task.Run(() => RunTransferAsync(control));
        return true;
    }

    private bool Stop(string taskId, StopMode mode)
    {
        if (!_tasks.TryGetValue(taskId, out var control))
        {
            return false;
        }
        if (control.State == TransferState.Paused)
        {
            if (mode == StopMode.Pause)
            {
                return true;
            }
            if (mode == StopMode.CancelAndDelete)
            {
                File.Delete(control.Spec.FilePath + ".neonsf.partial");
                File.Delete(control.Spec.FilePath + ".neonsf.state");
                File.Delete(control.Spec.FilePath + ".neonsf.state.tmp");
                File.Delete(control.Spec.FilePath);
            }
            control.StopMode = mode;
            control.State = TransferState.Cancelled;
            RemoveTerminalTask(control);
            EmitState("cancelled", control.Spec.TaskId);
            control.Cancellation.Dispose();
            return true;
        }
        control.StopMode = mode;
        control.Cancellation.Cancel();
        return true;
    }

    private async Task RunTransferAsync(TransferControl control)
    {
        var spec = control.Spec;
        control.State = TransferState.Running;
        control.StartedAt = DateTimeOffset.UtcNow;
        EmitState("started", spec.TaskId);

        Exception? lastError = null;
        for (var attempt = 0; attempt <= spec.MaxRetries; attempt++)
        {
            try
            {
                await DownloadAttemptAsync(control, attempt, control.Cancellation.Token);
                return;
            }
            catch (OperationCanceledException) when (control.Cancellation.IsCancellationRequested)
            {
                await FinishCancellationAsync(control);
                return;
            }
            catch (Exception error)
            {
                lastError = error;
                if (attempt >= spec.MaxRetries || IsPermanent(error))
                {
                    break;
                }
                EmitRetry(spec.TaskId, attempt + 1, error.Message);
                try
                {
                    await Task.Delay(
                        TimeSpan.FromMilliseconds(Math.Min(5000, 250 * (1 << attempt))),
                        control.Cancellation.Token);
                }
                catch (OperationCanceledException) when (control.Cancellation.IsCancellationRequested)
                {
                    await FinishCancellationAsync(control);
                    return;
                }
            }
        }

        control.State = TransferState.Failed;
        RemoveTerminalTask(control);
        EmitFailure(spec.TaskId, lastError?.Message ?? "Unknown transfer failure.");
        control.Cancellation.Dispose();
    }

    private async Task DownloadAttemptAsync(
        TransferControl control,
        int attempt,
        CancellationToken cancellationToken)
    {
        var checkpointPath = control.Spec.FilePath + ".neonsf.state";
        var shouldProbe = control.Spec.ExpectedSize is null ||
                          control.Spec.ExpectedSize >= ParallelTransferThreshold ||
                          File.Exists(checkpointPath);
        if (shouldProbe)
        {
            var plan = await ResolveParallelPlanAsync(control, cancellationToken);
            if (plan is not null && plan.TotalBytes >= ParallelTransferThreshold)
            {
                try
                {
                    await DownloadParallelAttemptAsync(control, plan, cancellationToken);
                    return;
                }
                catch (RangeNotSupportedException)
                {
                    File.Delete(checkpointPath);
                    File.Delete(control.Spec.FilePath + ".neonsf.partial");
                    control.DownloadedBytes = 0;
                    control.TotalBytes = 0;
                    control.EntityTag = null;
                    control.LastModified = null;
                }
            }
            else if (File.Exists(checkpointPath))
            {
                File.Delete(checkpointPath);
                File.Delete(control.Spec.FilePath + ".neonsf.partial");
            }
        }

        await DownloadSequentialAttemptAsync(control, attempt, cancellationToken);
    }

    private async Task DownloadSequentialAttemptAsync(
        TransferControl control,
        int attempt,
        CancellationToken cancellationToken)
    {
        var spec = control.Spec;
        var partialPath = spec.FilePath + ".neonsf.partial";
        var parent = Path.GetDirectoryName(spec.FilePath);
        if (!string.IsNullOrWhiteSpace(parent))
        {
            Directory.CreateDirectory(parent);
        }

        var existingLength = File.Exists(partialPath) ? new FileInfo(partialPath).Length : 0L;
        if (spec.ExpectedSize.HasValue && existingLength == spec.ExpectedSize.Value)
        {
            File.Move(partialPath, spec.FilePath, overwrite: true);
            control.DownloadedBytes = existingLength;
            control.TotalBytes = existingLength;
            control.State = TransferState.Completed;
            RemoveTerminalTask(control);
            var averageBps = AverageBytesPerSecond(control.WireBytes, control.ActiveTicks);
            EmitCompleted(control, averageBps, control.ActiveTicks);
            control.Cancellation.Dispose();
            return;
        }
        if (existingLength > 0 &&
            string.IsNullOrWhiteSpace(control.EntityTag) &&
            string.IsNullOrWhiteSpace(control.LastModified))
        {
            // A cross-process partial without a validator cannot be joined
            // safely. Keep the path but restart it with FileMode.Create.
            existingLength = 0;
        }
        using var request = new HttpRequestMessage(HttpMethod.Get, spec.Url);
        ConfigureVersion(request, spec.HttpVersionPolicy);
        foreach (var header in spec.Headers)
        {
            if (header.Key.Equals("content-length", StringComparison.OrdinalIgnoreCase) ||
                header.Key.Equals("transfer-encoding", StringComparison.OrdinalIgnoreCase) ||
                header.Key.Equals("connection", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            request.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }
        request.Headers.AcceptEncoding.Clear();
        request.Headers.AcceptEncoding.Add(new StringWithQualityHeaderValue("identity"));
        if (existingLength > 0)
        {
            request.Headers.Range = new RangeHeaderValue(existingLength, null);
            if (!string.IsNullOrWhiteSpace(control.EntityTag) &&
                EntityTagHeaderValue.TryParse(control.EntityTag, out var entityTag))
            {
                request.Headers.IfRange = new RangeConditionHeaderValue(entityTag);
            }
            else if (DateTimeOffset.TryParse(control.LastModified, out var lastModified))
            {
                request.Headers.IfRange = new RangeConditionHeaderValue(lastModified);
            }
        }

        var client = _clients.Get(spec);
        HttpResponseMessage response;
        using (var headerTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken))
        {
            headerTimeout.CancelAfter(TimeSpan.FromSeconds(spec.ReadTimeoutSeconds));
            try
            {
                response = await client.SendAsync(
                    request,
                    HttpCompletionOption.ResponseHeadersRead,
                    headerTimeout.Token);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                throw new TimeoutException(
                    $"Timed out waiting {spec.ReadTimeoutSeconds}s for response headers.");
            }
        }
        using (response)
        {

        if ((int)response.StatusCode >= 400)
        {
            throw new HttpRequestException(
                $"HTTP {(int)response.StatusCode}",
                null,
                response.StatusCode);
        }

        var responseETag = response.Headers.ETag?.ToString();
        var responseLastModified = response.Content.Headers.LastModified?.ToString("R");
        var append = existingLength > 0 && response.StatusCode == HttpStatusCode.PartialContent;
        if (append)
        {
            var rangeStart = response.Content.Headers.ContentRange?.From;
            if (rangeStart != existingLength)
            {
                throw new RangeValidationException(
                    $"RANGE_RESPONSE_INVALID: expected start {existingLength}, got {rangeStart?.ToString() ?? "none"}.");
            }
            if (!ResumeValidatorMatches(control, responseETag, responseLastModified))
            {
                File.Delete(partialPath);
                throw new RetryFromScratchException(
                    "RESUME_VALIDATOR_CHANGED: remote ETag/Last-Modified no longer matches the partial file.");
            }
        }
        else
        {
            existingLength = 0;
        }

        var responseLength = response.Content.Headers.ContentLength;
        var totalBytes = append && responseLength.HasValue
            ? existingLength + responseLength.Value
            : responseLength ?? spec.ExpectedSize ?? 0;
        control.TotalBytes = totalBytes;
        control.DownloadedBytes = existingLength;
        control.EntityTag = responseETag;
        control.LastModified = responseLastModified;
        EmitHeaders(
            spec.TaskId,
            totalBytes,
            response.StatusCode,
            response.Version,
            response.Headers.AcceptRanges.Contains("bytes"),
            1,
            "direct",
            responseETag,
            responseLastModified);

            var mode = append ? FileMode.Append : FileMode.Create;
            await using var output = new FileStream(
                partialPath,
                mode,
                FileAccess.Write,
                FileShare.Read,
                BufferSize,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var readTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);

            var buffer = new byte[BufferSize];
            var clock = Stopwatch.StartNew();
            var lastProgress = TimeSpan.Zero;
            var lastSampleAt = TimeSpan.Zero;
            var lastSampleBytes = existingLength;
            try
            {
                while (true)
                {
                    readTimeout.CancelAfter(TimeSpan.FromSeconds(spec.ReadTimeoutSeconds));
                    int read;
                    try
                    {
                        read = await input.ReadAsync(buffer, readTimeout.Token);
                    }
                    catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
                    {
                        throw new TimeoutException(
                            $"No response data received for {spec.ReadTimeoutSeconds}s.");
                    }
                    readTimeout.CancelAfter(Timeout.InfiniteTimeSpan);
                    if (read == 0)
                    {
                        break;
                    }
                    await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                    control.DownloadedBytes += read;
                    control.WireBytes += read;

                    if (clock.Elapsed - lastProgress >= ProgressInterval)
                    {
                        var sampleElapsed = Math.Max(
                            0.001,
                            (clock.Elapsed - lastSampleAt).TotalSeconds);
                        var rawInstantBps =
                            (control.DownloadedBytes - lastSampleBytes) / sampleElapsed;
                        var alpha = 1 - Math.Exp(-sampleElapsed / 0.75);
                        control.SmoothedBps = control.SmoothedBps <= 0
                            ? rawInstantBps
                            : control.SmoothedBps + alpha *
                                (rawInstantBps - control.SmoothedBps);
                        var activeTicks = control.ActiveTicks + clock.ElapsedTicks;
                        var averageBps = AverageBytesPerSecond(
                            control.WireBytes,
                            activeTicks);
                        EmitProgress(
                            control,
                            control.SmoothedBps,
                            rawInstantBps,
                            averageBps,
                            activeTicks);
                        lastProgress = clock.Elapsed;
                        lastSampleAt = clock.Elapsed;
                        lastSampleBytes = control.DownloadedBytes;
                    }
                }
                await output.FlushAsync(cancellationToken);
                await input.DisposeAsync();
                await output.DisposeAsync();

                if (totalBytes > 0 && control.DownloadedBytes != totalBytes)
                {
                    throw new InvalidDataException(
                        $"Incomplete transfer: {control.DownloadedBytes}/{totalBytes} bytes.");
                }
                if (spec.ExpectedSize.HasValue && control.DownloadedBytes != spec.ExpectedSize.Value)
                {
                    throw new InvalidDataException(
                        $"Expected {spec.ExpectedSize.Value} bytes, received {control.DownloadedBytes}.");
                }

                File.Move(partialPath, spec.FilePath, overwrite: true);
                control.State = TransferState.Completed;
                var finalActiveTicks = control.ActiveTicks + clock.ElapsedTicks;
                var finalAverageBps = AverageBytesPerSecond(
                    control.WireBytes,
                    finalActiveTicks);
                RemoveTerminalTask(control);
                EmitCompleted(control, finalAverageBps, finalActiveTicks);
                control.Cancellation.Dispose();
            }
            finally
            {
                clock.Stop();
                control.ActiveTicks += clock.ElapsedTicks;
            }
        }
    }

    private async Task<ParallelPlan?> ResolveParallelPlanAsync(
        TransferControl control,
        CancellationToken cancellationToken)
    {
        var spec = control.Spec;
        using var request = new HttpRequestMessage(HttpMethod.Head, spec.Url);
        ConfigureVersion(request, spec.HttpVersionPolicy);
        ApplyRequestHeaders(request, spec);

        var client = _clients.Get(spec);
        HttpResponseMessage response;
        using (var headerTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken))
        {
            headerTimeout.CancelAfter(TimeSpan.FromSeconds(spec.ReadTimeoutSeconds));
            try
            {
                response = await client.SendAsync(
                    request,
                    HttpCompletionOption.ResponseHeadersRead,
                    headerTimeout.Token);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                return null;
            }
            catch (HttpRequestException)
            {
                return null;
            }
        }

        using (response)
        {
            if ((int)response.StatusCode >= 400 ||
                !response.Headers.AcceptRanges.Contains("bytes"))
            {
                return null;
            }

            var totalBytes = response.Content.Headers.ContentLength ?? spec.ExpectedSize ?? 0;
            if (totalBytes <= 0)
            {
                return null;
            }
            if (spec.ExpectedSize.HasValue && spec.ExpectedSize.Value != totalBytes)
            {
                throw new InvalidDataException(
                    $"Expected {spec.ExpectedSize.Value} bytes, server reported {totalBytes}.");
            }

            return new ParallelPlan(
                totalBytes,
                response.Version,
                response.Headers.ETag?.ToString(),
                response.Content.Headers.LastModified?.ToString("R"));
        }
    }

    private async Task DownloadParallelAttemptAsync(
        TransferControl control,
        ParallelPlan plan,
        CancellationToken cancellationToken)
    {
        var spec = control.Spec;
        var partialPath = spec.FilePath + ".neonsf.partial";
        var checkpointPath = spec.FilePath + ".neonsf.state";
        var parent = Path.GetDirectoryName(spec.FilePath);
        if (!string.IsNullOrWhiteSpace(parent))
        {
            Directory.CreateDirectory(parent);
        }

        var checkpoint = await TryLoadCheckpointAsync(checkpointPath, cancellationToken);
        var canResume = checkpoint is not null &&
                        checkpoint.Url == spec.Url &&
                        checkpoint.TotalBytes == plan.TotalBytes &&
                        File.Exists(partialPath) &&
                        new FileInfo(partialPath).Length == plan.TotalBytes &&
                        ValidatorMatches(checkpoint, plan);
        if (!canResume)
        {
            File.Delete(checkpointPath);
            File.Delete(partialPath);
            checkpoint = CreateCheckpoint(spec, plan);
            await using (var initialFile = new FileStream(
                partialPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.Read,
                BufferSize,
                FileOptions.Asynchronous | FileOptions.RandomAccess))
            {
                initialFile.SetLength(plan.TotalBytes);
                await initialFile.FlushAsync(cancellationToken);
            }
            await SaveCheckpointAsync(checkpointPath, checkpoint, cancellationToken);
        }

        control.EntityTag = plan.EntityTag;
        control.LastModified = plan.LastModified;
        control.TotalBytes = plan.TotalBytes;
        control.DownloadedBytes = checkpoint!.Segments.Sum(segment => segment.DownloadedBytes);
        control.LastProgressTicks = 0;
        control.LastSampleTicks = 0;
        control.LastSampleBytes = control.DownloadedBytes;
        control.LastCheckpointTicks = Stopwatch.GetTimestamp();

        EmitHeaders(
            spec.TaskId,
            plan.TotalBytes,
            HttpStatusCode.PartialContent,
            plan.HttpVersion,
            true,
            checkpoint.Segments.Count,
            "parallel_range",
            plan.EntityTag,
            plan.LastModified);

        var clock = Stopwatch.StartNew();
        try
        {
            using var output = File.OpenHandle(
                partialPath,
                FileMode.Open,
                FileAccess.Write,
                FileShare.Read,
                FileOptions.Asynchronous | FileOptions.RandomAccess);
            var workers = checkpoint.Segments
                .Where(segment => segment.DownloadedBytes < segment.Length)
                .Select(segment => DownloadRangeAsync(
                    control,
                    plan,
                    checkpoint,
                    segment,
                    output,
                    checkpointPath,
                    clock,
                    cancellationToken));
            await Task.WhenAll(workers);
            await SaveCheckpointAsync(checkpointPath, checkpoint, cancellationToken);

            var downloaded = checkpoint.Segments.Sum(segment => segment.DownloadedBytes);
            if (downloaded != plan.TotalBytes)
            {
                throw new InvalidDataException(
                    $"Incomplete parallel transfer: {downloaded}/{plan.TotalBytes} bytes.");
            }
        }
        finally
        {
            clock.Stop();
            control.ActiveTicks += clock.ElapsedTicks;
            if (cancellationToken.IsCancellationRequested)
            {
                try
                {
                    await SaveCheckpointAsync(checkpointPath, checkpoint, CancellationToken.None);
                }
                catch (IOException)
                {
                }
            }
        }

        File.Delete(checkpointPath);
        File.Move(partialPath, spec.FilePath, overwrite: true);
        control.DownloadedBytes = plan.TotalBytes;
        control.TotalBytes = plan.TotalBytes;
        control.State = TransferState.Completed;
        var finalAverageBps = AverageBytesPerSecond(control.WireBytes, control.ActiveTicks);
        RemoveTerminalTask(control);
        EmitCompleted(control, finalAverageBps, control.ActiveTicks);
        control.Cancellation.Dispose();
    }

    private async Task DownloadRangeAsync(
        TransferControl control,
        ParallelPlan plan,
        TransferCheckpoint checkpoint,
        CheckpointSegment segment,
        Microsoft.Win32.SafeHandles.SafeFileHandle output,
        string checkpointPath,
        Stopwatch clock,
        CancellationToken cancellationToken)
    {
        var spec = control.Spec;
        var rangeStart = segment.Start + segment.DownloadedBytes;
        using var request = new HttpRequestMessage(HttpMethod.Get, spec.Url);
        ConfigureVersion(request, spec.HttpVersionPolicy);
        ApplyRequestHeaders(request, spec);
        request.Headers.Range = new RangeHeaderValue(rangeStart, segment.End);
        ApplyIfRange(request, plan.EntityTag, plan.LastModified);

        var client = _clients.Get(spec);
        HttpResponseMessage response;
        using (var headerTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken))
        {
            headerTimeout.CancelAfter(TimeSpan.FromSeconds(spec.ReadTimeoutSeconds));
            try
            {
                response = await client.SendAsync(
                    request,
                    HttpCompletionOption.ResponseHeadersRead,
                    headerTimeout.Token);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                throw new TimeoutException(
                    $"Timed out waiting {spec.ReadTimeoutSeconds}s for range headers.");
            }
        }

        using (response)
        {
            if (response.StatusCode == HttpStatusCode.OK)
            {
                throw new RangeNotSupportedException(
                    "RANGE_NOT_SUPPORTED: server ignored a parallel range request.");
            }
            if (response.StatusCode != HttpStatusCode.PartialContent)
            {
                throw new HttpRequestException(
                    $"HTTP {(int)response.StatusCode}",
                    null,
                    response.StatusCode);
            }

            var contentRange = response.Content.Headers.ContentRange;
            if (contentRange?.From != rangeStart ||
                contentRange.To != segment.End ||
                contentRange.Length != plan.TotalBytes)
            {
                throw new RangeValidationException(
                    $"RANGE_RESPONSE_INVALID: expected {rangeStart}-{segment.End}/{plan.TotalBytes}, " +
                    $"got {contentRange?.ToString() ?? "none"}.");
            }
            if (!ResponseValidatorMatches(
                    plan,
                    response.Headers.ETag?.ToString(),
                    response.Content.Headers.LastModified?.ToString("R")))
            {
                throw new RetryFromScratchException(
                    "RESUME_VALIDATOR_CHANGED: parallel response validator changed.");
            }

            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var readTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            var buffer = new byte[BufferSize];
            var writeOffset = rangeStart;
            while (true)
            {
                readTimeout.CancelAfter(TimeSpan.FromSeconds(spec.ReadTimeoutSeconds));
                int read;
                try
                {
                    read = await input.ReadAsync(buffer, readTimeout.Token);
                }
                catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
                {
                    throw new TimeoutException(
                        $"No range data received for {spec.ReadTimeoutSeconds}s.");
                }
                readTimeout.CancelAfter(Timeout.InfiniteTimeSpan);
                if (read == 0) break;
                if (writeOffset + read - 1 > segment.End)
                {
                    throw new RangeValidationException(
                        "RANGE_RESPONSE_INVALID: response exceeded the requested range.");
                }

                await RandomAccess.WriteAsync(
                    output,
                    buffer.AsMemory(0, read),
                    writeOffset,
                    cancellationToken);
                writeOffset += read;
                Interlocked.Add(ref segment.DownloadedBytes, read);
                Interlocked.Add(ref control.DownloadedBytes, read);
                Interlocked.Add(ref control.WireBytes, read);
                MaybeEmitParallelProgress(control, clock);
                await MaybeSaveCheckpointAsync(control, checkpointPath, checkpoint, cancellationToken);
            }
            if (segment.DownloadedBytes != segment.Length)
            {
                throw new InvalidDataException(
                    $"Incomplete range: {segment.DownloadedBytes}/{segment.Length} bytes.");
            }
        }
    }

    private static void ApplyRequestHeaders(HttpRequestMessage request, TransferSpec spec)
    {
        foreach (var header in spec.Headers)
        {
            if (header.Key.Equals("content-length", StringComparison.OrdinalIgnoreCase) ||
                header.Key.Equals("transfer-encoding", StringComparison.OrdinalIgnoreCase) ||
                header.Key.Equals("connection", StringComparison.OrdinalIgnoreCase) ||
                header.Key.Equals("range", StringComparison.OrdinalIgnoreCase) ||
                header.Key.Equals("if-range", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            request.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }
        request.Headers.AcceptEncoding.Clear();
        request.Headers.AcceptEncoding.Add(new StringWithQualityHeaderValue("identity"));
    }

    private static void ApplyIfRange(
        HttpRequestMessage request,
        string? entityTag,
        string? lastModified)
    {
        if (!string.IsNullOrWhiteSpace(entityTag) &&
            EntityTagHeaderValue.TryParse(entityTag, out var parsedEntityTag))
        {
            request.Headers.IfRange = new RangeConditionHeaderValue(parsedEntityTag);
        }
        else if (DateTimeOffset.TryParse(lastModified, out var parsedLastModified))
        {
            request.Headers.IfRange = new RangeConditionHeaderValue(parsedLastModified);
        }
    }

    private static TransferCheckpoint CreateCheckpoint(TransferSpec spec, ParallelPlan plan)
    {
        var segmentCount = Math.Min(
            spec.MaxConnections,
            Math.Max(2, (int)Math.Ceiling((double)plan.TotalBytes / MinimumSegmentSize)));
        var segmentSize = (long)Math.Ceiling((double)plan.TotalBytes / segmentCount);
        var segments = new List<CheckpointSegment>(segmentCount);
        for (var index = 0; index < segmentCount; index++)
        {
            var start = index * segmentSize;
            if (start >= plan.TotalBytes) break;
            segments.Add(new CheckpointSegment(
                start,
                Math.Min(plan.TotalBytes - 1, start + segmentSize - 1),
                0));
        }
        return new TransferCheckpoint(
            spec.Url,
            plan.TotalBytes,
            plan.EntityTag,
            plan.LastModified,
            segments);
    }

    private static bool ValidatorMatches(TransferCheckpoint checkpoint, ParallelPlan plan)
    {
        if (!string.IsNullOrWhiteSpace(checkpoint.EntityTag) ||
            !string.IsNullOrWhiteSpace(plan.EntityTag))
        {
            return string.Equals(checkpoint.EntityTag, plan.EntityTag, StringComparison.Ordinal);
        }
        if (!string.IsNullOrWhiteSpace(checkpoint.LastModified) ||
            !string.IsNullOrWhiteSpace(plan.LastModified))
        {
            return string.Equals(
                checkpoint.LastModified,
                plan.LastModified,
                StringComparison.Ordinal);
        }
        return false;
    }

    private static bool ResponseValidatorMatches(
        ParallelPlan plan,
        string? responseEntityTag,
        string? responseLastModified)
    {
        if (!string.IsNullOrWhiteSpace(plan.EntityTag))
        {
            return string.Equals(plan.EntityTag, responseEntityTag, StringComparison.Ordinal);
        }
        if (!string.IsNullOrWhiteSpace(plan.LastModified))
        {
            return string.Equals(
                plan.LastModified,
                responseLastModified,
                StringComparison.Ordinal);
        }
        return true;
    }

    private void MaybeEmitParallelProgress(TransferControl control, Stopwatch clock)
    {
        lock (control.ProgressSync)
        {
            var elapsedTicks = clock.ElapsedTicks;
            if (elapsedTicks - control.LastProgressTicks <
                ProgressInterval.TotalSeconds * Stopwatch.Frequency)
            {
                return;
            }
            var downloaded = Interlocked.Read(ref control.DownloadedBytes);
            var sampleTicks = Math.Max(1, elapsedTicks - control.LastSampleTicks);
            var sampleElapsed = (double)sampleTicks / Stopwatch.Frequency;
            var rawInstantBps = (downloaded - control.LastSampleBytes) / sampleElapsed;
            var alpha = 1 - Math.Exp(-sampleElapsed / 0.75);
            control.SmoothedBps = control.SmoothedBps <= 0
                ? rawInstantBps
                : control.SmoothedBps + alpha * (rawInstantBps - control.SmoothedBps);
            var activeTicks = control.ActiveTicks + elapsedTicks;
            EmitProgress(
                control,
                control.SmoothedBps,
                rawInstantBps,
                AverageBytesPerSecond(control.WireBytes, activeTicks),
                activeTicks);
            control.LastProgressTicks = elapsedTicks;
            control.LastSampleTicks = elapsedTicks;
            control.LastSampleBytes = downloaded;
        }
    }

    private static async Task MaybeSaveCheckpointAsync(
        TransferControl control,
        string path,
        TransferCheckpoint checkpoint,
        CancellationToken cancellationToken)
    {
        var now = Stopwatch.GetTimestamp();
        if (now - Interlocked.Read(ref control.LastCheckpointTicks) < Stopwatch.Frequency)
        {
            return;
        }
        if (!await control.CheckpointGate.WaitAsync(0, cancellationToken)) return;
        try
        {
            now = Stopwatch.GetTimestamp();
            if (now - Interlocked.Read(ref control.LastCheckpointTicks) < Stopwatch.Frequency)
            {
                return;
            }
            await SaveCheckpointAsync(path, checkpoint, cancellationToken);
            Interlocked.Exchange(ref control.LastCheckpointTicks, now);
        }
        finally
        {
            control.CheckpointGate.Release();
        }
    }

    private static async Task SaveCheckpointAsync(
        string path,
        TransferCheckpoint checkpoint,
        CancellationToken cancellationToken)
    {
        var tempPath = path + ".tmp";
        await using (var stream = new FileStream(
            tempPath,
            FileMode.Create,
            FileAccess.Write,
            FileShare.None,
            BufferSize,
            FileOptions.Asynchronous))
        {
            using var writer = new Utf8JsonWriter(stream);
            writer.WriteStartObject();
            writer.WriteString("url", checkpoint.Url);
            writer.WriteNumber("totalBytes", checkpoint.TotalBytes);
            if (!string.IsNullOrWhiteSpace(checkpoint.EntityTag))
            {
                writer.WriteString("etag", checkpoint.EntityTag);
            }
            if (!string.IsNullOrWhiteSpace(checkpoint.LastModified))
            {
                writer.WriteString("lastModified", checkpoint.LastModified);
            }
            writer.WriteStartArray("segments");
            foreach (var segment in checkpoint.Segments)
            {
                writer.WriteStartObject();
                writer.WriteNumber("start", segment.Start);
                writer.WriteNumber("end", segment.End);
                writer.WriteNumber("downloadedBytes", Interlocked.Read(ref segment.DownloadedBytes));
                writer.WriteEndObject();
            }
            writer.WriteEndArray();
            writer.WriteEndObject();
            writer.Flush();
            await stream.FlushAsync(cancellationToken);
        }
        File.Move(tempPath, path, overwrite: true);
    }

    private static async Task<TransferCheckpoint?> TryLoadCheckpointAsync(
        string path,
        CancellationToken cancellationToken)
    {
        if (!File.Exists(path)) return null;
        try
        {
            await using var stream = new FileStream(
                path,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                BufferSize,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            using var document = await JsonDocument.ParseAsync(
                stream,
                cancellationToken: cancellationToken);
            var root = document.RootElement;
            var segments = root.GetProperty("segments")
                .EnumerateArray()
                .Select(node => new CheckpointSegment(
                    node.GetProperty("start").GetInt64(),
                    node.GetProperty("end").GetInt64(),
                    node.GetProperty("downloadedBytes").GetInt64()))
                .ToList();
            return new TransferCheckpoint(
                root.GetProperty("url").GetString() ?? string.Empty,
                root.GetProperty("totalBytes").GetInt64(),
                root.TryGetProperty("etag", out var entityTag) ? entityTag.GetString() : null,
                root.TryGetProperty("lastModified", out var lastModified)
                    ? lastModified.GetString()
                    : null,
                segments);
        }
        catch (JsonException)
        {
            return null;
        }
        catch (IOException)
        {
            return null;
        }
    }

    private static double AverageBytesPerSecond(long bytes, long activeTicks)
    {
        var seconds = Math.Max(0.001, (double)activeTicks / Stopwatch.Frequency);
        return bytes / seconds;
    }

    private async Task FinishCancellationAsync(TransferControl control)
    {
        var mode = control.StopMode;
        if (mode == StopMode.CancelAndDelete)
        {
            await DeleteIfExistsAsync(control.Spec.FilePath + ".neonsf.partial");
            await DeleteIfExistsAsync(control.Spec.FilePath + ".neonsf.state");
            await DeleteIfExistsAsync(control.Spec.FilePath + ".neonsf.state.tmp");
            await DeleteIfExistsAsync(control.Spec.FilePath);
        }
        control.State = mode == StopMode.Pause ? TransferState.Paused : TransferState.Cancelled;
        if (mode != StopMode.Pause)
        {
            RemoveTerminalTask(control);
        }
        EmitState(mode == StopMode.Pause ? "paused" : "cancelled", control.Spec.TaskId);
        if (mode != StopMode.Pause)
        {
            control.Cancellation.Dispose();
        }
    }

    private static Task DeleteIfExistsAsync(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (FileNotFoundException)
        {
        }
        return Task.CompletedTask;
    }

    private static void ConfigureVersion(HttpRequestMessage request, string policy)
    {
        switch (policy)
        {
            case "http1_only":
                request.Version = HttpVersion.Version11;
                request.VersionPolicy = HttpVersionPolicy.RequestVersionExact;
                break;
            case "http2_only":
                request.Version = HttpVersion.Version20;
                request.VersionPolicy = HttpVersionPolicy.RequestVersionExact;
                break;
            case "http3_only":
                request.Version = HttpVersion.Version30;
                request.VersionPolicy = HttpVersionPolicy.RequestVersionExact;
                break;
            default:
                request.Version = HttpVersion.Version20;
                request.VersionPolicy = HttpVersionPolicy.RequestVersionOrLower;
                break;
        }
    }

    private static bool IsPermanent(Exception error)
    {
        if (error is RangeValidationException)
        {
            return true;
        }
        if (error is not HttpRequestException { StatusCode: { } status })
        {
            return false;
        }
        var code = (int)status;
        return code is >= 400 and < 500 &&
               status != HttpStatusCode.RequestTimeout &&
               status != HttpStatusCode.TooManyRequests;
    }

    private static bool ResumeValidatorMatches(
        TransferControl control,
        string? responseETag,
        string? responseLastModified)
    {
        if (!string.IsNullOrWhiteSpace(control.EntityTag))
        {
            return string.Equals(
                control.EntityTag,
                responseETag,
                StringComparison.Ordinal);
        }
        if (!string.IsNullOrWhiteSpace(control.LastModified))
        {
            return string.Equals(
                control.LastModified,
                responseLastModified,
                StringComparison.Ordinal);
        }
        return false;
    }

    private void RemoveTerminalTask(TransferControl control)
    {
        if (_tasks.TryGetValue(control.Spec.TaskId, out var current) &&
            ReferenceEquals(current, control))
        {
            _tasks.TryRemove(control.Spec.TaskId, out _);
        }
    }

    private void EmitAccepted(string taskId) => _writer.Write(writer =>
    {
        writer.WriteString("type", "accepted");
        writer.WriteString("taskId", taskId);
    });

    private void EmitState(string type, string taskId) => _writer.Write(writer =>
    {
        writer.WriteString("type", type);
        writer.WriteString("taskId", taskId);
    });

    private void EmitHeaders(
        string taskId,
        long totalBytes,
        HttpStatusCode status,
        Version version,
        bool supportsRanges,
        int connectionCount,
        string transferMode,
        string? entityTag,
        string? lastModified) => _writer.Write(writer =>
    {
        writer.WriteString("type", "headers");
        writer.WriteString("taskId", taskId);
        writer.WriteNumber("statusCode", (int)status);
        writer.WriteNumber("totalBytes", totalBytes);
        writer.WriteString("httpVersion", version.ToString());
        writer.WriteBoolean("supportsRanges", supportsRanges);
        writer.WriteNumber("connectionCount", connectionCount);
        writer.WriteString("transferMode", transferMode);
        if (!string.IsNullOrWhiteSpace(entityTag))
        {
            writer.WriteString("etag", entityTag);
        }
        if (!string.IsNullOrWhiteSpace(lastModified))
        {
            writer.WriteString("lastModified", lastModified);
        }
    });

    private void EmitProgress(
        TransferControl control,
        double instantBps,
        double rawInstantBps,
        double averageBps,
        long ticks) =>
        _writer.Write(writer =>
        {
            writer.WriteString("type", "progress");
            writer.WriteString("taskId", control.Spec.TaskId);
            writer.WriteNumber("downloadedBytes", control.DownloadedBytes);
            writer.WriteNumber("totalBytes", control.TotalBytes);
            writer.WriteNumber("instantBps", instantBps);
            writer.WriteNumber("rawInstantBps", rawInstantBps);
            writer.WriteNumber("windowBps", instantBps);
            writer.WriteNumber("averageBps", averageBps);
            writer.WriteNumber("activeTicks", ticks);
        });

    private void EmitCompleted(TransferControl control, double averageBps, long ticks) =>
        _writer.Write(writer =>
        {
            writer.WriteString("type", "completed");
            writer.WriteString("taskId", control.Spec.TaskId);
            writer.WriteNumber("downloadedBytes", control.DownloadedBytes);
            writer.WriteNumber("totalBytes", control.TotalBytes);
            writer.WriteNumber("averageBps", averageBps);
            writer.WriteNumber("activeTicks", ticks);
        });

    private void EmitRetry(string taskId, int attempt, string error) => _writer.Write(writer =>
    {
        writer.WriteString("type", "retrying");
        writer.WriteString("taskId", taskId);
        writer.WriteNumber("attempt", attempt);
        writer.WriteString("error", error);
    });

    private void EmitFailure(string taskId, string error) => _writer.Write(writer =>
    {
        writer.WriteString("type", "failed");
        writer.WriteString("taskId", taskId);
        writer.WriteString("error", error);
    });

    public async ValueTask DisposeAsync()
    {
        foreach (var task in _tasks.Values)
        {
            task.StopMode = StopMode.Pause;
            task.Cancellation.Cancel();
        }
        await Task.WhenAll(_tasks.Values.Select(task => task.Execution ?? Task.CompletedTask));
        foreach (var task in _tasks.Values)
        {
            task.Cancellation.Dispose();
        }
        _clients.Dispose();
    }

    private sealed class TransferControl
    {
        public TransferControl(TransferSpec spec)
        {
            Spec = spec;
            EntityTag = spec.ExpectedETag;
            LastModified = spec.ExpectedLastModified;
        }

        public TransferSpec Spec { get; }
        public CancellationTokenSource Cancellation { get; set; } = new();
        public volatile StopMode StopMode;
        public volatile TransferState State = TransferState.Pending;
        public Task? Execution { get; set; }
        public DateTimeOffset? StartedAt { get; set; }
        public long DownloadedBytes;
        public long TotalBytes;
        public long WireBytes;
        public long ActiveTicks;
        public double SmoothedBps;
        public string? EntityTag;
        public string? LastModified;
        public object ProgressSync { get; } = new();
        public SemaphoreSlim CheckpointGate { get; } = new(1, 1);
        public long LastProgressTicks;
        public long LastSampleTicks;
        public long LastSampleBytes;
        public long LastCheckpointTicks;
    }

    private enum StopMode
    {
        None,
        Pause,
        Cancel,
        CancelAndDelete,
    }

    private enum TransferState
    {
        Pending,
        Running,
        Paused,
        Completed,
        Failed,
        Cancelled,
    }

    private sealed class RangeValidationException(string message) : IOException(message);
    private sealed class RangeNotSupportedException(string message) : IOException(message);
    private sealed class RetryFromScratchException(string message) : IOException(message);

    private sealed record ParallelPlan(
        long TotalBytes,
        Version HttpVersion,
        string? EntityTag,
        string? LastModified);

    private sealed record TransferCheckpoint(
        string Url,
        long TotalBytes,
        string? EntityTag,
        string? LastModified,
        List<CheckpointSegment> Segments);

    private sealed class CheckpointSegment(long start, long end, long downloadedBytes)
    {
        public long Start { get; } = start;
        public long End { get; } = end;
        public long DownloadedBytes = downloadedBytes;
        public long Length => End - Start + 1;
    }
}
