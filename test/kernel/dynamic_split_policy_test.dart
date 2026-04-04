import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/downloader/dynamic_segment_policy.dart';

void main() {
  group('DynamicSegmentPolicy.plan', () {
    test('splits the final large tail when concurrency slots are free', () {
      final decisions = DynamicSegmentPolicy.plan(
        snapshots: const [
          DynamicSplitSnapshot(
            segmentIndex: 7,
            remainingBytes: 64 * 1024 * 1024,
            speedBytesPerSecond: 2.5 * 1024 * 1024,
            idleFor: Duration.zero,
            sinceLastSplit: Duration(seconds: 30),
          ),
        ],
        maxConcurrent: 4,
        totalSegments: 8,
      );

      expect(decisions, hasLength(1));
      expect(decisions.single.segmentIndex, 7);
      expect(decisions.single.reason, 'tail-steal');
      expect(decisions.single.stealBytes, greaterThan(0));
    });

    test('prefers the slow heavy tail over faster peers', () {
      final decisions = DynamicSegmentPolicy.plan(
        snapshots: const [
          DynamicSplitSnapshot(
            segmentIndex: 0,
            remainingBytes: 48 * 1024 * 1024,
            speedBytesPerSecond: 1.2 * 1024 * 1024,
            idleFor: Duration.zero,
            sinceLastSplit: Duration(seconds: 30),
          ),
          DynamicSplitSnapshot(
            segmentIndex: 1,
            remainingBytes: 18 * 1024 * 1024,
            speedBytesPerSecond: 4.8 * 1024 * 1024,
            idleFor: Duration.zero,
            sinceLastSplit: Duration(seconds: 30),
          ),
          DynamicSplitSnapshot(
            segmentIndex: 2,
            remainingBytes: 14 * 1024 * 1024,
            speedBytesPerSecond: 4.2 * 1024 * 1024,
            idleFor: Duration.zero,
            sinceLastSplit: Duration(seconds: 30),
          ),
        ],
        maxConcurrent: 4,
        totalSegments: 3,
      );

      expect(decisions, hasLength(1));
      expect(decisions.single.segmentIndex, 0);
      expect(decisions.single.reason, 'throughput-tail-steal');
    });

    test('allows stalled segments to be split even without speed samples', () {
      final decisions = DynamicSegmentPolicy.plan(
        snapshots: const [
          DynamicSplitSnapshot(
            segmentIndex: 3,
            remainingBytes: 40 * 1024 * 1024,
            speedBytesPerSecond: 0,
            idleFor: Duration(seconds: 6),
            sinceLastSplit: Duration(seconds: 30),
          ),
          DynamicSplitSnapshot(
            segmentIndex: 4,
            remainingBytes: 10 * 1024 * 1024,
            speedBytesPerSecond: 3 * 1024 * 1024,
            idleFor: Duration.zero,
            sinceLastSplit: Duration(seconds: 30),
          ),
        ],
        maxConcurrent: 3,
        totalSegments: 5,
      );

      expect(decisions, hasLength(1));
      expect(decisions.single.segmentIndex, 3);
      expect(decisions.single.reason, 'stall-tail-steal');
    });

    test('does not split when there are no free concurrency slots', () {
      final decisions = DynamicSegmentPolicy.plan(
        snapshots: const [
          DynamicSplitSnapshot(
            segmentIndex: 0,
            remainingBytes: 48 * 1024 * 1024,
            speedBytesPerSecond: 1.0 * 1024 * 1024,
            idleFor: Duration.zero,
            sinceLastSplit: Duration(seconds: 30),
          ),
          DynamicSplitSnapshot(
            segmentIndex: 1,
            remainingBytes: 44 * 1024 * 1024,
            speedBytesPerSecond: 0.8 * 1024 * 1024,
            idleFor: Duration.zero,
            sinceLastSplit: Duration(seconds: 30),
          ),
        ],
        maxConcurrent: 2,
        totalSegments: 2,
      );

      expect(decisions, isEmpty);
    });
  });
}
