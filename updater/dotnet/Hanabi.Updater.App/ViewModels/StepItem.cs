using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace Hanabi.Updater.App.ViewModels;

public sealed class StepItem : INotifyPropertyChanged
{
    private readonly string _pendingIndicator;
    private string _label;
    private string _indicator;
    private bool _isPending = true;
    private bool _isActive;
    private bool _isDone;
    private double _selectionOpacity;

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

    public bool IsPending
    {
        get => _isPending;
        private set => SetField(ref _isPending, value);
    }

    public bool IsActive
    {
        get => _isActive;
        private set => SetField(ref _isActive, value);
    }

    public bool IsDone
    {
        get => _isDone;
        private set => SetField(ref _isDone, value);
    }

    public double SelectionOpacity
    {
        get => _selectionOpacity;
        private set => SetField(ref _selectionOpacity, value);
    }

    public void MarkPending()
    {
        Indicator = _pendingIndicator;
        IsPending = true;
        IsActive = false;
        IsDone = false;
        SelectionOpacity = 0;
    }

    public void MarkActive()
    {
        Indicator = _pendingIndicator;
        IsPending = false;
        IsActive = true;
        IsDone = false;
        SelectionOpacity = 1;
    }

    public void MarkDone()
    {
        Indicator = "\uE73E";
        IsPending = false;
        IsActive = false;
        IsDone = true;
        SelectionOpacity = 0;
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
