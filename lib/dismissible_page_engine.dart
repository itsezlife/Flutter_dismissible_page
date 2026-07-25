/// Pure dismiss decision logic for the dismissible_page package, independent
/// of the widget tree.
///
/// Import this entrypoint to unit-test engine behavior without pumping widgets.
/// The root package barrel stays thin and does not re-export engine internals.
library;

export 'src/engine/dismiss_constants.dart';
