using System.ComponentModel;
using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Animation;
using Avalonia.Animation.Easings;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media.Transformation;
using Avalonia.Threading;
using Hanabi.Updater.App.ViewModels;

namespace Hanabi.Updater.App;

public partial class MainWindow : Window
{
    private const int DwmwaWindowCornerPreference = 33;
    private const int DwmWindowCornerPreferenceRound = 2;

    private readonly UpdaterViewModel _viewModel;
    private bool _pageAnimationQueued;

    public MainWindow()
    {
        InitializeComponent();
        _viewModel = new UpdaterViewModel(Environment.GetCommandLineArgs().Skip(1).ToArray());
        DataContext = _viewModel;
        _viewModel.PropertyChanged += OnViewModelPropertyChanged;
        Opened += OnWindowOpened;
        Closed += (_, _) => _viewModel.PropertyChanged -= OnViewModelPropertyChanged;
    }

    private void OnWindowOpened(object? sender, EventArgs e)
    {
        ApplyNativeWindowCorners();
        QueuePageEntrance();
    }

    private void ApplyNativeWindowCorners()
    {
        if (!OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22000))
        {
            return;
        }

        var handle = TryGetPlatformHandle()?.Handle ?? IntPtr.Zero;
        if (handle == IntPtr.Zero)
        {
            return;
        }

        var preference = DwmWindowCornerPreferenceRound;
        _ = DwmSetWindowAttribute(
            handle,
            DwmwaWindowCornerPreference,
            ref preference,
            sizeof(int));
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(
        IntPtr windowHandle,
        int attribute,
        ref int attributeValue,
        int attributeSize);

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(UpdaterViewModel.IsWelcomeVisible) or
            nameof(UpdaterViewModel.IsLicenseVisible) or
            nameof(UpdaterViewModel.IsLocationVisible) or
            nameof(UpdaterViewModel.IsProgressVisible) or
            nameof(UpdaterViewModel.IsDoneVisible) or
            nameof(UpdaterViewModel.IsAboutVisibleOverlay))
        {
            QueuePageEntrance();
        }
    }

    private void QueuePageEntrance()
    {
        if (_pageAnimationQueued)
        {
            return;
        }

        _pageAnimationQueued = true;
        Dispatcher.UIThread.Post(() =>
        {
            _pageAnimationQueued = false;
            Control target = _viewModel.IsAboutVisibleOverlay
                ? AboutContent
                : _viewModel.IsWelcomeVisible
                    ? WelcomeContent
                    : PageHost;

            target.Transitions = null;
            target.Opacity = 0;
            target.RenderTransform = TransformOperations.Parse("translate(0px, 7px)");
            Dispatcher.UIThread.Post(() =>
            {
                target.Transitions = new Transitions
                {
                    new DoubleTransition
                    {
                        Property = Visual.OpacityProperty,
                        Duration = TimeSpan.FromMilliseconds(180),
                        Easing = new CubicEaseOut()
                    },
                    new TransformOperationsTransition
                    {
                        Property = Visual.RenderTransformProperty,
                        Duration = TimeSpan.FromMilliseconds(180),
                        Easing = new CubicEaseOut()
                    }
                };
                target.Opacity = 1;
                target.RenderTransform = TransformOperations.Parse("translate(0px, 0px)");
            }, DispatcherPriority.Render);
        }, DispatcherPriority.Render);
    }

    private void OnStartButtonClick(object? sender, RoutedEventArgs e)
    {
        _viewModel.ShowLicense();
    }

    private async void OnPrimaryButtonClick(object? sender, RoutedEventArgs e)
    {
        if (await _viewModel.HandlePrimaryAsync())
        {
            Close();
        }
    }

    private void OnSecondaryButtonClick(object? sender, RoutedEventArgs e)
    {
        if (_viewModel.HandleSecondary())
        {
            Close();
        }
    }

    private void OnTitleBarPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            BeginMoveDrag(e);
        }
    }

    private void OnThemeToggleClick(object? sender, RoutedEventArgs e)
    {
        if (Avalonia.Application.Current != null)
        {
            Avalonia.Application.Current.RequestedThemeVariant = Avalonia.Application.Current.RequestedThemeVariant == Avalonia.Styling.ThemeVariant.Light
                ? Avalonia.Styling.ThemeVariant.Dark
                : Avalonia.Styling.ThemeVariant.Light;
        }
    }

    private void OnLangToggleClick(object? sender, RoutedEventArgs e)
    {
        _viewModel.ToggleLanguage();
    }

    private async void OnBrowseClick(object? sender, RoutedEventArgs e)
    {
        var topLevel = Avalonia.Controls.TopLevel.GetTopLevel(this);
        if (topLevel?.StorageProvider.CanPickFolder == true)
        {
            var folders = await topLevel.StorageProvider.OpenFolderPickerAsync(new Avalonia.Platform.Storage.FolderPickerOpenOptions
            {
                Title = _viewModel.TargetDirText,
                AllowMultiple = false
            });

            if (folders.Count > 0)
            {
                _viewModel.InstallLocation = folders[0].Path.LocalPath;
            }
        }
    }

    private void OnAboutClick(object? sender, RoutedEventArgs e)
    {
        _viewModel.ToggleAbout();
    }

    private void OnMinimizeClick(object? sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void OnCloseClick(object? sender, RoutedEventArgs e)
    {
        if (_viewModel.RequestClose())
        {
            Close();
        }
    }

    private void OnWindowClosing(object? sender, WindowClosingEventArgs e)
    {
        if (!_viewModel.RequestClose())
        {
            e.Cancel = true;
        }
    }

    private void OnSkipClick(object? sender, RoutedEventArgs e)
    {
        _viewModel.SkipSpeedTest();
    }
}
