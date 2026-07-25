import 'package:dismissible_page/src/engine/dismiss_constants.dart';
import 'package:dismissible_page/src/engine/dismiss_directions.dart';
import 'package:flutter/widgets.dart';

/// The settle action selected when a dismiss gesture ends.
///
/// Shared by Constrained and Free Motion: Constrained decides via
/// [AxisLock.decide]; Free Motion decides via `FreeMotion.decide`.
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
    required DismissDirections positiveSide,
    required DismissDirections negativeSide,
  }) : _positiveSide = positiveSide,
       _negativeSide = negativeSide;

  /// The only axis along which the gesture may move.
  final Axis axis;

  /// The atomic dismiss side selected when the axis was locked.
  ///
  /// After lock, the side that decides dismiss-vs-reverse follows the sign of
  /// the current extent — see [sideFor].
  final DismissDirections side;

  final DismissDirections _positiveSide;
  final DismissDirections _negativeSide;

  /// The atomic side that currently applies for a signed [extent].
  ///
  /// At origin, returns the side selected when the axis was locked.
  DismissDirections sideFor(double extent) => switch (extent) {
    > 0 => _positiveSide,
    < 0 => _negativeSide,
    _ => side,
  };

  /// Decides whether [progress] completes or reverses this locked gesture.
  ///
  /// [extent] selects which atomic side's threshold applies (sign-follows
  /// extent). At origin, the initially locked [side] is used.
  DismissDecision decide({
    required double progress,
    required double extent,
    required DismissThresholds thresholds,
  }) {
    assert(
      progress >= 0 && progress <= 1,
      'progress must be between 0 and 1',
    );
    return progress >= thresholds._forSide(sideFor(extent))
        ? DismissDecision.dismiss
        : DismissDecision.reverse;
  }

  /// Projects [delta] onto the locked axis given [currentExtent].
  ///
  /// Cross-axis components are discarded. Reverse toward origin is applied.
  /// When both atomic sides of the locked axis are permitted by [directions],
  /// the gesture may cross origin into the other side. When only one side is
  /// permitted, the resulting extent clamps at origin.
  Offset constrain(
    Offset delta, {
    required double currentExtent,
    required DismissDirections directions,
  }) {
    final primaryDelta = switch (axis) {
      Axis.horizontal => delta.dx,
      Axis.vertical => delta.dy,
    };
    if (primaryDelta == 0) return Offset.zero;

    final proposed = currentExtent + primaryDelta;
    final allowPositive = directions.contains(_positiveSide);
    final allowNegative = directions.contains(_negativeSide);
    final clamped = proposed.clamp(
      allowNegative ? double.negativeInfinity : 0.0,
      allowPositive ? double.infinity : 0.0,
    );
    final applied = clamped - currentExtent;
    if (applied == 0) return Offset.zero;

    return switch (axis) {
      Axis.horizontal => Offset(applied, 0),
      Axis.vertical => Offset(0, applied),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AxisLock &&
          axis == other.axis &&
          side == other.side &&
          _positiveSide == other._positiveSide &&
          _negativeSide == other._negativeSide;

  @override
  int get hashCode => Object.hash(axis, side, _positiveSide, _negativeSide);

  @override
  String toString() =>
      'AxisLock(axis: $axis, side: $side, '
      'positiveSide: $_positiveSide, negativeSide: $_negativeSide)';
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

    final (positiveSide, negativeSide) = switch ((axis, textDirection)) {
      (Axis.vertical, _) => (
        DismissDirections.down,
        DismissDirections.up,
      ),
      (Axis.horizontal, TextDirection.ltr) => (
        DismissDirections.startToEnd,
        DismissDirections.endToStart,
      ),
      (Axis.horizontal, TextDirection.rtl) => (
        DismissDirections.endToStart,
        DismissDirections.startToEnd,
      ),
    };

    final primaryDelta = switch (axis) {
      Axis.horizontal => delta.dx,
      Axis.vertical => delta.dy,
    };
    final side = switch (primaryDelta) {
      > 0 => positiveSide,
      < 0 => negativeSide,
      _ => null,
    };

    return switch (side) {
      final side? when contains(side) => AxisLock._(
        axis: axis,
        side: side,
        positiveSide: positiveSide,
        negativeSide: negativeSide,
      ),
      _ => null,
    };
  }
}
