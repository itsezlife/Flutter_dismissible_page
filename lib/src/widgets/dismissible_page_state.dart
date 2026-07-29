part of 'dismissible_page.dart';

/// Shared adapter scaffolding for [DismissiblePage] variants.
///
/// Owns scroll/settle controllers, drag presentation publishing, chrome
/// composition, and the gesture shell. Motion-specific gesture/scroll rules
/// stay in each concrete State.
abstract class _DismissiblePageState<W extends DismissiblePage> extends State<W>
    with SingleTickerProviderStateMixin {
  static const double originEpsilon = 1e-6;

  late final DismissiblePageScrollController scrollController;
  late final ScrollController defaultScrollController;
  late final AnimationController settleController;
  late final ValueNotifier<DismissiblePageDragUpdateDetails> dragNotifier;

  Size get screenSize => MediaQuery.sizeOf(context);

  bool dragUnderway = false;
  bool canInnerContentScroll = false;

  /// True while [DismissiblePage.confirmDismiss] is awaiting a result.
  bool confirmingDismiss = false;

  /// Axis of the nested scrollable, or null before it reports one.
  ///
  /// Scroll Arbitration owns this axis; variants consult it to decide whether
  /// an off-axis gesture shell has to coexist with arbitration.
  Axis? innerScrollAxis;

  /// Whether drag-to-dismiss is currently allowed for this variant.
  bool get dismissEnabled;

  /// Debug label for the post-frame scrollability check.
  String get postFrameDebugLabel;

  DragPresentationConfig get presentationConfig => DragPresentationConfig(
    minRadius: widget.minRadius,
    maxRadius: widget.maxRadius,
    minScale: widget.minScale,
    startingOpacity: widget.startingOpacity,
    minOpacity: widget.minOpacity,
  );

  @override
  void initState() {
    super.initState();
    // Resting details must not read MediaQuery — that inherited lookup is
    // illegal until after initState completes.
    dragNotifier = ValueNotifier(
      DismissiblePageDragUpdateDetails(
        radius: widget.minRadius,
        opacity: widget.startingOpacity,
      ),
    )..addListener(dragListener);
    settleController =
        AnimationController(vsync: this, duration: widget.reverseDuration)
          ..addListener(handleSettleTick)
          ..addStatusListener(handleSettleStatus);
    scrollController = DismissiblePageScrollController(
      shouldConsumeUserOffset: shouldConsumeUserOffset,
      onDismissDragStart: handleScrollDragStart,
      onDismissDragUpdate: handleScrollDragUpdate,
      onDismissDragEnd: handleScrollDragEnd,
    );
    defaultScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkCanInnerContentScroll();
      DismissiblePageDragNotification(
        details: dragNotifier.value,
      ).dispatch(context);
    }, debugLabel: postFrameDebugLabel);
  }

  @override
  void dispose() {
    dragNotifier
      ..removeListener(dragListener)
      ..dispose();
    scrollController.dispose();
    defaultScrollController.dispose();
    settleController
      ..removeListener(handleSettleTick)
      ..removeStatusListener(handleSettleStatus)
      ..dispose();
    super.dispose();
  }

  void checkCanInnerContentScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final previousCanScroll = canInnerContentScroll;
    final previousAxis = innerScrollAxis;
    canInnerContentScroll = position.maxScrollExtent > 0;
    innerScrollAxis = axisDirectionToAxis(position.axisDirection);
    // Structural flip (which gesture shells are mounted) — the only setState
    // this State needs.
    if (previousCanScroll != canInnerContentScroll ||
        previousAxis != innerScrollAxis) {
      setState(() {});
    }
  }

  void dragListener() {
    widget.onDragUpdate?.call(dragNotifier.value);
    DismissiblePageDragNotification(
      details: dragNotifier.value,
    ).dispatch(context);
  }

  void publishDetails(DismissiblePageDragUpdateDetails details) {
    if (!mounted) return;
    dragNotifier.value = details;
  }

  void handleSettleTick() {
    onSettleTick(widget.reverseCurve.transform(settleController.value));
  }

  void handleSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (mounted) settleController.value = 0;
    onSettleCompleted();
  }

  void dispatchDismissed() {
    DismissiblePageDragNotification(
      details: dragNotifier.value.copyWith(isDismissed: true),
    ).dispatch(context);
  }

  /// Completes dismiss, or reverse-settles when
  /// [DismissiblePage.confirmDismiss] returns false. Holds at the current
  /// extent until the Future completes.
  Future<void> awaitConfirmDismiss({
    required VoidCallback reverseSettle,
  }) async {
    if (widget.confirmDismiss case final confirm?) {
      confirmingDismiss = true;
      final shouldDismiss = await confirm();
      if (!mounted) return;
      confirmingDismiss = false;
      if (!shouldDismiss) {
        reverseSettle();
        return;
      }
    }
    dispatchDismissed();
    widget.onDismissed();
  }

  void handleScrollDragStart() => handleDragStart(innerScrollAxis);

  void handleScrollDragEnd() => handleDragEnd();

  /// Called each settle-animation frame with the eased progress `t` in 0–1.
  void onSettleTick(double t);

  /// Called when a reverse settle finishes; reset motion locals here.
  void onSettleCompleted();

  /// Called when a dismiss drag begins.
  ///
  /// [axis] is the axis the incoming gesture is confined to, or null when the
  /// shell tracks the full plane.
  void handleDragStart([Axis? axis]);

  void applyDelta(Offset delta);

  void handleDragEnd([DragEndDetails? details]);

  void handleScrollDragUpdate(double delta, ScrollPosition position);

  bool shouldConsumeUserOffset(double delta, ScrollPosition position);

  @override
  Widget build(BuildContext context) {
    final contentPadding = widget.isFullScreen
        ? EdgeInsets.zero
        : MediaQuery.paddingOf(context);

    final scrollMode =
        widget.interactionMode == DismissiblePageInteractionMode.scroll;
    final activeScrollController = (scrollMode && dismissEnabled)
        ? scrollController
        : defaultScrollController;
    final useScrollArbitration =
        scrollMode && dismissEnabled && canInnerContentScroll;

    // Chrome rebuilds on drag frames; builder content is the stable [child]
    // and is not rebuilt every pointer move.
    final chrome = ValueListenableBuilder<DismissiblePageDragUpdateDetails>(
      valueListenable: dragNotifier,
      child: widget.builder(context, activeScrollController),
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
        if (didPop) dispatchDismissed();
      },
      child: useScrollArbitration
          ? wrapWithCoexistingShell(chrome)
          : wrapWithGestures(chrome),
    );
  }

  Widget wrapWithGestures(Widget child) {
    if (!dismissEnabled) return child;
    return GestureDetector(
      behavior: widget.hitTestBehavior,
      dragStartBehavior: widget.dragStartBehavior,
      onPanStart: (_) => handleDragStart(),
      onPanUpdate: (details) => applyDelta(details.delta),
      onPanEnd: handleDragEnd,
      child: child,
    );
  }

  /// Wraps [child] in the gesture shell that coexists with Scroll Arbitration.
  ///
  /// Arbitration already serves the nested scrollable's axis, so the default
  /// is no shell at all. Variants that also need dismissal off that axis
  /// override this.
  Widget wrapWithCoexistingShell(Widget child) => child;

  /// A drag recognizer confined to [axis].
  ///
  /// Partitioning by axis is what lets a shell coexist with Scroll
  /// Arbitration: Flutter's gesture arena routes on-axis drags to the nested
  /// scrollable and cross-axis drags here.
  Widget wrapWithAxisPartitionedGestures(Widget child, Axis axis) {
    void start(DragStartDetails _) => handleDragStart(axis);
    void update(DragUpdateDetails details) => applyDelta(details.delta);

    return switch (axis) {
      Axis.horizontal => GestureDetector(
        behavior: widget.hitTestBehavior,
        dragStartBehavior: widget.dragStartBehavior,
        onHorizontalDragStart: start,
        onHorizontalDragUpdate: update,
        onHorizontalDragEnd: handleDragEnd,
        child: child,
      ),
      Axis.vertical => GestureDetector(
        behavior: widget.hitTestBehavior,
        dragStartBehavior: widget.dragStartBehavior,
        onVerticalDragStart: start,
        onVerticalDragUpdate: update,
        onVerticalDragEnd: handleDragEnd,
        child: child,
      ),
    };
  }
}
