import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Helper function to build a [DismissiblePage] with scrollable content for
  /// testing scroll behavior between page dismissal and inner
  /// scrolling
  Widget buildScrollableDismissible({
    required DismissiblePageDismissDirection direction,
    required DismissiblePageInteractionMode interactionMode,
    required ValueChanged<DismissiblePageDragUpdateDetails> onDragUpdate,
    required ValueChanged<ScrollController> onControllerCreated,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DismissiblePage(
          direction: direction,
          interactionMode: interactionMode,
          onDismissed: () {},
          onDragUpdate: onDragUpdate,
          builder: (context, controller) {
            // Pass the scroll controller back to the test for verification
            onControllerCreated(controller);
            return SingleChildScrollView(
              controller: controller,
              // Create tall content that requires scrolling (2200px height)
              child: const SizedBox(height: 2200, child: FlutterLogo()),
            );
          },
        ),
      ),
    );
  }

  /// Test that DismissiblePage creates a SingleAxisDismissiblePage by default
  /// (when direction is not multi)
  testWidgets('Should create SingleAxisDismissiblePage', (tester) async {
    await tester.pumpWidget(
      DismissiblePage(
        onDismissed: () {},
        interactionMode: DismissiblePageInteractionMode.gesture,
        builder: (context, scrollController) => const FlutterLogo(),
      ),
    );

    // Verify the correct internal widget type is created
    expect(find.byType(SingleAxisDismissiblePage), findsOneWidget);
    expect(find.byType(MultiAxisDismissiblePage), findsNothing);
  });

  /// Test that DismissiblePage creates a MultiAxisDismissiblePage when
  /// direction is set to multi
  testWidgets('Should create MultiAxisDismissiblePage', (tester) async {
    await tester.pumpWidget(
      DismissiblePage(
        direction: DismissiblePageDismissDirection.multi,
        onDismissed: () {},
        interactionMode: DismissiblePageInteractionMode.gesture,
        builder: (context, scrollController) => const FlutterLogo(),
      ),
    );

    // Verify the correct internal widget type is created for multi-axis
    expect(find.byType(SingleAxisDismissiblePage), findsNothing);
    expect(find.byType(MultiAxisDismissiblePage), findsOneWidget);
  });

  /// Test that when disabled=true, drag-to-dismiss is ignored while the page
  /// widget remains.
  testWidgets('disabled ignores drag-to-dismiss', (tester) async {
    var dragValue = 0.0;
    var dismissed = false;

    await tester.pumpWidget(
      DismissiblePage(
        onDismissed: () => dismissed = true,
        backgroundColor: Colors.greenAccent,
        disabled: true,
        onDragUpdate: (value) => dragValue = value.overallDragValue,
        interactionMode: DismissiblePageInteractionMode.gesture,
        builder: (context, scrollController) => const FlutterLogo(),
      ),
    );

    expect(find.byType(SingleAxisDismissiblePage), findsOneWidget);

    await tester.drag(find.byType(DismissiblePage), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(dragValue, 0.0);
    expect(dismissed, isFalse);
  });

  /// Test that the [onDragUpdate] callback is properly invoked during drag
  /// gestures and provides meaningful drag values
  /// and provides meaningful drag values
  testWidgets('onDragUpdate is called', (tester) async {
    var dragValue = 0.0;

    await tester.pumpWidget(
      DismissiblePage(
        onDismissed: () {},
        // Capture the drag value from the callback
        onDragUpdate: (value) => dragValue = value.overallDragValue,
        interactionMode: DismissiblePageInteractionMode.gesture,
        builder: (context, scrollController) => const FlutterLogo(),
      ),
    );

    // Initially, no drag should have occurred
    expect(dragValue, 0.0);

    // Perform a drag gesture on the dismissible page
    await tester.drag(find.byType(DismissiblePage), const Offset(100, 100));

    // Verify the drag callback was called and provided a non-zero value
    expect(dragValue, isNot(equals(0.0)));
  });

  /// Test scroll arbitration behavior for single-axis dismissible pages:
  /// - Downward drags should trigger page dismissal (not inner scroll)
  /// - Upward drags should first return the page to origin, then allow inner
  /// scrolling
  testWidgets(
    'scroll single-axis returns page before inner scroll',
    (tester) async {
      ScrollController? scrollController;

      await tester.pumpWidget(
        buildScrollableDismissible(
          direction: DismissiblePageDismissDirection.vertical,
          interactionMode: DismissiblePageInteractionMode.scroll,
          onDragUpdate: (_) {},
          onControllerCreated: (controller) {
            scrollController ??= controller;
          },
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);

      // Downward drag should trigger page dismissal, not inner scroll
      await tester.drag(scrollableFinder, const Offset(0, 120));
      await tester.pump();
      expect(scrollController!.offset, 0); // Inner scroll should remain at 0

      // First upward drag should return page to origin and start inner
      // scrolling
      await tester.drag(scrollableFinder, const Offset(0, -60));
      await tester.pump();
      final secondDragOffset = scrollController!.offset;
      expect(
        secondDragOffset,
        greaterThan(0),
      ); // Inner scroll should have started

      // Additional upward drag should continue inner scrolling
      await tester.drag(scrollableFinder, const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(scrollController!.offset, greaterThan(secondDragOffset));
    },
  );

  /// Test scroll arbitration behavior for multi-axis dismissible pages:
  /// - All drag directions should trigger page dismissal
  /// - Inner scrolling should be completely prevented in multi-axis mode
  testWidgets(
    'scroll multi-axis returns page before inner scroll',
    (tester) async {
      ScrollController? scrollController;

      await tester.pumpWidget(
        buildScrollableDismissible(
          direction: DismissiblePageDismissDirection.multi,
          interactionMode: DismissiblePageInteractionMode.scroll,
          onDragUpdate: (_) {},
          onControllerCreated: (controller) {
            scrollController ??= controller;
          },
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);

      // Downward drag should trigger page dismissal, not inner scroll
      await tester.drag(scrollableFinder, const Offset(0, 120));
      await tester.pump();
      expect(scrollController!.offset, 0);

      // Upward drag should also trigger page dismissal, not inner scroll
      await tester.drag(scrollableFinder, const Offset(0, -60));
      await tester.pump();
      expect(scrollController!.offset, 0); // Should remain 0 in multi-axis mode

      // Large upward drag should still not trigger inner scrolling
      await tester.drag(scrollableFinder, const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(
        scrollController!.offset,
        0,
      ); // Should still be 0 in multi-axis mode
    },
  );
}
