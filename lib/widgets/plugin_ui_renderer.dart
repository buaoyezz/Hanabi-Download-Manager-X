import 'package:fluent_ui/fluent_ui.dart';

import '../models/plugin_ui_schema.dart';
import '../theme/app_theme.dart';
import '../utils/fluent_icons.dart' as custom_icons;

class PluginUIRenderer {
  static Widget renderElement({
    required PluginUIElement element,
    required Map<String, dynamic> state,
    required ValueChanged<Map<String, dynamic>> onStateChanged,
    required void Function(String action) onAction,
  }) {
    switch (element.type) {
      case PluginUIElementType.switchToggle:
        return _buildSwitch(element, state, onStateChanged);
      case PluginUIElementType.textInput:
        return _buildTextInput(element, state, onStateChanged);
      case PluginUIElementType.button:
        return _buildButton(element, onAction);
      case PluginUIElementType.text:
        return _buildText(element);
      case PluginUIElementType.slider:
        return _buildSlider(element, state, onStateChanged);
      case PluginUIElementType.dropdown:
        return _buildDropdown(element, state, onStateChanged);
      case PluginUIElementType.unknown:
        return const SizedBox.shrink();
    }
  }

  static Widget _buildSwitch(
    PluginUIElement element,
    Map<String, dynamic> state,
    ValueChanged<Map<String, dynamic>> onStateChanged,
  ) {
    final value = state[element.id] ?? element.defaultValue ?? false;
    final isChecked = value == true || value == 'true';

    return _controlShell(
      element: element,
      trailing: ToggleSwitch(
        checked: isChecked,
        onChanged: (value) {
          final newState = Map<String, dynamic>.from(state);
          newState[element.id] = value;
          onStateChanged(newState);
        },
      ),
    );
  }

  static Widget _buildTextInput(
    PluginUIElement element,
    Map<String, dynamic> state,
    ValueChanged<Map<String, dynamic>> onStateChanged,
  ) {
    final value =
        state[element.id]?.toString() ?? element.defaultValue?.toString() ?? '';

    return _controlShell(
      element: element,
      body: TextFormBox(
        initialValue: value,
        placeholder: element.placeholder,
        onChanged: (value) {
          final newState = Map<String, dynamic>.from(state);
          newState[element.id] = value;
          onStateChanged(newState);
        },
      ),
    );
  }

  static Widget _buildButton(
    PluginUIElement element,
    void Function(String action) onAction,
  ) {
    return _controlShell(
      element: element,
      trailing: FilledButton(
        onPressed:
            element.action != null ? () => onAction(element.action!) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_elementIcon(element, fallback: custom_icons.FluentIcons.play),
                size: 14),
            const SizedBox(width: 6),
            Text(element.label),
          ],
        ),
      ),
      hideTitle: true,
    );
  }

  static Widget _buildText(PluginUIElement element) {
    return _controlShell(
      element: element,
      body: element.description == null || element.description!.isEmpty
          ? null
          : Text(
              element.description!,
              style: const TextStyle(fontSize: 12),
            ),
    );
  }

  static Widget _buildSlider(
    PluginUIElement element,
    Map<String, dynamic> state,
    ValueChanged<Map<String, dynamic>> onStateChanged,
  ) {
    final valueStr = state[element.id]?.toString() ??
        element.defaultValue?.toString() ??
        '0';
    final rawMin = element.min ?? 0.0;
    final rawMax = element.max ?? 100.0;
    final min = rawMin <= rawMax ? rawMin : rawMax;
    final normalizedMax = rawMin <= rawMax ? rawMax : rawMin;
    final max = normalizedMax == min ? min + 1.0 : normalizedMax;
    final value = (double.tryParse(valueStr) ?? min).clamp(min, max).toDouble();
    final divisions = element.divisions?.round().clamp(1, 1000).toInt();

    return _controlShell(
      element: element,
      body: Row(
        children: [
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (nextValue) {
                final newState = Map<String, dynamic>.from(state);
                newState[element.id] = nextValue;
                onStateChanged(newState);
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              _formatSliderValue(value),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDropdown(
    PluginUIElement element,
    Map<String, dynamic> state,
    ValueChanged<Map<String, dynamic>> onStateChanged,
  ) {
    final options = element.options ?? const <PluginDropdownOption>[];
    final rawValue = state[element.id] ?? element.defaultValue;
    final hasValue = options.any((option) => option.value == rawValue);
    final value = hasValue ? rawValue : null;

    return _controlShell(
      element: element,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 170, maxWidth: 240),
        child: ComboBox<dynamic>(
          value: value,
          isExpanded: true,
          items: options
              .map(
                (option) => ComboBoxItem(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              final newState = Map<String, dynamic>.from(state);
              newState[element.id] = value;
              onStateChanged(newState);
            }
          },
        ),
      ),
    );
  }

  static Widget _controlShell({
    required PluginUIElement element,
    Widget? body,
    Widget? trailing,
    bool hideTitle = false,
  }) {
    return Builder(
      builder: (context) {
        final title = hideTitle ? null : _titleBlock(context, element);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgLayer2.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.45),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              if (trailing != null && title != null && !compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    trailing,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) title,
                  if (title != null && (body != null || trailing != null))
                    const SizedBox(height: 10),
                  if (body != null) body,
                  if (body != null && trailing != null)
                    const SizedBox(height: 10),
                  if (trailing != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: trailing,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static Widget _titleBlock(BuildContext context, PluginUIElement element) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            _elementIcon(element),
            size: 14,
            color: AppTheme.accentPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                element.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (element.description != null &&
                  element.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  element.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static IconData _elementIcon(
    PluginUIElement element, {
    IconData? fallback,
  }) {
    final raw = element.icon?.trim();
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('fluent:')) {
        return custom_icons.FluentIcons.getIcon(raw.substring(7));
      }
      return custom_icons.FluentIcons.getIcon(raw);
    }

    switch (element.type) {
      case PluginUIElementType.switchToggle:
        return custom_icons.FluentIcons.settings;
      case PluginUIElementType.textInput:
        return custom_icons.FluentIcons.document;
      case PluginUIElementType.button:
        return fallback ?? custom_icons.FluentIcons.play;
      case PluginUIElementType.text:
        return custom_icons.FluentIcons.info;
      case PluginUIElementType.slider:
        return custom_icons.FluentIcons.settings;
      case PluginUIElementType.dropdown:
        return custom_icons.FluentIcons.filter;
      case PluginUIElementType.unknown:
        return fallback ?? custom_icons.FluentIcons.app_icon_default;
    }
  }

  static String _formatSliderValue(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
