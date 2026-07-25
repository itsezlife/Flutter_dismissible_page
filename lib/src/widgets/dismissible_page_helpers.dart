import 'package:dismissible_page/src/widgets/dismissible_page_dismiss_direction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shared gesture locals for dismissible page State classes.
///
/// Package-internal; not exported from the root barrel.
@internal
mixin DismissiblePageGestureMixin {
  /// Animation that drives settle / reverse motion after a drag.
  late final AnimationController moveController;

  /// Active pointer count used to ignore multi-touch during dismissal.
  int activePointerCount = 0;

  /// Whether a drag gesture is currently underway.
  bool dragUnderway = false;

  /// Whether a drag is underway or a settle animation is running.
  bool get isActive => dragUnderway || moveController.isAnimating;
}

/// Package-internal listener that coordinates scroll notifications with
/// dismiss drag callbacks.
@internal
class DismissiblePageListener extends StatelessWidget {
  /// Creates a [DismissiblePageListener].
  const DismissiblePageListener({
    required this.parentState,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.direction,
    required this.child,
    this.enabled = true,
    this.onPointerDown,
    super.key,
  });

  /// Parent State that owns shared gesture locals.
  final DismissiblePageGestureMixin parentState;

  /// Called when a dismiss drag starts.
  final ValueChanged<Offset> onStart;

  /// Called when a dismiss drag ends.
  final ValueChanged<DragEndDetails> onEnd;

  /// Called when a dismiss drag updates.
  final ValueChanged<DragUpdateDetails> onUpdate;

  /// Optional pointer-down routing (e.g. multi-axis recognizer).
  final ValueChanged<PointerDownEvent>? onPointerDown;

  /// Allowed dismiss direction for scroll-notification filtering.
  final DismissiblePageDismissDirection direction;

  /// Child content.
  final Widget child;

  /// Whether gesture / scroll listening is enabled.
  final bool enabled;

  bool get _dragUnderway => parentState.dragUnderway;

  void _startOrUpdateDrag(DragUpdateDetails? details) {
    if (details == null) return;
    if (_dragUnderway) {
      onUpdate(details);
    } else {
      onStart(details.globalPosition);
    }
  }

  void _updateDrag(DragUpdateDetails? details) {
    if (details != null && details.primaryDelta != null) {
      if (_dragUnderway) {
        onUpdate(details);
      }
    }
  }

  bool _isSameDirections(ScrollMetrics metrics) {
    final axis = metrics.axis;
    switch (direction) {
      case DismissiblePageDismissDirection.vertical:
        return axis == Axis.vertical;
      case DismissiblePageDismissDirection.up:
        return axis == Axis.vertical && metrics.extentAfter == 0;
      case DismissiblePageDismissDirection.down:
        return axis == Axis.vertical && metrics.extentBefore == 0;
      case DismissiblePageDismissDirection.horizontal:
        return axis == Axis.horizontal;
      case DismissiblePageDismissDirection.endToStart:
        return axis == Axis.horizontal && metrics.extentAfter == 0;
      case DismissiblePageDismissDirection.startToEnd:
        return axis == Axis.horizontal && metrics.extentBefore == 0;
      case DismissiblePageDismissDirection.none:
        return false;
      case DismissiblePageDismissDirection.multi:
        return true;
    }
  }

  bool _onScrollNotification(ScrollNotification scrollInfo) {
    if (!enabled) return false;
    if (_isSameDirections(scrollInfo.metrics)) {
      if (scrollInfo is OverscrollNotification) {
        _startOrUpdateDrag(scrollInfo.dragDetails);
        return false;
      }

      if (scrollInfo is ScrollUpdateNotification) {
        if (scrollInfo.metrics.outOfRange) {
          _startOrUpdateDrag(scrollInfo.dragDetails);
        } else {
          _updateDrag(scrollInfo.dragDetails);
        }
        return false;
      }
    }

    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!enabled) return;
    parentState.activePointerCount++;
    onPointerDown?.call(event);
  }

  void _onPointerUp(_) {
    if (!enabled) return;
    parentState.activePointerCount--;
    if (_dragUnderway && parentState.activePointerCount == 0) {
      onEnd(DragEndDetails());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: enabled ? _onPointerDown : null,
      onPointerCancel: enabled ? _onPointerUp : null,
      onPointerUp: enabled ? _onPointerUp : null,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: child,
      ),
    );
  }
}
