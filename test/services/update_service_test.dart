import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/update_service.dart';

void main() {
  group('VersionInfo.parse', () {
    test('recognizes numbered alpha versions', () {
      final version = VersionInfo.parse('v1.3.3-alpha.2');

      expect(version.major, 1);
      expect(version.minor, 3);
      expect(version.patch, 3);
      expect(version.channel, VersionChannel.alpha);
      expect(version.preReleaseNumber, 2);
      expect(version.fullVersionString, '1.3.3-alpha.2');
    });

    test('orders numbered prerelease versions within the same channel', () {
      final alpha2 = VersionInfo.parse('1.3.3-alpha.2');
      final alpha3 = VersionInfo.parse('1.3.3-alpha.3');
      final beta1 = VersionInfo.parse('1.3.3-beta.1');
      final release = VersionInfo.parse('1.3.3');

      expect(alpha3.compareTo(alpha2), greaterThan(0));
      expect(beta1.compareTo(alpha3), greaterThan(0));
      expect(release.compareTo(beta1), greaterThan(0));
    });
  });

  group('UpdateInfo.fromJson', () {
    test('keeps numbered alpha tag as alpha update and extracts zip asset', () {
      final update = UpdateInfo.fromJson({
        'tag_name': 'v1.3.3-alpha.2',
        'body': 'Alpha release',
        'published_at': '2026-04-26T00:00:00Z',
        'prerelease': true,
        'assets': [
          {
            'name': 'HanabiDownloadManagerX_1.3.3-alpha.2.zip',
            'browser_download_url':
                'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/v1.3.3-alpha.2/HanabiDownloadManagerX_1.3.3-alpha.2.zip',
          },
        ],
      });

      expect(update.version, '1.3.3-alpha.2');
      expect(update.versionInfo.channel, VersionChannel.alpha);
      expect(update.versionInfo.preReleaseNumber, 2);
      expect(update.downloadUrl,
          endsWith('HanabiDownloadManagerX_1.3.3-alpha.2.zip'));
    });
  });
}
