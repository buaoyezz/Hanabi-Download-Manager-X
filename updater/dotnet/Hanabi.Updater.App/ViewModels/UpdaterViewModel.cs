using System.ComponentModel;
using System.Runtime.CompilerServices;
using Avalonia.Platform;
using Hanabi.Updater.Core;

namespace Hanabi.Updater.App.ViewModels;

public sealed class UpdaterViewModel : INotifyPropertyChanged
{
    private readonly ParseResult _parseResult;
    private CancellationTokenSource? _cancellation;
    private WizardPage _page = WizardPage.Welcome;
    private string _title = "许可协议";
    private string _description = "请仔细阅读以下许可条款";
    private string _detail = "等待开始";
    private int _percent;
    private bool _isRunning;
    private bool _hasFailed;
    private bool _licenseAccepted;
    private bool _canCancel = true;
    private bool _isSkipVisible;
    private bool _isAboutVisibleOverlay;
    private string _primaryButtonText = "下一步  >";
    private bool _isEnglish = false;
    private bool _useAccelerationNode = true;
    private UpdateStage _currentStage;
    private bool _isSkippingSpeedTest;
    private bool _currentSkipMirror;
    private bool _isProgressIndeterminate;

    public string WindowTitleText => "Hanabi Download Manager X Setup";
    public string ShellTitleText => "Setup";
    public string SetupTitleText => "Hanabi Download Manager X";
    public string SetupSubtitleText => _isEnglish ? "Install or update Hanabi Download Manager X" : "安装或更新 Hanabi Download Manager X";
    public string StartInstallText => _isEnglish ? "Continue" : "继续";
    public string StepProgressText => _isEnglish ? "SETUP STEPS" : "安装步骤";
    public string FooterStatusText => _isEnglish ? "Keep this window open until setup completes" : "安装或更新完成前请保持此窗口开启";
    public string SetupVersionText
    {
        get
        {
            var version = typeof(UpdaterViewModel).Assembly.GetName().Version;
            return $"Setup v{version?.Major ?? 1}.{version?.Minor ?? 0}.{version?.Build ?? 0}";
        }
    }
    public string AboutText => _isEnglish ? "About" : "关于";
    public string AboutToolTipText => _isEnglish ? "About Hanabi Download Manager X Setup" : "关于 Hanabi Download Manager X Setup";
    public string BackText => _isEnglish ? "Back" : "返回";
    public string AcceptLicenseText => _isEnglish ? "I accept the terms in the License Agreement" : "我接受许可协议中的条款";
    public string TargetDirText => _isEnglish ? "Target Directory" : "目标目录";
    public string ChangeDirText => _isEnglish ? "Browse..." : "浏览...";
    public string LocationWarningText => _isEnglish ? "Settings and download tasks are preserved. The app will close before application files are replaced." : "设置和下载任务会被保留；替换应用文件前会等待主程序安全退出。";
    public string InstallProgressText => _isEnglish ? "Install Progress" : "安装进度";
    public string SpecialThanksText => _isEnglish ? "Special Thanks: ghproxy.com, moeyy.cn (GitHub Mirrors)" : "特别鸣谢: ghproxy.com, moeyy.cn 提供下载加速支持";

    private string _installLocation;
    public string InstallLocation
    {
        get => _installLocation;
        set
        {
            if (SetField(ref _installLocation, value))
            {
                OnPropertyChanged(nameof(IsInstallLocationValid));
                OnPropertyChanged(nameof(InstallLocationStatusText));
                OnPropertyChanged(nameof(CanUsePrimaryButton));
                if (_page == WizardPage.Location)
                {
                    Detail = value;
                }
            }
        }
    }

