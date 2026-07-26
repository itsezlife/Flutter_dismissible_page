import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pager Scroll Arbitration', () {
    const atFirstPage = ScrollExtentMetrics(
      pixels: 0,
      minScrollExtent: 0,
      maxScrollExtent: 300,
    );
    const atLastPage = ScrollExtentMetrics(
      pixels: 300,
      minScrollExtent: 0,
      maxScrollExtent: 300,
    );
    const midPager = ScrollExtentMetrics(
      pixels: 150,
      minScrollExtent: 0,
      maxScrollExtent: 300,
    );

    bool consume(
      DismissDirections directions, {
      required double delta,
      required ScrollExtentMetrics metrics,
      required bool isSettledOnWholePage,
      TextDirection textDirection = TextDirection.ltr,
    }) {
      return directions.shouldConsumePagerScrollDelta(
        delta: delta,
        metrics: metrics,
        textDirection: textDirection,
        isSettledOnWholePage: isSettledOnWholePage,
      );
    }

    test('does not consume pager-axis dismiss from a half-turned page', () {
      expect(
        consume(
          DismissDirections.horizontal,
          delta: 4,
          metrics: atFirstPage,
          isSettledOnWholePage: false,
        ),
        isFalse,
      );
    });

    test('consumes further-back delta only when settled on the first page', () {
      expect(
        consume(
          DismissDirections.startToEnd,
          delta: 4,
          metrics: atFirstPage,
          isSettledOnWholePage: true,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.startToEnd,
          delta: 4,
          metrics: midPager,
          isSettledOnWholePage: true,
        ),
        isFalse,
      );
    });

    test(
      'consumes further-forward delta only when settled on the last page',
      () {
        expect(
          consume(
            DismissDirections.endToStart,
            delta: -4,
            metrics: atLastPage,
            isSettledOnWholePage: true,
          ),
          isTrue,
        );
        expect(
          consume(
            DismissDirections.endToStart,
            delta: -4,
            metrics: midPager,
            isSettledOnWholePage: true,
          ),
          isFalse,
        );
      },
    );

    test('does not consume a delta toward a disallowed pager side', () {
      expect(
        consume(
          DismissDirections.endToStart,
          delta: 4,
          metrics: atFirstPage,
          isSettledOnWholePage: true,
        ),
        isFalse,
      );
      expect(
        consume(
          DismissDirections.empty,
          delta: 4,
          metrics: atFirstPage,
          isSettledOnWholePage: true,
        ),
        isFalse,
      );
    });

    test('resolves reading-relative pager edges in LTR and RTL', () {
      // Deltas are scroll-space (applyUserOffset), already axis-normalized.
      expect(
        consume(
          DismissDirections.startToEnd,
          delta: 4,
          metrics: atFirstPage,
          isSettledOnWholePage: true,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.startToEnd,
          delta: -4,
          metrics: atLastPage,
          isSettledOnWholePage: true,
          textDirection: TextDirection.rtl,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.endToStart,
          delta: -4,
          metrics: atLastPage,
          isSettledOnWholePage: true,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.endToStart,
          delta: 4,
          metrics: atFirstPage,
          isSettledOnWholePage: true,
          textDirection: TextDirection.rtl,
        ),
        isTrue,
      );
    });

    test('horizontal composite consumes at either settled pager edge', () {
      expect(
        consume(
          DismissDirections.horizontal,
          delta: 4,
          metrics: atFirstPage,
          isSettledOnWholePage: true,
        ),
        isTrue,
      );
      expect(
        consume(
          DismissDirections.horizontal,
          delta: -4,
          metrics: atLastPage,
          isSettledOnWholePage: true,
        ),
        isTrue,
      );
    });
  });
}
