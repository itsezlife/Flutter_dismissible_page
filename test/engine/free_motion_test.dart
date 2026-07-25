import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Free Motion', () {
    test('progress is the dominant axis fraction of the bounds', () {
      const bounds = Size(800, 600);

      // 80 / 800 = 0.1 horizontally, no vertical movement.
      expect(const FreeMotion(Offset(80, 0)).progressIn(bounds), 0.1);
      // 300 / 600 = 0.5 vertically, sign does not matter.
      expect(const FreeMotion(Offset(0, -300)).progressIn(bounds), 0.5);
      // Diagonal: the dominant fraction wins (0.5 over 0.1).
      expect(const FreeMotion(Offset(80, -300)).progressIn(bounds), 0.5);
    });

    test('one threshold decides dismiss versus reverse', () {
      const bounds = Size(800, 600);

      // 90 / 600 = 0.15 — reaching the default threshold dismisses.
      expect(
        const FreeMotion(Offset(0, 90)).decide(
          bounds: bounds,
          threshold: kDismissThreshold,
        ),
        DismissDecision.dismiss,
      );
      expect(
        const FreeMotion(Offset(0, 89)).decide(
          bounds: bounds,
          threshold: kDismissThreshold,
        ),
        DismissDecision.reverse,
      );
      // A custom threshold applies to the free-plane gesture as a whole:
      // 200 / 600 ≈ 0.33 falls short of 0.5.
      expect(
        const FreeMotion(Offset(200, 200)).decide(
          bounds: bounds,
          threshold: 0.5,
        ),
        DismissDecision.reverse,
      );
    });
  });
}
