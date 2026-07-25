import 'dart:async';
import 'dart:math';

import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_builder.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_chrome.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_drag_update_details.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_interaction_mode.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_scroll_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// {@template constrained_dismissible_page}
/// A dismissible page whose motion is Constrained Motion: each gesture locks
/// onto a single [Axis] (chosen by the dominant delta) and then moves only
/// along that axis and only toward sides permitted by [directions].
///
/// This is the public Constrained variant of the sealed page API. It wires the
/// Dismiss Engine (Axis Lock, [AxisLock], [DismissThresholds],
/// [DragPresentationConfig], and Scroll Arbitration) to a
/// thin gesture/scroll adapter and the shared [DismissiblePageChrome]; it owns
/// no domain rules of its own. See
/// [ConstrainedMotionDirections.resolveAxisLock].
///
/// [interactionMode] is orthogonal to motion:
/// - [DismissiblePageInteractionMode.scroll] (default) coordinates dismissal
///   with a nested scrollable via an attachable [ScrollController] handed to
///   [builder].
/// - [DismissiblePageInteractionMode.gesture] handles content that never
///   scrolls with a direct drag recognizer.
///
/// An empty [directions] set or [disabled] both make the page
/// non-dismissible; [disabled] is the motion-agnostic switch shared with the
/// Free variant, while an empty set is the degenerate Constrained
/// configuration.
/// {@endtemplate}
class ConstrainedDismissiblePage extends StatefulWidget {
  /// {@macro constrained_dismissible_page}
  const ConstrainedDismissiblePage({
    required this.builder,
    required this.onDismissed,
    this.directions = DismissDirections.vertical,
    this.thresholds = const DismissThresholds(),
    this.interactionMode = DismissiblePageInteractionMode.scroll,
    this.disabled = false,
    this.onDragStart,
    this.onDragEnd,
    this.onDragUpdate,
    this.isFullScreen = true,
    this.backgroundColor,
    this.dragStartBehavior = DragStartBehavior.down,
    this.dragSensitivity = 0.7,
    this.minScale = .85,
    this.minRadius = 7,
    this.maxRadius = 30,
    this.maxTransformValue = .4,
    this.startingOpacity = 1,
    this.enableBackgroundOpacity = true,
    this.minOpacity = 0,
    this.reverseDuration = const Duration(milliseconds: 200),
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
  });

  /// Builds the content to dismiss.
  ///
  /// The provided [ScrollController] must be attached to the primary
  /// scrollable when [interactionMode] is
  /// [DismissiblePageInteractionMode.scroll].
  final DismissiblePageBuilder builder;

  /// Called when a gesture crosses the permitted side's Dismiss Threshold.
  final VoidCallback onDismissed;

  /// The sides that may complete a dismissal. An empty set disables drag.
  final DismissDirections directions;

  /// Per-atomic-side progress thresholds for the locked side.
  final DismissThresholds thresholds;

  /// How dismissal is coordinated with nested scrolling.
  final DismissiblePageInteractionMode interactionMode;

  /// When true, drag-to-dismiss is disabled while content stays interactive.
  final bool disabled;

  /// Called when a dismiss drag starts.
  final VoidCallback? onDragStart;

  /// Called when a dismiss drag ends without dismissing.
  final VoidCallback? onDragEnd;

  /// Called with presentation details on every drag frame.
  final ValueChanged<DismissiblePageDragUpdateDetails>? onDragUpdate;

  /// Whether the page ignores device padding.
  final bool isFullScreen;

  /// Page background painted behind the transformed content.
  final Color? backgroundColor;

  /// How drag start is recognized.
  final DragStartBehavior dragStartBehavior;

  /// Scales how far a drag translates the page.
  final double dragSensitivity;

  /// Content scale at full drag progress.
  final double minScale;

  /// Border radius at rest.
  final double minRadius;

  /// Border radius at full drag progress.
  final double maxRadius;

  /// Maximum translation as a fraction of the axis extent (0.0–1.0).
  final double maxTransformValue;

  /// Background opacity at rest.
  final double startingOpacity;

  /// Whether the background opacity follows drag progress.
  final bool enableBackgroundOpacity;

  /// Floor for background opacity as progress increases.
  final double minOpacity;

  /// Duration of the settle animation when a gesture reverses.
  final Duration reverseDuration;

  /// Hit-test behavior of the drag recognizer.
  final HitTestBehavior hitTestBehavior;

