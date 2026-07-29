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
///
/// Under [DismissiblePageInteractionMode.scroll], Scroll Arbitration owns the
/// nested scrollable's axis (mid-list on-axis scrolls; edge overscroll
/// dismisses) while a full-plane gesture shell coexists so off-axis-dominant
/// starts can still begin Free Motion. Once that shell wins, the remainder of
/// the gesture tracks the full plane.
/// {@endtemplate}
class FreeDismissiblePage extends DismissiblePage {
  /// {@macro free_dismissible_page}
  const FreeDismissiblePage({
    required super.builder,
    required super.onDismissed,
    super.confirmDismiss,
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
    super.shape,
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
      shape: presentation.shape,
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
    if (!dismissEnabled || confirmingDismiss) return;
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

  void _reverseSettleToRest() {
    _settleFrom = _dragOffset;
    unawaited(settleController.forward(from: 0));
    widget.onDragEnd?.call();
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
        unawaited(
          awaitConfirmDismiss(reverseSettle: _reverseSettleToRest),
        );
      case DismissDecision.reverse:
        _reverseSettleToRest();
    }
  }

  @override
  void onSettleTick(double t) {
    _publishOffset(Offset.lerp(_settleFrom, Offset.zero, t)!);
  }

  @override
  void onSettleCompleted() => _publishOffset(Offset.zero);

  /// Always dual-mounts under Scroll Arbitration: a full-plane shell that
  /// coexists with the nested scrollable's axis.
  ///
  /// The shell self-yields when the initial dominant delta lies on the scroll
  /// axis (so mid-list scrolling stays with the nested scrollable). Off-axis-
  /// dominant starts claim the arena at hit-slop timing so a nested
  /// axis-locked drag cannot steal Free Motion; after the shell wins it
  /// tracks the full plane for the rest of the gesture.
  @override
  Widget wrapWithCoexistingShell(Widget child) {
    if (innerScrollAxis case final scrollAxis?) {
      return RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          _FreeScrollCoexistencePanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                _FreeScrollCoexistencePanGestureRecognizer
              >(
                () => _FreeScrollCoexistencePanGestureRecognizer(
                  scrollAxis: scrollAxis,
                  canInnerContentScroll: () => canInnerContentScroll,
                ),
                (instance) {
                  instance
                    ..dragStartBehavior = widget.dragStartBehavior
                    ..onStart = (_) {
                      handleDragStart();
                    }
                    ..onUpdate = (details) {
                      applyDelta(details.delta);
                    }
                    ..onEnd = handleDragEnd;
                },
              ),
        },
        behavior: widget.hitTestBehavior,
        child: child,
      );
    }
    return wrapWithGestures(child);
  }

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

/// Full-plane pan that self-yields to a nested scrollable on on-axis-dominant
/// starts, and claims off-axis-dominant starts at hit-slop timing.
///
/// Plain [PanGestureRecognizer] uses pan-slop and loses many horizontal-
/// dominant diagonals to a nested [VerticalDragGestureRecognizer] (hit-slop on
/// dy alone). This recognizer decides from the initial dominant delta once
/// either axis crosses hit-slop: yield when that delta is on [scrollAxis] and
/// the list can scroll; otherwise accept and track the full plane.
class _FreeScrollCoexistencePanGestureRecognizer extends PanGestureRecognizer {
  _FreeScrollCoexistencePanGestureRecognizer({
    required this.scrollAxis,
    required this.canInnerContentScroll,
  });

  /// Axis owned by Scroll Arbitration / the nested scrollable.
  final Axis scrollAxis;

  /// Whether the nested list can scroll — on-axis-dominant starts yield when
  /// this is true.
  final bool Function() canInnerContentScroll;

  Offset _pending = Offset.zero;
  bool _decisionMade = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pending = Offset.zero;
    _decisionMade = false;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event case final PointerMoveEvent move when !_decisionMade) {
      _pending += move.delta;
      final hitSlop = computeHitSlop(move.kind, gestureSettings);
      final absDx = _pending.dx.abs();
      final absDy = _pending.dy.abs();
      if (max(absDx, absDy) > hitSlop) {
        _decisionMade = true;
        final onAxisDominant = switch (scrollAxis) {
          Axis.vertical => absDy >= absDx,
          Axis.horizontal => absDx >= absDy,
        };
        if (onAxisDominant && canInnerContentScroll()) {
          resolve(GestureDisposition.rejected);
          stopTrackingPointer(move.pointer);
          return;
        }
        resolve(GestureDisposition.accepted);
      }
    }
    super.handleEvent(event);
  }
}
