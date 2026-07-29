/// Flutter widget that dismisses a page via drag gestures, optionally
/// coordinated with nested scrollables.
///
/// The thin public API exposes the two sealed page variants
/// (`ConstrainedDismissiblePage`, `FreeDismissiblePage`) plus the vocabulary
/// they are configured with: `DismissDirections`, `DismissThresholds`,
/// `DismissiblePageShape`, `DismissiblePageInteractionMode`, drag details, the
/// builder typedef, and the transparent route helpers. Other Dismiss Engine
/// internals live behind the dedicated
/// `package:dismissible_page/dismissible_page_engine.dart` entrypoint and are
/// not re-exported here.
library;

export 'src/engine/constrained_motion.dart' show DismissThresholds;
export 'src/engine/dismiss_directions.dart';
export 'src/engine/dismissible_page_shape.dart';
export 'src/engine/pager_commitment.dart' show PagerCommitment;
export 'src/engine/pager_origin_crossing.dart' show PagerOriginCrossing;
export 'src/routes/dismissible_extensions.dart';
export 'src/routes/dismissible_routes.dart';
export 'src/widgets/dismissible_page.dart';
export 'src/widgets/dismissible_page_builder.dart';
export 'src/widgets/dismissible_page_drag_update_details.dart';
export 'src/widgets/dismissible_page_interaction_mode.dart';
export 'src/widgets/dismissible_page_scroll_controller.dart'
    show DismissiblePageDragNotification;
export 'src/widgets/dismissible_page_view.dart';
export 'src/widgets/dismissible_page_view_controller.dart'
    show DismissiblePageViewController;