    public UpdaterViewModel(string[] args)
    {
        _parseResult = UpdaterArguments.Parse(args);

        _installLocation = _parseResult.Arguments is null
            ? "启动参数缺失，无法定位安装目录"
            : Path.GetDirectoryName(_parseResult.Arguments.AppPath) ?? _parseResult.Arguments.AppPath;

        Steps =
        [
            new StepItem("许可协议", "\uE8A5"),
            new StepItem("安装位置", "\uE8B7"),
            new StepItem("正在安装", "\uE896"),
            new StepItem("安装完成", "\uE73E")
        ];

        UpdateStepState(0);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public IReadOnlyList<StepItem> Steps { get; }

    public string LicenseText { get; } = LoadLicenseText();

    public bool IsWelcomeVisible => _page == WizardPage.Welcome && !_isAboutVisibleOverlay;

    public bool IsWizardVisible => _page != WizardPage.Welcome;

    public bool IsLicenseVisible => _page == WizardPage.License && !_isAboutVisibleOverlay;

    public bool IsLocationVisible => _page == WizardPage.Location && !_isAboutVisibleOverlay;

    public bool IsProgressVisible => _page == WizardPage.Progress && !_isAboutVisibleOverlay;

    public bool IsDoneVisible => _page == WizardPage.Done && !_isAboutVisibleOverlay;

    public bool IsPrimaryButtonVisible => !_isAboutVisibleOverlay && _page != WizardPage.Progress;

    public bool IsCancelButtonVisible => !_isAboutVisibleOverlay &&
        _page == WizardPage.Progress && IsRunning && CanCancel;

    public bool IsFooterStatusVisible => !_isAboutVisibleOverlay && _page == WizardPage.Progress;

    public bool CanAdjustPreferences => !IsRunning;

    public bool IsSecondaryButtonVisible => !_isAboutVisibleOverlay &&
        (_page is WizardPage.License or WizardPage.Location ||
         _page == WizardPage.Done && HasFailed);

    public string SecondaryButtonText => _page == WizardPage.Done && HasFailed
        ? (_isEnglish ? "Close" : "关闭")
        : (_isEnglish ? "Back" : "上一步");

    public bool IsAboutVisibleOverlay
    {
        get => _isAboutVisibleOverlay;
        set
        {
            if (SetField(ref _isAboutVisibleOverlay, value))
            {
                OnPropertyChanged(nameof(IsMainContentVisible));
                OnPropertyChanged(nameof(IsWelcomeVisible));
            }
        }
    }

    public bool IsMainContentVisible => _page != WizardPage.Welcome && !_isAboutVisibleOverlay;

    public bool IsSuccessResult => _page == WizardPage.Done && !HasFailed;

    public bool IsFailureResult => _page == WizardPage.Done && HasFailed;

    public string ResultLabelText => HasFailed
        ? (_isEnglish ? "ACTION NEEDED" : "需要处理")
        : (_isEnglish ? "UPDATE COMPLETE" : "更新完成");

    public string Title
    {
        get => _title;
        private set => SetField(ref _title, value);
    }

    public string Description
    {
        get => _description;
        private set => SetField(ref _description, value);
    }

    public string Detail
    {
        get => _detail;
        private set => SetField(ref _detail, value);
    }

    public int Percent
    {
        get => _percent;
        private set
        {
            if (SetField(ref _percent, value))
            {
                OnPropertyChanged(nameof(PercentText));
            }
        }
    }

    public string PercentText => $"{Percent}%";

    public bool IsProgressIndeterminate
    {
        get => _isProgressIndeterminate;
        private set => SetField(ref _isProgressIndeterminate, value);
    }

    public bool IsRunning
    {
        get => _isRunning;
        private set
        {
            if (SetField(ref _isRunning, value))
            {
                OnPropertyChanged(nameof(CanAdjustPreferences));
                OnPropertyChanged(nameof(IsCancelButtonVisible));
                OnPropertyChanged(nameof(IsFooterStatusVisible));
            }
        }
    }

    public bool HasFailed
    {
        get => _hasFailed;
        private set
        {
            if (SetField(ref _hasFailed, value))
            {
                OnPropertyChanged(nameof(IsSuccessResult));
                OnPropertyChanged(nameof(IsFailureResult));
                OnPropertyChanged(nameof(ResultLabelText));
            }
        }
    }

    public bool LicenseAccepted
    {
        get => _licenseAccepted;
        set
        {
            if (SetField(ref _licenseAccepted, value))
            {
                OnPropertyChanged(nameof(CanUsePrimaryButton));
            }
        }
    }

    public bool CanUsePrimaryButton =>
        _page switch
        {
            WizardPage.License => LicenseAccepted,
            WizardPage.Location => IsInstallLocationValid && !IsRunning,
            WizardPage.Progress => IsRunning && CanCancel,
            _ => !IsRunning
        };

    public bool IsInstallLocationValid
    {
        get
        {
            try
            {
                return !string.IsNullOrWhiteSpace(InstallLocation) &&
                    !string.IsNullOrWhiteSpace(Path.GetPathRoot(Path.GetFullPath(InstallLocation)));
            }
            catch
            {
                return false;
            }
        }
    }

    public string InstallLocationStatusText
    {
        get
        {
            if (!IsInstallLocationValid)
            {
                return _isEnglish ? "Choose a valid installation directory." : "请选择有效的安装目录。";
            }

            try
            {
                var root = Path.GetPathRoot(Path.GetFullPath(InstallLocation));
                var drive = string.IsNullOrWhiteSpace(root) ? null : new DriveInfo(root);
                if (drive?.IsReady == true)
                {
                    return _isEnglish
                        ? $"{drive.AvailableFreeSpace / 1024d / 1024 / 1024:F1} GB available"
                        : $"可用空间 {drive.AvailableFreeSpace / 1024d / 1024 / 1024:F1} GB";
                }
            }
            catch
            {
                // Some network locations do not expose free-space information.
            }

            return _isEnglish ? "The directory will be created if needed." : "目录不存在时将自动创建。";
        }
    }

    public bool CanCancel
    {
        get => _canCancel;
        private set
        {
            if (SetField(ref _canCancel, value))
            {
                OnPropertyChanged(nameof(CanUsePrimaryButton));
                OnPropertyChanged(nameof(IsCancelButtonVisible));
            }
        }
    }

    public bool UseAccelerationNode
    {
        get => _useAccelerationNode;
        set => SetField(ref _useAccelerationNode, value);
    }

    public bool IsSkipVisible
    {
        get => _isSkipVisible;
        private set => SetField(ref _isSkipVisible, value);
    }

    public string AccelerationNodeText =>
        _isEnglish ? "Use acceleration nodes" : "使用加速节点";

    public string SkipText => _isEnglish ? "Skip speed test" : "跳过测速";

    public string PrimaryButtonText
    {
        get => _primaryButtonText;
        private set => SetField(ref _primaryButtonText, value);
    }

    public bool RequestClose()
    {
        if (!IsRunning)
        {
            return true;
        }

        if (_cancellation?.IsCancellationRequested == true)
        {
            Detail = _isEnglish
                ? "Stopping and cleaning temporary files..."
                : "正在停止操作并清理临时文件...";
            return false;
        }

        if (CanCancel)
        {
            Cancel();
            Description = _isEnglish
                ? "Waiting for the current operation to stop safely"
                : "正在安全停止当前操作";
            return false;
        }

        Detail = _isEnglish
            ? "Application files are being replaced. Setup will close when this step finishes."
            : "正在替换应用文件，此阶段不能强制退出，请等待安装完成。";
        return false;
    }

    public void ShowLicense()
    {
        _page = WizardPage.License;
        Title = _isEnglish ? "License Agreement" : "许可协议";
        Description = _isEnglish ? "Please read the following license terms" : "请仔细阅读以下许可条款";
        PrimaryButtonText = _isEnglish ? "Continue" : "继续";
        UpdateStepState(0);
        NotifyPageState();
    }

    public void ShowLocation()
    {
        if (!LicenseAccepted)
        {
            return;
        }

        _page = WizardPage.Location;
        Title = _isEnglish ? "Install Location" : "安装位置";
        Description = _isEnglish ? "Setup will use the current application directory" : "Setup 将使用当前程序目录";
        Detail = InstallLocation;
        PrimaryButtonText = _isEnglish ? "Install" : "开始安装";
        UpdateStepState(1);
        NotifyPageState();
    }

    public void ToggleLanguage()
    {
        _isEnglish = !_isEnglish;
        UpdateStrings();
    }

    private void UpdateStrings()
    {
        OnPropertyChanged(nameof(SetupTitleText));
        OnPropertyChanged(nameof(SetupSubtitleText));
        OnPropertyChanged(nameof(StartInstallText));
        OnPropertyChanged(nameof(StepProgressText));
        OnPropertyChanged(nameof(FooterStatusText));
        OnPropertyChanged(nameof(AboutText));
        OnPropertyChanged(nameof(AboutToolTipText));
        OnPropertyChanged(nameof(BackText));
        OnPropertyChanged(nameof(AcceptLicenseText));
        OnPropertyChanged(nameof(TargetDirText));
        OnPropertyChanged(nameof(ChangeDirText));
        OnPropertyChanged(nameof(LocationWarningText));
        OnPropertyChanged(nameof(InstallProgressText));
        OnPropertyChanged(nameof(SpecialThanksText));
        OnPropertyChanged(nameof(AccelerationNodeText));
        OnPropertyChanged(nameof(SkipText));
        OnPropertyChanged(nameof(SecondaryButtonText));
        OnPropertyChanged(nameof(InstallLocationStatusText));
        OnPropertyChanged(nameof(ResultLabelText));

        Steps[0].Label = _isEnglish ? "License" : "许可协议";
        Steps[1].Label = _isEnglish ? "Location" : "安装位置";
        Steps[2].Label = _isEnglish ? "Installing" : "正在安装";
        Steps[3].Label = _isEnglish ? "Complete" : "安装完成";

        switch (_page)
        {
            case WizardPage.Welcome:
                break;
            case WizardPage.License:
                ShowLicense();
                break;
            case WizardPage.Location:
                ShowLocation();
                break;
            case WizardPage.Progress:
                Title = _isEnglish ? "Installing" : "正在安装";
                Description = _isEnglish ? "Applying update, please do not close this window" : "正在应用更新，请不要关闭此窗口";
                PrimaryButtonText = _isEnglish ? "Cancel" : "取消";
                break;
            case WizardPage.Done:
                Title = HasFailed ? (_isEnglish ? "Update Failed" : "更新失败") : (_isEnglish ? "Complete" : "万事大吉");
                Description = HasFailed ? (_isEnglish ? "An error occurred during update" : "安装过程中出现错误，已尝试回滚") : (_isEnglish ? "Hanabi Download Manager X has been successfully updated" : "Hanabi Download Manager X 已经更新完成");
                PrimaryButtonText = HasFailed ? (_isEnglish ? "Retry" : "重试") : (_isEnglish ? "Finish" : "完成");
                break;
        }
    }

    public void ToggleAbout()
    {
        if (IsRunning)
        {
            return;
        }

        IsAboutVisibleOverlay = !IsAboutVisibleOverlay;
    }

    public async Task<bool> HandlePrimaryAsync()
    {
        switch (_page)
        {
            case WizardPage.License:
                ShowLocation();
                break;
            case WizardPage.Location:
                await StartInstallAsync();
                break;
            case WizardPage.Progress:
                Cancel();
                break;
            case WizardPage.Done:
                if (HasFailed)
                {
                    await StartInstallAsync(_currentSkipMirror);
                    return false;
                }
                return true;
        }

        return false;
    }

    public bool HandleSecondary()
    {
        switch (_page)
        {
            case WizardPage.License:
                _page = WizardPage.Welcome;
                NotifyPageState();
                return false;
            case WizardPage.Location:
                ShowLicense();
                return false;
            case WizardPage.Done when HasFailed:
                return true;
            default:
                return false;
        }
    }

    private async Task StartInstallAsync(bool skipMirror = false)
    {
        if (IsRunning)
        {
            return;
        }

        _page = WizardPage.Progress;
        Title = _isEnglish ? "Installing" : "正在安装";
        Description = _isEnglish ? "Applying update, please do not close this window" : "正在应用更新，请不要关闭此窗口";
        Detail = _isEnglish ? "Getting ready" : "准备开始";
        Percent = 0;
        IsProgressIndeterminate = true;
        IsRunning = true;
        HasFailed = false;
        CanCancel = true;
        IsSkipVisible = false;
        _currentSkipMirror = skipMirror || !UseAccelerationNode;
        PrimaryButtonText = _isEnglish ? "Cancel" : "取消";
        UpdateStepState(2);
        NotifyPageState();

        if (!_parseResult.IsSuccess || _parseResult.Arguments is null)
        {
            Fail(_isEnglish ? "Setup Failed" : "安装失败", _isEnglish ? "Setup arguments are incomplete" : "安装程序启动参数不完整", _parseResult.Error ?? (_isEnglish ? "Cannot parse arguments" : "无法解析启动参数"));
            return;
        }

        var executableName = Path.GetFileName(_parseResult.Arguments.AppPath);
        var actualAppPath = Path.Combine(InstallLocation, executableName);
        var actualArgs = _parseResult.Arguments with
        {
            AppPath = actualAppPath,
            SkipMirror = skipMirror || !UseAccelerationNode
        };

        var cancellation = new CancellationTokenSource();
        _cancellation = cancellation;
        var engine = new UpdateEngine(actualArgs);
        var progress = new Progress<UpdateProgress>(ApplyProgress);

        try
        {
            await Task.Run(() => engine.RunAsync(progress, cancellation.Token));
            Succeed();
        }
        catch (OperationCanceledException)
        {
            if (_isSkippingSpeedTest)
            {
                _isSkippingSpeedTest = false;
                IsRunning = false;
                _cancellation.Dispose();
                _cancellation = null;
                await StartInstallAsync(skipMirror: true);
                return;
            }
            Fail(_isEnglish ? "Update Canceled" : "已取消更新", _isEnglish ? "No files were replaced" : "没有继续替换应用文件", _isEnglish ? "You can restart the update process later" : "你可以稍后重新启动更新流程");
        }
        catch (Exception ex)
        {
            Fail(_isEnglish ? "Update Failed" : "更新失败", _isEnglish ? "An error occurred during update, rolling back" : "安装过程中出现错误，已尝试回滚", ex.Message);
        }
    }

    public void Cancel()
    {
        if (!IsRunning || !CanCancel)
        {
            return;
        }

        CanCancel = false;
        Detail = _isEnglish ? "Canceling update" : "正在取消更新";
        _cancellation?.Cancel();
    }

    public void SkipSpeedTest()
    {
        if (!IsRunning || !IsSkipVisible)
        {
            return;
        }

        IsSkipVisible = false;
        _isSkippingSpeedTest = true;
        Detail = _isEnglish ? "Skipping speed test, using GitHub directly..." : "跳过测速，直接使用 GitHub 源...";
        _cancellation?.Cancel();
    }

    private void ApplyProgress(UpdateProgress progress)
    {
        _currentStage = progress.Stage;
        Title = progress.Title;
        Description = progress.Description;
        Detail = progress.Detail;
        Percent = Math.Clamp(progress.Percent, 0, 100);
        IsProgressIndeterminate = progress.Stage is UpdateStage.Preparing ||
            progress.Stage == UpdateStage.Downloading && progress.TotalBytes is null;
        CanCancel = progress.Stage is UpdateStage.Preparing or UpdateStage.Downloading or UpdateStage.WaitingForAppExit or UpdateStage.Extracting;
        IsSkipVisible = !_currentSkipMirror && progress.CanSkip;
    }

    private void Succeed()
    {
        IsRunning = false;
        HasFailed = false;
        CanCancel = false;
        _page = WizardPage.Done;
        Title = _isEnglish ? "Complete" : "万事大吉";
        Description = _isEnglish ? "Hanabi Download Manager X has been successfully updated" : "Hanabi Download Manager X 已经更新完成";
        if (_currentStage != UpdateStage.Completed)
        {
            Detail = _isEnglish ? "The new version is ready" : "新版本已准备就绪";
        }
        PrimaryButtonText = _isEnglish ? "Finish" : "完成";
        Percent = 100;
        IsProgressIndeterminate = false;
        UpdateStepState(4);
        NotifyPageState();
        DisposeCancellation();
    }

    private void Fail(string title, string description, string detail)
    {
        IsRunning = false;
        HasFailed = true;
        CanCancel = false;
        _page = WizardPage.Done;
        Title = title;
        Description = description;
        Detail = detail;
        PrimaryButtonText = _isEnglish ? "Retry" : "重试";
        IsProgressIndeterminate = false;
        NotifyPageState();
        DisposeCancellation();
    }

    private void UpdateStepState(int activeIndex)
    {
        for (var index = 0; index < Steps.Count; index++)
        {
            if (index < activeIndex)
            {
                Steps[index].MarkDone();
            }
            else if (index == activeIndex)
            {
                Steps[index].MarkActive();
            }
            else
            {
                Steps[index].MarkPending();
            }
        }
    }

    private void NotifyPageState()
    {
        OnPropertyChanged(nameof(IsWelcomeVisible));
        OnPropertyChanged(nameof(IsWizardVisible));
        OnPropertyChanged(nameof(IsLicenseVisible));
        OnPropertyChanged(nameof(IsLocationVisible));
        OnPropertyChanged(nameof(IsProgressVisible));
        OnPropertyChanged(nameof(IsDoneVisible));
        OnPropertyChanged(nameof(CanUsePrimaryButton));
        OnPropertyChanged(nameof(IsAboutVisibleOverlay));
        OnPropertyChanged(nameof(IsMainContentVisible));
        OnPropertyChanged(nameof(IsPrimaryButtonVisible));
        OnPropertyChanged(nameof(IsCancelButtonVisible));
        OnPropertyChanged(nameof(IsFooterStatusVisible));
        OnPropertyChanged(nameof(IsSecondaryButtonVisible));
        OnPropertyChanged(nameof(SecondaryButtonText));
        OnPropertyChanged(nameof(CanAdjustPreferences));
        OnPropertyChanged(nameof(IsSuccessResult));
        OnPropertyChanged(nameof(IsFailureResult));
        OnPropertyChanged(nameof(ResultLabelText));
    }

    private void DisposeCancellation()
    {
        _cancellation?.Dispose();
        _cancellation = null;
    }

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    private static string LoadLicenseText()
    {
        try
        {
            using var stream = AssetLoader.Open(new Uri("avares://HanabiUpdater/Assets/LICENSE"));
            using var reader = new StreamReader(stream);
            return reader.ReadToEnd();
        }
        catch
        {
            return "GNU General Public License v3.0\n\nLicense file could not be loaded from Assets/LICENSE.";
        }
    }

    private enum WizardPage
    {
        Welcome,
        License,
        Location,
        Progress,
        Done
    }
}
