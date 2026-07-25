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

/// {@template free_dismissible_page}
/// A dismissible page whose motion is Free Motion: the gesture moves the page
/// in the full plane (2D) without Axis Lock, and a single [threshold]
/// decides whether the gesture dismisses or reverses.
///
/// This is the public Free variant of the sealed page API. It wires the
/// Dismiss Engine ([FreeMotion], [DragPresentationConfig], and Free Motion
/// Scroll Arbitration via [ScrollExtentMetrics.shouldConsumeFreeScrollDelta])
/// to a thin gesture/scroll adapter and the shared [DismissiblePageChrome];
/// it owns no domain rules of its own. Free Motion is independent of Dismiss
/// Directions combinatorics, so this widget has no directions parameter.
///
/// [interactionMode] is orthogonal to motion:
/// - [DismissiblePageInteractionMode.scroll] (default) coordinates dismissal
///   with a nested scrollable via an attachable [ScrollController] handed to
///   [builder].
/// - [DismissiblePageInteractionMode.gesture] handles content that never
///   scrolls with a direct drag recognizer.
/// {@endtemplate}
class FreeDismissiblePage extends StatefulWidget {
  /// {@macro free_dismissible_page}
  const FreeDismissiblePage({
    required this.builder,
    required this.onDismissed,
    this.threshold = kDismissThreshold,
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
    this.reverseCurve = Curves.easeInOut,
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
  }) : assert(
         threshold >= 0 && threshold <= 1,
         'threshold must be between 0 and 1',
       );

  /// Builds the content to dismiss.
  ///
  /// The provided [ScrollController] must be attached to the primary
  /// scrollable when [interactionMode] is
  /// [DismissiblePageInteractionMode.scroll].
  final DismissiblePageBuilder builder;

  /// Called when the free-plane gesture crosses [threshold].
  final VoidCallback onDismissed;

  /// The single Dismiss Threshold (0.0–1.0) for the free-plane gesture.
  final double threshold;

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

  /// Maximum translation as a fraction of each axis extent (0.0–1.0).
  final double maxTransformValue;

  /// Background opacity at rest.
  final double startingOpacity;

  /// Whether the background opacity follows drag progress.
  final bool enableBackgroundOpacity;

  /// Floor for background opacity as progress increases.
  final double minOpacity;

  /// Duration of the settle animation when a gesture reverses.
  final Duration reverseDuration;

  /// Easing curve of the settle animation when a gesture reverses.
  final Curve reverseCurve;

  /// Hit-test behavior of the drag recognizer.
  final HitTestBehavior hitTestBehavior;

  @override
  State<FreeDismissiblePage> createState() => _FreeDismissiblePageState();
}

class _FreeDismissiblePageState extends State<FreeDismissiblePage>
    with SingleTickerProviderStateMixin {
  static const double _kOriginEpsilon = 1e-6;

  late final DismissiblePageScrollController _scrollController;
  late final ScrollController _defaultScrollController;
  late final AnimationController _settleController;
  late final ValueNotifier<DismissiblePageDragUpdateDetails> _dragNotifier;

  late final Size _screenSize = MediaQuery.sizeOf(context);

  /// Accumulated free-plane drag offset in pixels.
  Offset _dragOffset = Offset.zero;

  /// Drag offset captured when a reverse settle begins.
  Offset _settleFrom = Offset.zero;

  bool _dragUnderway = false;
  bool _canInnerContentScroll = false;

  bool get _dismissEnabled => !widget.disabled;

  @override
  void initState() {
    super.initState();
    // Resting details must not read MediaQuery — that inherited lookup is
    // illegal until after initState completes.
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
    }, debugLabel: 'FreeDismissiblePage.postFrame');
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

  late final DragPresentationConfig _presentationConfig =
      DragPresentationConfig(
        minRadius: widget.minRadius,
        maxRadius: widget.maxRadius,
        minScale: widget.minScale,
        startingOpacity: widget.startingOpacity,
        minOpacity: widget.minOpacity,
      );

  DismissiblePageDragUpdateDetails _detailsForOffset(Offset offset) {
    final progress = FreeMotion(offset).progressIn(_screenSize);
    final horizontalFraction = _screenSize.width == 0
        ? 0.0
        : (offset.dx / _screenSize.width * widget.dragSensitivity).clamp(
            -widget.maxTransformValue,
            widget.maxTransformValue,
          );
    final verticalFraction = _screenSize.height == 0
        ? 0.0
        : (offset.dy / _screenSize.height * widget.dragSensitivity).clamp(
            -widget.maxTransformValue,
            widget.maxTransformValue,
          );
    final presentation = _presentationConfig.map(
      progress: (progress * widget.dragSensitivity).clamp(0.0, 1.0),
      offset: Offset(
        horizontalFraction * _screenSize.width,
        verticalFraction * _screenSize.height,
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

  /// Pushes a new chrome frame without rebuilding the State subtree.
  void _publishOffset(Offset offset) {
    _dragOffset = offset;
    if (!mounted) return;

    _dragNotifier.value = _detailsForOffset(offset);
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
      _publishOffset(Offset.zero);
    }
  }

  void _applyDelta(Offset delta) {
    if (!_dragUnderway || _settleController.isAnimating) return;
    if (delta == Offset.zero) return;

    _publishOffset(_dragOffset + delta);
  }

  void _handleDragEnd([DragEndDetails? _]) {
    if (!_dragUnderway) return;
    _dragUnderway = false;
    if (_dragOffset == Offset.zero) return;

    final decision = FreeMotion(_dragOffset).decide(
      bounds: _screenSize,
      threshold: widget.threshold,
    );
    switch (decision) {
      case DismissDecision.dismiss:
        _dispatchDismissed();
        widget.onDismissed();
      case DismissDecision.reverse:
        _settleFrom = _dragOffset;
        unawaited(_settleController.forward(from: 0));
        widget.onDragEnd?.call();
    }
  }

  void _handleSettleTick() {
    final t = widget.reverseCurve.transform(_settleController.value);
    _publishOffset(Offset.lerp(_settleFrom, Offset.zero, t)!);
  }

  void _handleSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    if (mounted) _settleController.value = 0;
    _publishOffset(Offset.zero);
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
    final axisOffset = switch (scrollAxis) {
      Axis.horizontal => _dragOffset.dx,
      Axis.vertical => _dragOffset.dy,
    };

    final hasScrollableContent =
        (position.maxScrollExtent - position.minScrollExtent).abs() >
        _kOriginEpsilon;
    final isReturning =
        (axisOffset > 0 && delta < 0) || (axisOffset < 0 && delta > 0);
    final reachesOrigin =
        isReturning && (delta.abs() + _kOriginEpsilon >= axisOffset.abs());

    if (hasScrollableContent && reachesOrigin) {
      _publishOffset(switch (scrollAxis) {
        Axis.horizontal => Offset(0, _dragOffset.dy),
        Axis.vertical => Offset(_dragOffset.dx, 0),
      });
      return;
    }

    _applyDelta(delta2D);
  }

  void _handleScrollDragEnd() => _handleDragEnd();

  bool _shouldConsumeUserOffset(double delta, ScrollPosition position) {
    if (!_dismissEnabled) return false;

    // Keep consuming while the page is displaced so inner content does not
    // start scrolling mid-dismissal.
    if (_dragOffset != Offset.zero) return true;

    return ScrollExtentMetrics.fromScrollMetrics(
      position,
    ).shouldConsumeFreeScrollDelta(delta);
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
