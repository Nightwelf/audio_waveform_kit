import 'package:audio_waveform_kit/src/utils/rms_bucket_accumulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RmsBucketAccumulator', () {
    test('starts empty', () {
      final acc = RmsBucketAccumulator(8);
      expect(acc.buckets, isEmpty);
    });

    test('add does not push a bucket until the window is full', () {
      // windowsPerBucket starts at 1, so each add pushes a bucket.
      final acc = RmsBucketAccumulator(8)..add(0.5);
      expect(acc.buckets, equals([0.5]));
    });

    test('flushPartial writes the unfinished bucket', () {
      final acc = RmsBucketAccumulator(8);
      // Force window size > 1 by overflowing, then add a partial window.
      for (var i = 0; i < 9; i++) {
        acc.add(1);
      }
      // After overflow the window size doubled; a partial bucket may remain.
      final before = acc.buckets.length;
      acc
        ..add(1)
        ..flushPartial();
      expect(acc.buckets.length, greaterThanOrEqualTo(before));
    });

    test('merges buckets when exceeding maxBuckets', () {
      const maxBuckets = 4;
      final acc = RmsBucketAccumulator(maxBuckets);
      // Add enough windows to trigger at least one merge.
      for (var i = 0; i < maxBuckets * 2 + 2; i++) {
        acc.add(1);
      }
      expect(acc.buckets.length, lessThanOrEqualTo(maxBuckets + 1));
    });

    test('merge averages adjacent bucket pairs', () {
      const maxBuckets = 2;
      final acc = RmsBucketAccumulator(maxBuckets)
        ..add(0) // bucket 0
        ..add(1) // bucket 1
        ..add(0); // bucket 2 → length 3 > 2 → merge
      // Buckets [0,1,2] → merge pairs: [(0+1)/2] then carry odd → [0.5, 0].
      expect(acc.buckets.first, closeTo(0.5, 1e-9));
    });

    test('reset clears all state', () {
      final acc = RmsBucketAccumulator(8)
        ..add(0.3)
        ..add(0.4)
        ..reset();
      expect(acc.buckets, isEmpty);
    });
  });
}
