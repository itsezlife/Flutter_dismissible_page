import 'package:example/demo/widgets/cubic_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'CubicPageView does not dispose a parent-owned PageController',
    (tester) async {
      final controller = PageController();

      await tester.pumpWidget(
        MaterialApp(
          home: CubicPageView(
            controller: controller,
            children: const [
              SizedBox.expand(child: Text('a')),
              SizedBox.expand(child: Text('b')),
            ],
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      // Parent still owns the controller; disposing here must not throw
      // "used after being disposed" from a child double-dispose.
      expect(controller.dispose, returnsNormally);
    },
  );
}
