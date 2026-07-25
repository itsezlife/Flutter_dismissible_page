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

  late final Size screenSize = MediaQuery.sizeOf(context);

  bool dragUnderway = false;
  bool canInnerContentScroll = false;

  /// Whether drag-to-dismiss is currently allowed for this variant.
  bool get dismissEnabled;

  /// Debug label for the post-frame scrollability check.
  String get postFrameDebugLabel;

  late final DragPresentationConfig presentationConfig = DragPresentationConfig(
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
    final previous = canInnerContentScroll;
    canInnerContentScroll = scrollController.position.maxScrollExtent > 0;
    // Structural flip (gesture shell vs scroll arbitration) — the only
    // setState this State needs.
    if (previous != canInnerContentScroll) setState(() {});
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

  void handleScrollDragStart() => handleDragStart();

  void handleScrollDragEnd() => handleDragEnd();

  /// Called each settle-animation frame with the eased progress `t` in 0–1.
  void onSettleTick(double t);

  /// Called when a reverse settle finishes; reset motion locals here.
  void onSettleCompleted();

  void handleDragStart([Offset? position]);

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
      child: useScrollArbitration ? chrome : wrapWithGestures(chrome),
    );
  }

  Widget wrapWithGestures(Widget child) {
    if (!dismissEnabled) return child;
    return GestureDetector(
      behavior: widget.hitTestBehavior,
      dragStartBehavior: widget.dragStartBehavior,
      onPanStart: (details) => handleDragStart(details.globalPosition),
      onPanUpdate: (details) => applyDelta(details.delta),
      onPanEnd: handleDragEnd,
      child: child,
    );
  }
}
