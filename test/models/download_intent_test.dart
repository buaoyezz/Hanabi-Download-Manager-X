import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/models/download_intent.dart';

void main() {
  group('DownloadIntent.parse', () {
    test('recognizes normalized http downloads', () {
      final intent = DownloadIntent.parse(
        'HTTPS://Example.COM/files/demo%20file.zip#fragment',
      );

      expect(intent.type, DownloadIntentType.http);
      expect(intent.isRecognized, isTrue);
      expect(intent.isCurrentlySupported, isTrue);
      expect(
        intent.normalizedValue,
        'https://example.com/files/demo%20file.zip',
      );
      expect(intent.suggestedFileName(), 'demo file.zip');
    });

    test('recognizes magnet links and extracts display name', () {
      final intent = DownloadIntent.parse(
        'magnet:?xt=urn:btih:ABCDEF123456&dn=Ubuntu%2024.04.iso',
      );

      expect(intent.type, DownloadIntentType.magnet);
      expect(intent.isRecognized, isTrue);
      expect(intent.isCurrentlySupported, isFalse);
      expect(
        intent.normalizedValue,
        'magnet:?dn=Ubuntu+24.04.iso&xt=urn%3Abtih%3AABCDEF123456',
      );
      expect(intent.suggestedFileName(), 'Ubuntu 24.04.iso');
    });

    test('recognizes local torrent files', () {
      final intent = DownloadIntent.parse(r'C:\Downloads\Ubuntu.torrent');

      expect(intent.type, DownloadIntentType.torrentFile);
      expect(intent.isRecognized, isTrue);
      expect(intent.isCurrentlySupported, isFalse);
      expect(intent.normalizedValue, r'C:\Downloads\Ubuntu.torrent');
      expect(intent.suggestedFileName(), 'Ubuntu.torrent');
    });

    test('recognizes resolver intents with plugin hints', () {
      final intent = DownloadIntent.parse(
        'hanabi-resolver://example-parser/resolve?name=Video&plugin=video-parser',
      );

      expect(intent.type, DownloadIntentType.resolver);
      expect(intent.pluginHint, 'video-parser');
      expect(intent.suggestedFileName(), 'Video');
    });

    test('serializes intent metadata for plugin calls', () {
      final intent = DownloadIntent.parse(
        'magnet:?dn=Demo&xt=urn:btih:ABC',
        sourceMeta: {'source': 'test'},
        pluginHint: 'bt',
      );
      final restored = DownloadIntent.fromJson(intent.toJson());

      expect(restored.type, DownloadIntentType.magnet);
      expect(restored.pluginHint, 'bt');
      expect(restored.sourceMeta['source'], 'test');
      expect(restored.normalizedValue, intent.normalizedValue);
    });

    test('marks unsupported schemes as unsupported', () {
      final intent = DownloadIntent.parse('ftp://example.com/file.zip');

      expect(intent.type, DownloadIntentType.unsupported);
      expect(intent.isRecognized, isFalse);
      expect(intent.isCurrentlySupported, isFalse);
      expect(intent.suggestedFileName(), isNull);
    });
  });
}
