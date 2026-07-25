/// Flutter widget that allows you to dismiss page to any direction, forget the
/// boring back button and plain transitions.
///
/// - Dismiss to any direction
/// - Works with nested list view
/// - Animating border
/// - Animating background
/// - Animating scale
library;

export 'src/routes/dismissible_extensions.dart';
export 'src/routes/dismissible_routes.dart';
export 'src/widgets/dismissible_page.dart';
export 'src/widgets/dismissible_page_dismiss_direction.dart';
export 'src/widgets/dismissible_page_drag_update_details.dart';
export 'src/widgets/dismissible_page_interaction_mode.dart';
export 'src/widgets/dismissible_page_scroll_controller.dart'
    show DismissiblePageDragNotification;
export 'src/widgets/multi_axis_dismissible_page.dart';
export 'src/widgets/single_axis_dismissible_page.dart';
