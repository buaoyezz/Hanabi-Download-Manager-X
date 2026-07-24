import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/clipboard_listener_service.dart';

void main() {
  const link = 'ed2k://|file|Hanabi.zip|123456|'
      'ABCDEF0123456789ABCDEF0123456789|/';

  test('clipboard heuristics recognize a standalone ED2K file link', () {
    expect(ClipboardDownloadUrlHeuristics.extractUrl(link), link);
    expect(ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(link), isTrue);
  });

  test('clipboard signature normalizes ED2K links', () {
    expect(
      ClipboardDownloadUrlHeuristics.signatureFor(link.toLowerCase()),
      link.toLowerCase(),
    );
  });
}
