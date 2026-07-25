import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scroll Arbitration', () {
    const range = ScrollExtentMetrics(
      pixels: 40,
      minScrollExtent: 0,
      maxScrollExtent: 100,
    );
    const atMin = ScrollExtentMetrics(
      pixels: 0,
      minScrollExtent: 0,
      maxScrollExtent: 100,
    );
    const atMax = ScrollExtentMetrics(
      pixels: 100,
      minScrollExtent: 0,
      maxScrollExtent: 100,
    );

    bool consume(
      DismissDirections directions, {
      required double delta,
      required ScrollExtentMetrics metrics,
      Axis scrollAxis = Axis.vertical,
      TextDirection textDirection = TextDirection.ltr,
    }) {
      return directions.shouldConsumeScrollDelta(
        delta: delta,
        metrics: metrics,
        scrollAxis: scrollAxis,
        textDirection: textDirection,
      );
    }

    test('consumes a downward delta only at the min scroll extent', () {
      expect(consume(DismissDirections.down, delta: 4, metrics: atMin), isTrue);
      expect(
        consume(DismissDirections.down, delta: 4, metrics: range),
        isFalse,
      );
    });

    test('consumes an upward delta only at the max scroll extent', () {
      expect(
        consume(DismissDirections.up, delta: -4, metrics: atMax),
        isTrue,
      );
      expect(
        consume(DismissDirections.up, delta: -4, metrics: range),
        isFalse,
      );
    });

    test('does not consume a delta toward a disallowed side', () {
      expect(
        consume(DismissDirections.up, delta: 4, metrics: atMin),
        isFalse,
      );
    });

    test('does not consume when no dismiss sides are allowed', () {
      expect(
        consume(DismissDirections.empty, delta: 4, metrics: atMin),
        isFalse,
      );
    });

    test('resolves reading-relative sides in LTR and RTL', () {
      // Deltas are scroll-space (applyUserOffset), already axis-normalized.
      expect(
        consume(
          DismissDirections.startToEnd,
          delta: 4,
          metrics: atMin,
          scrollAxis: Axis.horizontal,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.startToEnd,
          delta: -4,
          metrics: atMax,
          scrollAxis: Axis.horizontal,
          textDirection: TextDirection.rtl,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.endToStart,
          delta: -4,
          metrics: atMax,
          scrollAxis: Axis.horizontal,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.endToStart,
          delta: 4,
          metrics: atMin,
          scrollAxis: Axis.horizontal,
          textDirection: TextDirection.rtl,
        ),
        isTrue,
      );
    });

    test('vertical composites consume at either vertical boundary', () {
      expect(
        consume(DismissDirections.vertical, delta: 4, metrics: atMin),
        isTrue,
      );
      expect(
        consume(DismissDirections.vertical, delta: -4, metrics: atMax),
        isTrue,
      );
      expect(
        consume(DismissDirections.vertical, delta: 4, metrics: range),
        isFalse,
      );
    });

    test('targets only deltas toward an allowed atomic side', () {
      expect(
        DismissDirections.down.targetsPermittedDismissSide(
          delta: 4,
          scrollAxis: Axis.vertical,
          textDirection: TextDirection.ltr,
        ),
        isTrue,
      );
      expect(
        DismissDirections.down.targetsPermittedDismissSide(
          delta: -4,
          scrollAxis: Axis.vertical,
          textDirection: TextDirection.ltr,
        ),
        isFalse,
      );
    });
  });
}
