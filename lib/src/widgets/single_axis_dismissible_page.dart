// ignore_for_file: discarded_futures

import 'dart:math';

import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_builder.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_chrome.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_dismiss_direction.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_drag_update_details.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_helpers.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_interaction_mode.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_scroll_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// {@template single_axis_dismissible_page}
/// A specialized dismissible page that handles single-directional dismissal
/// gestures.
///
/// This widget allows users to dismiss content by dragging in a specific
/// direction (horizontal, vertical, or constrained directional). It provides
/// smooth animations, gesture recognition, and integration with scrollable
/// widgets.
///
/// The widget supports two interaction modes:
/// - [DismissiblePageInteractionMode.gesture]: Direct gesture handling
/// - [DismissiblePageInteractionMode.scroll]: Integration with scroll
/// controllers
///
/// Key features:
/// - Single-direction drag detection with directional constraints
/// - Animated transformations (scale, radius, opacity, translation)
/// - Scroll-aware gesture handling with proper coordination
/// - Customizable dismiss thresholds per direction
/// - Smooth return animations when dismissal threshold is not met
/// - RTL text direction support for horizontal gestures
/// {@endtemplate}
@visibleForTesting
class SingleAxisDismissiblePage extends StatefulWidget {
  /// {@macro single_axis_dismissible_page}
  const SingleAxisDismissiblePage({
    required this.builder,
    required this.onDismissed,
    required this.isFullScreen,
    required this.backgroundColor,
    required this.direction,
    required this.dismissThresholds,
    required this.dragStartBehavior,
    required this.dragSensitivity,
    required this.minRadius,
    required this.minScale,
    required this.maxRadius,
    required this.maxTransformValue,
    required this.startingOpacity,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragUpdate,
    required this.reverseDuration,
    required this.hitTestBehavior,
    required this.contentPadding,
    required this.interactionMode,
    required this.enableBackgroundOpacity,
    required this.minOpacity,
    this.disabled = false,
    super.key,
  });

  /// The initial opacity of the background when the page is displayed.
  final double startingOpacity;

  /// Called when the user starts dragging the widget.
  final VoidCallback? onDragStart;

  /// Called when the user ends dragging the widget.
  final VoidCallback? onDragEnd;

  /// Called when the widget has been dismissed.
  final VoidCallback onDismissed;

  /// Called when the widget has been dragged with updated details.
  final ValueChanged<DismissiblePageDragUpdateDetails>? onDragUpdate;

  /// Whether the widget should ignore device padding.
  final bool isFullScreen;

  /// If true, drag-to-dismiss gestures are disabled (content remains
  /// interactive).
  final bool disabled;

  /// The minimum scale factor applied during drag gestures.
  final double minScale;

  /// The minimum border radius of the widget.
  final double minRadius;

  /// The maximum border radius applied during drag gestures.
  final double maxRadius;

  /// The maximum transform value for drag distance (0.0 - 1.0).
  final double maxTransformValue;

  /// Builder function that creates the dismissible content.
  final DismissiblePageBuilder builder;

  /// The background color of the dismissible page.
  final Color? backgroundColor;

  /// The direction in which the widget can be dismissed.
  final DismissiblePageDismissDirection direction;

  /// Custom dismiss thresholds for different directions.
  final Map<DismissiblePageDismissDirection, double> dismissThresholds;

  /// Controls the responsiveness of drag gestures.
  final double dragSensitivity;

  /// Determines how drag start behavior is handled.
  final DragStartBehavior dragStartBehavior;

  /// Duration for the return animation when dismissal threshold is not met.
  final Duration reverseDuration;

  /// How the widget behaves during hit tests.
  final HitTestBehavior hitTestBehavior;

  /// Padding applied to the content area.
  final EdgeInsetsGeometry contentPadding;

  /// Controls how drag-to-dismiss interaction is coordinated with scrollables.
  final DismissiblePageInteractionMode interactionMode;

  /// Whether to enable background opacity animation.
  final bool enableBackgroundOpacity;

