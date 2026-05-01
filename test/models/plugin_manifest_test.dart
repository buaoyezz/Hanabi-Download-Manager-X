import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/models/plugin_manifest.dart';
import 'package:hanabi_download_managerx/models/plugin_ui_schema.dart';

void main() {
  group('PluginManifest', () {
    test('parses UI extension controls without requiring exact map generics',
        () {
      final manifest = PluginManifest.fromJsonString(r'''
{
  "id": "hanabi.test.ui",
  "name": "UI Test",
  "version": "1.0.0",
  "author": "Hanabi",
  "entry": "main.py",
  "capabilities": ["settings", "sidebar"],
  "themeOverrides": {"accent": "#60cdff"},
  "uiExtensions": {
    "settings": {
      "controls": [
        {
          "type": "dropdown",
          "id": "mode",
          "label": "Mode",
          "default": "fast",
          "options": ["fast", {"label": "Safe", "value": "safe"}]
        },
        "bad control",
        {"type": "unknown_type", "id": "ignored", "label": "Ignored"}
      ]
    }
  }
}
''');

      final settings = manifest.uiExtensions?['settings'];

      expect(manifest.themeOverrides?['accent'], '#60cdff');
      expect(settings, hasLength(1));
      expect(settings!.single.type, PluginUIElementType.dropdown);
      expect(settings.single.options, hasLength(2));
      expect(settings.single.options!.first.label, 'fast');
      expect(settings.single.options!.last.value, 'safe');
    });

    test('keeps a malformed manifest isolated as validation errors', () {
      final manifest = PluginManifest.fromJsonString(r'''
{
  "id": "bad",
  "name": "",
  "version": "",
  "author": "",
  "entry": "",
  "capabilities": []
}
''');

      expect(manifest.validate(), isNotEmpty);
    });

    test('does not fail plugin loading for malformed UI controls', () {
      final manifest = PluginManifest.fromJsonString(r'''
{
  "id": "hanabi.test.bad_ui",
  "name": "Bad UI Test",
  "version": "1.0.0",
  "author": "Hanabi",
  "entry": "main.py",
  "capabilities": ["settings"],
  "ui_extensions": {
    "settings": [
      {
        "type": "dropdown",
        "id": "mode",
        "label": "Mode",
        "options": {"fast": "Fast"}
      },
      {
        "type": "slider",
        "id": "level",
        "label": "Level",
        "min": "bad",
        "max": 5
      }
    ]
  }
}
''');

      final settings = manifest.uiExtensions?['settings'];

      expect(settings, hasLength(2));
      expect(settings!.first.type, PluginUIElementType.dropdown);
      expect(settings.first.options, isNull);
      expect(settings.last.type, PluginUIElementType.slider);
      expect(manifest.validate(), isEmpty);
    });

    test('parses sidebar placement from object-style sidebar extension', () {
      final manifest = PluginManifest.fromJsonString(r'''
{
  "id": "hanabi.test.sidebar_top",
  "name": "Sidebar Top Test",
  "version": "1.0.0",
  "author": "Hanabi",
  "entry": "main.py",
  "capabilities": ["sidebar"],
  "ui_extensions": {
    "sidebar": {
      "placement": "top",
      "controls": [
        {
          "type": "text",
          "id": "overview",
          "label": "Overview"
        }
      ]
    }
  }
}
''');

      expect(manifest.sidebarPlacement, PluginSidebarPlacement.top);
      expect(manifest.uiExtensions?['sidebar'], hasLength(1));
    });

    test('defaults sidebar placement to bottom for legacy sidebar arrays', () {
      final manifest = PluginManifest.fromJsonString(r'''
{
  "id": "hanabi.test.sidebar_bottom",
  "name": "Sidebar Bottom Test",
  "version": "1.0.0",
  "author": "Hanabi",
  "entry": "main.py",
  "capabilities": ["sidebar"],
  "ui_extensions": {
    "sidebar": [
      {
        "type": "text",
        "id": "overview",
        "label": "Overview"
      }
    ]
  }
}
''');

      expect(manifest.sidebarPlacement, PluginSidebarPlacement.bottom);
      expect(manifest.uiExtensions?['sidebar'], hasLength(1));
    });
  });
}
