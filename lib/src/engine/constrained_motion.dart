import 'package:dismissible_page/src/engine/dismiss_constants.dart';
import 'package:dismissible_page/src/engine/dismiss_directions.dart';
import 'package:flutter/widgets.dart';

/// The settle action selected when a Constrained gesture ends.
enum DismissDecision {
  /// Complete the dismissal.
  dismiss,

  /// Return the page to its resting position.
  reverse,
}

/// Per-atomic-side progress thresholds for Constrained Motion.
@immutable
final class DismissThresholds {
  /// Creates thresholds for each atomic dismiss side.
  const DismissThresholds({
    this.up = kDismissThreshold,
    this.down = kDismissThreshold,
    this.startToEnd = kDismissThreshold,
    this.endToStart = kDismissThreshold,
  }) : assert(up >= 0 && up <= 1, 'up must be between 0 and 1'),
       assert(down >= 0 && down <= 1, 'down must be between 0 and 1'),
       assert(
         startToEnd >= 0 && startToEnd <= 1,
         'startToEnd must be between 0 and 1',
       ),
       assert(
         endToStart >= 0 && endToStart <= 1,
         'endToStart must be between 0 and 1',
       );

  /// Threshold for upward dismissal.
  final double up;

  /// Threshold for downward dismissal.
  final double down;

  /// Threshold for dismissal in the reading direction.
  final double startToEnd;

  /// Threshold for dismissal opposite the reading direction.
  final double endToStart;

  double _forSide(DismissDirections side) => switch (side) {
    DismissDirections.up => up,
    DismissDirections.down => down,
    DismissDirections.startToEnd => startToEnd,
    DismissDirections.endToStart => endToStart,
    _ => throw StateError('side must be one atomic DismissDirections value'),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DismissThresholds &&
          up == other.up &&
          down == other.down &&
          startToEnd == other.startToEnd &&
          endToStart == other.endToStart;

  @override
  int get hashCode => Object.hash(up, down, startToEnd, endToStart);

  @override
  String toString() =>
      'DismissThresholds('
      'up: $up, '
      'down: $down, '
      'startToEnd: $startToEnd, '
      'endToStart: $endToStart)';
}

/// The stable axis and atomic side selected for a Constrained gesture.
@immutable
final class AxisLock {
  const AxisLock._({
    required this.axis,
    required this.side,
    required bool positive,
  }) : _positive = positive;

  /// The only axis along which the gesture may move.
  final Axis axis;

  /// The atomic dismiss side selected when the axis was locked.
  final DismissDirections side;

  final bool _positive;

  /// Decides whether [progress] completes or reverses this locked gesture.
  DismissDecision decide({
    required double progress,
    required DismissThresholds thresholds,
  }) {
    assert(
      progress >= 0 && progress <= 1,
      'progress must be between 0 and 1',
    );
    return progress >= thresholds._forSide(side)
        ? DismissDecision.dismiss
        : DismissDecision.reverse;
  }

  /// Projects [delta] onto the locked axis when it advances the locked side.
  ///
  /// Cross-axis and opposite-side movement is discarded.
  Offset constrain(Offset delta) {
    final primaryDelta = switch (axis) {
      Axis.horizontal => delta.dx,
      Axis.vertical => delta.dy,
    };
    if (primaryDelta == 0 || (primaryDelta > 0) != _positive) {
      return Offset.zero;
    }

    return switch (axis) {
      Axis.horizontal => Offset(primaryDelta, 0),
      Axis.vertical => Offset(0, primaryDelta),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AxisLock &&
          axis == other.axis &&
          side == other.side &&
          _positive == other._positive;

  @override
  int get hashCode => Object.hash(axis, side, _positive);

  @override
  String toString() =>
      'AxisLock(axis: $axis, side: $side, positive: $_positive)';
}

/// Axis-lock behavior for Constrained Motion.
extension ConstrainedMotionDirections on DismissDirections {
  /// Resolves the stable axis and atomic side for an initial gesture [delta].
  ///
  /// When both axes are permitted, an exactly diagonal delta has no dominant
  /// axis and therefore does not lock. A delta toward a disallowed side also
  /// does not lock.
  AxisLock? resolveAxisLock({
    required Offset delta,
    required TextDirection textDirection,
  }) {
    final allowsVertical =
        contains(DismissDirections.up) || contains(DismissDirections.down);
    final allowsHorizontal =
        contains(DismissDirections.startToEnd) ||
        contains(DismissDirections.endToStart);

    final axis = switch ((allowsHorizontal, allowsVertical)) {
      (false, false) => null,
      (true, false) => Axis.horizontal,
      (false, true) => Axis.vertical,
      (true, true) when delta.dx.abs() > delta.dy.abs() => Axis.horizontal,
      (true, true) when delta.dy.abs() > delta.dx.abs() => Axis.vertical,
      (true, true) => null,
    };
    if (axis == null) return null;

    final side = switch ((axis, textDirection)) {
      (Axis.vertical, _) when delta.dy < 0 => DismissDirections.up,
      (Axis.vertical, _) when delta.dy > 0 => DismissDirections.down,
      (Axis.horizontal, TextDirection.ltr) when delta.dx > 0 =>
        DismissDirections.startToEnd,
      (Axis.horizontal, TextDirection.ltr) when delta.dx < 0 =>
        DismissDirections.endToStart,
      (Axis.horizontal, TextDirection.rtl) when delta.dx < 0 =>
        DismissDirections.startToEnd,
      (Axis.horizontal, TextDirection.rtl) when delta.dx > 0 =>
        DismissDirections.endToStart,
      _ => null,
    };

    return switch (side) {
      final side? when contains(side) => AxisLock._(
        axis: axis,
        side: side,
        positive: switch (axis) {
          Axis.horizontal => delta.dx > 0,
          Axis.vertical => delta.dy > 0,
        },
      ),
      _ => null,
    };
  }
}
