import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Edge Dismiss Cool-down', () {
    const window = Duration(milliseconds: 300);
    const cooldown = EdgeDismissCooldown(window);
    final t0 = DateTime.utc(2026);

    test('a pager that has not been paged is armed immediately', () {
      expect(
        cooldown.isArmed(now: t0),
        isTrue,
      );
    });

    test('is disarmed while the quiet interval has not elapsed', () {
      expect(
        cooldown.isArmed(
          now: t0.add(const Duration(milliseconds: 299)),
          lastUserPagingActivity: t0,
        ),
        isFalse,
      );
    });

    test('re-arms once the quiet interval elapses', () {
      expect(
        cooldown.isArmed(
          now: t0.add(window),
          lastUserPagingActivity: t0,
        ),
        isTrue,
      );
    });
  });
}
