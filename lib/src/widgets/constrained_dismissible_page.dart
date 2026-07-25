part of 'dismissible_page.dart';

/// {@template constrained_dismissible_page}
/// A dismissible page whose motion is Constrained Motion: each gesture locks
/// onto a single [Axis] (chosen by the dominant delta) and then moves only
/// along that axis and only toward sides permitted by [directions]. Reverse
/// toward origin on the locked axis is allowed; when both sides of that axis
/// are permitted, the gesture may cross origin into the other allowed side.
///
/// ## Choosing [directions]
///
/// [DismissDirections] is a combinable bitmask. Pass a preset, one atom, or
/// build a custom set with [DismissDirections.add]:
///
/// ```dart
/// DismissiblePage.constrained(
///   // up or down (default if omitted)
///   directions: DismissDirections.vertical,
///   builder: ...,
///   onDismissed: ...,
/// );
///
/// DismissiblePage.constrained(
///   // custom: up and start-to-end only
///   directions: DismissDirections.up.add(DismissDirections.startToEnd),
///   builder: ...,
///   onDismissed: ...,
/// );
///
/// DismissiblePage.constrained(
///   // vertical without up
///   directions: DismissDirections.vertical.remove(DismissDirections.up),
///   builder: ...,
///   onDismissed: ...,
/// );
/// ```
///
/// Combining cross-axis sides (e.g. [DismissDirections.up] added to
/// [DismissDirections.startToEnd]) does **not** enable Free Motion. The
/// gesture still axis-locks; only the allowed side on the locked axis can
/// dismiss. For full-plane drag, use [FreeDismissiblePage].
/// [DismissDirections.empty] or [disabled] both turn drag dismissal off.
///
/// [interactionMode] is orthogonal to motion:
/// - [DismissiblePageInteractionMode.scroll] (default) coordinates dismissal
///   with a nested scrollable via an attachable [ScrollController] handed to
///   [builder].
/// - [DismissiblePageInteractionMode.gesture] handles content that never
///   scrolls with a direct drag recognizer.
/// {@endtemplate}
class ConstrainedDismissiblePage extends DismissiblePage {
  /// {@macro constrained_dismissible_page}
  const ConstrainedDismissiblePage({
    required super.builder,
    required super.onDismissed,
    this.directions = DismissDirections.vertical,
    this.thresholds = const DismissThresholds(),
    super.interactionMode,
    super.disabled,
    super.onDragStart,
    super.onDragEnd,
    super.onDragUpdate,
    super.isFullScreen,
    super.backgroundColor,
    super.dragStartBehavior,
    super.dragSensitivity,
    super.minScale,
    super.minRadius,
    super.maxRadius,
    super.maxTransformValue,
    super.startingOpacity,
    super.enableBackgroundOpacity,
    super.minOpacity,
    super.reverseDuration,
    super.reverseCurve,
    super.hitTestBehavior,
    super.key,
  });

  /// The sides that may complete a dismissal.
  ///
  /// Combine atoms with [DismissDirections.add], strip with
  /// [DismissDirections.remove], or use presets like
  /// [DismissDirections.vertical]. Defaults to
  /// [DismissDirections.vertical]. [DismissDirections.empty] disables drag.
  /// See [DismissDirections] for full combine examples.
  final DismissDirections directions;

  /// Per-atomic-side progress thresholds for the locked side.
  final DismissThresholds thresholds;

  @override
  State<ConstrainedDismissiblePage> createState() =>
      _ConstrainedDismissiblePageState();
}

