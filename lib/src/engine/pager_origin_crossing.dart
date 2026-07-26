/// Whether a committed pager-axis dismissal may cross origin into the other
/// permitted pager-axis side.
///
/// Default [clampAtOrigin] means allowing both pager-axis sides grants an edge
/// dismissal at each end without a mid-gesture flip. [crossToOppositeSide]
/// restores Axis Lock's ordinary crossing behavior.
enum PagerOriginCrossing {
  /// Clamp at origin; the opposite pager-axis side needs a new gesture.
  clampAtOrigin,

  /// Allow the gesture to cross origin into the other permitted side.
  crossToOppositeSide,
}
