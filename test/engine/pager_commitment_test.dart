import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pager Commitment', () {
    test(
      'locked-until-release keeps a paging gesture from becoming dismiss',
      () {
        var state = const PagerCommitmentState.undecided();

        // First meaningful delta is not dismiss-eligible → page scroll.
        var step = PagerCommitment.lockedUntilRelease.decide(
          state,
          eligibleForDismiss: false,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.pageScroll);
        state = step.next;

        // Later, at an edge and eligible — still locked to page scroll.
        step = PagerCommitment.lockedUntilRelease.decide(
          state,
          eligibleForDismiss: true,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.pageScroll);
      },
    );

    test(
      'locked-until-release keeps dismiss from becoming paging after origin',
      () {
        var state = const PagerCommitmentState.undecided();

        var step = PagerCommitment.lockedUntilRelease.decide(
          state,
          eligibleForDismiss: true,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.dismiss);
        state = step.next;

        // Reverse reaches origin and is no longer edge-eligible — still
        // dismiss.
        step = PagerCommitment.lockedUntilRelease.decide(
          state,
          eligibleForDismiss: false,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.dismiss);
      },
    );

    test(
      'handoff-at-origin releases dismiss to paging when reverse reaches '
      'origin',
      () {
        var state = const PagerCommitmentState.undecided();

        var step = PagerCommitment.handoffAtOrigin.decide(
          state,
          eligibleForDismiss: true,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.dismiss);
        state = step.next;

        // Still dismissing while extent is away from origin.
        step = PagerCommitment.handoffAtOrigin.decide(
          state,
          eligibleForDismiss: false,
          dismissExtentIsAtOrigin: false,
        );
        expect(step.disposition, PagerAxisDisposition.dismiss);
        state = step.next;

        // At origin and no longer eligible → hand off to page scroll.
        step = PagerCommitment.handoffAtOrigin.decide(
          state,
          eligibleForDismiss: false,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.pageScroll);
      },
    );

    test(
      'handoff-at-origin keeps paging from becoming dismiss mid-gesture',
      () {
        var state = const PagerCommitmentState.undecided();

        var step = PagerCommitment.handoffAtOrigin.decide(
          state,
          eligibleForDismiss: false,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.pageScroll);
        state = step.next;

        step = PagerCommitment.handoffAtOrigin.decide(
          state,
          eligibleForDismiss: true,
          dismissExtentIsAtOrigin: true,
        );
        expect(step.disposition, PagerAxisDisposition.pageScroll);
      },
    );

    test('afterRelease clears commitment for a new gesture', () {
      var state = const PagerCommitmentState.undecided();
      final step = PagerCommitment.lockedUntilRelease.decide(
        state,
        eligibleForDismiss: false,
        dismissExtentIsAtOrigin: true,
      );
      expect(step.disposition, PagerAxisDisposition.pageScroll);

      state = step.next.afterRelease();
      final nextGesture = PagerCommitment.lockedUntilRelease.decide(
        state,
        eligibleForDismiss: true,
        dismissExtentIsAtOrigin: true,
      );
      expect(nextGesture.disposition, PagerAxisDisposition.dismiss);
    });
  });
}
