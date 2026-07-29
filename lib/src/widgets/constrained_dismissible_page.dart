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
///   [builder]. Scroll Arbitration serves the sides on that scrollable's own
///   axis; when [directions] also allow a side off that axis, a cross-axis
///   drag recognizer coexists with arbitration so those sides stay live while
///   mid-list on-axis drags keep scrolling the inner content.
/// - [DismissiblePageInteractionMode.gesture] handles content that never
///   scrolls with a direct drag recognizer.
/// {@endtemplate}
class ConstrainedDismissiblePage extends DismissiblePage {
  /// {@macro constrained_dismissible_page}
  const ConstrainedDismissiblePage({
    required super.builder,
    required super.onDismissed,
    super.confirmDismiss,
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
  late final _motion = ConstrainedDismissMotion();

  TextDirection get _textDirection => Directionality.of(context);

  @override
  bool get dismissEnabled =>
      !widget.disabled && widget.directions.allowsDragDismissal;

  @override
  String get postFrameDebugLabel => 'ConstrainedDismissiblePage.postFrame';

  void _publishCurrentMotion() {
    publishDetails(
      _motion.details(
        screenSize: screenSize,
        presentationConfig: presentationConfig,
        dragSensitivity: widget.dragSensitivity,
        maxTransformValue: widget.maxTransformValue,
      ),
    );
  }

  void _publishExtent(double extent) {
    _motion.extent = extent;
    _publishCurrentMotion();
  }

  @override
  void handleDragStart([Axis? axis]) {
    if (!dismissEnabled || confirmingDismiss) return;
    widget.onDragStart?.call();
    dragUnderway = true;

    // Catching a settling page continues the previous gesture, but only when
    // the new drag is on the locked axis. A lock and its extent belong to one
    // axis, so a gesture on the other axis starts clean — otherwise an
    // on-axis drag could finish a cross-axis dismissal left mid-settle.
    final continuesLockedAxis =
        settleController.isAnimating && _motion.continuesSettlingAxis(axis);
    settleController.stop();
    if (continuesLockedAxis) return;

    _motion.reset();
    _publishCurrentMotion();
  }

  @override
  void applyDelta(Offset delta) {
    if (!dragUnderway || settleController.isAnimating) return;
    final changed = _motion.applyDelta(
      delta,
      directions: widget.directions,
      textDirection: _textDirection,
    );
    if (changed) _publishCurrentMotion();
  }

  void _reverseSettleToRest() {
    _motion.beginSettle();
    unawaited(settleController.forward(from: 0));
    widget.onDragEnd?.call();
  }

  @override
  void handleDragEnd([DragEndDetails? _]) {
    if (!dragUnderway) return;
    dragUnderway = false;
    if (_motion.lock == null || _motion.extent == 0) return;

    switch (_motion.decide(
      screenSize: screenSize,
      thresholds: widget.thresholds,
    )) {
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
    _motion.settle(t);
    _publishCurrentMotion();
  }

  @override
  void onSettleCompleted() {
    _motion.reset();
    _publishCurrentMotion();
  }

  /// Mounts a cross-axis shell alongside Scroll Arbitration when some allowed
  /// side leaves the nested scrollable's axis.
  ///
  /// When every allowed side lies on the scroll axis, arbitration already
  /// serves them all and nothing extra joins the gesture arena.
  @override
  Widget wrapWithCoexistingShell(Widget child) {
    if (innerScrollAxis case final scrollAxis?
        when widget.directions.leavesAxis(scrollAxis)) {
      return wrapWithAxisPartitionedGestures(child, flipAxis(scrollAxis));
    }
    return child;
  }

  @override
  void handleScrollDragUpdate(double delta, ScrollPosition position) {
    final scrollAxis = axisDirectionToAxis(position.axisDirection);
    final delta2D = switch (scrollAxis) {
      Axis.vertical => Offset(0, delta),
      Axis.horizontal => Offset(delta, 0),
    };

    // Stock single-axis / Free: when a reverse scroll delta would reach or
    // cross origin and the nested list can scroll, snap to rest and let the
    // leftover drive the list — do not flip into the opposite dismiss side.
    // Axis Lock still allows origin crossing on the gesture path.
    final hasScrollableContent =
        (position.maxScrollExtent - position.minScrollExtent).abs() >
        _DismissiblePageState.originEpsilon;
    final dragExtent = _motion.extent;
    final isReturning =
        (dragExtent > 0 && delta < 0) || (dragExtent < 0 && delta > 0);
    final reachesOrigin =
        isReturning &&
        (delta.abs() + _DismissiblePageState.originEpsilon >= dragExtent.abs());
    if (hasScrollableContent && reachesOrigin) {
      _publishExtent(0);
      return;
    }

    applyDelta(delta2D);
  }

  bool _isDeltaReturningToOrigin(Offset delta) {
    final lock = _motion.lock;
    if (lock == null) return false;
    final axisDelta = switch (lock.axis) {
      Axis.horizontal => delta.dx,
      Axis.vertical => delta.dy,
    };
    return (_motion.extent > 0 && axisDelta < 0) ||
        (_motion.extent < 0 && axisDelta > 0);
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
    if (_motion.extent != 0 && _isDeltaReturningToOrigin(delta2D)) return true;

    return widget.directions.shouldConsumeScrollDelta(
      delta: delta,
      metrics: ScrollExtentMetrics.fromScrollMetrics(position),
      scrollAxis: scrollAxis,
      textDirection: _textDirection,
    );
  }
}
