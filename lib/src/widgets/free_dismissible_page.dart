part of 'dismissible_page.dart';

/// {@template free_dismissible_page}
/// A dismissible page whose motion is Free Motion: the gesture moves the page
/// in the full plane (2D) without Axis Lock, and a single [threshold]
/// decides whether the gesture dismisses or reverses.
///
/// Free Motion is independent of Dismiss Directions combinatorics, so this
/// widget has no directions parameter. Prefer
/// [DismissiblePageInteractionMode.scroll] when the child has a primary
/// scrollable, and [DismissiblePageInteractionMode.gesture] when it never
/// scrolls.
/// {@endtemplate}
class FreeDismissiblePage extends DismissiblePage {
  /// {@macro free_dismissible_page}
  const FreeDismissiblePage({
    required super.builder,
    required super.onDismissed,
    this.threshold = kDismissThreshold,
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
  }) : assert(
         threshold >= 0 && threshold <= 1,
         'threshold must be between 0 and 1',
       );

  /// The single Dismiss Threshold (0.0–1.0) for the free-plane gesture.
  final double threshold;

  @override
  State<FreeDismissiblePage> createState() => _FreeDismissiblePageState();
}

class _FreeDismissiblePageState
    extends _DismissiblePageState<FreeDismissiblePage> {
  /// Accumulated free-plane drag offset in pixels.
  Offset _dragOffset = Offset.zero;

  /// Drag offset captured when a reverse settle begins.
  Offset _settleFrom = Offset.zero;

  @override
  bool get dismissEnabled => !widget.disabled;

  @override
  String get postFrameDebugLabel => 'FreeDismissiblePage.postFrame';

  DismissiblePageDragUpdateDetails _detailsForOffset(Offset offset) {
    final progress = FreeMotion(offset).progressIn(screenSize);
    final horizontalFraction = screenSize.width == 0
        ? 0.0
        : (offset.dx / screenSize.width * widget.dragSensitivity).clamp(
            -widget.maxTransformValue,
            widget.maxTransformValue,
          );
    final verticalFraction = screenSize.height == 0
        ? 0.0
        : (offset.dy / screenSize.height * widget.dragSensitivity).clamp(
            -widget.maxTransformValue,
            widget.maxTransformValue,
          );
    final presentation = presentationConfig.map(
      progress: (progress * widget.dragSensitivity).clamp(0.0, 1.0),
      offset: Offset(
        horizontalFraction * screenSize.width,
        verticalFraction * screenSize.height,
      ),
    );
    return DismissiblePageDragUpdateDetails(
      overallDragValue: min(progress, widget.maxTransformValue),
      radius: presentation.radius,
      opacity: presentation.opacity,
      offset: presentation.offset,
      scale: presentation.scale,
    );
  }

  void _publishOffset(Offset offset) {
    _dragOffset = offset;
    publishDetails(_detailsForOffset(offset));
  }

  @override
  void handleDragStart([Axis? _]) {
    if (!dismissEnabled) return;
    widget.onDragStart?.call();
    dragUnderway = true;
    if (settleController.isAnimating) {
      settleController.stop();
    } else {
      _publishOffset(Offset.zero);
    }
  }

  @override
  void applyDelta(Offset delta) {
    if (!dragUnderway || settleController.isAnimating) return;
    if (delta == Offset.zero) return;

    _publishOffset(_dragOffset + delta);
  }

  @override
  void handleDragEnd([DragEndDetails? _]) {
    if (!dragUnderway) return;
    dragUnderway = false;
    if (_dragOffset == Offset.zero) return;

    final decision = FreeMotion(_dragOffset).decide(
      bounds: screenSize,
      threshold: widget.threshold,
    );
    switch (decision) {
      case DismissDecision.dismiss:
        dispatchDismissed();
        widget.onDismissed();
      case DismissDecision.reverse:
        _settleFrom = _dragOffset;
        unawaited(settleController.forward(from: 0));
        widget.onDragEnd?.call();
    }
  }

  @override
  void onSettleTick(double t) {
    _publishOffset(Offset.lerp(_settleFrom, Offset.zero, t)!);
  }

  @override
  void onSettleCompleted() => _publishOffset(Offset.zero);

  @override
  void handleScrollDragUpdate(double delta, ScrollPosition position) {
    final scrollAxis = axisDirectionToAxis(position.axisDirection);
    final delta2D = switch (scrollAxis) {
      Axis.vertical => Offset(0, delta),
      Axis.horizontal => Offset(delta, 0),
    };
    final axisOffset = switch (scrollAxis) {
      Axis.horizontal => _dragOffset.dx,
      Axis.vertical => _dragOffset.dy,
    };

    final hasScrollableContent =
        (position.maxScrollExtent - position.minScrollExtent).abs() >
        _DismissiblePageState.originEpsilon;
    final isReturning =
        (axisOffset > 0 && delta < 0) || (axisOffset < 0 && delta > 0);
    final reachesOrigin =
        isReturning &&
        (delta.abs() + _DismissiblePageState.originEpsilon >= axisOffset.abs());

    if (hasScrollableContent && reachesOrigin) {
      _publishOffset(switch (scrollAxis) {
        Axis.horizontal => Offset(0, _dragOffset.dy),
        Axis.vertical => Offset(_dragOffset.dx, 0),
      });
      return;
    }

    applyDelta(delta2D);
  }

  @override
  bool shouldConsumeUserOffset(double delta, ScrollPosition position) {
    if (!dismissEnabled) return false;

    // Keep consuming while the page is displaced so inner content does not
    // start scrolling mid-dismissal.
    if (_dragOffset != Offset.zero) return true;

    return ScrollExtentMetrics.fromScrollMetrics(
      position,
    ).shouldConsumeFreeScrollDelta(delta);
  }
}
