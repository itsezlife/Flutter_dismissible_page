import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DismissDirections', () {
    test('empty set means drag dismissal is unavailable', () {
      expect(DismissDirections.empty.allowsDragDismissal, isFalse);
    });

    test('atomic sides can be combined', () {
      final directions = DismissDirections.up | DismissDirections.startToEnd;

      expect(directions.contains(DismissDirections.up), isTrue);
      expect(directions.contains(DismissDirections.startToEnd), isTrue);
      expect(directions.contains(DismissDirections.down), isFalse);
      expect(directions.contains(DismissDirections.endToStart), isFalse);
      expect(directions.allowsDragDismissal, isTrue);
    });

    test('vertical is the alias of up and down', () {
      expect(
        DismissDirections.vertical,
        DismissDirections.up | DismissDirections.down,
      );
      expect(DismissDirections.vertical.contains(DismissDirections.up), isTrue);
      expect(
        DismissDirections.vertical.contains(DismissDirections.down),
        isTrue,
      );
      expect(
        DismissDirections.vertical.contains(DismissDirections.startToEnd),
        isFalse,
      );
    });

    test('horizontal is the alias of startToEnd and endToStart', () {
      expect(
        DismissDirections.horizontal,
        DismissDirections.startToEnd | DismissDirections.endToStart,
      );
      expect(
        DismissDirections.horizontal.contains(DismissDirections.startToEnd),
        isTrue,
      );
      expect(
        DismissDirections.horizontal.contains(DismissDirections.endToStart),
        isTrue,
      );
      expect(
        DismissDirections.horizontal.contains(DismissDirections.up),
        isFalse,
      );
    });

    test('all is the alias of every atom', () {
      expect(
        DismissDirections.all,
        DismissDirections.vertical | DismissDirections.horizontal,
      );
      expect(DismissDirections.all.contains(DismissDirections.up), isTrue);
      expect(DismissDirections.all.contains(DismissDirections.down), isTrue);
      expect(
        DismissDirections.all.contains(DismissDirections.startToEnd),
        isTrue,
      );
      expect(
        DismissDirections.all.contains(DismissDirections.endToStart),
        isTrue,
      );
    });

    test('add and remove update membership immutably', () {
      const base = DismissDirections.vertical;

      final withStart = base.add(DismissDirections.startToEnd);
      expect(withStart.contains(DismissDirections.up), isTrue);
      expect(withStart.contains(DismissDirections.startToEnd), isTrue);
      expect(base.contains(DismissDirections.startToEnd), isFalse);

      final withoutUp = withStart.remove(DismissDirections.up);
      expect(withoutUp.contains(DismissDirections.up), isFalse);
      expect(withoutUp.contains(DismissDirections.down), isTrue);
      expect(withoutUp.contains(DismissDirections.startToEnd), isTrue);
      expect(withStart.contains(DismissDirections.up), isTrue);
    });
  });
}
