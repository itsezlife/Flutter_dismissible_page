import 'dart:math' as math;

import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Package-internal callback that checks edge-dismiss eligibility.
@internal
typedef PagerDismissEligibility =
    bool Function(double delta, ScrollPosition position);

/// Package-internal callback that applies an edge-dismiss delta.
@internal
typedef PagerDismissUpdate =
    void Function(double delta, ScrollPosition position);

/// A [PageController] whose page position can coordinate edge dismissal.
///
/// Pass this controller to a stock horizontal [PageView]. It retains the
/// standard programmatic page APIs while allowing the pager page widget to
/// arbitrate user offsets at settled pager edges.
class DismissiblePageViewController extends ScrollController
    implements PageController {
  /// Creates a page controller.
  DismissiblePageViewController({
    this.initialPage = 0,
    this.keepPage = true,
    this.viewportFraction = 1,
    super.onAttach,
    super.onDetach,
  }) : assert(viewportFraction > 0, 'viewportFraction must be greater than 0');

  @override
  final int initialPage;

  @override
  final bool keepPage;

  @override
  final double viewportFraction;

  PagerDismissEligibility? _isDismissEligible;
  PagerDismissUpdate? _onDismissUpdate;
  VoidCallback? _onDismissStart;
  VoidCallback? _onDismissEnd;
  bool Function()? _dismissExtentIsAtOrigin;
  PagerCommitment _commitment = PagerCommitment.lockedUntilRelease;

  /// Installs the package-internal dismissal adapter.
  @internal
  void configureDismissal({
    required PagerDismissEligibility isDismissEligible,
    required VoidCallback onDismissStart,
    required PagerDismissUpdate onDismissUpdate,
    required VoidCallback onDismissEnd,
    required bool Function() dismissExtentIsAtOrigin,
    required PagerCommitment commitment,
  }) {
    _isDismissEligible = isDismissEligible;
    _onDismissStart = onDismissStart;
    _onDismissUpdate = onDismissUpdate;
    _onDismissEnd = onDismissEnd;
    _dismissExtentIsAtOrigin = dismissExtentIsAtOrigin;
    _commitment = commitment;
  }

  /// Removes the package-internal dismissal adapter.
  @internal
  void clearDismissal() {
    _isDismissEligible = null;
    _onDismissStart = null;
    _onDismissUpdate = null;
    _onDismissEnd = null;
    _dismissExtentIsAtOrigin = null;
  }

  @override
  double? get page => position.page;

  @override
  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
  }) {
    final pagePosition = position;
    if (pagePosition.cachedPage case _?) {
      pagePosition.cachedPage = page.toDouble();
      return Future<void>.value();
    }
    if (!pagePosition.hasViewportDimension) {
      pagePosition.pageToUseOnStartup = page.toDouble();
      return Future<void>.value();
    }
    return pagePosition.animateTo(
      pagePosition.getPixelsFromPage(page.toDouble()),
      duration: duration,
      curve: curve,
    );
  }

  @override
  void jumpToPage(int page) {
    final pagePosition = position;
    if (pagePosition.cachedPage case _?) {
      pagePosition.cachedPage = page.toDouble();
      return;
    }
    if (!pagePosition.hasViewportDimension) {
      pagePosition.pageToUseOnStartup = page.toDouble();
      return;
    }
    pagePosition.jumpTo(pagePosition.getPixelsFromPage(page.toDouble()));
  }

  @override
  Future<void> nextPage({
    required Duration duration,
    required Curve curve,
  }) {
    return animateToPage(page!.round() + 1, duration: duration, curve: curve);
  }

  @override
  Future<void> previousPage({
    required Duration duration,
    required Curve curve,
  }) {
    return animateToPage(page!.round() - 1, duration: duration, curve: curve);
  }

  @override
  DismissiblePageViewPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return DismissiblePageViewPosition(
      physics: physics,
      context: context,
      controller: this,
      initialPage: initialPage,
      keepPage: keepPage,
      viewportFraction: viewportFraction,
      oldPosition: oldPosition,
    );
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    (position as DismissiblePageViewPosition).viewportFraction =
        viewportFraction;
  }

  @override
  DismissiblePageViewPosition get position =>
      super.position as DismissiblePageViewPosition;
}

