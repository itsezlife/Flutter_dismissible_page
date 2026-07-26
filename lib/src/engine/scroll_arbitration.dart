import 'package:dismissible_page/src/engine/dismiss_directions.dart';
import 'package:flutter/widgets.dart';

/// Nested scrollable extents consulted by Scroll Arbitration.
@immutable
final class ScrollExtentMetrics {
  /// Creates metrics from the scrollable's current extents.
  const ScrollExtentMetrics({
    required this.pixels,
    required this.minScrollExtent,
    required this.maxScrollExtent,
  });

  /// Creates metrics from a Flutter [ScrollMetrics] snapshot.
  factory ScrollExtentMetrics.fromScrollMetrics(ScrollMetrics metrics) =>
      ScrollExtentMetrics(
        pixels: metrics.pixels,
        minScrollExtent: metrics.minScrollExtent,
        maxScrollExtent: metrics.maxScrollExtent,
      );

  /// Current scroll offset.
  final double pixels;

  /// Minimum scroll offset.
  final double minScrollExtent;

  /// Maximum scroll offset.
  final double maxScrollExtent;

  /// Whether [pixels] is at or beyond the minimum extent.
  bool get isAtMinExtent => pixels <= minScrollExtent;

  /// Whether [pixels] is at or beyond the maximum extent.
  bool get isAtMaxExtent => pixels >= maxScrollExtent;

  /// Whether [delta] should be consumed as Free Motion dismissal instead of
  /// inner scroll.
  ///
  /// Free Motion has no Dismiss Directions filter: any [delta] the nested
  /// scrollable cannot consume at its boundary becomes dismissal movement.
  /// [delta] is in scroll-space (`ScrollPosition.applyUserOffset` units).
  bool shouldConsumeFreeScrollDelta(double delta) {
    if (delta == 0) return false;
    return delta > 0 ? isAtMinExtent : isAtMaxExtent;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScrollExtentMetrics &&
          pixels == other.pixels &&
          minScrollExtent == other.minScrollExtent &&
          maxScrollExtent == other.maxScrollExtent;

  @override
  int get hashCode => Object.hash(pixels, minScrollExtent, maxScrollExtent);

  @override
  String toString() =>
      'ScrollExtentMetrics('
      'pixels: $pixels, '
      'minScrollExtent: $minScrollExtent, '
      'maxScrollExtent: $maxScrollExtent)';
}

/// Scroll-vs-dismiss arbitration for Constrained Motion.
extension ScrollArbitration on DismissDirections {
  /// Whether [delta] targets a permitted atomic dismiss side.
  ///
  /// [delta] is in scroll-space (`ScrollPosition.applyUserOffset` units):
  /// Flutter has already normalized axis direction (including RTL reverse).
  /// [textDirection] only maps that signed delta onto reading-relative atoms.
  bool targetsPermittedDismissSide({
    required double delta,
    required Axis scrollAxis,
    required TextDirection textDirection,
  }) {
    final side = _sideForScrollDelta(
      delta: delta,
      scrollAxis: scrollAxis,
      textDirection: textDirection,
    );
    return switch (side) {
      final side? => contains(side),
      null => false,
    };
  }

  /// Whether [delta] should be consumed as dismissal instead of inner scroll.
  ///
  /// Consumes only when the attempted atomic side is permitted and the nested
  /// scrollable cannot consume [delta] at its boundary for that side.
  ///
  /// [delta] is in scroll-space (`ScrollPosition.applyUserOffset` units).
  /// See [targetsPermittedDismissSide].
  bool shouldConsumeScrollDelta({
    required double delta,
    required ScrollExtentMetrics metrics,
    required Axis scrollAxis,
    required TextDirection textDirection,
  }) {
    if (!targetsPermittedDismissSide(
      delta: delta,
      scrollAxis: scrollAxis,
      textDirection: textDirection,
    )) {
      return false;
    }

    return delta > 0 ? metrics.isAtMinExtent : metrics.isAtMaxExtent;
  }

  /// Whether [delta] should be consumed as horizontal pager-axis dismissal.
  ///
  /// Same edge and Dismiss Directions rules as [shouldConsumeScrollDelta],
  /// plus a settled whole-page gate: a half-turned page never starts
  /// pager-axis dismissal. MVP locks the pager axis to horizontal.
  ///
  /// [delta] is in scroll-space (`ScrollPosition.applyUserOffset` units).
  bool shouldConsumePagerScrollDelta({
    required double delta,
    required ScrollExtentMetrics metrics,
    required TextDirection textDirection,
    required bool isSettledOnWholePage,
  }) {
    if (!isSettledOnWholePage) return false;
    return shouldConsumeScrollDelta(
      delta: delta,
      metrics: metrics,
      scrollAxis: Axis.horizontal,
      textDirection: textDirection,
    );
  }

  DismissDirections? _sideForScrollDelta({
    required double delta,
    required Axis scrollAxis,
    required TextDirection textDirection,
  }) {
    if (delta == 0 || !allowsDragDismissal) return null;

    return switch ((scrollAxis, textDirection, delta > 0)) {
      (Axis.vertical, _, true) => DismissDirections.down,
      (Axis.vertical, _, false) => DismissDirections.up,
      (Axis.horizontal, TextDirection.ltr, true) =>
        DismissDirections.startToEnd,
      (Axis.horizontal, TextDirection.ltr, false) =>
        DismissDirections.endToStart,
      (Axis.horizontal, TextDirection.rtl, true) =>
        DismissDirections.endToStart,
      (Axis.horizontal, TextDirection.rtl, false) =>
        DismissDirections.startToEnd,
    };
  }
}
