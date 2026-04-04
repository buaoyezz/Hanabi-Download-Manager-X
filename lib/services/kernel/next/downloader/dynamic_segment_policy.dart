import 'dart:math';

class DynamicSplitSnapshot {
  final int segmentIndex;
  final int remainingBytes;
  final double speedBytesPerSecond;
  final Duration idleFor;
  final Duration sinceLastSplit;

  const DynamicSplitSnapshot({
    required this.segmentIndex,
    required this.remainingBytes,
    required this.speedBytesPerSecond,
    required this.idleFor,
    required this.sinceLastSplit,
  });
}

class DynamicSplitDecision {
  final int segmentIndex;
  final int stealBytes;
  final String reason;
  final double score;

  const DynamicSplitDecision({
    required this.segmentIndex,
    required this.stealBytes,
    required this.reason,
    required this.score,
  });
}

class DynamicSegmentPolicy {
  static const int minSplitBytes = 8 * 1024 * 1024;
  static const int maxPlansPerCheck = 2;
  static const Duration splitCooldown = Duration(seconds: 8);
  static const Duration stallThreshold = Duration(seconds: 4);

  static List<DynamicSplitDecision> plan({
    required List<DynamicSplitSnapshot> snapshots,
    required int maxConcurrent,
    required int totalSegments,
    int maxSegments = 256,
  }) {
    if (snapshots.isEmpty) return const [];

    final active =
        snapshots.where((snapshot) => snapshot.remainingBytes > 0).toList();
    if (active.isEmpty) return const [];

    final freeSlots = max(0, maxConcurrent - active.length);
    final segmentBudget = max(0, maxSegments - totalSegments);
    final maxPlans = min(segmentBudget, min(freeSlots, maxPlansPerCheck));
    if (maxPlans <= 0) return const [];

    final avgRemaining =
        active.fold<int>(0, (sum, snapshot) => sum + snapshot.remainingBytes) /
            active.length;
    final speedSamples = active
        .map((snapshot) => snapshot.speedBytesPerSecond)
        .where((speed) => speed > 0)
        .toList()
      ..sort();
    final medianSpeed =
        speedSamples.isEmpty ? 0.0 : speedSamples[speedSamples.length ~/ 2];
    final singleTailMode = active.length == 1;
    final candidates = <DynamicSplitDecision>[];

    for (final snapshot in active) {
      if (snapshot.remainingBytes < minSplitBytes * 2) continue;
      if (snapshot.sinceLastSplit < splitCooldown) continue;

      final tailRatio =
          avgRemaining <= 0 ? 1.0 : snapshot.remainingBytes / avgRemaining;
      final isStalled = snapshot.idleFor >= stallThreshold;
      final hasSpeedSample = snapshot.speedBytesPerSecond > 0;
      final isSlow = medianSpeed > 0 &&
          hasSpeedSample &&
          snapshot.speedBytesPerSecond < medianSpeed * 0.7;
      final isHeavyTail = tailRatio >= (singleTailMode ? 1.0 : 1.35);

      if (!singleTailMode && !isStalled && !(isSlow && isHeavyTail)) {
        continue;
      }

      final reason = isStalled
          ? 'stall-tail-steal'
          : singleTailMode
              ? 'tail-steal'
              : 'throughput-tail-steal';
      final stealRatio = isStalled
          ? 0.65
          : singleTailMode
              ? 0.60
              : 0.50;
      final stealBytes =
          _computeStealBytes(snapshot.remainingBytes, stealRatio);
      if (stealBytes <= 0) continue;

      var score = tailRatio;
      if (singleTailMode) score += 1.0;
      if (isStalled) score += 2.0;
      if (medianSpeed > 0 && hasSpeedSample) {
        score +=
            (1 - (snapshot.speedBytesPerSecond / medianSpeed)).clamp(0, 1.5);
      }

      candidates.add(
        DynamicSplitDecision(
          segmentIndex: snapshot.segmentIndex,
          stealBytes: stealBytes,
          reason: reason,
          score: score,
        ),
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(maxPlans).toList();
  }

  static int _computeStealBytes(int remainingBytes, double stealRatio) {
    if (remainingBytes < minSplitBytes * 2) return 0;
    final proposed = (remainingBytes * stealRatio).round();
    return proposed.clamp(minSplitBytes, remainingBytes - minSplitBytes);
  }
}
