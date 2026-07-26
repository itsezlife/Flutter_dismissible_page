# Pager-axis dismiss gating: clamp at origin, and a pager-axis-only settled gate

Next to a pager, a committed pager-axis dismissal clamps at origin by default (`PagerOriginCrossing.clampAtOrigin`), even when Dismiss Directions permit both pager-axis sides: permitting both sides means an edge dismissal at each end, not a mid-gesture flip between them, which at an edge page is neither meaningful nor convenient. Crossing is opt-in per page view. Correspondingly, the Pager Commitment settled gate applies to the pager axis only — off-pager-axis dismissal may start while a page is still settling and runs concurrently with that settle. A configurable Edge Dismiss Cool-down (300ms default) after user paging keeps gesture spamming from landing on an accidental edge dismissal.

## Considered Options

- **Let Axis Lock's crossing apply as-is on the pager axis** — rejected as the default. It is correct on an ordinary Constrained Dismissible Page, but on a pager the opposite side is the paging-adjacent one, so crossing reads as a bug rather than a feature. Kept as `crossToOppositeSide`.
- **A third `PagerCommitment` value for crossing** — rejected. Pager Commitment arbitrates page-scroll against dismiss; Origin Crossing arbitrates one dismiss side against the other. Folding them together would make two independent axes of behavior share one enum.
- **Express the restriction only through Dismiss Directions** — rejected: it cannot say "both edges may dismiss, but not within one gesture."
- **Gate all dismissal on the pager being settled** — rejected. It buys nothing off the pager axis and produces a dead gesture whenever a user swipes during the settle, which is the failure mode a stories-style vertical dismiss most needs to avoid.
- **End the settle by jumping to the nearest page when an off-axis dismiss wins** — rejected for the visible jump; concurrent motion is coherent because the dismissal transforms the page while the settle transforms the pager's contents.
- **A recognizer biased toward the off-pager axis** — rejected for now. The shell already uses axis-specific recognizers rather than a pan recognizer, so stock arena competition resolves by dominant axis, matching Axis Lock's own rule.

## Consequences

- `clampAtOrigin` needs no new engine surface: the page view constrains against the locked atom, and `AxisLock`'s existing single-side clamp applies.
- Under `clampAtOrigin` with `handoffAtOrigin`, reversing to origin hands off to paging, since no opposite dismiss side can be entered.
- Edge Dismiss Cool-down lives in the engine as a value type over explicit timestamps; the forked page position stamps user paging activity, and programmatic page changes deliberately do not.