class _ConstrainedDismissiblePageState
    extends _DismissiblePageState<ConstrainedDismissiblePage> {
  late final TextDirection _textDirection = Directionality.of(context);

  /// The axis/side locked for the active gesture, or null before a lock.
  AxisLock? _lock;

  /// Accumulated drag distance in pixels along the locked axis.
  double _dragExtent = 0;

  /// Drag extent captured when a reverse settle begins.
  double _settleFrom = 0;

  @override
  bool get dismissEnabled =>
      !widget.disabled && widget.directions.allowsDragDismissal;

  @override
  String get postFrameDebugLabel => 'ConstrainedDismissiblePage.postFrame';

  Axis get _axis => _lock?.axis ?? Axis.vertical;

  double get _axisExtent => switch (_axis) {
    Axis.horizontal => screenSize.width,
    Axis.vertical => screenSize.height,
  };

  /// Raw drag progress along the locked axis (0.0–1.0), the value compared
  /// against the Dismiss Threshold.
  double get _progress => _axisExtent == 0
      ? 0
      : (_dragExtent.abs() / _axisExtent).clamp(0.0, 1.0);

  DismissiblePageDragUpdateDetails _detailsForExtent(double extent) {
    final axisExtent = _axisExtent;
    final progress = axisExtent == 0
        ? 0.0
        : (extent.abs() / axisExtent).clamp(0.0, 1.0);
    final translationFraction = (extent / axisExtent * widget.dragSensitivity)
        .clamp(
          -widget.maxTransformValue,
          widget.maxTransformValue,
        );
    final offset = switch (_axis) {
      Axis.horizontal => Offset(translationFraction * screenSize.width, 0),
      Axis.vertical => Offset(0, translationFraction * screenSize.height),
    };
    final presentation = presentationConfig.map(
      progress: (progress * widget.dragSensitivity).clamp(0.0, 1.0),
      offset: offset,
    );
    return DismissiblePageDragUpdateDetails(
      overallDragValue: min(progress, widget.maxTransformValue),
      radius: presentation.radius,
      opacity: presentation.opacity,
      offset: presentation.offset,
      scale: presentation.scale,
    );
  }

  void _publishExtent(double extent) {
    _dragExtent = extent;
    publishDetails(_detailsForExtent(extent));
  }

  @override
  void handleDragStart([Offset? _]) {
    if (!dismissEnabled) return;
    widget.onDragStart?.call();
    dragUnderway = true;
    if (settleController.isAnimating) {
      settleController.stop();
    } else {
      _publishExtent(0);
      _lock = null;
    }
  }

  @override
  void applyDelta(Offset delta) {
    if (!dragUnderway || settleController.isAnimating) return;
    final lock = _lock ??= widget.directions.resolveAxisLock(
      delta: delta,
      textDirection: _textDirection,
    );
    if (lock == null) return;

    // The engine projects the delta onto the locked axis, allows reverse
    // toward origin, and clamps or side-flips per Dismiss Directions.
    final projected = lock.constrain(
      delta,
      currentExtent: _dragExtent,
      directions: widget.directions,
    );
    final axisDelta = switch (lock.axis) {
      Axis.horizontal => projected.dx,
      Axis.vertical => projected.dy,
    };
    if (axisDelta == 0) return;

    _publishExtent(_dragExtent + axisDelta);
  }

  @override
  void handleDragEnd([DragEndDetails? _]) {
    if (!dragUnderway) return;
    dragUnderway = false;
    final lock = _lock;
    if (lock == null || _dragExtent == 0) return;

    switch (lock.decide(
      progress: _progress,
      extent: _dragExtent,
      thresholds: widget.thresholds,
    )) {
      case DismissDecision.dismiss:
        dispatchDismissed();
        widget.onDismissed();
      case DismissDecision.reverse:
        _settleFrom = _dragExtent;
        unawaited(settleController.forward(from: 0));
        widget.onDragEnd?.call();
    }
  }

  @override
  void onSettleTick(double t) => _publishExtent(_settleFrom * (1 - t));

  @override
  void onSettleCompleted() {
    _publishExtent(0);
    _lock = null;
  }

  @override
  void handleScrollDragUpdate(double delta, ScrollPosition position) {
    final scrollAxis = axisDirectionToAxis(position.axisDirection);
    final delta2D = switch (scrollAxis) {
      Axis.vertical => Offset(0, delta),
      Axis.horizontal => Offset(delta, 0),
    };

    // Axis Lock.constrain applies reverse-to-origin, clamps single-side sets
    // at origin, and may cross into the other allowed side. Do not snap to
    // origin here — that would discard permitted side flips.
    applyDelta(delta2D);
  }

  bool _isDeltaReturningToOrigin(Offset delta) {
    final lock = _lock;
    if (lock == null) return false;
    final axisDelta = switch (lock.axis) {
      Axis.horizontal => delta.dx,
      Axis.vertical => delta.dy,
    };
    return (_dragExtent > 0 && axisDelta < 0) ||
        (_dragExtent < 0 && axisDelta > 0);
  }

  @override
  bool shouldConsumeUserOffset(double delta, ScrollPosition position) {
    if (!dismissEnabled) return false;
    final scrollAxis = axisDirectionToAxis(position.axisDirection);
    final delta2D = switch (scrollAxis) {
      Axis.vertical => Offset(0, delta),
      Axis.horizontal => Offset(delta, 0),
    };

    // Keep consuming while the page returns toward origin so inner content
    // does not start scrolling prematurely.
    if (_dragExtent != 0 && _isDeltaReturningToOrigin(delta2D)) return true;

    return widget.directions.shouldConsumeScrollDelta(
      delta: delta,
      metrics: ScrollExtentMetrics.fromScrollMetrics(position),
      scrollAxis: scrollAxis,
      textDirection: _textDirection,
    );
  }
}
