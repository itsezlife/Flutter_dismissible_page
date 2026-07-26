import 'dart:async';

import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:dismissible_page/src/widgets/constrained_dismiss_motion.dart';
import 'package:dismissible_page/src/widgets/dismissible_page.dart'
    show DismissiblePage;
import 'package:dismissible_page/src/widgets/dismissible_page_chrome.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_drag_update_details.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_scroll_controller.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_view_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Builds pager content with the controller coordinated by
/// [DismissiblePageView].
typedef DismissiblePageViewBuilder =
    Widget Function(
      BuildContext context,
      DismissiblePageViewController controller,
    );

/// A dismissible page that coordinates a horizontal [PageView].
///
/// This is a parallel page API, not an Interaction Mode of [DismissiblePage].
/// Attach the builder-supplied controller to a stock horizontal [PageView].
class DismissiblePageView extends StatefulWidget {
  /// Creates a dismissible horizontal pager page.
  const DismissiblePageView({
    required this.builder,
    required this.onDismissed,
    this.directions = DismissDirections.vertical,
    this.thresholds = const DismissThresholds(),
    this.controller,
    this.pagerCommitment = PagerCommitment.lockedUntilRelease,
    this.originCrossing = PagerOriginCrossing.clampAtOrigin,
    this.edgeDismissCooldown = kEdgeDismissCooldown,
    this.disabled = false,
    this.onDragStart,
    this.onDragEnd,
    this.onDragUpdate,
    this.isFullScreen = true,
    this.backgroundColor,
    this.dragStartBehavior = DragStartBehavior.down,
    this.dragSensitivity = .7,
    this.minScale = .85,
    this.minRadius = 7,
    this.maxRadius = 30,
    this.maxTransformValue = .4,
    this.startingOpacity = 1,
    this.enableBackgroundOpacity = true,
    this.minOpacity = 0,
    this.reverseDuration = const Duration(milliseconds: 200),
    this.reverseCurve = Curves.easeInOut,
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
  });

  /// Builds content with the package page controller.
  final DismissiblePageViewBuilder builder;

  /// Called when a gesture completes a dismissal.
  final VoidCallback onDismissed;

  /// The sides that may complete a dismissal.
  final DismissDirections directions;

  /// Per-side progress thresholds.
  final DismissThresholds thresholds;

  /// An optional externally owned package page controller.
  final DismissiblePageViewController? controller;

  /// How the first pager-axis decision is retained during a gesture.
  final PagerCommitment pagerCommitment;

  /// Whether a committed pager-axis dismissal may cross origin.
  final PagerOriginCrossing originCrossing;

  /// Quiet interval after user paging before pager-axis edge dismiss re-arms.
  final Duration edgeDismissCooldown;

  /// Whether dismissal is disabled while paging remains interactive.
  final bool disabled;

  /// Called when a dismiss drag starts.
  final VoidCallback? onDragStart;

  /// Called when a dismiss drag reverses without dismissing.
  final VoidCallback? onDragEnd;

  /// Called with presentation details on every dismiss frame.
  final ValueChanged<DismissiblePageDragUpdateDetails>? onDragUpdate;

  /// Whether the page ignores device padding.
  final bool isFullScreen;

  /// Page background painted behind transformed content.
  final Color? backgroundColor;

  /// How an off-pager-axis drag starts.
  final DragStartBehavior dragStartBehavior;

  /// Scales drag translation and presentation progress.
  final double dragSensitivity;

  /// Content scale at full progress.
  final double minScale;

  /// Border radius at rest.
  final double minRadius;

  /// Border radius at full progress.
  final double maxRadius;

  /// Maximum translation as a fraction of the active axis.
  final double maxTransformValue;

  /// Background opacity at rest.
  final double startingOpacity;

  /// Whether background opacity follows drag progress.
  final bool enableBackgroundOpacity;

  /// Minimum background opacity.
  final double minOpacity;

  /// Duration of a reverse settle.
  final Duration reverseDuration;

  /// Curve of a reverse settle.
  final Curve reverseCurve;

  /// Hit-test behavior of the off-axis gesture shell.
  final HitTestBehavior hitTestBehavior;

  @override
  State<DismissiblePageView> createState() => _DismissiblePageViewState();
}

