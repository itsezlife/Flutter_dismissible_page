import 'dart:async';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Thin widget tests for the public [ConstrainedDismissiblePage] seam.
  ///
  /// These cover wiring only — variant/direction selection, disabled, scroll
  /// controller attachment, interaction modes, and the externally observable
  /// dismiss-vs-reverse outcome. Engine edge cases (axis-lock tables,
  /// per-side thresholds, arbitration boundaries) live in the engine unit
  /// tests and are not re-encoded here.
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// A vertical scrollable tall enough to scroll on the 800x600 test screen.
  Widget verticalList(ScrollController controller) => SingleChildScrollView(
    controller: controller,
    child: const SizedBox(height: 2200, child: FlutterLogo()),
  );

  /// Wraps [child] in an ancestor horizontal drag recognizer.
  ///
  /// The ancestor only wins the gesture arena when the page itself mounts no
  /// competing cross-axis recognizer, so `sawDrag` is how these tests observe
  /// dual-mount versus arbitration-only from the outside.
  Widget withAncestorHorizontalDrag(Widget child, VoidCallback sawDrag) =>
      GestureDetector(
        onHorizontalDragUpdate: (_) => sawDrag(),
        child: child,
      );

  testWidgets('exposes ConstrainedDismissiblePage with Dismiss Directions', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          directions: DismissDirections.horizontal,
          onDismissed: () {},
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    expect(find.byType(ConstrainedDismissiblePage), findsOneWidget);
  });

  testWidgets('scroll mode is the default and supplies a ScrollController', (
    tester,
  ) async {
    ScrollController? provided;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          onDismissed: () {},
          builder: (context, controller) {
            provided = controller;
            return verticalList(controller);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The provided controller attaches to the primary scrollable.
    expect(provided?.hasClients, isTrue);
  });

  testWidgets('gesture mode dismisses non-scrollable content past threshold', (
    tester,
  ) async {
    var dismissed = false;
    var dragEnded = false;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragEnd: () => dragEnded = true,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // Screen is 600 tall; 200px down is ~0.33 progress, well past the
    // default 0.15 threshold for the down side.
    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expect(dragEnded, isFalse);
  });

  testWidgets('a gesture that falls short of the threshold reverses', (
    tester,
  ) async {
    var dismissed = false;
    var dragEnded = false;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragEnd: () => dragEnded = true,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // ~0.05 progress on a 600-tall screen — below the 0.15 threshold.
    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 30),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
    expect(dragEnded, isTrue);
  });

  testWidgets(
    'confirmDismiss false reverse-settles without calling onDismissed',
    (tester) async {
      var dismissed = false;
      var dragEnded = false;

      await tester.pumpWidget(
        wrap(
          ConstrainedDismissiblePage(
            interactionMode: DismissiblePageInteractionMode.gesture,
            confirmDismiss: () async => false,
            onDismissed: () => dismissed = true,
            onDragEnd: () => dragEnded = true,
            builder: (context, controller) => const FlutterLogo(),
          ),
        ),
      );

      await tester.drag(
        find.byType(ConstrainedDismissiblePage),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      expect(dismissed, isFalse);
      expect(dragEnded, isTrue);
    },
  );

  testWidgets(
    'confirmDismiss true completes dismiss and calls onDismissed',
    (tester) async {
      var dismissed = false;
      var dragEnded = false;

      await tester.pumpWidget(
        wrap(
          ConstrainedDismissiblePage(
            interactionMode: DismissiblePageInteractionMode.gesture,
            confirmDismiss: () async => true,
            onDismissed: () => dismissed = true,
            onDragEnd: () => dragEnded = true,
            builder: (context, controller) => const FlutterLogo(),
          ),
        ),
      );

      await tester.drag(
        find.byType(ConstrainedDismissiblePage),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(dragEnded, isFalse);
    },
  );

  testWidgets(
    'omitted confirmDismiss preserves legacy dismiss past threshold',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        wrap(
          ConstrainedDismissiblePage(
            interactionMode: DismissiblePageInteractionMode.gesture,
            onDismissed: () => dismissed = true,
            builder: (context, controller) => const FlutterLogo(),
          ),
        ),
      );

      await tester.drag(
        find.byType(ConstrainedDismissiblePage),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'confirmDismiss holds dismiss until the Future completes',
    (tester) async {
      var dismissed = false;
      final gate = Completer<bool>();

      await tester.pumpWidget(
        wrap(
          ConstrainedDismissiblePage(
            interactionMode: DismissiblePageInteractionMode.gesture,
            confirmDismiss: () => gate.future,
            onDismissed: () => dismissed = true,
            builder: (context, controller) => const FlutterLogo(),
          ),
        ),
      );

      await tester.drag(
        find.byType(ConstrainedDismissiblePage),
        const Offset(0, 200),
      );
      await tester.pump();

      expect(dismissed, isFalse);

      gate.complete(true);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    },
  );

  testWidgets('respects the selected side: a disallowed side cannot dismiss', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          directions: DismissDirections.up,
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // Dragging down is not a permitted side when only `up` is allowed.
    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
  });

  testWidgets('disabled pages cannot begin dismissal', (tester) async {
    var dismissed = false;
    var dragValue = 0.0;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          disabled: true,
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragUpdate: (details) => dragValue = details.overallDragValue,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
    expect(dragValue, 0.0);
  });

  testWidgets('empty directions cannot begin dismissal', (tester) async {
    var dismissed = false;
    var dragValue = 0.0;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          directions: DismissDirections.empty,
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragUpdate: (details) => dragValue = details.overallDragValue,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
    expect(dragValue, 0.0);
  });

  testWidgets('onDragUpdate reports non-zero progress during a drag', (
    tester,
  ) async {
    var dragValue = 0.0;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () {},
          onDragUpdate: (details) => dragValue = details.overallDragValue,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 30),
    );
    await tester.pump();

    expect(dragValue, greaterThan(0.0));
  });

  testWidgets('drag lifecycle emits start and populated presentation details', (
    tester,
  ) async {
    var started = false;
    DismissiblePageDragUpdateDetails? lastDetails;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () {},
          onDragStart: () => started = true,
          onDragUpdate: (details) => lastDetails = details,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 60),
    );
    await tester.pump();

    expect(started, isTrue);
    // Drag details expose progress-driven presentation, not just a flag.
    expect(lastDetails, isNotNull);
    if (lastDetails case final details?) {
      expect(details.overallDragValue, greaterThan(0.0));
      expect(details.offset, isNot(Offset.zero));
      expect(details.scale, lessThan(1.0));
      expect(details.opacity, lessThanOrEqualTo(1.0));
      expect(details.radius, greaterThanOrEqualTo(7.0));
    }
  });

  testWidgets('scroll mode dismisses via overscroll at the top boundary', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          onDismissed: () => dismissed = true,
          builder: (context, controller) => verticalList(controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // At the top boundary a downward drag is arbitrated to dismissal rather
    // than inner scroll.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 220),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets(
    'scroll mode reverse after dismiss start moves the page back',
    (tester) async {
      final dragValues = <double>[];

      await tester.pumpWidget(
        wrap(
          ConstrainedDismissiblePage(
            onDismissed: () {},
            onDragUpdate: (details) => dragValues.add(details.overallDragValue),
            builder: (context, controller) => verticalList(controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SingleChildScrollView)),
      );
      // Overscroll at the top starts a downward dismiss.
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(dragValues, isNotEmpty);
      final afterStart = dragValues.last;
      expect(afterStart, greaterThan(0));

      // Reverse toward origin without lifting — page must follow.
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      expect(dragValues.last, lessThan(afterStart));
      expect(dragValues.last, greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'scroll mode snaps at origin instead of crossing into the other side',
    (tester) async {
      Offset? lastOffset;
      late ScrollController provided;

      await tester.pumpWidget(
        wrap(
          ConstrainedDismissiblePage(
            onDismissed: () {},
            onDragUpdate: (details) => lastOffset = details.offset,
            builder: (context, controller) {
              provided = controller;
              return verticalList(controller);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SingleChildScrollView)),
      );
      // Overscroll at the top starts a downward dismiss.
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(lastOffset?.dy, greaterThan(0));

      // A reverse large enough to cross origin must snap to rest — not flip
      // into the up side. Leftover of this frame is dropped (stock/Free);
      // later on-axis motion scrolls the list.
      await gesture.moveBy(const Offset(0, -160));
      await tester.pump();
      expect(lastOffset?.dy, 0);

      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(lastOffset?.dy, 0);
      expect(provided.offset, greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'gesture mode can cross origin into the other allowed vertical side',
    (tester) async {
      Offset? lastOffset;

      await tester.pumpWidget(
        wrap(
          ConstrainedDismissiblePage(
            interactionMode: DismissiblePageInteractionMode.gesture,
            onDismissed: () {},
            onDragUpdate: (details) => lastOffset = details.offset,
            builder: (context, controller) => const FlutterLogo(),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ConstrainedDismissiblePage)),
      );
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(lastOffset?.dy, greaterThan(0));

      // Without a nested scrollable, Axis Lock may cross into the other
      // allowed side on a bidirectional set.
      await gesture.moveBy(const Offset(0, -160));
      await tester.pump();
      expect(lastOffset?.dy, lessThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'scroll mode dismisses across a side that leaves the scroll axis',
    (tester) async {
      var dismissed = false;
      var ancestorSawDrag = false;

      await tester.pumpWidget(
        wrap(
          withAncestorHorizontalDrag(
            ConstrainedDismissiblePage(
              directions: DismissDirections.all,
              onDismissed: () => dismissed = true,
              builder: (context, controller) => verticalList(controller),
            ),
            () => ancestorSawDrag = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 300px on an 800-wide screen is ~0.375 progress, past the default 0.15
      // threshold for the startToEnd side.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      // The page's own cross-axis recognizer won the arena, not the ancestor.
      expect(ancestorSawDrag, isFalse);
    },
  );

  testWidgets('scroll mode partitions the shell against a horizontal list', (
    tester,
  ) async {
    var dismissed = false;
    late ScrollController provided;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          directions: DismissDirections.all,
          onDismissed: () => dismissed = true,
          builder: (context, controller) {
            provided = controller;
            return SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: const SizedBox(width: 2200, child: FlutterLogo()),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // On-axis for a horizontal list: the list keeps the gesture.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    expect(provided.offset, greaterThan(0));
    expect(dismissed, isFalse);

    // Vertical is now the cross axis, so the shell serves it.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('scroll mode keeps mid-list on-axis drags scrolling the list', (
    tester,
  ) async {
    var dismissed = false;
    late ScrollController provided;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          directions: DismissDirections.all,
          onDismissed: () => dismissed = true,
          builder: (context, controller) {
            provided = controller;
            return verticalList(controller);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // On-axis and away from the boundary the inner list keeps the gesture,
    // even though a cross-axis recognizer is mounted alongside arbitration.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(provided.offset, greaterThan(0));
    expect(dismissed, isFalse);
  });

  testWidgets('scroll mode still dismisses on-axis at the edge under a shell', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          directions: DismissDirections.all,
          onDismissed: () => dismissed = true,
          builder: (context, controller) => verticalList(controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // On-axis dismissal is still Scroll Arbitration's job at the boundary,
    // even with a cross-axis recognizer mounted alongside it.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 220),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets('a cross-axis drag cannot inherit a settling on-axis lock', (
    tester,
  ) async {
    Offset? lastOffset;

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          directions: DismissDirections.all,
          onDismissed: () {},
          onDragUpdate: (details) => lastOffset = details.offset,
          builder: (context, controller) => verticalList(controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(SingleChildScrollView));

    // Overscroll at the top starts an on-axis dismiss, released short of the
    // threshold so it settles back.
    final onAxis = await tester.startGesture(center);
    await onAxis.moveBy(const Offset(0, 20));
    await onAxis.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(lastOffset?.dy, greaterThan(0));
    await onAxis.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Interrupt the settle with a cross-axis drag. The vertical lock and its
    // extent belong to the finished gesture, so this one must start clean
    // instead of freezing on an axis it cannot move.
    final crossAxis = await tester.startGesture(center);
    await crossAxis.moveBy(const Offset(100, 0));
    await tester.pump();

    expect(lastOffset?.dy, 0);
    expect(lastOffset?.dx, greaterThan(0));

    await crossAxis.up();
    await tester.pumpAndSettle();
  });

  testWidgets('scroll mode arbitrates alone when every side is on-axis', (
    tester,
  ) async {
    var dismissed = false;
    var ancestorSawDrag = false;

    await tester.pumpWidget(
      wrap(
        withAncestorHorizontalDrag(
          ConstrainedDismissiblePage(
            onDismissed: () => dismissed = true,
            builder: (context, controller) => verticalList(controller),
          ),
          () => ancestorSawDrag = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();

    // Vertical directions on a vertical list: no cross-axis recognizer
    // competes, so the horizontal drag reaches the ancestor untouched.
    expect(ancestorSawDrag, isTrue);
    expect(dismissed, isFalse);
  });

  testWidgets('scroll mode mounts no shell when dismissal is turned off', (
    tester,
  ) async {
    for (final page in [
      (label: 'disabled', disabled: true, directions: DismissDirections.all),
      (
        label: 'empty directions',
        disabled: false,
        directions: DismissDirections.empty,
      ),
    ]) {
      var dismissed = false;
      var ancestorSawDrag = false;

      await tester.pumpWidget(
        wrap(
          withAncestorHorizontalDrag(
            ConstrainedDismissiblePage(
              key: ValueKey(page.label),
              disabled: page.disabled,
              directions: page.directions,
              onDismissed: () => dismissed = true,
              builder: (context, controller) => verticalList(controller),
            ),
            () => ancestorSawDrag = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(ancestorSawDrag, isTrue, reason: page.label);

      // Overscroll at the top boundary is passed to the list, not consumed.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 220),
      );
      await tester.pumpAndSettle();
      expect(dismissed, isFalse, reason: page.label);
    }
  });

  testWidgets('a reversing gesture eases the settle with the given curve', (
    tester,
  ) async {
    final curve = _RecordingCurve();

    await tester.pumpWidget(
      wrap(
        ConstrainedDismissiblePage(
          reverseCurve: curve,
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () {},
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // ~0.05 progress on a 600-tall screen — below the 0.15 threshold, so the
    // gesture reverses and settles.
    await tester.drag(
      find.byType(ConstrainedDismissiblePage),
      const Offset(0, 30),
    );
    await tester.pumpAndSettle();

    expect(curve.wasConsulted, isTrue);
  });
}

/// A [Curve] that records whether it drove an animation, for asserting that a
/// configured settle curve is actually applied.
// ignore: must_be_immutable
class _RecordingCurve extends Curve {
  bool wasConsulted = false;

  @override
  double transformInternal(double t) {
    wasConsulted = true;
    return t;
  }
}
