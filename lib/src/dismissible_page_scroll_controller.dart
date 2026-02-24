part of 'dismissible_page.dart';

typedef _ShouldConsumeUserOffset =
    bool Function(double delta, ScrollPosition position);
typedef _HandleDismissOffset =
    void Function(double delta, ScrollPosition position);

class _DismissiblePageScrollController extends ScrollController {
  _DismissiblePageScrollController({
    required this.shouldConsumeUserOffset,
    required this.onDismissDragStart,
    required this.onDismissDragUpdate,
    required this.onDismissDragEnd,
  });

  final _ShouldConsumeUserOffset shouldConsumeUserOffset;
  final VoidCallback onDismissDragStart;
  final _HandleDismissOffset onDismissDragUpdate;
  final VoidCallback onDismissDragEnd;

  @override
  _DismissiblePageScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _DismissiblePageScrollPosition(
      physics: physics.applyTo(const AlwaysScrollableScrollPhysics()),
      context: context,
      oldPosition: oldPosition,
      shouldConsumeUserOffset: shouldConsumeUserOffset,
      onDismissDragStart: onDismissDragStart,
      onDismissDragUpdate: onDismissDragUpdate,
      onDismissDragEnd: onDismissDragEnd,
    );
  }

  @override
  _DismissiblePageScrollPosition get position =>
      super.position as _DismissiblePageScrollPosition;
}

class _DismissiblePageScrollPosition extends ScrollPositionWithSingleContext {
  _DismissiblePageScrollPosition({
    required super.physics,
    required super.context,
    required this.shouldConsumeUserOffset,
    required this.onDismissDragStart,
    required this.onDismissDragUpdate,
    required this.onDismissDragEnd,
    super.oldPosition,
  });

  final _ShouldConsumeUserOffset shouldConsumeUserOffset;
  final VoidCallback onDismissDragStart;
  final _HandleDismissOffset onDismissDragUpdate;
  final VoidCallback onDismissDragEnd;

  bool get listShouldScroll => pixels > 0;
  bool deltaAwareListShouldScroll(double delta) =>
      listShouldScroll && delta > 0;

  bool _dismissDragUnderway = false;

  @override
  void applyUserOffset(double delta) {
    final shouldConsume = shouldConsumeUserOffset(delta, this);
    if (shouldConsume) {
      if (!_dismissDragUnderway) {
        _dismissDragUnderway = true;
        onDismissDragStart();
      }
      onDismissDragUpdate(delta, this);
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (_dismissDragUnderway) {
      _dismissDragUnderway = false;
      onDismissDragEnd();
    }
    super.goBallistic(velocity);
  }

  @override
  void dispose() {
    if (_dismissDragUnderway) {
      _dismissDragUnderway = false;
      onDismissDragEnd();
    }
    super.dispose();
  }
}
