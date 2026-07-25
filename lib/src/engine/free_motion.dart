import 'dart:math';
import 'dart:ui';

import 'package:dismissible_page/src/engine/constrained_motion.dart';

/// A full-plane (2D) drag offset for Free Motion.
///
/// Free Motion is independent of Dismiss Directions and Axis Lock: the whole
/// gesture plane participates, and a single Dismiss Threshold applies.
extension type const FreeMotion(Offset offset) {
  /// Free-plane drag progress (0.0–1.0) within [bounds].
  ///
  /// The dominant axis fraction wins: the larger of the horizontal and
  /// vertical distances relative to the corresponding bounds dimension.
  double progressIn(Size bounds) {
    final horizontal = bounds.width == 0
        ? 0.0
        : offset.dx.abs() / bounds.width;
    final vertical = bounds.height == 0
        ? 0.0
        : offset.dy.abs() / bounds.height;
    return max(horizontal, vertical).clamp(0.0, 1.0);
  }

  /// Decides whether this free-plane gesture completes or reverses.
  ///
  /// [threshold] is the single Dismiss Threshold (0.0–1.0) compared against
  /// [progressIn] for [bounds].
  DismissDecision decide({
    required Size bounds,
    required double threshold,
  }) {
    assert(
      threshold >= 0 && threshold <= 1,
      'threshold must be between 0 and 1',
    );
    return progressIn(bounds) >= threshold
        ? DismissDecision.dismiss
        : DismissDecision.reverse;
  }
}
