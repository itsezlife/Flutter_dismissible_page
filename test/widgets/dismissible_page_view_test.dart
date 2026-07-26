import 'dart:async';
import 'dart:math';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('mid-pager horizontal swipes change pages', (tester) async {
    var currentPage = 0;
    var maxDismissProgress = 0.0;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.horizontal,
          onDismissed: () {},
          onDragUpdate: (details) {
            maxDismissProgress = max(
              maxDismissProgress,
              details.overallDragValue,
            );
          },
          builder: (context, controller) => PageView(
            controller: controller,
            onPageChanged: (page) => currentPage = page,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.green),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(currentPage, 1);
    expect(maxDismissProgress, 0);
  });

  testWidgets('a permitted first-edge swipe dismisses past threshold', (
    tester,
  ) async {
    var dismissed = false;
    var maxProgress = 0.0;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.startToEnd,
          onDismissed: () => dismissed = true,
          onDragUpdate: (details) {
            maxProgress = max(maxProgress, details.overallDragValue);
          },
          builder: (context, controller) => PageView(
            controller: controller,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expect(maxProgress, greaterThan(0));
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('a permitted last-edge swipe dismisses forward', (tester) async {
    final controller = DismissiblePageViewController(initialPage: 1);
    var dismissed = false;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          controller: controller,
          directions: DismissDirections.endToStart,
          onDismissed: () => dismissed = true,
          builder: (context, controller) => PageView(
            controller: controller,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('handoff-at-origin can reverse from dismiss into paging', (
    tester,
  ) async {
    var currentPage = 0;
    DismissiblePageViewController? supplied;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.startToEnd,
          pagerCommitment: PagerCommitment.handoffAtOrigin,
          onDismissed: () {},
          builder: (context, controller) {
            supplied = controller;
            return PageView(
              controller: controller,
              onPageChanged: (page) => currentPage = page,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-500, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(currentPage, 1);
    expect(supplied!.page, 1);
  });

  testWidgets(
    'clamp-at-origin keeps a pager-axis dismiss from crossing into the '
    'other side',
    (tester) async {
      var minDx = 0.0;
      var maxDx = 0.0;

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            directions: DismissDirections.horizontal,
            onDismissed: () {},
            onDragUpdate: (details) {
              minDx = min(minDx, details.offset.dx);
              maxDx = max(maxDx, details.offset.dx);
            },
            builder: (context, controller) => PageView(
              controller: controller,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-240, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(maxDx, greaterThan(0));
      expect(minDx, 0);
    },
  );

  testWidgets(
    'cross-to-opposite-side lets a pager-axis dismiss pass through origin',
    (tester) async {
      var minDx = 0.0;
      var maxDx = 0.0;

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            directions: DismissDirections.horizontal,
            originCrossing: PagerOriginCrossing.crossToOppositeSide,
            onDismissed: () {},
            onDragUpdate: (details) {
              minDx = min(minDx, details.offset.dx);
              maxDx = max(maxDx, details.offset.dx);
            },
            builder: (context, controller) => PageView(
              controller: controller,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-240, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(maxDx, greaterThan(0));
      expect(minDx, lessThan(0));
    },
  );

  testWidgets(
    'clamp-at-origin with handoff-at-origin hands reverse at origin to paging',
    (tester) async {
      var currentPage = 0;

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            directions: DismissDirections.horizontal,
            pagerCommitment: PagerCommitment.handoffAtOrigin,
            onDismissed: () {},
            builder: (context, controller) => PageView(
              controller: controller,
              onPageChanged: (page) => currentPage = page,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-500, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(currentPage, 1);
    },
  );

  testWidgets(
    'cross-to-opposite-side with handoff keeps a crossing reverse on dismiss',
    (tester) async {
      var currentPage = 0;
      var minDx = 0.0;

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            directions: DismissDirections.horizontal,
            pagerCommitment: PagerCommitment.handoffAtOrigin,
            originCrossing: PagerOriginCrossing.crossToOppositeSide,
            onDismissed: () {},
            onDragUpdate: (details) {
              minDx = min(minDx, details.offset.dx);
            },
            builder: (context, controller) => PageView(
              controller: controller,
              onPageChanged: (page) => currentPage = page,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(minDx, lessThan(0));
      expect(currentPage, 0);
    },
  );

  testWidgets('locked-until-release does not hand dismiss off to paging', (
    tester,
  ) async {
    var currentPage = 0;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.startToEnd,
          onDismissed: () {},
          builder: (context, controller) => PageView(
            controller: controller,
            onPageChanged: (page) => currentPage = page,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-500, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(currentPage, 0);
  });

  testWidgets(
    'edge dismiss cool-down blocks then re-arms after user paging',
    (tester) async {
      var dismissed = false;
      const cooldown = Duration(milliseconds: 300);

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            directions: DismissDirections.horizontal,
            onDismissed: () => dismissed = true,
            builder: (context, controller) => PageView(
              controller: controller,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page toward the last edge.
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Immediately try to dismiss at the last edge — cool-down should block.
      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(dismissed, isFalse);

      await tester.pump(cooldown);

      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'a new user paging delta during cool-down restarts the quiet interval',
    (tester) async {
      var dismissed = false;
      const cooldown = Duration(milliseconds: 300);

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            directions: DismissDirections.horizontal,
            onDismissed: () => dismissed = true,
            builder: (context, controller) => PageView(
              controller: controller,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.green),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 200));

      // Page again before cool-down elapses — restarts the clock.
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 200));
      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(dismissed, isFalse);

      await tester.pump(cooldown);
      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'programmatic page changes do not arm the edge dismiss cool-down',
    (tester) async {
      final controller = DismissiblePageViewController();
      var dismissed = false;

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            controller: controller,
            directions: DismissDirections.horizontal,
            onDismissed: () => dismissed = true,
            builder: (context, controller) => PageView(
              controller: controller,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(
        controller.nextPage(
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();

      // No cool-down from programmatic paging — edge dismiss is armed.
      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'cool-down does not gate off-pager-axis dismissal',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        wrap(
          DismissiblePageView(
            directions:
                DismissDirections.vertical | DismissDirections.horizontal,
            onDismissed: () => dismissed = true,
            builder: (context, controller) => PageView(
              controller: controller,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets('disabled blocks edge dismiss while leaving paging active', (
    tester,
  ) async {
    var currentPage = 0;
    var dismissed = false;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.horizontal,
          disabled: true,
          onDismissed: () => dismissed = true,
          builder: (context, controller) => PageView(
            controller: controller,
            onPageChanged: (page) => currentPage = page,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(dismissed, isFalse);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(currentPage, 1);
  });

  testWidgets('empty directions leave paging active without edge dismiss', (
    tester,
  ) async {
    var currentPage = 0;
    var dismissed = false;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.empty,
          onDismissed: () => dismissed = true,
          builder: (context, controller) => PageView(
            controller: controller,
            onPageChanged: (page) => currentPage = page,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(dismissed, isFalse);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(currentPage, 1);
  });

  testWidgets('per-side threshold reverses a short edge drag', (tester) async {
    var dismissed = false;
    var dragEnded = false;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.startToEnd,
          thresholds: const DismissThresholds(startToEnd: .5),
          onDismissed: () => dismissed = true,
          onDragEnd: () => dragEnded = true,
          builder: (context, controller) => PageView(
            controller: controller,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
    expect(dragEnded, isTrue);
  });

  testWidgets('vertical shell dismisses without changing the page', (
    tester,
  ) async {
    var currentPage = 0;
    var dismissed = false;
    var maxProgress = 0.0;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          directions: DismissDirections.down,
          onDismissed: () => dismissed = true,
          onDragUpdate: (details) {
            maxProgress = max(maxProgress, details.overallDragValue);
          },
          builder: (context, controller) => PageView(
            controller: controller,
            onPageChanged: (page) => currentPage = page,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expect(maxProgress, greaterThan(0));
    expect(currentPage, 0);
  });

  testWidgets('external controller remains caller-owned', (tester) async {
    final controller = DismissiblePageViewController(initialPage: 1);

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          controller: controller,
          onDismissed: () {},
          builder: (context, controller) => PageView(
            controller: controller,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.page, 1);

    await tester.pumpWidget(const SizedBox());

    void listener() {}
    expect(() => controller.addListener(listener), returnsNormally);
    controller
      ..removeListener(listener)
      ..dispose();
  });

  testWidgets('external controller changes pages programmatically while idle', (
    tester,
  ) async {
    final controller = DismissiblePageViewController();
    var currentPage = 0;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          controller: controller,
          onDismissed: () {},
          builder: (context, controller) => PageView(
            controller: controller,
            onPageChanged: (page) => currentPage = page,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Don't await the animation future: the test clock only advances while
    // pumping, so awaiting before pumpAndSettle would deadlock the test.
    unawaited(
      controller.nextPage(
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      ),
    );
    await tester.pumpAndSettle();

    expect(currentPage, 1);
    expect(controller.page, 1);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('internally created controller is disposed with the page', (
    tester,
  ) async {
    DismissiblePageViewController? supplied;

    await tester.pumpWidget(
      wrap(
        DismissiblePageView(
          onDismissed: () {},
          builder: (context, controller) {
            supplied = controller;
            return PageView(
              controller: controller,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());

    expect(() => supplied!.addListener(() {}), throwsFlutterError);
  });
}
