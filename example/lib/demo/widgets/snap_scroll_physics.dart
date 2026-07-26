import 'package:flutter/widgets.dart';

/// Snaps from [start] to [end] over `durationSeconds` using [curve].
///
/// Pure easing — no spring physics, no oscillation.
class CurvedPageSnapSimulation extends Simulation {
  /// Creates a fixed-duration curved page snap.
  CurvedPageSnapSimulation({
    required this.start,
    required this.end,
    required double durationSeconds,
    this.curve = Curves.easeOutCubic,
  }) : _duration = durationSeconds;

  /// Pixel offset at the start of the snap.
  final double start;

  /// Pixel offset at the end of the snap.
  final double end;

  /// Easing curve applied over the duration.
  final Curve curve;

  final double _duration;

  @override
  double x(double time) {
    final t = (time / _duration).clamp(0.0, 1.0);
    return start + (end - start) * curve.transform(t);
  }

  @override
  double dx(double time) {
    const h = 0.0001;
    return (x(time + h) - x(time - h)) / (2 * h);
  }

  @override
  bool isDone(double time) => time >= _duration;
}

/// [PageScrollPhysics] that settles with a fixed-duration curve instead of a
/// spring simulation.
class SnapScrollPhysics extends PageScrollPhysics {
  /// Creates page snap physics with a fixed [snapDuration] and [snapCurve].
  const SnapScrollPhysics({
    super.parent,
    this.snapDuration = const Duration(milliseconds: 280),
    this.snapCurve = Curves.easeOutCubic,
  });

  /// How long a mid-page ballistic snap lasts.
  final Duration snapDuration;

  /// Curve used by [CurvedPageSnapSimulation].
  final Curve snapCurve;

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnapScrollPhysics(
      parent: buildParent(ancestor),
      snapDuration: snapDuration,
      snapCurve: snapCurve,
    );
  }

  double _getPage(ScrollMetrics position) {
    if (position case PageMetrics(:final page?)) return page;
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double targetPage) {
    if (position case PageMetrics(
      :final pixels,
      :final page?,
      :final viewportDimension,
      :final viewportFraction,
    )) {
      return pixels +
          (targetPage - page) * viewportDimension * viewportFraction;
    }
    return targetPage * position.viewportDimension;
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    var page = _getPage(position);
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return _getPixels(position, page.roundToDouble());
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = _getTargetPixels(position, tolerance, velocity);

    if (target != position.pixels) {
      return CurvedPageSnapSimulation(
        start: position.pixels,
        end: target,
        durationSeconds: snapDuration.inMilliseconds / 1000,
        curve: snapCurve,
      );
    }
    return null;
  }
}
