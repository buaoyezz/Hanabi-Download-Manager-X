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

    test('normalizes full-width punctuation in numbered alpha versions', () {
      final version = VersionInfo.parse('v1.3.3-alpha。1');

      expect(version.channel, VersionChannel.alpha);
      expect(version.preReleaseNumber, 1);
      expect(version.fullVersionString, '1.3.3-alpha.1');
    });

    test('orders numbered prerelease versions within the same channel', () {
      final alpha2 = VersionInfo.parse('1.3.3-alpha.2');
      final alpha3 = VersionInfo.parse('1.3.3-alpha.3');
      final release = VersionInfo.parse('1.3.3');

      expect(alpha3.compareTo(alpha2), greaterThan(0));
      expect(release.compareTo(alpha3), greaterThan(0));
    });

    test('marks unsupported prerelease channels as not supported', () {
      final version = VersionInfo.parse('1.3.3-preview.1');

      expect(version.channel, VersionChannel.alpha);
      expect(version.preReleaseNumber, 1);
      expect(version.isSupportedChannel, isFalse);
      expect(version.fullVersionString, '1.3.3-preview.1');
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

    test('prefers Hanabi app package over browser extension zips', () {
      final update = UpdateInfo.fromJson({
        'tag_name': 'V1.3.2',
        'body': 'Release',
        'published_at': '2026-04-26T00:00:00Z',
        'prerelease': false,
        'assets': [
          {
            'name': 'chrome_extension.zip',
            'size': 145728,
            'browser_download_url':
                'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.3.2/chrome_extension.zip',
          },
          {
            'name': 'firefox_extension.zip',
            'size': 145850,
            'browser_download_url':
                'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.3.2/firefox_extension.zip',
          },
          {
            'name': 'HanabiDownloadManagerX_Release_Latest.zip',
            'size': 58539561,
            'browser_download_url':
                'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.3.2/HanabiDownloadManagerX_Release_Latest.zip',
          },
        ],
      });

      expect(
        update.downloadUrl,
        'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.3.2/HanabiDownloadManagerX_Release_Latest.zip',
      );
    });

    test('does not treat unlabelled prereleases as release channel', () {
      final update = UpdateInfo.fromJson({
        'tag_name': 'v1.3.3',
        'body': 'Preview release',
        'published_at': '2026-04-26T00:00:00Z',
        'prerelease': true,
        'assets': [
          {
            'name': 'HanabiDownloadManagerX_1.3.3.zip',
            'browser_download_url':
                'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/v1.3.3/HanabiDownloadManagerX_1.3.3.zip',
          },
        ],
      });

      expect(update.versionInfo.channel, VersionChannel.alpha);
      expect(update.versionInfo.isSupportedChannel, isFalse);
    });
  });

  group('UpdateService prerelease filtering', () {
    test('does not treat alpha.2 as the current alpha.1 release changelog', () {
      final service = UpdateService();
      final alpha2 = _release('v1.3.3-alpha.2');

      service.debugSetReleasesForTest([alpha2]);

      expect(service.debugFindReleaseByVersion('1.3.3-alpha.1'), isNull);
      expect(service.debugFindReleaseByVersion('1.3.3-alpha.2'), alpha2);
    });

    test('alpha channel builds receive newer alpha releases by default', () {
      final service = UpdateService()
        ..debugSetCurrentVersionForTest('1.3.3-alpha.1')
        ..debugSetReleasesForTest([_release('v1.3.3-alpha.2')]);

      service.debugFilterAvailableUpdateForTest();

      expect(service.availableUpdate, isNotNull);
      expect(service.availableUpdate!.version, '1.3.3-alpha.2');
    });
  });
}

UpdateInfo _release(String tag) {
  return UpdateInfo.fromJson({
    'tag_name': tag,
    'body': 'Alpha release',
    'published_at': '2026-04-26T00:00:00Z',
    'prerelease': tag.contains('-'),
    'assets': [
      {
        'name':
            'HanabiDownloadManagerX_${tag.replaceFirst(RegExp(r'^[vV]'), '')}.zip',
        'browser_download_url':
            'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/$tag/HanabiDownloadManagerX.zip',
      },
    ],
  });
}