  /// The minimum opacity of the background when the page is displayed.
  final double minOpacity;

  @override
  State<SingleAxisDismissiblePage> createState() =>
      _SingleAxisDismissiblePageState();
}

class _SingleAxisDismissiblePageState extends State<SingleAxisDismissiblePage>
    with TickerProviderStateMixin, DismissiblePageGestureMixin {
  static const double _kOriginEpsilon = 1e-6;

  /// Animation that controls the movement offset during drag gestures.
  late Animation<Offset> _moveAnimation;

  /// Custom scroll controller for scroll-aware dismissal mode.
  late final DismissiblePageScrollController _scrollController;

  /// Default scroll controller for gesture-only mode.
  late final ScrollController _defaultScrollController;

  /// The current drag extent in the primary axis direction.
  double _dragExtent = 0;

  /// The text direction of the current context, used for RTL support.
  late final TextDirection _textDirection = Directionality.of(context);

  /// The screen size, used for calculating drag percentages.
  late final Size _screenSize = MediaQuery.sizeOf(context);

  bool _canInnerContentScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = DismissiblePageScrollController(
      shouldConsumeUserOffset: _shouldConsumeUserOffset,
      onDismissDragStart: _handleScrollDragStart,
      onDismissDragUpdate: _handleScrollDragUpdate,
      onDismissDragEnd: _handleScrollDragEnd,
    );
    _defaultScrollController = ScrollController();
    moveController = AnimationController(
      duration: Duration.zero,
      vsync: this,
    );
    moveController
      ..addStatusListener(_handleDismissStatusChanged)
      ..addListener(_moveAnimationListener);
    _updateMoveAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCanInnerContentScroll();
      DismissiblePageDragNotification(details: _details).dispatch(context);
    }, debugLabel: 'SingleAxisDismissiblePage.checkCanInnerContentScroll');
  }

  void _checkCanInnerContentScroll() {
    if (!_scrollController.hasClients) return;

    final oldCanInnerContentScroll = _canInnerContentScroll;
    _canInnerContentScroll = _scrollController.position.maxScrollExtent > 0;

    if (oldCanInnerContentScroll == _canInnerContentScroll) return;

    setState(() {});
  }

  DragPresentationConfig get _presentationConfig => DragPresentationConfig(
    minRadius: widget.minRadius,
    maxRadius: widget.maxRadius,
    minScale: widget.minScale,
    startingOpacity: widget.startingOpacity,
    minOpacity: widget.minOpacity,
  );

  DragPresentation get _presentation {
    // Constrained motion stores a fractional drag offset; chrome expects
    // pixels.
    final fractional = _offset;
    return _presentationConfig.map(
      progress: _dragValue.clamp(0.0, 1.0),
      offset: Offset(
        fractional.dx * _screenSize.width,
        fractional.dy * _screenSize.height,
      ),
    );
  }

  DismissiblePageDragUpdateDetails get _details =>
      DismissiblePageDragUpdateDetails(
        overallDragValue: min(
          _dragExtent / _overallDragAxisExtent,
          widget.maxTransformValue,
        ),
        radius: _presentation.radius,
        opacity: _presentation.opacity,
        offset: _presentation.offset,
        scale: _presentation.scale,
      );

  /// Animation listener that triggers drag update callbacks.
  void _moveAnimationListener() {
    if (widget.onDragUpdate case final onDragUpdate?) {
      onDragUpdate.call(_details);
    }

    DismissiblePageDragNotification(details: _details).dispatch(context);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _defaultScrollController.dispose();
    moveController
      ..removeStatusListener(_handleDismissStatusChanged)
      ..removeListener(_moveAnimationListener)
      ..dispose();
    super.dispose();
  }

  /// Returns true if the scroll delta can be converted to a drag delta.
  bool get _canConvertScrollDeltaToDragDelta =>
      widget.direction.axes.contains(Axis.vertical) &&
      widget.interactionMode == DismissiblePageInteractionMode.scroll;

  /// Returns true if the configured direction is along the X-axis.
  bool get _directionIsXAxis {
    return widget.direction.axes.contains(Axis.horizontal);
  }

  /// Converts a drag extent to its corresponding dismiss direction.
  ///
  /// Takes into account the text direction for horizontal gestures to
  /// properly handle RTL layouts.
  ///
  /// [extent] - The drag extent value to convert.
  ///
  /// Returns the corresponding dismiss direction, or null if extent is zero.
  DismissiblePageDismissDirection? _extentToDirection(double extent) {
    if (extent == 0.0) return null;
    if (_directionIsXAxis) {
      switch (_textDirection) {
        case TextDirection.rtl:
          return extent < 0
              ? DismissiblePageDismissDirection.startToEnd
              : DismissiblePageDismissDirection.endToStart;
        case TextDirection.ltr:
          return extent > 0
              ? DismissiblePageDismissDirection.startToEnd
              : DismissiblePageDismissDirection.endToStart;
      }
    }
    return extent > 0
        ? DismissiblePageDismissDirection.down
        : DismissiblePageDismissDirection.up;
  }

  /// The current dismiss direction based on the drag extent.
  DismissiblePageDismissDirection? get _dismissDirection =>
      _extentToDirection(_dragExtent);

  /// The total extent of the drag axis (width for horizontal, height for
  /// vertical).
  double get _overallDragAxisExtent {
    return _directionIsXAxis ? _screenSize.width : _screenSize.height;
  }

  /// Handles the start of a drag gesture.
  void _handleDragStart([DragStartDetails? _]) {
    widget.onDragStart?.call();
    dragUnderway = true;
    if (moveController.isAnimating) {
      _dragExtent =
          moveController.value * _overallDragAxisExtent * _dragExtent.sign;
      moveController.stop();
    } else {
      _dragExtent = 0.0;
      moveController.value = 0.0;
    }
    _updateMoveAnimation();
  }

  /// Handles drag update events from gesture recognizers.
  void _handleDragUpdate(DragUpdateDetails details) {
    if (!isActive || moveController.isAnimating) return;
    final delta = details.primaryDelta;
    if (delta == null) return;
    _applyDragDelta(delta);
  }

  /// Applies a drag delta to the current drag extent.
  void _applyDragDelta(double delta, {bool isScrollDelta = false}) {
    if (!isActive || moveController.isAnimating) return;
    final oldDragExtent = _dragExtent;

    if (isScrollDelta && !_canConvertScrollDeltaToDragDelta) {
      return;
    }

    switch (widget.direction) {
      case DismissiblePageDismissDirection.horizontal:
      case DismissiblePageDismissDirection.vertical:
        _dragExtent += delta;
      case DismissiblePageDismissDirection.up:
        if (_dragExtent + delta < 0) _dragExtent += delta;
      case DismissiblePageDismissDirection.down:
        if (_dragExtent + delta > 0) _dragExtent += delta;
      case DismissiblePageDismissDirection.endToStart:
        switch (_textDirection) {
          case TextDirection.rtl:
            if (_dragExtent + delta > 0) _dragExtent += delta;
          case TextDirection.ltr:
            if (_dragExtent + delta < 0) _dragExtent += delta;
        }
      case DismissiblePageDismissDirection.startToEnd:
        switch (_textDirection) {
          case TextDirection.rtl:
            if (_dragExtent + delta < 0) _dragExtent += delta;
          case TextDirection.ltr:
            if (_dragExtent + delta > 0) _dragExtent += delta;
        }
      case DismissiblePageDismissDirection.multi ||
          DismissiblePageDismissDirection.none:
        // Multi-axis is handled by MultiAxisDismissiblePage
        break;
    }

    if (oldDragExtent.sign != _dragExtent.sign) {
      _updateMoveAnimation();
    }

    if (!moveController.isAnimating) {
      moveController.value = _dragExtent.abs() / _overallDragAxisExtent;
    }
  }

  /// Updates the move animation based on the current drag extent and direction.
  void _updateMoveAnimation() {
    final end = _dragExtent.sign * widget.dragSensitivity;
    _moveAnimation = moveController.drive(
      Tween<Offset>(
        begin: Offset.zero,
        end: _directionIsXAxis ? Offset(end, 0) : Offset(0, end),
      ),
    );
  }

  /// The dismiss threshold for the current dismiss direction.
  double get _dismissThreshold =>
      widget.dismissThresholds[_dismissDirection] ?? kDismissThreshold;

  /// Handles the end of a drag gesture.
  void _handleDragEnd([DragEndDetails? _]) {
    if (!isActive || moveController.isAnimating) return;
    dragUnderway = false;
    if (!moveController.isDismissed) {
      if (moveController.value > _dismissThreshold) {
        DismissiblePageDragNotification(
          details: _details.copyWith(isDismissed: true),
        ).dispatch(context);
        widget.onDismissed.call();
      } else {
        moveController
          ..reverseDuration =
              widget.reverseDuration * (1 / moveController.value)
          ..reverse();
        DismissiblePageDragNotification(
          details: _details,
        ).dispatch(context);
        widget.onDragEnd?.call();
      }
    }
  }

  /// Handles the start of a scroll-based drag operation.
  void _handleScrollDragStart() {
    _handleDragStart();
  }

  /// Handles scroll-based drag updates.
  void _handleScrollDragUpdate(
    double delta,
    ScrollPosition position,
  ) {
    final hasScrollableContent =
        (position.maxScrollExtent - position.minScrollExtent).abs() >
        _kOriginEpsilon;
    final isReturningToOrigin =
        _dragExtent != 0 && _isDeltaReturningPageToOrigin(delta);
    final reachesOrCrossesOrigin =
        isReturningToOrigin &&
        (delta.abs() + _kOriginEpsilon >= _dragExtent.abs());

    if (hasScrollableContent && reachesOrCrossesOrigin) {
      _dragExtent = 0;
      moveController.value = 0;
      _updateMoveAnimation();
      return;
    }

    _applyDragDelta(delta, isScrollDelta: true);
  }

  /// Handles the end of a scroll-based drag operation.
  void _handleScrollDragEnd() {
    _handleDragEnd();
  }

  /// Determines if a delta is returning the page toward its origin.
  ///
  /// This is used to ensure smooth gesture coordination when the user
  /// reverses direction during a drag operation.
  bool _isDeltaReturningPageToOrigin(double delta) {
    return (_dragExtent > 0 && delta < 0) || (_dragExtent < 0 && delta > 0);
  }

  /// Maps the legacy direction enum onto [DismissDirections] for arbitration.
  DismissDirections get _dismissDirections => switch (widget.direction) {
    DismissiblePageDismissDirection.vertical => DismissDirections.vertical,
    DismissiblePageDismissDirection.horizontal => DismissDirections.horizontal,
    DismissiblePageDismissDirection.up => DismissDirections.up,
    DismissiblePageDismissDirection.down => DismissDirections.down,
    DismissiblePageDismissDirection.startToEnd => DismissDirections.startToEnd,
    DismissiblePageDismissDirection.endToStart => DismissDirections.endToStart,
    DismissiblePageDismissDirection.none ||
    DismissiblePageDismissDirection.multi => DismissDirections.empty,
  };

  /// Determines whether the scroll controller should consume user scroll input.
  ///
  /// Returns true if the scroll input should be consumed for dismissal,
  /// false if it should be handled by the scroll view.
  bool _shouldConsumeUserOffset(double delta, ScrollPosition position) {
    // Keep consuming while the page is returning toward origin so content does
    // not start scrolling prematurely.
    if (_dragExtent != 0 && _isDeltaReturningPageToOrigin(delta)) {
      return true;
    }

    final directions = _dismissDirections;
    final scrollAxis = axisDirectionToAxis(position.axisDirection);

    // Mid-drag gesture mode keeps consuming permitted sides even mid-range.
    if (_dragExtent != 0 &&
        widget.interactionMode == DismissiblePageInteractionMode.gesture) {
      return directions.targetsPermittedDismissSide(
        delta: delta,
        scrollAxis: scrollAxis,
        textDirection: _textDirection,
      );
    }

    return directions.shouldConsumeScrollDelta(
      delta: delta,
      metrics: ScrollExtentMetrics.fromScrollMetrics(position),
      scrollAxis: scrollAxis,
      textDirection: _textDirection,
    );
  }

  /// Handles animation status changes for the dismiss animation.
  void _handleDismissStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !dragUnderway) {
      DismissiblePageDragNotification(
        details: _details.copyWith(isDismissed: true),
      ).dispatch(context);
      widget.onDismissed();
    }
  }

  /// The current drag value as an absolute value between 0.0 and 1.0.
  double get _dragValue => _directionIsXAxis
      ? _moveAnimation.value.dx.abs()
      : _moveAnimation.value.dy.abs();

  /// The X component of the drag offset, clamped to maxTransformValue.
  double get _getDx {
    if (_directionIsXAxis) {
      if (_moveAnimation.value.dx.isNegative) {
        return max(_moveAnimation.value.dx, -widget.maxTransformValue);
      } else {
        return min(_moveAnimation.value.dx, widget.maxTransformValue);
      }
    }
    return _moveAnimation.value.dx;
  }

  /// The Y component of the drag offset, clamped to maxTransformValue.
  double get _getDy {
    if (!_directionIsXAxis) {
      if (_moveAnimation.value.dy.isNegative) {
        return max(_moveAnimation.value.dy, -widget.maxTransformValue);
      } else {
        return min(_moveAnimation.value.dy, widget.maxTransformValue);
      }
    }
    return _moveAnimation.value.dy;
  }

  /// The current offset for the transform, combining X and Y components.
  Offset get _offset => Offset(_getDx, _getDy);

  @override
  Widget build(BuildContext context) {
    final scrollController =
        widget.interactionMode == DismissiblePageInteractionMode.scroll
        ? _scrollController
        : _defaultScrollController;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          DismissiblePageDragNotification(
            details: _details.copyWith(isDismissed: true),
          ).dispatch(context);
        }
      },
      child: () {
        final animatedChild = AnimatedBuilder(
          animation: _moveAnimation,
          builder: (context, child) {
            return DismissiblePageChrome(
              presentation: _presentation,
              backgroundColor: widget.backgroundColor,
              enableBackgroundOpacity: widget.enableBackgroundOpacity,
              contentPadding: widget.contentPadding,
              child: child!,
            );
          },
          child: widget.builder(context, scrollController),
        );

        if (widget.interactionMode == DismissiblePageInteractionMode.scroll &&
            _canInnerContentScroll &&
            _canConvertScrollDeltaToDragDelta) {
          return animatedChild;
        }

        return GestureDetector(
          onHorizontalDragStart: (_directionIsXAxis && !widget.disabled)
              ? _handleDragStart
              : null,
          onHorizontalDragUpdate: (_directionIsXAxis && !widget.disabled)
              ? _handleDragUpdate
              : null,
          onHorizontalDragEnd: (_directionIsXAxis && !widget.disabled)
              ? _handleDragEnd
              : null,
          onVerticalDragStart: (!_directionIsXAxis && !widget.disabled)
              ? _handleDragStart
              : null,
          onVerticalDragUpdate: (!_directionIsXAxis && !widget.disabled)
              ? _handleDragUpdate
              : null,
          onVerticalDragEnd: (!_directionIsXAxis && !widget.disabled)
              ? _handleDragEnd
              : null,
          behavior: widget.hitTestBehavior,
          dragStartBehavior: widget.dragStartBehavior,
          child: DismissiblePageListener(
            onStart: (_) => _handleDragStart(),
            onUpdate: _handleDragUpdate,
            onEnd: _handleDragEnd,
            parentState: this,
            direction: widget.direction,
            enabled: !widget.disabled,
            child: animatedChild,
          ),
        );
      }(),
    );
  }
}
