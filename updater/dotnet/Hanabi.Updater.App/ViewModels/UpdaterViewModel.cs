using System.ComponentModel;
using System.Runtime.CompilerServices;
using Avalonia.Platform;
using Hanabi.Updater.Core;

namespace Hanabi.Updater.App.ViewModels;

public sealed class UpdaterViewModel : INotifyPropertyChanged
{
    private readonly string[] _args;
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

    public string SetupTitleText => "Hanabi Download Manager X";
    public string SetupSubtitleText => _isEnglish ? "Fast and powerful download manager" : "快速、强大的下载管理器";
    public string StartInstallText => _isEnglish ? "Start Install" : "开始安装";
    public string AboutText => _isEnglish ? "About" : "关于";
    public string BackText => _isEnglish ? "Back" : "返回";
    public string AcceptLicenseText => _isEnglish ? "I accept the terms in the License Agreement" : "我接受许可协议中的条款";
    public string TargetDirText => _isEnglish ? "Target Directory" : "目标目录";
    public string ChangeDirText => _isEnglish ? "Browse..." : "浏览...";
    public string LocationWarningText => _isEnglish ? "If your old process is still running, We will wait for the app to exit, then replace the files." : "若您的旧进程仍在运行,我们会等待主程序退出，然后在替换当前目录中的文件";
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
                if (_page == WizardPage.Location)
                {
                    Detail = value;
                }
            }
        }
    }

    public UpdaterViewModel(string[] args)
    {
        _args = args;
        _parseResult = UpdaterArguments.Parse(_args);

        _installLocation = _parseResult.Arguments is null
            ? "启动参数缺失，无法定位安装目录"
            : Path.GetDirectoryName(_parseResult.Arguments.AppPath) ?? _parseResult.Arguments.AppPath;

        Steps =
        [
            new StepItem("许可协议", "\uE8A5"),
            new StepItem("安装位置", "\uE838"),
            new StepItem("正在安装", "\uE896"),
            new StepItem("万事大吉", "\uE73E")
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

    public bool IsPrimaryButtonVisible => !_isAboutVisibleOverlay;

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

    public bool IsRunning
    {
        get => _isRunning;
        private set => SetField(ref _isRunning, value);
    }

    public bool HasFailed
    {
        get => _hasFailed;
        private set => SetField(ref _hasFailed, value);
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
            WizardPage.Progress => IsRunning && CanCancel,
            _ => !IsRunning
        };

    public bool CanCancel
    {
        get => _canCancel;
        private set
        {
            if (SetField(ref _canCancel, value))
            {
                OnPropertyChanged(nameof(CanUsePrimaryButton));
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

    public void ShowLicense()
    {
        _page = WizardPage.License;
        Title = _isEnglish ? "License Agreement" : "许可协议";
        Description = _isEnglish ? "Please read the following license terms" : "请仔细阅读以下许可条款";
        PrimaryButtonText = _isEnglish ? "Next  >" : "下一步  >";
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
        Description = _isEnglish ? "The updater will install to the current Hanabi directory" : "更新器将安装到当前 Hanabi 目录";
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
        OnPropertyChanged(nameof(AboutText));
        OnPropertyChanged(nameof(BackText));
        OnPropertyChanged(nameof(AcceptLicenseText));
        OnPropertyChanged(nameof(TargetDirText));
        OnPropertyChanged(nameof(ChangeDirText));
        OnPropertyChanged(nameof(LocationWarningText));
        OnPropertyChanged(nameof(InstallProgressText));
        OnPropertyChanged(nameof(SpecialThanksText));
        OnPropertyChanged(nameof(AccelerationNodeText));
        OnPropertyChanged(nameof(SkipText));

        Steps[0].Label = _isEnglish ? "License" : "许可协议";
        Steps[1].Label = _isEnglish ? "Location" : "安装位置";
        Steps[2].Label = _isEnglish ? "Installing" : "正在安装";
        Steps[3].Label = _isEnglish ? "Complete" : "万事大吉";

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
                PrimaryButtonText = HasFailed ? (_isEnglish ? "Close" : "关闭") : (_isEnglish ? "Finish" : "完成");
                break;
        }
    }

    public void ToggleAbout()
    {
        IsAboutVisibleOverlay = !IsAboutVisibleOverlay;
    }

    public async Task HandlePrimaryAsync()
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
                break;
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
            Fail(_isEnglish ? "Update Failed" : "更新失败", _isEnglish ? "Updater arguments incomplete" : "更新器启动参数不完整", _parseResult.Error ?? (_isEnglish ? "Cannot parse arguments" : "无法解析启动参数"));
            return;
        }

        var actualAppPath = Path.Combine(InstallLocation, "HanabiDownloadManagerX.exe");
        var actualArgs = _parseResult.Arguments with
        {
            AppPath = actualAppPath,
            SkipMirror = skipMirror || !UseAccelerationNode
        };

        _cancellation = new CancellationTokenSource();
        var engine = new UpdateEngine(actualArgs);
        var progress = new Progress<UpdateProgress>(ApplyProgress);

        try
        {
            await engine.RunAsync(progress, _cancellation.Token);
            Succeed();
        }
        catch (OperationCanceledException)
        {
            if (_isSkippingSpeedTest)
            {
                _isSkippingSpeedTest = false;
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

    public async void SkipSpeedTest()
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
        CanCancel = progress.Stage is UpdateStage.Preparing or UpdateStage.Downloading or UpdateStage.WaitingForAppExit or UpdateStage.Extracting;
        IsSkipVisible = !_currentSkipMirror && progress.Stage == UpdateStage.Downloading && Percent < 50;
    }

    private void Succeed()
    {
        IsRunning = false;
        HasFailed = false;
        CanCancel = false;
        _page = WizardPage.Done;
        Title = _isEnglish ? "Complete" : "万事大吉";
        Description = _isEnglish ? "Hanabi Download Manager X has been successfully updated" : "Hanabi Download Manager X 已经更新完成";
        Detail = _isEnglish ? "New version has been launched" : "新版本已启动";
        PrimaryButtonText = _isEnglish ? "Finish" : "完成";
        Percent = 100;
        UpdateStepState(4);
        NotifyPageState();
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
        PrimaryButtonText = _isEnglish ? "Close" : "关闭";
        NotifyPageState();
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
