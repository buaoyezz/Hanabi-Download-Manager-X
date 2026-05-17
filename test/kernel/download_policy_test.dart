import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';

void main() {
  group('NsfxParallelDownloadPolicy.parallelBlockReason', () {
    test('allows fresh HTTP download without validator', () {
      final result = NsfxParallelDownloadPolicy.parallelBlockReason(
        url: 'https://example.com/file.bin',
        hasStrongValidator: false,
        hasPartialProgress: false,
        resumeDataOrigin: NsfxResumeDataOrigin.runtime,
        resumeSafetyLevel: NsfxResumeSafetyLevel.unknown,
        supportsRange: true,
      );

      expect(result, isNull);
    });

    test('allows same-session multipart resume without validator', () {
      final result = NsfxParallelDownloadPolicy.parallelBlockReason(
        url: 'https://example.com/file.bin',
        hasStrongValidator: false,
        hasPartialProgress: true,
        resumeDataOrigin: NsfxResumeDataOrigin.runtime,
        resumeSafetyLevel: NsfxResumeSafetyLevel.sessionOnly,
        supportsRange: true,
        storedTotalSize: 1024,
        observedTotalSize: 1024,
      );

      expect(result, isNull);
    });

    test('blocks persisted multipart resume without validator when unverified',
        () {
      final result = NsfxParallelDownloadPolicy.parallelBlockReason(
        url: 'https://example.com/file.bin',
        hasStrongValidator: false,
        hasPartialProgress: true,
        resumeDataOrigin: NsfxResumeDataOrigin.persisted,
        resumeSafetyLevel: NsfxResumeSafetyLevel.unknown,
        supportsRange: true,
        storedTotalSize: 1024,
        observedTotalSize: 1024,
      );

      expect(
        result,
        'cannot safely resume persisted multi-part download without '
        'validator or verified stable range behavior',
      );
    });

    test('blocks persisted multipart resume with only weak validator state',
        () {
      final result = NsfxParallelDownloadPolicy.parallelBlockReason(
        url: 'https://example.com/file.bin',
        hasStrongValidator: false,
        hasPartialProgress: true,
        resumeDataOrigin: NsfxResumeDataOrigin.persisted,
        resumeSafetyLevel: NsfxResumeSafetyLevel.strictValidator,
        supportsRange: true,
        storedTotalSize: 1024,
        observedTotalSize: 1024,
      );

      expect(
        result,
        'cannot safely resume persisted multi-part download without '
        'validator or verified stable range behavior',
      );
    });

    test('allows verified persisted resume without validator when size matches',
        () {
      final result = NsfxParallelDownloadPolicy.parallelBlockReason(
        url: 'https://example.com/file.bin',
        hasStrongValidator: false,
        hasPartialProgress: true,
        resumeDataOrigin: NsfxResumeDataOrigin.persisted,
        resumeSafetyLevel: NsfxResumeSafetyLevel.verifiedNoValidator,
        supportsRange: true,
        storedTotalSize: 1024,
        observedTotalSize: 1024,
      );

      expect(result, isNull);
    });

    test('blocks verified persisted resume when remote size changed', () {
      final result = NsfxParallelDownloadPolicy.parallelBlockReason(
        url: 'https://example.com/file.bin',
        hasStrongValidator: false,
        hasPartialProgress: true,
        resumeDataOrigin: NsfxResumeDataOrigin.persisted,
        resumeSafetyLevel: NsfxResumeSafetyLevel.verifiedNoValidator,
        supportsRange: true,
        storedTotalSize: 1024,
        observedTotalSize: 2048,
      );

      expect(result, 'stored file size no longer matches remote resource');
    });

    test('blocks non-http schemes', () {
      final result = NsfxParallelDownloadPolicy.parallelBlockReason(
        url: 'ftp://example.com/file.bin',
        hasStrongValidator: true,
        hasPartialProgress: false,
        resumeDataOrigin: NsfxResumeDataOrigin.runtime,
        resumeSafetyLevel: NsfxResumeSafetyLevel.strictValidator,
        supportsRange: true,
      );

      expect(result, 'URL scheme is not HTTP(S)');
    });
  });

  group('NsfxRetryPolicy', () {
    test('uses bounded deterministic backoff', () {
      expect(NsfxRetryPolicy.segmentRetryDelayMs(1), 637);
      expect(NsfxRetryPolicy.segmentRetryDelayMs(2), 1024);
      expect(NsfxRetryPolicy.segmentRetryDelayMs(3), 2161);
      expect(NsfxRetryPolicy.segmentRetryDelayMs(20), 15000);
    });

    test('config defaults use retry policy defaults', () {
      expect(NsfxConfig().maxRetries, NsfxRetryPolicy.defaultMaxRetries);
    });
  });

  group('NsfxStartupProbePolicy', () {
    test('uses fast start for fresh multi-thread downloads', () {
      final result = NsfxStartupProbePolicy.shouldUseFastStart(
        hasPartialProgress: false,
        configuredThreads: 8,
      );

      expect(result, isTrue);
    });

    test('does not use fast start when partial progress exists', () {
      final result = NsfxStartupProbePolicy.shouldUseFastStart(
        hasPartialProgress: true,
        configuredThreads: 8,
      );

      expect(result, isFalse);
    });

    test('does not use fast start for single-thread configuration', () {
      final result = NsfxStartupProbePolicy.shouldUseFastStart(
        hasPartialProgress: false,
        configuredThreads: 1,
      );

      expect(result, isFalse);
    });
  });
}