  @override
  State<ConstrainedDismissiblePage> createState() =>
      _ConstrainedDismissiblePageState();
}

class _ConstrainedDismissiblePageState extends State<ConstrainedDismissiblePage>
    with SingleTickerProviderStateMixin {
  static const double _kOriginEpsilon = 1e-6;

  late final DismissiblePageScrollController _scrollController;
  late final ScrollController _defaultScrollController;
  late final AnimationController _settleController;
  late final ValueNotifier<DismissiblePageDragUpdateDetails> _dragNotifier;

  late final TextDirection _textDirection = Directionality.of(context);
  late final Size _screenSize = MediaQuery.sizeOf(context);

  /// The axis/side locked for the active gesture, or null before a lock.
  AxisLock? _lock;

  /// Accumulated drag distance in pixels along the locked axis.
  double _dragExtent = 0;

  /// Drag extent captured when a reverse settle begins.
  double _settleFrom = 0;

  bool _dragUnderway = false;
  bool _canInnerContentScroll = false;

  bool get _dismissEnabled =>
      !widget.disabled && widget.directions.allowsDragDismissal;

  @override
  void initState() {
    super.initState();
    // Resting details must not read MediaQuery/Directionality — those
    // inherited lookups are illegal until after initState completes.
    _dragNotifier = ValueNotifier(
      DismissiblePageDragUpdateDetails(
        radius: widget.minRadius,
        opacity: widget.startingOpacity,
      ),
    )..addListener(_dragListener);
    _settleController =
        AnimationController(vsync: this, duration: widget.reverseDuration)
          ..addListener(_handleSettleTick)
          ..addStatusListener(_handleSettleStatus);
    _scrollController = DismissiblePageScrollController(
      shouldConsumeUserOffset: _shouldConsumeUserOffset,
      onDismissDragStart: _handleScrollDragStart,
      onDismissDragUpdate: _handleScrollDragUpdate,
      onDismissDragEnd: _handleScrollDragEnd,
    );
    _defaultScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCanInnerContentScroll();
      DismissiblePageDragNotification(
        details: _dragNotifier.value,
      ).dispatch(context);
    }, debugLabel: 'ConstrainedDismissiblePage.postFrame');
  }

  @override
  void dispose() {
    _dragNotifier
      ..removeListener(_dragListener)
      ..dispose();
    _scrollController.dispose();
    _defaultScrollController.dispose();
    _settleController
      ..removeListener(_handleSettleTick)
      ..removeStatusListener(_handleSettleStatus)
      ..dispose();
    super.dispose();
  }

  void _checkCanInnerContentScroll() {
    if (!_scrollController.hasClients) return;
    final previous = _canInnerContentScroll;
    _canInnerContentScroll = _scrollController.position.maxScrollExtent > 0;
    // Structural flip (gesture shell vs scroll arbitration) — the only
    // setState this State needs.
    if (previous != _canInnerContentScroll) setState(() {});
  }

  // --- Presentation -------------------------------------------------------

  DragPresentationConfig get _presentationConfig => DragPresentationConfig(
    minRadius: widget.minRadius,
    maxRadius: widget.maxRadius,
    minScale: widget.minScale,
    startingOpacity: widget.startingOpacity,
    minOpacity: widget.minOpacity,
  );

  Axis get _axis => _lock?.axis ?? Axis.vertical;

  double get _axisExtent => switch (_axis) {
    Axis.horizontal => _screenSize.width,
    Axis.vertical => _screenSize.height,
  };

  /// Raw drag progress along the locked axis (0.0–1.0), the value compared
  /// against the Dismiss Threshold.
  double get _progress =>
      _axisExtent == 0 ? 0 : (_dragExtent.abs() / _axisExtent).clamp(0.0, 1.0);

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
      Axis.horizontal => Offset(translationFraction * _screenSize.width, 0),
      Axis.vertical => Offset(0, translationFraction * _screenSize.height),
    };
    final presentation = _presentationConfig.map(
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

  /// Pushes a new chrome frame without rebuilding the State subtree.
  void _publishExtent(double extent) {
    _dragExtent = extent;
    if (!mounted) return;

    _dragNotifier.value = _detailsForExtent(extent);
  }

  void _dragListener() {
    widget.onDragUpdate?.call(_dragNotifier.value);
    DismissiblePageDragNotification(
      details: _dragNotifier.value,
    ).dispatch(context);
  }

  // --- Gesture adapter ----------------------------------------------------

  void _handleDragStart([Offset? _]) {
    if (!_dismissEnabled) return;
    widget.onDragStart?.call();
    _dragUnderway = true;
    if (_settleController.isAnimating) {
      _settleController.stop();
    } else {
      _publishExtent(0);
      _lock = null;
    }
  }

  void _applyDelta(Offset delta) {
    if (!_dragUnderway || _settleController.isAnimating) return;
    final lock = _lock ??= widget.directions.resolveAxisLock(
      delta: delta,
      textDirection: _textDirection,
    );
    if (lock == null) return;

    // The engine projects the delta onto the locked axis and discards
    // cross-axis and opposite-side movement, keeping this adapter thin.
    final projected = lock.constrain(delta);
    final axisDelta = switch (lock.axis) {
      Axis.horizontal => projected.dx,
      Axis.vertical => projected.dy,
    };
    if (axisDelta == 0) return;

    _publishExtent(_dragExtent + axisDelta);
  }

  void _handleDragEnd([DragEndDetails? _]) {
    if (!_dragUnderway) return;
    _dragUnderway = false;
    final lock = _lock;
    if (lock == null || _dragExtent == 0) return;

    switch (lock.decide(progress: _progress, thresholds: widget.thresholds)) {
      case DismissDecision.dismiss:
        _dispatchDismissed();
        widget.onDismissed();
      case DismissDecision.reverse:
        _settleFrom = _dragExtent;
        unawaited(_settleController.forward(from: 0));
        widget.onDragEnd?.call();
    }
  }

  void _handleSettleTick() {
    final t = Curves.easeInOut.transform(_settleController.value);
    _publishExtent(_settleFrom * (1 - t));
  }

  void _handleSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    if (mounted) _settleController.value = 0;
    _publishExtent(0);
    _lock = null;
  }

  void _dispatchDismissed() {
    DismissiblePageDragNotification(
      details: _dragNotifier.value.copyWith(isDismissed: true),
    ).dispatch(context);
  }

  // --- Scroll arbitration adapter -----------------------------------------

  void _handleScrollDragStart() => _handleDragStart();

  void _handleScrollDragUpdate(double delta, ScrollPosition position) {
    final scrollAxis = axisDirectionToAxis(position.axisDirection);
    final delta2D = switch (scrollAxis) {
      Axis.vertical => Offset(0, delta),
      Axis.horizontal => Offset(delta, 0),
    };

    final hasScrollableContent =
        (position.maxScrollExtent - position.minScrollExtent).abs() >
        _kOriginEpsilon;
    final isReturning = _dragExtent != 0 && _isDeltaReturningToOrigin(delta2D);
    final reachesOrigin =
        isReturning && (delta.abs() + _kOriginEpsilon >= _dragExtent.abs());

    if (hasScrollableContent && reachesOrigin) {
      _publishExtent(0);
      return;
    }

    _applyDelta(delta2D);
  }

  void _handleScrollDragEnd() => _handleDragEnd();

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

  bool _shouldConsumeUserOffset(double delta, ScrollPosition position) {
    if (!_dismissEnabled) return false;
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

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final contentPadding = widget.isFullScreen
        ? EdgeInsets.zero
        : MediaQuery.paddingOf(context);

    final scrollMode =
        widget.interactionMode == DismissiblePageInteractionMode.scroll;
    final scrollController = (scrollMode && _dismissEnabled)
        ? _scrollController
        : _defaultScrollController;
    final useScrollArbitration =
        scrollMode && _dismissEnabled && _canInnerContentScroll;

    // Chrome rebuilds on drag frames; builder content is the stable [child]
    // and is not rebuilt every pointer move.
    final chrome = ValueListenableBuilder<DismissiblePageDragUpdateDetails>(
      valueListenable: _dragNotifier,
      child: widget.builder(context, scrollController),
      builder: (context, details, child) {
        return DismissiblePageChrome(
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
        );
      },
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _dispatchDismissed();
      },
      child: useScrollArbitration ? chrome : _wrapWithGestures(chrome),
    );
  }

  Widget _wrapWithGestures(Widget child) {
    if (!_dismissEnabled) return child;
    return GestureDetector(
      behavior: widget.hitTestBehavior,
      dragStartBehavior: widget.dragStartBehavior,
      onPanStart: (details) => _handleDragStart(details.globalPosition),
      onPanUpdate: (details) => _applyDelta(details.delta),
      onPanEnd: _handleDragEnd,
      child: child,
    );
  }
}
