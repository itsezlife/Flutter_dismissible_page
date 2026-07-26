import 'dart:math';

import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_drag_update_details.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shared mutable adapter for Constrained Motion widget states.
///
/// Gesture owners remain responsible for lifecycle and animation scheduling;
/// this object owns the stable axis-lock, extent, presentation, and threshold
/// calculations shared by ordinary pages and pager pages.
@internal
final class ConstrainedDismissMotion {
  AxisLock? _lock;
  double _settleFrom = 0;

  /// Current signed dismiss extent in logical pixels.
  double extent = 0;

  /// The active axis lock, if a meaningful delta established one.
  AxisLock? get lock => _lock;

  /// Whether the current extent is effectively at rest.
  bool isAtOrigin(double epsilon) => extent.abs() <= epsilon;

  /// Whether a settling motion can be caught by a new drag on [axis].
  bool continuesSettlingAxis(Axis? axis) => axis == null || _lock?.axis == axis;

  /// Clears the active lock and extent for a new gesture.
  void reset() {
    _lock = null;
    extent = 0;
    _settleFrom = 0;
  }

  /// Applies [delta] through Constrained Motion's axis-lock rules.
  bool applyDelta(
    Offset delta, {
    required DismissDirections directions,
    required TextDirection textDirection,
  }) {
    final lock = _lock ??= directions.resolveAxisLock(
      delta: delta,
      textDirection: textDirection,
    );
    if (lock == null) return false;
    final projected = lock.constrain(
      delta,
      currentExtent: extent,
      directions: directions,
    );
    final axisDelta = switch (lock.axis) {
      Axis.horizontal => projected.dx,
      Axis.vertical => projected.dy,
    };
    if (axisDelta == 0) return false;
    extent += axisDelta;
    return true;
  }

  /// Returns whether the current extent dismisses or reverses.
  DismissDecision decide({
    required Size screenSize,
    required DismissThresholds thresholds,
  }) {
    final lock = _lock;
    if (lock == null) return DismissDecision.reverse;
    final axisExtent = _axisExtent(screenSize);
    final progress = axisExtent == 0
        ? 0.0
        : (extent.abs() / axisExtent).clamp(0.0, 1.0);
    return lock.decide(
      progress: progress,
      extent: extent,
      thresholds: thresholds,
    );
  }

  /// Captures the current extent as the start of reverse settlement.
  void beginSettle() => _settleFrom = extent;

  /// Applies eased reverse-settle progress [t].
  void settle(double t) => extent = _settleFrom * (1 - t);

  /// Maps the current extent onto public drag presentation details.
  DismissiblePageDragUpdateDetails details({
    required Size screenSize,
    required DragPresentationConfig presentationConfig,
    required double dragSensitivity,
    required double maxTransformValue,
  }) {
    final axis = _lock?.axis ?? Axis.vertical;
    final axisExtent = _axisExtent(screenSize);
    final progress = axisExtent == 0
        ? 0.0
        : (extent.abs() / axisExtent).clamp(0.0, 1.0);
    final translationFraction = (extent / axisExtent * dragSensitivity).clamp(
      -maxTransformValue,
      maxTransformValue,
    );
    final offset = switch (axis) {
      Axis.horizontal => Offset(translationFraction * screenSize.width, 0),
      Axis.vertical => Offset(0, translationFraction * screenSize.height),
    };
    final presentation = presentationConfig.map(
      progress: (progress * dragSensitivity).clamp(0.0, 1.0),
      offset: offset,
    );
    return DismissiblePageDragUpdateDetails(
      overallDragValue: min(progress, maxTransformValue),
      radius: presentation.radius,
      opacity: presentation.opacity,
      offset: presentation.offset,
      scale: presentation.scale,
    );
  }

  double _axisExtent(Size screenSize) => switch (_lock?.axis ?? Axis.vertical) {
    Axis.horizontal => screenSize.width,
    Axis.vertical => screenSize.height,
  };
}
