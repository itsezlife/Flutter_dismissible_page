import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drag presentation mapping', () {
    const defaultRestShape = RoundedRectangleBorder();
    const defaultDraggedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(30)),
    );

    test('resting progress keeps default rest shape and passes offset', () {
      const config = DragPresentationConfig();
      final presentation = config.map(
        progress: 0,
        offset: const Offset(12, -4),
      );

      expect(presentation.progress, 0);
      expect(presentation.offset, const Offset(12, -4));
      expect(presentation.shape, defaultRestShape);
      expect(presentation.opacity, 1);
      expect(presentation.scale, 1);
    });

    test(
      'default Shape Snap keeps rest at threshold then jumps to dragged',
      () {
        const config = DragPresentationConfig();

        expect(
          config.map(progress: 0.01, offset: Offset.zero).shape,
          defaultRestShape,
        );
        expect(
          config.map(progress: 0.011, offset: Offset.zero).shape,
          defaultDraggedShape,
        );
        expect(
          config.map(progress: 1, offset: const Offset(40, 0)).shape,
          defaultDraggedShape,
        );
      },
    );

    test('full progress reaches min opacity and min scale', () {
      const config = DragPresentationConfig();
      final presentation = config.map(
        progress: 1,
        offset: const Offset(40, 0),
      );

      expect(presentation.progress, 1);
      expect(presentation.offset, const Offset(40, 0));
      expect(presentation.shape, defaultDraggedShape);
      expect(presentation.opacity, 0);
      expect(presentation.scale, 0.85);
    });

    test('custom Shape Snap threshold is respected', () {
      const rest = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      );
      const dragged = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(40)),
      );
      const config = DragPresentationConfig(
        shape: DismissiblePageShape.snap(
          rest: rest,
          dragged: dragged,
          threshold: 0.25,
        ),
      );

      expect(config.map(progress: 0.25, offset: Offset.zero).shape, rest);
      expect(config.map(progress: 0.26, offset: Offset.zero).shape, dragged);
    });

    test('builder Shape Strategy returns the builder shape for progress', () {
      final shapes = <double, ShapeBorder>{
        0: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(1)),
        ),
        0.4: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        1: const CircleBorder(),
      };
      final config = DragPresentationConfig(
        shape: DismissiblePageShape.builder(
          (progress) => shapes[progress]!,
        ),
      );

      expect(config.map(progress: 0, offset: Offset.zero).shape, shapes[0]);
      expect(config.map(progress: 0.4, offset: Offset.zero).shape, shapes[0.4]);
      expect(config.map(progress: 1, offset: Offset.zero).shape, shapes[1]);
    });

    test(
      'mid progress under Shape Snap keeps dragged shape while opacity and '
      'scale still interpolate',
      () {
        const config = DragPresentationConfig();
        final presentation = config.map(
          progress: 0.5,
          offset: Offset.zero,
        );

        expect(presentation.shape, defaultDraggedShape);
        expect(presentation.opacity, 0.5);
        expect(presentation.scale, 0.925);
      },
    );

    test('opacity never falls below the configured floor', () {
      const config = DragPresentationConfig(
        minOpacity: 0.2,
      );
      final presentation = config.map(
        progress: 1,
        offset: Offset.zero,
      );

      expect(presentation.opacity, 0.2);
    });
  });
}
