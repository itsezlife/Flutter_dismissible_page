/// Combinable set of allowed drag sides that may complete a dismissal.
///
/// [DismissDirections] is a bitmask. Start from atomic sides or named
/// composites, then combine with [add], or strip sides with [remove]. Pass
/// the result to `ConstrainedDismissiblePage.directions`.
///
/// Atomic sides: [up], [down], [startToEnd], [endToStart].
/// Named composites: [vertical] ([up] plus [down]), [horizontal]
/// ([startToEnd] plus [endToStart]), [all] (every atom).
/// [empty] means drag dismissal is off.
///
/// ## Combining
///
/// ```dart
/// // Preset: dismiss up or down (same as the Constrained default).
/// DismissDirections.vertical
///
/// // One atom.
/// DismissDirections.down
///
/// // Custom mix — add the sides you want.
/// DismissDirections.up.add(DismissDirections.startToEnd)
///
/// // Chain add for three sides.
/// DismissDirections.up
///     .add(DismissDirections.startToEnd)
///     .add(DismissDirections.endToStart)
///
/// // Composite minus one side.
/// DismissDirections.vertical.remove(DismissDirections.up)
///
/// // Every cardinal side, still Constrained Motion (not Free Motion).
/// DismissDirections.all
/// ```
///
/// The `|` operator is equivalent to [add] if you prefer operator syntax.
///
/// Cross-axis combinations stay Constrained Motion: the gesture locks onto
/// one axis by dominant delta, then only the allowed side on that axis can
/// dismiss. Free Motion is a separate page type (`FreeDismissiblePage`), not
/// a direction flag.
extension type const DismissDirections(int _value) {
  /// No sides allowed — drag dismissal is unavailable.
  static const DismissDirections empty = DismissDirections(0);

  /// Drag up only.
  static const DismissDirections up = DismissDirections(1 << 0);

  /// Drag down only.
  static const DismissDirections down = DismissDirections(1 << 1);

  /// Drag in the reading direction (e.g. left-to-right in LTR).
  static const DismissDirections startToEnd = DismissDirections(1 << 2);

  /// Drag opposite the reading direction (e.g. right-to-left in LTR).
  static const DismissDirections endToStart = DismissDirections(1 << 3);

  /// Alias of [up] | [down].
  static const DismissDirections vertical = DismissDirections(
    (1 << 0) | (1 << 1),
  );

  /// Alias of [startToEnd] | [endToStart].
  static const DismissDirections horizontal = DismissDirections(
    (1 << 2) | (1 << 3),
  );

  /// Alias of [vertical] | [horizontal] — every atomic side allowed.
  ///
  /// Still Constrained Motion semantics: any cardinal side may complete a
  /// dismissal, but this is not Free Motion.
  static const DismissDirections all = DismissDirections(
    (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3),
  );

  /// Whether any side may complete a drag dismissal.
  bool get allowsDragDismissal => _value != 0;

  /// Whether every side in [other] is also allowed by this set.
  bool contains(DismissDirections other) =>
      (_value & other._value) == other._value;

  /// Union of this set and [other]. Operator form of [add]; prefer [add].
  DismissDirections operator |(DismissDirections other) =>
      DismissDirections(_value | other._value);

  /// Returns a copy with every side in [other] allowed.
  ///
  /// The preferred way to build a custom set:
  ///
  /// ```dart
  /// DismissDirections.up.add(DismissDirections.startToEnd)
  /// ```
  DismissDirections add(DismissDirections other) => this | other;

  /// Returns a copy with every side in [other] disallowed.
  DismissDirections remove(DismissDirections other) =>
      DismissDirections(_value & ~other._value);
}