class _DismissiblePageViewState extends State<DismissiblePageView>
    with SingleTickerProviderStateMixin {
  static const _originEpsilon = 1e-6;

  late DismissiblePageViewController _controller;
  late bool _ownsController;
  late final AnimationController _settleController;
  late final ValueNotifier<DismissiblePageDragUpdateDetails> _dragNotifier;
  late final _motion = ConstrainedDismissMotion();
  bool _dragUnderway = false;

  bool get _dismissEnabled =>
      !widget.disabled && widget.directions.allowsDragDismissal;

  TextDirection get _textDirection => Directionality.of(context);

  Size get _screenSize => MediaQuery.sizeOf(context);

  DragPresentationConfig get _presentationConfig => DragPresentationConfig(
    minRadius: widget.minRadius,
    maxRadius: widget.maxRadius,
    minScale: widget.minScale,
    startingOpacity: widget.startingOpacity,
    minOpacity: widget.minOpacity,
  );

  @override
  void initState() {
    super.initState();
    _dragNotifier = ValueNotifier(
      DismissiblePageDragUpdateDetails(
        radius: widget.minRadius,
        opacity: widget.startingOpacity,
      ),
    )..addListener(_notifyDragUpdate);
    _settleController =
        AnimationController(vsync: this, duration: widget.reverseDuration)
          ..addListener(_handleSettleTick)
          ..addStatusListener(_handleSettleStatus);
    _setController(widget.controller);
  }

  @override
  void didUpdateWidget(DismissiblePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _clearController();
      _setController(widget.controller);
    } else {
      _configureController();
    }
    _settleController.duration = widget.reverseDuration;
  }

  void _setController(DismissiblePageViewController? external) {
    _ownsController = external == null;
    _controller = external ?? DismissiblePageViewController();
    _configureController();
  }

  void _configureController() {
    _controller.configureDismissal(
      isDismissEligible: _isDismissEligible,
      onDismissStart: () => _handleDragStart(Axis.horizontal),
      onDismissUpdate: _handlePagerUpdate,
      onDismissEnd: _handleDragEnd,
      dismissExtentIsAtOrigin: () => _motion.isAtOrigin(_originEpsilon),
      commitment: widget.pagerCommitment,
      originCrossing: widget.originCrossing,
      edgeDismissCooldown: widget.edgeDismissCooldown,
    );
  }

  void _clearController() {
    _controller.clearDismissal();
    if (_ownsController) _controller.dispose();
  }

  @override
  void dispose() {
    _clearController();
    _dragNotifier
      ..removeListener(_notifyDragUpdate)
      ..dispose();
    _settleController
      ..removeListener(_handleSettleTick)
      ..removeStatusListener(_handleSettleStatus)
      ..dispose();
    super.dispose();
  }

  bool _isDismissEligible(double delta, ScrollPosition position) {
    if (!_dismissEnabled) return false;
    if (!_controller.isEdgeDismissCooldownArmed) return false;
    final page = _controller.page;
    final isSettled =
        page != null && (page - page.roundToDouble()).abs() <= _originEpsilon;
    return widget.directions.shouldConsumePagerScrollDelta(
      delta: delta,
      metrics: ScrollExtentMetrics.fromScrollMetrics(position),
      textDirection: _textDirection,
      isSettledOnWholePage: isSettled,
    );
  }

  void _notifyDragUpdate() {
    widget.onDragUpdate?.call(_dragNotifier.value);
    DismissiblePageDragNotification(
      details: _dragNotifier.value,
    ).dispatch(context);
  }

  void _publishCurrentMotion() {
    if (!mounted) return;
    _dragNotifier.value = _motion.details(
      screenSize: _screenSize,
      presentationConfig: _presentationConfig,
      dragSensitivity: widget.dragSensitivity,
      maxTransformValue: widget.maxTransformValue,
    );
  }

  void _handleDragStart(Axis axis) {
    if (!_dismissEnabled) return;
    widget.onDragStart?.call();
    _dragUnderway = true;
    final continuesLockedAxis =
        _settleController.isAnimating && _motion.continuesSettlingAxis(axis);
    _settleController.stop();
    if (continuesLockedAxis) return;
    _motion.reset();
    _publishCurrentMotion();
  }

  void _applyDelta(Offset delta, {bool clampAtOrigin = false}) {
    if (!_dragUnderway || _settleController.isAnimating) return;
    final changed = _motion.applyDelta(
      delta,
      directions: widget.directions,
      textDirection: _textDirection,
      clampAtOrigin: clampAtOrigin,
    );
    if (changed) _publishCurrentMotion();
  }

  void _handlePagerUpdate(double delta, ScrollPosition _) {
    _applyDelta(
      Offset(delta, 0),
      clampAtOrigin: switch (widget.originCrossing) {
        PagerOriginCrossing.clampAtOrigin => true,
        PagerOriginCrossing.crossToOppositeSide => false,
      },
    );
  }

  void _handleDragEnd() {
    if (!_dragUnderway) return;
    _dragUnderway = false;
    if (_motion.lock == null || _motion.extent == 0) return;
    switch (_motion.decide(
      screenSize: _screenSize,
      thresholds: widget.thresholds,
    )) {
      case DismissDecision.dismiss:
        DismissiblePageDragNotification(
          details: _dragNotifier.value.copyWith(isDismissed: true),
        ).dispatch(context);
        widget.onDismissed();
      case DismissDecision.reverse:
        _motion.beginSettle();
        unawaited(_settleController.forward(from: 0));
        widget.onDragEnd?.call();
    }
  }

  void _handleSettleTick() {
    final t = widget.reverseCurve.transform(_settleController.value);
    _motion.settle(t);
    _publishCurrentMotion();
  }

  void _handleSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _settleController.value = 0;
    _motion.reset();
    _publishCurrentMotion();
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = widget.isFullScreen
        ? EdgeInsets.zero
        : MediaQuery.paddingOf(context);
    final chrome = ValueListenableBuilder<DismissiblePageDragUpdateDetails>(
      valueListenable: _dragNotifier,
      child: widget.builder(context, _controller),
      builder: (context, details, child) => DismissiblePageChrome(
        presentation: DragPresentation(
          progress: details.overallDragValue,
          offset: details.offset,
          radius: details.radius,
          opacity: details.opacity,
          scale: details.scale,
        ),
        backgroundColor: widget.backgroundColor,
        enableBackgroundOpacity: widget.enableBackgroundOpacity,
        contentPadding: contentPadding,
        child: child!,
      ),
    );

    final child =
        _dismissEnabled && widget.directions.leavesAxis(Axis.horizontal)
        ? GestureDetector(
            behavior: widget.hitTestBehavior,
            dragStartBehavior: widget.dragStartBehavior,
            onVerticalDragStart: (_) => _handleDragStart(Axis.vertical),
            onVerticalDragUpdate: (details) => _applyDelta(details.delta),
            onVerticalDragEnd: (_) => _handleDragEnd(),
            child: chrome,
          )
        : chrome;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          DismissiblePageDragNotification(
            details: _dragNotifier.value.copyWith(isDismissed: true),
          ).dispatch(context);
        }
      },
      child: child,
    );
  }
}
