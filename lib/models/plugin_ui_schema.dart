enum PluginUIElementType {
  switchToggle,
  textInput,
  button,
  text,
  slider,
  dropdown,
  unknown
}

class PluginDropdownOption {
  final String label;
  final dynamic value;

  const PluginDropdownOption({required this.label, required this.value});

  factory PluginDropdownOption.fromJson(Object? raw) {
    if (raw is! Map) {
      final value = raw?.toString() ?? '';
      return PluginDropdownOption(label: value, value: raw);
    }
    final json = _stringKeyedMap(raw);
    return PluginDropdownOption(
      label: json['label']?.toString() ?? '',
      value: json.containsKey('value') ? json['value'] : json['label'],
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
      };
}

class PluginUIElement {
  final PluginUIElementType type;
  final String id;
  final String label;
  final String? description;
  final dynamic defaultValue;
  final String? action;
  final String? placeholder;
  final List<PluginDropdownOption>? options;
  final double? min;
  final double? max;
  final double? divisions;
  final String? icon;

  const PluginUIElement({
    required this.type,
    required this.id,
    required this.label,
    this.description,
    this.defaultValue,
    this.action,
    this.placeholder,
    this.options,
    this.min,
    this.max,
    this.divisions,
    this.icon,
  });

  factory PluginUIElement.fromJson(Object? raw) {
    if (raw is! Map) {
      return const PluginUIElement(
        type: PluginUIElementType.unknown,
        id: '',
        label: '',
      );
    }
    final json = _stringKeyedMap(raw);
    final optionsRaw = json['options'];
    return PluginUIElement(
      type: _parseType(json['type']?.toString()),
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString(),
      defaultValue: json['default'],
      action: json['action']?.toString(),
      placeholder: json['placeholder']?.toString(),
      options: optionsRaw is List
          ? optionsRaw
              .map(PluginDropdownOption.fromJson)
              .where((option) => option.label.isNotEmpty)
              .toList()
          : null,
      min: _toDouble(json['min']),
      max: _toDouble(json['max']),
      divisions: _toDouble(json['divisions']),
      icon: json['icon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': _typeToString(type),
      'id': id,
      'label': label,
      if (description != null) 'description': description,
      if (defaultValue != null) 'default': defaultValue,
      if (action != null) 'action': action,
      if (placeholder != null) 'placeholder': placeholder,
      if (options != null) 'options': options!.map((e) => e.toJson()).toList(),
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (divisions != null) 'divisions': divisions,
      if (icon != null) 'icon': icon,
    };
  }

  static PluginUIElementType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'switch':
      case 'toggle':
      case 'switch_toggle':
        return PluginUIElementType.switchToggle;
      case 'text_input':
      case 'textInput':
      case 'input':
        return PluginUIElementType.textInput;
      case 'button':
        return PluginUIElementType.button;
      case 'text':
        return PluginUIElementType.text;
      case 'slider':
        return PluginUIElementType.slider;
      case 'dropdown':
        return PluginUIElementType.dropdown;
      default:
        return PluginUIElementType.unknown;
    }
  }

  static String _typeToString(PluginUIElementType type) {
    switch (type) {
      case PluginUIElementType.switchToggle:
        return 'switch';
      case PluginUIElementType.textInput:
        return 'text_input';
      case PluginUIElementType.button:
        return 'button';
      case PluginUIElementType.text:
        return 'text';
      case PluginUIElementType.slider:
        return 'slider';
      case PluginUIElementType.dropdown:
        return 'dropdown';
      case PluginUIElementType.unknown:
        return 'unknown';
    }
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> value) {
  return {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}
