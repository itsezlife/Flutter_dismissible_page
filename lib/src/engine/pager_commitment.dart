import 'package:flutter/foundation.dart';

/// Per-gesture choice between page scrolling and dismissal on a pager's axis.
///
/// The default [lockedUntilRelease] locks the choice from the first meaningful
/// delta until gesture release. [handoffAtOrigin] allows list-like handoff
/// when a dismiss reverse returns to origin (dismiss → page scroll only).
enum PagerCommitment {
  /// Choice locks for the whole gesture (default).
  lockedUntilRelease,

  /// Dismiss may hand off to paging when reverse reaches origin.
  handoffAtOrigin,
}

/// How the current pager-axis delta should be applied.
enum PagerAxisDisposition {
  /// Drive the pager's page scroll.
  pageScroll,

  /// Drive pager-axis dismissal.
  dismiss,
}

/// Immutable per-gesture Pager Commitment memory.
///
/// Backed by the locked [PagerAxisDisposition], or `null` while undecided.
extension type const PagerCommitmentState(PagerAxisDisposition? disposition) {
  /// No choice yet for this gesture.
  const PagerCommitmentState.undecided() : this(null);

  /// State after the pointer is released.
  PagerCommitmentState afterRelease() => const PagerCommitmentState.undecided();
}

/// Result of applying one delta under a [PagerCommitment] policy.
@immutable
final class PagerCommitmentDecision {
  /// Creates a decision with the disposition for this delta and next state.
  const PagerCommitmentDecision({
    required this.disposition,
    required this.next,
  });

  /// How this delta should be applied.
  final PagerAxisDisposition disposition;

  /// Commitment state to carry into the next delta.
  final PagerCommitmentState next;
}

/// Pager Commitment transitions for a gesture.
extension PagerCommitmentPolicy on PagerCommitment {
  /// Resolves how [eligibleForDismiss] applies under this policy.
  ///
  /// Call only for a meaningful (non-noise) pager-axis delta; the first such
  /// call locks the choice. [dismissExtentIsAtOrigin] is true when dismiss
  /// drag extent is at rest (≈ 0). Feed [PagerCommitmentState] from the
  /// previous decision (or [PagerCommitmentState.undecided] /
  /// [PagerCommitmentState.afterRelease] at gesture start).
  PagerCommitmentDecision decide(
    PagerCommitmentState current, {
    required bool eligibleForDismiss,
    required bool dismissExtentIsAtOrigin,
  }) {
    return switch (this) {
      PagerCommitment.lockedUntilRelease => _decideLocked(
        current,
        eligibleForDismiss: eligibleForDismiss,
      ),
      PagerCommitment.handoffAtOrigin => _decideHandoff(
        current,
        eligibleForDismiss: eligibleForDismiss,
        dismissExtentIsAtOrigin: dismissExtentIsAtOrigin,
      ),
    };
  }

  PagerCommitmentDecision _decideLocked(
    PagerCommitmentState current, {
    required bool eligibleForDismiss,
  }) {
    return switch (current.disposition) {
      final locked? => PagerCommitmentDecision(
        disposition: locked,
        next: current,
      ),
      null => _lockInitial(eligibleForDismiss: eligibleForDismiss),
    };
  }

  PagerCommitmentDecision _decideHandoff(
    PagerCommitmentState current, {
    required bool eligibleForDismiss,
    required bool dismissExtentIsAtOrigin,
  }) {
    return switch (current.disposition) {
      // Dismiss reverse reached origin and this delta is not edge-dismiss:
      // hand off to page scrolling (list-like). Page scroll stays locked —
      // handoff does not unlock paging → dismiss mid-gesture.
      PagerAxisDisposition.dismiss
          when dismissExtentIsAtOrigin && !eligibleForDismiss =>
        _lockInitial(eligibleForDismiss: false),
      final locked? => PagerCommitmentDecision(
        disposition: locked,
        next: current,
      ),
      null => _lockInitial(eligibleForDismiss: eligibleForDismiss),
    };
  }

  PagerCommitmentDecision _lockInitial({required bool eligibleForDismiss}) {
    final disposition = eligibleForDismiss
        ? PagerAxisDisposition.dismiss
        : PagerAxisDisposition.pageScroll;
    return PagerCommitmentDecision(
      disposition: disposition,
      next: PagerCommitmentState(disposition),
    );
  }
}
