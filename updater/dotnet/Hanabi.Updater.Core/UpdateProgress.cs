namespace Hanabi.Updater.Core;

public enum UpdateStage
{
    Preparing,
    Downloading,
    WaitingForAppExit,
    Extracting,
    Applying,
    Cleaning,
    Launching,
    Completed
}

public sealed record UpdateProgress(
    UpdateStage Stage,
    int Percent,
    string Title,
    string Description,
    string Detail,
    bool CanSkip = false,
    long? BytesReceived = null,
    long? TotalBytes = null,
    double? BytesPerSecond = null,
    TimeSpan? EstimatedRemaining = null,
    string? SourceHost = null,
    int RetryAttempt = 0);
