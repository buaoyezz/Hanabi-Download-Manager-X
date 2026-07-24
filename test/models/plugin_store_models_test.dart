import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/models/plugin_store_models.dart';

void main() {
  group('PluginStoreEntry', () {
    test('preserves API, compatibility and security metadata', () {
      final entry = PluginStoreEntry.fromJson({
        'manifestVersion': 1,
        'apiVersion': '1.0',
        'id': 'hanabi.example.demo',
        'name': 'Demo',
        'version': '1.2.0',
        'description': 'Demo plugin',
        'author': 'Hanabi',
        'downloadUrl': 'https://example.com/demo.zip',
        'hash': 'sha256:abc',
        'minAppVersion': '1.5.0',
        'maxAppVersion': '1.9.0',
        'capabilities': ['download:custom:demo'],
        'intentSchemes': ['hanabi+demo'],
        'permissions': ['network'],
        'reviewStatus': 'published',
      });

      expect(entry.isInstallable, isTrue);
      expect(entry.maxAppVersion, '1.9.0');
      expect(entry.intentSchemes, ['hanabi+demo']);
      expect(entry.permissions, ['network']);
      expect(entry.toJson()['apiVersion'], '1.0');
    });

    test('does not offer unsupported protocol majors for installation', () {
      final entry = PluginStoreEntry.fromJson({
        'manifestVersion': '2',
        'apiVersion': '2.0',
        'id': 'hanabi.example.future',
        'name': 'Future',
        'version': '2.0.0',
        'description': '',
        'author': 'Hanabi',
        'downloadUrl': 'https://example.com/future.zip',
        'hash': '',
        'reviewStatus': 'published',
      });

      expect(entry.manifestVersion, 2);
      expect(entry.isInstallable, isFalse);
    });
  });
}
