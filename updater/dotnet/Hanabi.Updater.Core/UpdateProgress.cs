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
    string Detail);
