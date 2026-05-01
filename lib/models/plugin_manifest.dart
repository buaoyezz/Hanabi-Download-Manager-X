import 'dart:convert';

import 'plugin_ui_schema.dart';

enum PluginInstallState {
  available,
  enabled,
  disabled,
  incompatible,
  invalid,
}

enum PluginSidebarPlacement {
  top,
  bottom,
}

class PluginPermissionSet {
  const PluginPermissionSet({
    this.network = false,
    this.fileWrite = false,
    this.systemCommand = false,
  });

  final bool network;
  final bool fileWrite;
  final bool systemCommand;

  factory PluginPermissionSet.fromJson(Object? json) {
    if (json is List) {
      final values = json.map((value) => value.toString()).toSet();
      return PluginPermissionSet(
        network: values.contains('network'),
        fileWrite:
            values.contains('file_write') || values.contains('fileWrite'),
        systemCommand: values.contains('system_command') ||
            values.contains('systemCommand'),
      );
    }
    if (json is Map) {
      return PluginPermissionSet(
        network: json['network'] == true,
        fileWrite: json['file_write'] == true || json['fileWrite'] == true,
        systemCommand:
            json['system_command'] == true || json['systemCommand'] == true,
      );
    }
    return const PluginPermissionSet();
  }

  List<String> toList() {
    return [
      if (network) 'network',
      if (fileWrite) 'file_write',
      if (systemCommand) 'system_command',
    ];
  }
}

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.entry,
    required this.capabilities,
    this.icon,
    this.description = '',
    this.category = 'other',
    this.minAppVersion,
    this.permissions = const PluginPermissionSet(),
    this.themeOverrides,
    this.uiExtensions,
    this.sidebarPlacement = PluginSidebarPlacement.bottom,
  });

  final String id;
  final String name;
  final String version;
  final String author;
  final String entry;
  final List<String> capabilities;
  final String? icon;
  final String description;
  final String category;
  final String? minAppVersion;
  final PluginPermissionSet permissions;
  final Map<String, dynamic>? themeOverrides;
  final Map<String, List<PluginUIElement>>? uiExtensions;
  final PluginSidebarPlacement sidebarPlacement;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final capabilitiesRaw = json['capabilities'];
    final capabilities = capabilitiesRaw is List
        ? capabilitiesRaw
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final uiExtensionsRaw = json['ui_extensions'] ?? json['uiExtensions'];

    return PluginManifest(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
      author: json['author']?.toString().trim() ?? '',
      entry: json['entry']?.toString().trim() ?? '',
      capabilities: capabilities,
      icon: json['icon']?.toString().trim(),
      description: json['description']?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? 'other',
      minAppVersion: json['minAppVersion']?.toString().trim(),
      permissions: PluginPermissionSet.fromJson(json['permissions']),
      themeOverrides:
          _stringKeyedMap(json['theme_overrides'] ?? json['themeOverrides']),
      uiExtensions: _parseUiExtensions(uiExtensionsRaw),
      sidebarPlacement: _parseSidebarPlacement(uiExtensionsRaw, json),
    );
  }

  static Map<String, List<PluginUIElement>>? _parseUiExtensions(dynamic json) {
    if (json is! Map) return null;
    final map = <String, List<PluginUIElement>>{};
    for (final entry in json.entries) {
      final elementsRaw = _uiElementsRaw(entry.value);
      if (elementsRaw == null) {
        continue;
      }
      final elements = <PluginUIElement>[];
      for (final rawElement in elementsRaw) {
        try {
          final element = PluginUIElement.fromJson(rawElement);
          if (element.type != PluginUIElementType.unknown) {
            elements.add(element);
          }
        } catch (_) {
          // A malformed UI control should not make the whole plugin unloadable.
        }
      }
      if (elements.isNotEmpty) {
        map[entry.key.toString()] = elements;
      }
    }
    return map.isEmpty ? null : map;
  }

  static List<dynamic>? _uiElementsRaw(dynamic value) {
    if (value is List) {
      return value;
    }
    if (value is Map) {
      final elements = value['elements'] ?? value['items'] ?? value['controls'];
      if (elements is List) {
        return elements;
      }
    }
    return null;
  }

  static PluginSidebarPlacement _parseSidebarPlacement(
    dynamic uiExtensions,
    Map<String, dynamic> manifestJson,
  ) {
    Object? rawPlacement =
        manifestJson['sidebar_placement'] ?? manifestJson['sidebarPlacement'];
    if (rawPlacement == null && uiExtensions is Map) {
      final sidebar = uiExtensions['sidebar'];
      if (sidebar is Map) {
        rawPlacement = sidebar['placement'] ??
            sidebar['position'] ??
            sidebar['nav_position'] ??
            sidebar['navPosition'];
      }
    }
    final placement = rawPlacement?.toString().trim().toLowerCase();
    switch (placement) {
      case 'top':
      case 'upper':
      case 'main':
        return PluginSidebarPlacement.top;
      case 'bottom':
      case 'lower':
      case 'footer':
        return PluginSidebarPlacement.bottom;
      default:
        return PluginSidebarPlacement.bottom;
    }
  }

  static String _sidebarPlacementToString(PluginSidebarPlacement placement) {
    switch (placement) {
      case PluginSidebarPlacement.top:
        return 'top';
      case PluginSidebarPlacement.bottom:
        return 'bottom';
    }
  }

  static Map<String, dynamic>? _stringKeyedMap(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  factory PluginManifest.fromJsonString(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('plugin.json must be a JSON object');
    }
    return PluginManifest.fromJson(_stringKeyedMap(decoded)!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'author': author,
        'entry': entry,
        'capabilities': capabilities,
        if (icon != null && icon!.isNotEmpty) 'icon': icon,
        if (description.isNotEmpty) 'description': description,
        if (category.isNotEmpty && category != 'other') 'category': category,
        if (minAppVersion != null && minAppVersion!.isNotEmpty)
          'minAppVersion': minAppVersion,
        'permissions': permissions.toList(),
        if (themeOverrides != null) 'theme_overrides': themeOverrides,
        if (uiExtensions != null)
          'ui_extensions': uiExtensions!.map(
            (key, value) =>
                MapEntry(key, value.map((e) => e.toJson()).toList()),
          ),
        if (sidebarPlacement != PluginSidebarPlacement.bottom)
          'sidebar_placement': _sidebarPlacementToString(sidebarPlacement),
      };

  List<String> validate() {
    final errors = <String>[];
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{1,62}$').hasMatch(id)) {
      errors.add(
          'id must be 2-63 lowercase letters, numbers, dot, dash or underscore');
    }
    if (name.isEmpty) {
      errors.add('name is required');
    }
    if (version.isEmpty) {
      errors.add('version is required');
    }
    if (author.isEmpty) {
      errors.add('author is required');
    }
    if (entry.isEmpty) {
      errors.add('entry is required');
    }
    if (capabilities.isEmpty) {
      errors.add('capabilities is required');
    }
    return errors;
  }

  bool supportsCapability(String capability) {
    return capabilities.contains(capability);
  }
}

class InstalledPlugin {
  const InstalledPlugin({
    required this.manifest,
    required this.directory,
    required this.state,
    this.enabled = false,
    this.lastError,
  });

  final PluginManifest manifest;
  final String directory;
  final PluginInstallState state;
  final bool enabled;
  final String? lastError;

  String get id => manifest.id;
  String get name => manifest.name;
  String get version => manifest.version;

  InstalledPlugin copyWith({
    PluginManifest? manifest,
    String? directory,
    PluginInstallState? state,
    bool? enabled,
    String? lastError,
  }) {
    return InstalledPlugin(
      manifest: manifest ?? this.manifest,
      directory: directory ?? this.directory,
      state: state ?? this.state,
      enabled: enabled ?? this.enabled,
      lastError: lastError ?? this.lastError,
    );
  }
}
