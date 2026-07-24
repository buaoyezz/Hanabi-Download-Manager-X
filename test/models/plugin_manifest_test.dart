import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/models/plugin_manifest.dart';

void main() {
  group('PluginManifest', () {
    test('keeps legacy manifests compatible with API v1 defaults', () {
      final manifest = PluginManifest.fromJson({
        'id': 'hanabi.example.legacy',
        'name': 'Legacy plugin',
        'version': '0.1.0',
        'author': 'Hanabi',
        'entry': 'main.py',
        'capabilities': ['download:custom'],
      });

      expect(manifest.manifestVersion, PluginManifest.currentManifestVersion);
      expect(manifest.apiVersion, PluginManifest.currentApiVersion);
      expect(manifest.runtime.isDefault, isTrue);
      expect(manifest.validate(), isEmpty);
    });

    test('parses and serializes runtime and routing extensions', () {
      final manifest = PluginManifest.fromJson({
        'manifestVersion': 1,
        'apiVersion': '1.0',
        'id': 'hanabi.example.deno',
        'name': 'Deno plugin',
        'version': '1.2.3',
        'author': 'Hanabi',
        'entry': 'src/main.ts',
        'capabilities': ['download:custom:demo'],
        'intentSchemes': ['HANABI+DEMO'],
        'priority': 25,
        'maxAppVersion': '2.0.0',
        'runtime': {
          'executable': 'deno',
          'arguments': ['run', '--allow-net', '{entry}'],
          'environment': {'PLUGIN_MODE': 'production'},
          'workingDirectory': 'src',
          'timeoutSeconds': 45,
        },
      });

      expect(manifest.intentSchemes, ['hanabi+demo']);
      expect(manifest.handlesIntentScheme('HANABI+DEMO'), isTrue);
      expect(manifest.runtime.executable, 'deno');
      expect(manifest.runtime.arguments.last, '{entry}');
      expect(manifest.validate(), isEmpty);

      final serialized = manifest.toJson();
      expect(serialized['apiVersion'], '1.0');
      expect(serialized['intentSchemes'], ['hanabi+demo']);
      expect((serialized['runtime'] as Map)['timeoutSeconds'], 45);
    });

    test('rejects unsafe paths, reserved environment and malformed UI', () {
      final manifest = PluginManifest.fromJson({
        'manifestVersion': 2,
        'apiVersion': '2.0',
        'id': 'hanabi.example.invalid',
        'name': 'Invalid plugin',
        'version': '1.0.0',
        'author': 'Hanabi',
        'entry': '../outside.py',
        'icon': 'C:\\outside.png',
        'capabilities': ['download:custom', 'download:custom'],
        'permissions': ['network', 'registry'],
        'minAppVersion': 'latest',
        'intentSchemes': ['https'],
        'priority': 5000,
        'runtime': {
          'executable': '../outside.exe',
          'environment': {
            'HANABI_PLUGIN_ID': 'spoofed',
            'NESTED': {'value': true},
          },
          'timeoutSeconds': 0,
        },
        'ui_extensions': {
          'settings': [
            {'type': 'button', 'id': 'run', 'label': 'Run'},
          ],
        },
      });

      final errors = manifest.validate().join('\n');
      expect(errors, contains('manifestVersion 2 is not supported'));
      expect(errors, contains('apiVersion 2.0 is not supported'));
      expect(errors, contains('entry must be a relative path'));
      expect(errors, contains('icon must be a relative path'));
      expect(errors, contains('capabilities must not contain duplicates'));
      expect(errors, contains('unknown permissions: registry'));
      expect(errors, contains('minAppVersion must be a version number'));
      expect(errors, contains('invalid intent scheme'));
      expect(errors, contains('priority must be between'));
      expect(errors, contains('reserved HANABI_'));
      expect(errors, contains('runtime.executable must stay inside'));
      expect(
          errors, contains('runtime.environment.NESTED must be a JSON scalar'));
      expect(errors, contains('requires an action'));
    });
  });
}
