import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drag presentation mapping', () {
    test('resting progress keeps default visual bounds and passes offset', () {
      const config = DragPresentationConfig();
      final presentation = config.map(
        progress: 0,
        offset: const Offset(12, -4),
      );

      expect(presentation.progress, 0);
      expect(presentation.offset, const Offset(12, -4));
      expect(presentation.radius, 7);
      expect(presentation.opacity, 1);
      expect(presentation.scale, 1);
    });

    test('full progress reaches max radius, min opacity, and min scale', () {
      const config = DragPresentationConfig();
      final presentation = config.map(
        progress: 1,
        offset: const Offset(40, 0),
      );

      expect(presentation.progress, 1);
      expect(presentation.offset, const Offset(40, 0));
      expect(presentation.radius, 30);
      expect(presentation.opacity, 0);
      expect(presentation.scale, 0.85);
    });

    test('mid progress interpolates radius, opacity, and scale', () {
      const config = DragPresentationConfig();
      final presentation = config.map(
        progress: 0.5,
        offset: Offset.zero,
      );

      expect(presentation.radius, 18.5);
      expect(presentation.opacity, 0.5);
      expect(presentation.scale, 0.925);
    });

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
