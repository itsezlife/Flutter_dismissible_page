import 'package:example/demo/widgets/cubic_page_view.dart';
import 'package:example/demo/widgets/snap_scroll_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(
    PageController controller, {
    ScrollPhysics physics = const SnapScrollPhysics(),
  }) {
    return MaterialApp(
      home: CubicPageView(
        controller: controller,
        physics: physics,
        children: const [
          SizedBox.expand(child: Text('a')),
          SizedBox.expand(child: Text('b')),
        ],
      ),
    );
  }

  testWidgets(
    'CubicPageView does not dispose a parent-owned PageController',
    (tester) async {
      final controller = PageController();

      await tester.pumpWidget(wrap(controller));
      await tester.pumpWidget(const SizedBox.shrink());

      // Parent still owns the controller; disposing here must not throw
      // "used after being disposed" from a child double-dispose.
      expect(controller.dispose, returnsNormally);
    },
  );

  testWidgets('user drag past mid-page settles on the next page', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    // Wider than half a 800px test viewport so PageScrollPhysics completes.
    await tester.drag(find.byType(PageView), const Offset(-450, 0));
    await tester.pumpAndSettle();

    expect(controller.page, closeTo(1, 0.01));
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('user drag under mid-page snaps back', (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(controller.page, closeTo(0, 0.01));
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets(
    'mid-drag settles within SnapScrollPhysics snapDuration',
    (tester) async {
      const snap = Duration(milliseconds: 100);
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          controller,
          physics: const SnapScrollPhysics(snapDuration: snap),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<SnapScrollPhysics>(),
      );

      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      // Pointer-up schedules ballistic; one frame starts it, then the snap
      // window plus a frame of slack covers ticker scheduling.
      await tester.pump();
      await tester.pump(snap + const Duration(milliseconds: 16));

      expect(controller.page, closeTo(1, 0.01));
    },
  );
}
