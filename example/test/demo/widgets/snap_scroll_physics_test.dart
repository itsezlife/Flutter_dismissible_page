import 'package:example/demo/widgets/snap_scroll_physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurvedPageSnapSimulation', () {
    test('starts at start, ends at end, and finishes at snapDuration', () {
      const duration = Duration(milliseconds: 280);
      final sim = CurvedPageSnapSimulation(
        start: 100,
        end: 500,
        durationSeconds: duration.inMilliseconds / 1000,
      );

      expect(sim.x(0), 100);
      expect(sim.isDone(0), isFalse);
      expect(sim.x(duration.inMilliseconds / 1000), 500);
      expect(sim.isDone(duration.inMilliseconds / 1000), isTrue);
      // Past duration stays at end — no spring overshoot.
      expect(sim.x(1), 500);
    });

    test('eases through the curve between start and end', () {
      const durationSeconds = 0.28;
      final sim = CurvedPageSnapSimulation(
        start: 0,
        end: 100,
        durationSeconds: durationSeconds,
      );

      final mid = sim.x(durationSeconds / 2);
      // easeOutCubic is ahead of linear at the halfway mark.
      expect(mid, greaterThan(50));
      expect(mid, lessThan(100));
      expect(mid, closeTo(Curves.easeOutCubic.transform(0.5) * 100, 0.01));
    });
  });

  group('SnapScrollPhysics', () {
    const physics = SnapScrollPhysics(
      snapDuration: Duration(milliseconds: 200),
    );

    PageMetrics metrics({
      required double pixels,
      double min = 0,
      double max = 800,
      double viewport = 800,
    }) {
      return PageMetrics(
        minScrollExtent: min,
        maxScrollExtent: max,
        pixels: pixels,
        viewportDimension: viewport,
        axisDirection: AxisDirection.right,
        viewportFraction: 1,
        devicePixelRatio: 1,
      );
    }

    test(
      'mid-page ballistic returns a curved snap toward the nearer whole page',
      () {
        // Halfway through page 0 → 1 at rest; ~0.5 threshold rounds to page 1.
        final sim = physics.createBallisticSimulation(
          metrics(pixels: 400),
          0,
        );

        expect(sim, isA<CurvedPageSnapSimulation>());
        final curved = sim! as CurvedPageSnapSimulation;
        expect(curved.start, 400);
        expect(curved.end, 800);
        expect(curved.isDone(0.2), isTrue);
      },
    );

    test('boundary away from content defers to parent physics', () {
      final sim = physics.createBallisticSimulation(
        metrics(pixels: 0),
        -1000,
      );

      // Parent ClampingScrollPhysics returns a ballistic that is not our curve.
      expect(sim, isNot(isA<CurvedPageSnapSimulation>()));
    });
  });
}
