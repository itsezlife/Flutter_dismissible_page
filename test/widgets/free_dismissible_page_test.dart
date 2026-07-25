import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Thin widget tests for the public [FreeDismissiblePage] seam.
  ///
  /// These cover wiring only — variant exposure, disabled, scroll controller
  /// attachment, interaction modes, and the externally observable
  /// dismiss-vs-reverse outcome. Free Motion math (progress, single-threshold
  /// decision, arbitration boundaries) lives in the engine unit tests and is
  /// not re-encoded here.
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// A vertical scrollable tall enough to scroll on the 800x600 test screen.
  Widget verticalList(ScrollController controller) => SingleChildScrollView(
    controller: controller,
    child: const SizedBox(height: 2200, child: FlutterLogo()),
  );

  testWidgets('exposes FreeDismissiblePage without Dismiss Directions', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          onDismissed: () {},
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    expect(find.byType(FreeDismissiblePage), findsOneWidget);
  });

  testWidgets('scroll mode is the default and supplies a ScrollController', (
    tester,
  ) async {
    ScrollController? provided;

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          onDismissed: () {},
          builder: (context, controller) {
            provided = controller;
            return SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 2200, child: FlutterLogo()),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The provided controller attaches to the primary scrollable.
    expect(provided?.hasClients, isTrue);
  });

  testWidgets('gesture mode dismisses a free-plane drag past the threshold', (
    tester,
  ) async {
    var dismissed = false;
    var dragEnded = false;

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragEnd: () => dragEnded = true,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // A diagonal drag: 150 / 600 = 0.25 vertically dominates and is well
    // past the default 0.15 threshold. No Axis Lock filters it out.
    await tester.drag(
      find.byType(FreeDismissiblePage),
      const Offset(100, 150),
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
        FreeDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragEnd: () => dragEnded = true,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // ~0.05 progress on a 600-tall screen — below the 0.15 threshold.
    await tester.drag(
      find.byType(FreeDismissiblePage),
      const Offset(20, 30),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
    expect(dragEnded, isTrue);
  });

  testWidgets('one custom threshold governs the whole free-plane gesture', (
    tester,
  ) async {
    var dismissed = false;
    var dragEnded = false;

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          threshold: 0.5,
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragEnd: () => dragEnded = true,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // 150 / 600 = 0.25 — past the default 0.15, short of the custom 0.5.
    await tester.drag(
      find.byType(FreeDismissiblePage),
      const Offset(100, 150),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
    expect(dragEnded, isTrue);
  });

  testWidgets('a drag tracks both plane axes without Axis Lock', (
    tester,
  ) async {
    DismissiblePageDragUpdateDetails? lastDetails;

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () {},
          onDragUpdate: (details) => lastDetails = details,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    await tester.drag(
      find.byType(FreeDismissiblePage),
      const Offset(60, 40),
    );
    await tester.pump();

    // Both components of the diagonal drag survive into presentation —
    // Constrained Motion would have discarded the non-dominant axis.
    expect(lastDetails, isNotNull);
    if (lastDetails case final details?) {
      expect(details.offset.dx, greaterThan(0.0));
      expect(details.offset.dy, greaterThan(0.0));
    }
  });

  testWidgets('disabled pages cannot begin dismissal', (tester) async {
    var dismissed = false;
    var dragValue = 0.0;

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          disabled: true,
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () => dismissed = true,
          onDragUpdate: (details) => dragValue = details.overallDragValue,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    await tester.drag(
      find.byType(FreeDismissiblePage),
      const Offset(100, 200),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isFalse);
    expect(dragValue, 0.0);
  });

  testWidgets('drag lifecycle emits start and populated presentation details', (
    tester,
  ) async {
    var started = false;
    DismissiblePageDragUpdateDetails? lastDetails;

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () {},
          onDragStart: () => started = true,
          onDragUpdate: (details) => lastDetails = details,
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    await tester.drag(
      find.byType(FreeDismissiblePage),
      const Offset(40, 60),
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
        FreeDismissiblePage(
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
    'scroll mode starts a free dismiss from a horizontal-dominant mid-list '
    'drag',
    (tester) async {
      var dismissed = false;
      late ScrollController provided;

      await tester.pumpWidget(
        wrap(
          FreeDismissiblePage(
            onDismissed: () => dismissed = true,
            builder: (context, controller) {
              provided = controller;
              return verticalList(controller);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll into the list first so the off-axis dismiss starts mid-content,
      // not at the top edge.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(provided.offset, greaterThan(0));

      // Horizontal-dominant drag must engage the Free shell. 300 / 800 = 0.375
      // progress, past the default 0.15 threshold.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'scroll mode dismisses a horizontal-dominant diagonal under a vertical '
    'list',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        wrap(
          FreeDismissiblePage(
            onDismissed: () => dismissed = true,
            builder: (context, controller) => verticalList(controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Horizontal-dominant but not pure: the nested VerticalDrag must not
      // steal the gesture just because there is a small dy component.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(280, 50),
      );
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'scroll mode keeps full-plane tracking after the Free shell wins',
    (tester) async {
      Offset? lastOffset;

      await tester.pumpWidget(
        wrap(
          FreeDismissiblePage(
            onDismissed: () {},
            onDragUpdate: (details) => lastOffset = details.offset,
            builder: (context, controller) => verticalList(controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(SingleChildScrollView));
      final gesture = await tester.startGesture(center);

      // Off-axis-dominant start lets the Free shell win.
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      expect(lastOffset?.dx, greaterThan(0));

      // After the win, Free Motion stays 2D — further vertical movement also
      // displaces the page (Constrained dual-mount would not).
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(lastOffset?.dx, greaterThan(0));
      expect(lastOffset?.dy, greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('scroll mode keeps mid-list on-axis drags scrolling the list', (
    tester,
  ) async {
    var dismissed = false;
    late ScrollController provided;

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          onDismissed: () => dismissed = true,
          builder: (context, controller) {
            provided = controller;
            return verticalList(controller);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll into the list first so the gesture starts mid-content, not at the
    // top edge where overscroll arbitration would also claim on-axis motion.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final scrolled = provided.offset;
    expect(scrolled, greaterThan(0));

    // On-axis mid-list: the Free shell yields so the list keeps scrolling.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(provided.offset, greaterThan(scrolled));
    expect(dismissed, isFalse);
  });

  testWidgets(
    'scroll mode engages the full-plane shell when content cannot scroll',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        wrap(
          FreeDismissiblePage(
            onDismissed: () => dismissed = true,
            builder: (context, controller) => SingleChildScrollView(
              controller: controller,
              // Fits inside the 600-tall test screen — nothing to scroll.
              child: const SizedBox(height: 200, child: FlutterLogo()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No yield path: an on-axis drag still dismisses via the full-plane
      // shell (gesture-parity with non-scrollable content).
      await tester.drag(
        find.byType(FreeDismissiblePage),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    },
  );

  testWidgets('a reversing gesture eases the settle with the given curve', (
    tester,
  ) async {
    final curve = _RecordingCurve();

    await tester.pumpWidget(
      wrap(
        FreeDismissiblePage(
          reverseCurve: curve,
          interactionMode: DismissiblePageInteractionMode.gesture,
          onDismissed: () {},
          builder: (context, controller) => const FlutterLogo(),
        ),
      ),
    );

    // Below the 0.15 threshold, so the gesture reverses and settles.
    await tester.drag(
      find.byType(FreeDismissiblePage),
      const Offset(20, 30),
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
