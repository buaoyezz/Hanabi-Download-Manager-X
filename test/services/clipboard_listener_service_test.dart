import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/clipboard_listener_service.dart';

void main() {
  group('ClipboardDownloadUrlHeuristics.extractUrl', () {
    test('accepts a standalone direct file URL', () {
      expect(
        ClipboardDownloadUrlHeuristics.extractUrl(
          'https://example.com/files/archive.zip',
        ),
        'https://example.com/files/archive.zip',
      );
    });

    test('accepts a wrapped direct URL', () {
      expect(
        ClipboardDownloadUrlHeuristics.extractUrl(
          '<https://example.com/files/archive.zip>',
        ),
        'https://example.com/files/archive.zip',
      );
    });

    test('rejects mixed prose around a URL', () {
      expect(
        ClipboardDownloadUrlHeuristics.extractUrl(
          '快看这个链接 https://example.com/files/archive.zip',
        ),
        isNull,
      );
    });

    test('rejects multiple URLs in the same clipboard payload', () {
      expect(
        ClipboardDownloadUrlHeuristics.extractUrl(
          'https://example.com/a.zip https://example.com/b.zip',
        ),
        isNull,
      );
    });
  });

  group('ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl', () {
    test('accepts GitHub releases direct jar URLs', () {
      const url =
          'https://github.com/KonekokoHouse/Epsilon-Rewrite/releases/download/latest/epsilon_rewrite-5.0.0.jar';

      expect(ClipboardDownloadUrlHeuristics.extractUrl(url), url);
      expect(
        ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(url),
        isTrue,
      );
    });

    test('accepts GitHub release asset signed URLs', () {
      const url =
          'https://release-assets.githubusercontent.com/github-production-release-asset/1163090993/589e6a51-6ff8-40de-acfa-4e62e341d839?sp=r&sv=2018-11-09&sr=b&spr=https&se=2026-04-03T13%3A13%3A57Z&rscd=attachment%3B+filename%3Depsilon_rewrite-5.0.0.jar&rsct=application%2Foctet-stream&skoid=96c2d410-5711-43a1-aedd-ab1947aa7ab0&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skt=2026-04-03T12%3A13%3A18Z&ske=2026-04-03T13%3A13%3A57Z&sks=b&skv=2018-11-09&sig=TcDSzdV32LAVq4T%2FTh3rFQgcEtXbhjoXXAepJ9dMBdA%3D&jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmVsZWFzZS1hc3NldHMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIiwia2V5Ijoia2V5MSIsImV4cCI6MTc3NTIyMTYzMiwibmJmIjoxNzc1MjE5ODMyLCJwYXRoIjoicmVsZWFzZWFzc2V0cHJvZHVjdGlvbi5ibG9iLmNvcmUud2luZG93cy5uZXQifQ.2GI-o4QeVdwHj8qal95lB6nvujTBqH43MqnaFCJ2ez0&response-content-disposition=attachment%3B%20filename%3Depsilon_rewrite-5.0.0.jar&response-content-type=application%2Foctet-stream';

      expect(ClipboardDownloadUrlHeuristics.extractUrl(url), url);
      expect(
        ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(url),
        isTrue,
      );
    });

    test('accepts unknown query keys carrying attachment filename metadata',
        () {
      expect(
        ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(
          'https://example.com/token?rscd=attachment%3B%20filename%3Darchive.zip',
        ),
        isTrue,
      );
    });

    test('accepts unknown query keys carrying download mime metadata', () {
      expect(
        ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(
          'https://example.com/token?rsct=application%2Foctet-stream',
        ),
        isTrue,
      );
    });

    test('accepts filename query with a known extension', () {
      expect(
        ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(
          'https://example.com/get?filename=archive.zip',
        ),
        isTrue,
      );
    });

    test('rejects generic media pages', () {
      expect(
        ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(
          'https://example.com/video/12345',
        ),
        isFalse,
      );
    });

    test('rejects generic file id queries without strong download hints', () {
      expect(
        ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(
          'https://example.com/open?file=12345',
        ),
        isFalse,
      );
    });
  });
}
