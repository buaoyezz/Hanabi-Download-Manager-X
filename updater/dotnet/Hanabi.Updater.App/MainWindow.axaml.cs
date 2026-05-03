using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Hanabi.Updater.App.ViewModels;

namespace Hanabi.Updater.App;

public partial class MainWindow : Window
{
    private readonly UpdaterViewModel _viewModel;

    public MainWindow()
    {
        InitializeComponent();
        _viewModel = new UpdaterViewModel(Environment.GetCommandLineArgs().Skip(1).ToArray());
        DataContext = _viewModel;
    }

    private void OnStartButtonClick(object? sender, RoutedEventArgs e)
    {
        _viewModel.ShowLicense();
    }

    private async void OnPrimaryButtonClick(object? sender, RoutedEventArgs e)
    {
        var shouldClose = _viewModel.IsDoneVisible;
        await _viewModel.HandlePrimaryAsync();

        if (shouldClose)
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
        if (_viewModel.IsRunning)
        {
            _viewModel.Cancel();
        }

        Close();
    }

    private void OnSkipClick(object? sender, RoutedEventArgs e)
    {
        _viewModel.SkipSpeedTest();
    }
}
