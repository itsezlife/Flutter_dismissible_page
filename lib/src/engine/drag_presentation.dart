import 'dart:ui' show Offset, lerpDouble;

import 'package:flutter/foundation.dart';

/// Visual bounds used to map drag progress into presentation details.
@immutable
final class DragPresentationConfig {
  /// Creates presentation bounds matching the package's historical defaults.
  const DragPresentationConfig({
    this.minRadius = 7,
    this.maxRadius = 30,
    this.minScale = 0.85,
    this.startingOpacity = 1,
    this.minOpacity = 0,
  });

  /// Border radius at progress 0.
  final double minRadius;

  /// Border radius at progress 1.
  final double maxRadius;

  /// Content scale at progress 1 (progress 0 is always 1.0).
  final double minScale;

  /// Background opacity at progress 0.
  final double startingOpacity;

  /// Floor for background opacity as progress increases.
  final double minOpacity;

  /// Maps [progress] and gesture [offset] to deterministic presentation
  /// details.
  DragPresentation map({
    required double progress,
    required Offset offset,
  }) {
    assert(
      progress >= 0 && progress <= 1,
      'progress must be between 0 and 1',
    );
    return DragPresentation(
      progress: progress,
      offset: offset,
      radius: lerpDouble(minRadius, maxRadius, progress)!,
      opacity: lerpDouble(
        startingOpacity,
        minOpacity,
        progress,
      )!.clamp(minOpacity, 1.0),
      scale: lerpDouble(1, minScale, progress)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DragPresentationConfig &&
          minRadius == other.minRadius &&
          maxRadius == other.maxRadius &&
          minScale == other.minScale &&
          startingOpacity == other.startingOpacity &&
          minOpacity == other.minOpacity;

  @override
  int get hashCode => Object.hash(
    minRadius,
    maxRadius,
    minScale,
    startingOpacity,
    minOpacity,
  );

  @override
  String toString() =>
      'DragPresentationConfig('
      'minRadius: $minRadius, '
      'maxRadius: $maxRadius, '
      'minScale: $minScale, '
      'startingOpacity: $startingOpacity, '
      'minOpacity: $minOpacity)';
}

/// Already-computed visual details for a dismissible drag frame.
@immutable
final class DragPresentation {
  /// Creates a drag presentation snapshot.
  const DragPresentation({
    required this.progress,
    required this.offset,
    required this.radius,
    required this.opacity,
    required this.scale,
  });

  /// Drag progress in the range 0.0–1.0.
  final double progress;

  /// Gesture translation for this frame.
  final Offset offset;

  /// Border radius for this frame.
  final double radius;

  /// Background opacity for this frame.
  final double opacity;

  /// Content scale for this frame.
  final double scale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DragPresentation &&
          progress == other.progress &&
          offset == other.offset &&
          radius == other.radius &&
          opacity == other.opacity &&
          scale == other.scale;

  @override
  int get hashCode => Object.hash(progress, offset, radius, opacity, scale);

  @override
  String toString() =>
      'DragPresentation('
      'progress: $progress, '
      'offset: $offset, '
      'radius: $radius, '
      'opacity: $opacity, '
      'scale: $scale)';
}
