import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/models/download_intent.dart';

void main() {
  group('DownloadIntent ED2K', () {
    test('parses and normalizes an ED2K file link', () {
      final intent = DownloadIntent.parse(
        'ED2K://|FILE|Hanabi%20Archive.zip|123456|'
        'abcdef0123456789abcdef0123456789|/',
      );

      expect(intent.type, DownloadIntentType.ed2k);
      expect(intent.isEd2k, isTrue);
      expect(
        intent.normalizedValue,
        'ed2k://|file|Hanabi%20Archive.zip|123456|'
        'ABCDEF0123456789ABCDEF0123456789|/',
      );
      expect(intent.suggestedFileName(), 'Hanabi Archive.zip');
      expect(intent.toJson()['type'], 'ed2k');
    });

    test('supports the ED2K wire aliases', () {
      expect(
        DownloadIntentTypeName.fromWireName('ed2k'),
        DownloadIntentType.ed2k,
      );
      expect(
        DownloadIntentTypeName.fromWireName('edonkey'),
        DownloadIntentType.ed2k,
      );
    });

    test('does not treat server links as download tasks', () {
      final intent = DownloadIntent.parse(
        'ed2k://|server|127.0.0.1|4661|/',
      );

      expect(intent.type, DownloadIntentType.unsupported);
    });

    test('rejects invalid file links before plugin routing', () {
      const hash = 'ABCDEF0123456789ABCDEF0123456789';

      expect(
        DownloadIntent.parse('ed2k://|file|empty.bin|0|$hash|/').type,
        DownloadIntentType.unsupported,
      );
      expect(
        DownloadIntent.parse('ed2k://|file|bad\nname.bin|10|$hash|/').type,
        DownloadIntentType.unsupported,
      );
    });
  });
}
