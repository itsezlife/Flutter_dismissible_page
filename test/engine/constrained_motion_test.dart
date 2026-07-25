import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Constrained Motion', () {
    test('locks cross-axis directions to the dominant axis', () {
      final lock = DismissDirections.all.resolveAxisLock(
        delta: const Offset(8, 3),
        textDirection: TextDirection.ltr,
      );

      expect(lock?.axis, Axis.horizontal);
      expect(lock?.side, DismissDirections.startToEnd);
    });

    test('chooses the only permitted axis before comparing components', () {
      final lock = DismissDirections.vertical.resolveAxisLock(
        delta: const Offset(8, 3),
        textDirection: TextDirection.ltr,
      );

      expect(lock?.axis, Axis.vertical);
      expect(lock?.side, DismissDirections.down);
    });

    test('resolves reading-relative sides in LTR and RTL', () {
      final ltrLock = DismissDirections.horizontal.resolveAxisLock(
        delta: const Offset(8, 0),
        textDirection: TextDirection.ltr,
      );
      final rtlLock = DismissDirections.horizontal.resolveAxisLock(
        delta: const Offset(8, 0),
        textDirection: TextDirection.rtl,
      );

      expect(ltrLock?.side, DismissDirections.startToEnd);
      expect(rtlLock?.side, DismissDirections.endToStart);
    });

    test('does not lock when the resolved atomic side is disallowed', () {
      final lock = DismissDirections.up.resolveAxisLock(
        delta: const Offset(0, 8),
        textDirection: TextDirection.ltr,
      );

      expect(lock, isNull);
    });

    test('keeps the locked axis and atomic side for later deltas', () {
      final lock = DismissDirections.all.resolveAxisLock(
        delta: const Offset(8, 3),
        textDirection: TextDirection.ltr,
      );

      expect(lock?.constrain(const Offset(2, 9)), const Offset(2, 0));
      expect(lock?.constrain(const Offset(-2, 0)), Offset.zero);
    });

    test('uses the threshold configured for each locked atomic side', () {
      const thresholds = DismissThresholds(
        up: 0.2,
        down: 0.3,
        startToEnd: 0.4,
        endToStart: 0.5,
      );
      const cases = [
        (Offset(0, -8), 0.2),
        (Offset(0, 8), 0.3),
        (Offset(8, 0), 0.4),
        (Offset(-8, 0), 0.5),
      ];

      for (final (delta, threshold) in cases) {
        final lock = DismissDirections.all.resolveAxisLock(
          delta: delta,
          textDirection: TextDirection.ltr,
        );

        expect(
          lock?.decide(progress: threshold, thresholds: thresholds),
          DismissDecision.dismiss,
        );
        expect(
          lock?.decide(progress: threshold - 0.01, thresholds: thresholds),
          DismissDecision.reverse,
        );
      }
    });
  });
}