/// Page position used by [DismissiblePageViewController].
///
/// The page-metric implementation mirrors Flutter's page position because
/// Flutter's stock implementation is private and its controller hard-casts to
/// that private type.
class DismissiblePageViewPosition extends ScrollPositionWithSingleContext
    implements PageMetrics {
  /// Creates a package page position.
  DismissiblePageViewPosition({
    required super.physics,
    required super.context,
    required this.controller,
    this.initialPage = 0,
    bool keepPage = true,
    double viewportFraction = 1,
    super.oldPosition,
  }) : assert(
         viewportFraction > 0,
         'viewportFraction must be greater than 0',
       ),
       _viewportFraction = viewportFraction,
       pageToUseOnStartup = initialPage.toDouble(),
       super(initialPixels: null, keepScrollOffset: keepPage);

  /// Controller that owns this position's pager-dismiss adapter.
  final DismissiblePageViewController controller;

  /// Page shown before a stored page or programmatic change takes precedence.
  final int initialPage;

  /// Page restored when viewport dimensions first become available.
  double pageToUseOnStartup;

  /// Page retained while the viewport has a zero dimension.
  double? cachedPage;
  PagerCommitmentState _commitmentState =
      const PagerCommitmentState.undecided();
  bool _dismissDragUnderway = false;

  double _viewportFraction;

  @override
  double get viewportFraction => _viewportFraction;

  /// Updates the fraction occupied by each page while preserving [page].
  set viewportFraction(double value) {
    if (_viewportFraction == value) return;
    final oldPage = page;
    _viewportFraction = value;
    if (oldPage case final oldPage?) {
      forcePixels(getPixelsFromPage(oldPage));
    }
  }

  double get _initialPageOffset =>
      math.max(0, viewportDimension * (viewportFraction - 1) / 2);

  /// Converts a pixel offset to a fractional page.
  double getPageFromPixels(double pixels, double viewportDimension) {
    final actual =
        math.max(0, pixels - _initialPageOffset) /
        (viewportDimension * viewportFraction);
    final rounded = actual.roundToDouble();
    return (actual - rounded).abs() < precisionErrorTolerance
        ? rounded
        : actual;
  }

  /// Converts a fractional page to its pixel offset.
  double getPixelsFromPage(double page) =>
      page * viewportDimension * viewportFraction + _initialPageOffset;

  @override
  double? get page {
    if (!hasPixels) return null;
    return hasContentDimensions || haveDimensions
        ? cachedPage ??
              getPageFromPixels(
                clampDouble(pixels, minScrollExtent, maxScrollExtent),
                viewportDimension,
              )
        : null;
  }

  @override
  void applyUserOffset(double delta) {
    final eligibility = controller._isDismissEligible;
    if (eligibility == null || delta.abs() <= precisionErrorTolerance) {
      super.applyUserOffset(delta);
      return;
    }

    final decision = controller._commitment.decide(
      _commitmentState,
      eligibleForDismiss: eligibility(delta, this),
      dismissExtentIsAtOrigin:
          controller._dismissExtentIsAtOrigin?.call() ?? true,
    );
    _commitmentState = decision.next;
    switch (decision.disposition) {
      case PagerAxisDisposition.pageScroll:
        if (_dismissDragUnderway) {
          _dismissDragUnderway = false;
          controller._onDismissEnd?.call();
        }
        super.applyUserOffset(delta);
      case PagerAxisDisposition.dismiss:
        if (!_dismissDragUnderway) {
          _dismissDragUnderway = true;
          controller._onDismissStart?.call();
        }
        controller._onDismissUpdate?.call(delta, this);
    }
  }

  @override
  void goBallistic(double velocity) {
    if (_dismissDragUnderway) {
      _dismissDragUnderway = false;
      controller._onDismissEnd?.call();
      _commitmentState = _commitmentState.afterRelease();
      goIdle();
      return;
    }
    _commitmentState = _commitmentState.afterRelease();
    super.goBallistic(velocity);
  }

  @override
  void dispose() {
    if (_dismissDragUnderway) {
      _dismissDragUnderway = false;
      controller._onDismissEnd?.call();
    }
    super.dispose();
  }

  @override
  void saveScrollOffset() {
    PageStorage.maybeOf(context.storageContext)?.writeState(
      context.storageContext,
      cachedPage ?? getPageFromPixels(pixels, viewportDimension),
    );
  }

  @override
  void restoreScrollOffset() {
    if (hasPixels) return;
    final value =
        PageStorage.maybeOf(
              context.storageContext,
            )?.readState(context.storageContext)
            as double?;
    if (value case final value?) pageToUseOnStartup = value;
  }

  @override
  void saveOffset() {
    context.saveOffset(
      cachedPage ?? getPageFromPixels(pixels, viewportDimension),
    );
  }

  @override
  void restoreOffset(double offset, {bool initialRestore = false}) {
    if (initialRestore) {
      pageToUseOnStartup = offset;
    } else {
      jumpTo(getPixelsFromPage(offset));
    }
  }

  @override
  bool applyViewportDimension(double viewportDimension) {
    final oldViewportDimension = hasViewportDimension
        ? this.viewportDimension
        : null;
    if (viewportDimension == oldViewportDimension) return true;

    final result = super.applyViewportDimension(viewportDimension);
    final oldPixels = hasPixels ? pixels : null;
    final page = switch ((oldPixels, oldViewportDimension)) {
      (null, _) => pageToUseOnStartup,
      (_, 0) => cachedPage!,
      (final pixels?, final dimension?) => getPageFromPixels(pixels, dimension),
      _ => pageToUseOnStartup,
    };
    final newPixels = getPixelsFromPage(page);
    cachedPage = viewportDimension == 0 ? page : null;
    if (newPixels != oldPixels) {
      correctPixels(newPixels);
      return false;
    }
    return result;
  }

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    if (other case DismissiblePageViewPosition(cachedPage: final cached?)) {
      cachedPage = cached;
    }
  }

  @override
  bool applyContentDimensions(
    double minScrollExtent,
    double maxScrollExtent,
  ) {
    final newMin = minScrollExtent + _initialPageOffset;
    return super.applyContentDimensions(
      newMin,
      math.max(newMin, maxScrollExtent - _initialPageOffset),
    );
  }

  @override
  PageMetrics copyWith({
    double? minScrollExtent,
    double? maxScrollExtent,
    double? pixels,
    double? viewportDimension,
    AxisDirection? axisDirection,
    double? viewportFraction,
    double? devicePixelRatio,
  }) {
    return PageMetrics(
      minScrollExtent:
          minScrollExtent ??
          (hasContentDimensions ? this.minScrollExtent : null),
      maxScrollExtent:
          maxScrollExtent ??
          (hasContentDimensions ? this.maxScrollExtent : null),
      pixels: pixels ?? (hasPixels ? this.pixels : null),
      viewportDimension:
          viewportDimension ??
          (hasViewportDimension ? this.viewportDimension : null),
      axisDirection: axisDirection ?? this.axisDirection,
      viewportFraction: viewportFraction ?? this.viewportFraction,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }
}
