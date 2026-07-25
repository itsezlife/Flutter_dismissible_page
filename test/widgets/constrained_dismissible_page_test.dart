import 'package:dismissible_page/dismissible_page.dart';
import 'package:dismissible_page/dismissible_page_engine.dart';
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
          builder: (context, controller) => SingleChildScrollView(
            controller: controller,
            child: const SizedBox(height: 2200, child: FlutterLogo()),
          ),
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
}
