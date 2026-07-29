import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Package default Shape Strategy: Shape Snap from rest radius 0 to dragged 30.
const DismissiblePageShape kDefaultDismissiblePageShape =
    DismissiblePageShape.snap(
      rest: RoundedRectangleBorder(),
      dragged: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
    );

/// How Page Shape is produced from Drag Progress.
///
/// Either library-managed [DismissiblePageShape.snap] between a rest and
/// dragged outline, or a caller-managed [DismissiblePageShape.builder].
@immutable
sealed class DismissiblePageShape {
  /// Creates a Shape Strategy.
  const DismissiblePageShape();

  /// Shape Snap: keep [rest] while progress is at or below [threshold], then
  /// jump to [dragged] for the rest of the gesture.
  const factory DismissiblePageShape.snap({
    required ShapeBorder rest,
    required ShapeBorder dragged,
    double threshold,
  }) = DismissiblePageShapeSnap;

  /// Caller-managed mapping from Drag Progress to Page Shape.
  const factory DismissiblePageShape.builder(
    ShapeBorder Function(double progress) build,
  ) = DismissiblePageShapeBuilder;

  /// Resolves the Page Shape for [progress] in `0.0`–`1.0`.
  ShapeBorder resolve(double progress);
}

/// Library-managed Shape Snap between [rest] and [dragged].
@immutable
final class DismissiblePageShapeSnap extends DismissiblePageShape {
  /// Creates a Shape Snap strategy.
  const DismissiblePageShapeSnap({
    required this.rest,
    required this.dragged,
    this.threshold = 1e-6,
  });

  /// Page Shape while Drag Progress is at or below [threshold].
  final ShapeBorder rest;

  /// Page Shape once Drag Progress exceeds [threshold].
  final ShapeBorder dragged;

  /// Drag Progress at or below which [rest] remains; above this, [dragged].
  final double threshold;

  @override
  ShapeBorder resolve(double progress) =>
      progress <= threshold ? rest : dragged;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DismissiblePageShapeSnap &&
          rest == other.rest &&
          dragged == other.dragged &&
          threshold == other.threshold;

  @override
  int get hashCode => Object.hash(rest, dragged, threshold);

  @override
  String toString() =>
      'DismissiblePageShape.snap('
      'rest: $rest, '
      'dragged: $dragged, '
      'threshold: $threshold)';
}

/// Caller-managed progress → Page Shape mapping.
@immutable
final class DismissiblePageShapeBuilder extends DismissiblePageShape {
  /// Creates a builder Shape Strategy.
  const DismissiblePageShapeBuilder(this.build);

  /// Maps Drag Progress to a Page Shape.
  final ShapeBorder Function(double progress) build;

  @override
  ShapeBorder resolve(double progress) => build(progress);

  @override
  String toString() => 'DismissiblePageShape.builder(...)';
}
