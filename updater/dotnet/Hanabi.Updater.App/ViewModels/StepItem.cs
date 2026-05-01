using System.ComponentModel;
using System.Runtime.CompilerServices;
using Avalonia.Media;

namespace Hanabi.Updater.App.ViewModels;

public sealed class StepItem : INotifyPropertyChanged
{
    private static readonly IBrush ActiveBackground = Brush.Parse("#1E3A52");
    private static readonly IBrush TransparentBackground = Brushes.Transparent;
    private static readonly IBrush ActiveForeground = Brush.Parse("#49B6FF");
    private static readonly IBrush DoneForeground = Brush.Parse("#A9A9A9");
    private static readonly IBrush PendingForeground = Brush.Parse("#8E8E8E");
    private static readonly IBrush LabelActiveForeground = Brush.Parse("#FFFFFF");
    private static readonly IBrush LabelMutedForeground = Brush.Parse("#A7A7A7");

    private readonly string _pendingIndicator;
    private string _indicator;
    private IBrush _background = TransparentBackground;
    private IBrush _indicatorForeground = PendingForeground;
    private IBrush _labelForeground = LabelMutedForeground;

    private string _label;
    
    public StepItem(string label, string pendingIndicator)
    {
        _label = label;
        _pendingIndicator = pendingIndicator;
        _indicator = pendingIndicator;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public string Label
    {
        get => _label;
        set => SetField(ref _label, value);
    }

    public string Indicator
    {
        get => _indicator;
        private set => SetField(ref _indicator, value);
    }

    public IBrush Background
    {
        get => _background;
        private set => SetField(ref _background, value);
    }

    public IBrush IndicatorForeground
    {
        get => _indicatorForeground;
        private set => SetField(ref _indicatorForeground, value);
    }

    public IBrush LabelForeground
    {
        get => _labelForeground;
        private set => SetField(ref _labelForeground, value);
    }

    public void MarkPending()
    {
        Indicator = _pendingIndicator;
        Background = TransparentBackground;
        IndicatorForeground = PendingForeground;
        LabelForeground = LabelMutedForeground;
    }

    public void MarkActive()
    {
        Indicator = _pendingIndicator;
        Background = ActiveBackground;
        IndicatorForeground = ActiveForeground;
        LabelForeground = ActiveForeground;
    }

    public void MarkDone()
    {
        Indicator = "\uE73E";
        Background = TransparentBackground;
        IndicatorForeground = DoneForeground;
        LabelForeground = LabelMutedForeground;
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
