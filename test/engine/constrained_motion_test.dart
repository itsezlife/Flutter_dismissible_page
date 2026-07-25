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

    test('projects later deltas onto the locked axis', () {
      final lock = DismissDirections.all.resolveAxisLock(
        delta: const Offset(8, 3),
        textDirection: TextDirection.ltr,
      );

      expect(
        lock?.constrain(
          const Offset(2, 9),
          currentExtent: 8,
          directions: DismissDirections.all,
        ),
        const Offset(2, 0),
      );
    });

    test('allows reverse toward origin on the locked axis', () {
      final lock = DismissDirections.down.resolveAxisLock(
        delta: const Offset(0, 8),
        textDirection: TextDirection.ltr,
      );

      expect(
        lock?.constrain(
          const Offset(0, -3),
          currentExtent: 8,
          directions: DismissDirections.down,
        ),
        const Offset(0, -3),
      );
    });

    test('crosses origin into the other allowed side on a bidirectional axis',
        () {
      final lock = DismissDirections.vertical.resolveAxisLock(
        delta: const Offset(0, 8),
        textDirection: TextDirection.ltr,
      );

      expect(
        lock?.constrain(
          const Offset(0, -12),
          currentExtent: 8,
          directions: DismissDirections.vertical,
        ),
        const Offset(0, -12),
      );
      expect(lock?.sideFor(-4), DismissDirections.up);
    });

    test('clamps at origin when only a single side is permitted', () {
      final lock = DismissDirections.down.resolveAxisLock(
        delta: const Offset(0, 8),
        textDirection: TextDirection.ltr,
      );

      expect(
        lock?.constrain(
          const Offset(0, -12),
          currentExtent: 8,
          directions: DismissDirections.down,
        ),
        const Offset(0, -8),
      );
      expect(
        lock?.constrain(
          const Offset(0, -1),
          currentExtent: 0,
          directions: DismissDirections.down,
        ),
        Offset.zero,
      );
    });

    test('dismiss-vs-reverse uses the threshold of the side matching extent',
        () {
      const thresholds = DismissThresholds(up: 0.2, down: 0.5);
      final lock = DismissDirections.vertical.resolveAxisLock(
        delta: const Offset(0, 8),
        textDirection: TextDirection.ltr,
      );

      // Still on the initially locked down side.
      expect(
        lock?.decide(progress: 0.4, extent: 10, thresholds: thresholds),
        DismissDecision.reverse,
      );
      // After crossing origin, the up threshold (0.2) applies.
      expect(
        lock?.decide(progress: 0.4, extent: -10, thresholds: thresholds),
        DismissDecision.dismiss,
      );
    });

    test('RTL reverse and origin crossing stay reading-relative', () {
      final lock = DismissDirections.horizontal.resolveAxisLock(
        delta: const Offset(-8, 0),
        textDirection: TextDirection.rtl,
      );

      expect(lock?.side, DismissDirections.startToEnd);
      expect(
        lock?.constrain(
          const Offset(12, 0),
          currentExtent: -8,
          directions: DismissDirections.horizontal,
        ),
        const Offset(12, 0),
      );
      expect(lock?.sideFor(4), DismissDirections.endToStart);
      expect(
        lock?.decide(
          progress: 0.5,
          extent: 4,
          thresholds: const DismissThresholds(
            startToEnd: 0.9,
            endToStart: 0.3,
          ),
        ),
        DismissDecision.dismiss,
      );
    });

    test('reports which axes the allowed sides lie on', () {
      expect(DismissDirections.vertical.allowsAxis(Axis.vertical), isTrue);
      expect(DismissDirections.vertical.allowsAxis(Axis.horizontal), isFalse);
      expect(DismissDirections.up.allowsAxis(Axis.vertical), isTrue);
      expect(DismissDirections.endToStart.allowsAxis(Axis.horizontal), isTrue);
      expect(DismissDirections.all.allowsAxis(Axis.vertical), isTrue);
      expect(DismissDirections.all.allowsAxis(Axis.horizontal), isTrue);
      expect(DismissDirections.empty.allowsAxis(Axis.vertical), isFalse);
      expect(DismissDirections.empty.allowsAxis(Axis.horizontal), isFalse);
    });

    test('reports when an allowed side leaves a given axis', () {
      // Every allowed side lies on the vertical axis.
      expect(DismissDirections.vertical.leavesAxis(Axis.vertical), isFalse);
      // A cross-axis side leaves the vertical axis.
      expect(
        DismissDirections.up
            .add(DismissDirections.startToEnd)
            .leavesAxis(Axis.vertical),
        isTrue,
      );
      expect(DismissDirections.all.leavesAxis(Axis.vertical), isTrue);
      expect(DismissDirections.all.leavesAxis(Axis.horizontal), isTrue);
      expect(DismissDirections.horizontal.leavesAxis(Axis.vertical), isTrue);
      expect(DismissDirections.horizontal.leavesAxis(Axis.horizontal), isFalse);
      expect(DismissDirections.empty.leavesAxis(Axis.vertical), isFalse);
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
        final extent = delta.dy != 0 ? delta.dy : delta.dx;

        expect(
          lock?.decide(
            progress: threshold,
            extent: extent,
            thresholds: thresholds,
          ),
          DismissDecision.dismiss,
        );
        expect(
          lock?.decide(
            progress: threshold - 0.01,
            extent: extent,
            thresholds: thresholds,
          ),
          DismissDecision.reverse,
        );
      }
    });
  });
}
