import 'package:dismissible_page/src/widgets/dismissible_page_drag_update_details.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Whether a user scroll [delta] should be consumed as page dismissal.
@internal
typedef ShouldConsumeUserOffset =
    bool Function(double delta, ScrollPosition position);

/// Applies a dismiss drag [delta] from scroll input.
@internal
typedef HandleDismissOffset =
    void Function(double delta, ScrollPosition position);

/// Package-internal scroll controller that arbitrates dismiss vs inner scroll.
@internal
class DismissiblePageScrollController extends ScrollController {
  /// Creates a [DismissiblePageScrollController].
  DismissiblePageScrollController({
    required this.shouldConsumeUserOffset,
    required this.onDismissDragStart,
    required this.onDismissDragUpdate,
    required this.onDismissDragEnd,
  });

  /// Whether a user scroll delta should be consumed as dismissal.
  final ShouldConsumeUserOffset shouldConsumeUserOffset;

  /// Called when a dismiss drag starts from scroll input.
  final VoidCallback onDismissDragStart;

  /// Called when a dismiss drag updates from scroll input.
  final HandleDismissOffset onDismissDragUpdate;

  /// Called when a dismiss drag ends from scroll input.
  final VoidCallback onDismissDragEnd;

  @override
  DismissiblePageScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return DismissiblePageScrollPosition(
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
  DismissiblePageScrollPosition get position =>
      super.position as DismissiblePageScrollPosition;
}

/// Package-internal scroll position used by [DismissiblePageScrollController].
@internal
class DismissiblePageScrollPosition extends ScrollPositionWithSingleContext {
  /// Creates a [DismissiblePageScrollPosition].
  DismissiblePageScrollPosition({
    required super.physics,
    required super.context,
    required this.shouldConsumeUserOffset,
    required this.onDismissDragStart,
    required this.onDismissDragUpdate,
    required this.onDismissDragEnd,
    super.oldPosition,
  });

  /// Whether a user scroll delta should be consumed as dismissal.
  final ShouldConsumeUserOffset shouldConsumeUserOffset;

  /// Called when a dismiss drag starts from scroll input.
  final VoidCallback onDismissDragStart;

  /// Called when a dismiss drag updates from scroll input.
  final HandleDismissOffset onDismissDragUpdate;

  /// Called when a dismiss drag ends from scroll input.
  final VoidCallback onDismissDragEnd;

  /// Whether the list has scrolled past the origin.
  bool get listShouldScroll => pixels > 0;

  /// Whether the list should scroll given [delta].
  bool deltaAwareListShouldScroll(double delta) =>
      listShouldScroll && delta > 0;

  /// Guards start/end so each dismiss drag emits lifecycle callbacks once.
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

/// {@template dismissible_page_drag_notification}
/// A [Notification] related to a dismissible page drag, which will be
/// dispatched to the [NotificationListener].
/// {@endtemplate}
class DismissiblePageDragNotification extends Notification
    with ViewportNotificationMixin {
  /// {@macro dismissible_page_drag_notification}
  DismissiblePageDragNotification({
    required this.details,
  });

  /// The details of the drag update.
  final DismissiblePageDragUpdateDetails details;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add(
      'radius: ${details.radius}, opacity: ${details.opacity}, '
      'offset: ${details.offset}, '
      'overallDragValue: ${details.overallDragValue}, scale: ${details.scale}',
    );
  }
}
