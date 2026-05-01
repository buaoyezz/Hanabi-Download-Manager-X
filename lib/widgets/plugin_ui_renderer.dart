import 'package:fluent_ui/fluent_ui.dart';
import '../models/plugin_ui_schema.dart';

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

    return ListTile(
      title: Text(element.label),
      subtitle: element.description != null ? Text(element.description!) : null,
      trailing: ToggleSwitch(
        checked: isChecked,
        onChanged: (v) {
          final newState = Map<String, dynamic>.from(state);
          newState[element.id] = v;
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(element.label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (element.description != null) ...[
            const SizedBox(height: 4),
            Text(element.description!, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 8),
          TextFormBox(
            initialValue: value,
            placeholder: element.placeholder,
            onChanged: (v) {
              final newState = Map<String, dynamic>.from(state);
              newState[element.id] = v;
              onStateChanged(newState);
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildButton(
    PluginUIElement element,
    void Function(String action) onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: FilledButton(
        onPressed:
            element.action != null ? () => onAction(element.action!) : null,
        child: Text(element.label),
      ),
    );
  }

  static Widget _buildText(PluginUIElement element) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(element.label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (element.description != null) ...[
            const SizedBox(height: 4),
            Text(element.description!),
          ],
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(element.label),
          if (element.description != null) ...[
            const SizedBox(height: 4),
            Text(element.description!, style: const TextStyle(fontSize: 12)),
          ],
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) {
              final newState = Map<String, dynamic>.from(state);
              newState[element.id] = v;
              onStateChanged(newState);
            },
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(element.label),
              if (element.description != null) ...[
                const SizedBox(height: 4),
                Text(element.description!,
                    style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          ComboBox<dynamic>(
            value: value,
            items: options
                .map((e) => ComboBoxItem(
                      value: e.value,
                      child: Text(e.label),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                final newState = Map<String, dynamic>.from(state);
                newState[element.id] = v;
                onStateChanged(newState);
              }
            },
          ),
        ],
      ),
    );
  }
}
