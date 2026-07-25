/// Combinable set of allowed drag sides that may complete a dismissal.
///
/// Atoms are [up], [down], [startToEnd], and [endToStart]. Named composites
/// such as [vertical] and [horizontal] are OR-aliases of those atoms. The
/// [empty] set means dismissal by drag is not allowed.
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

  /// Union of this set and [other].
  DismissDirections operator |(DismissDirections other) =>
      DismissDirections(_value | other._value);

  /// Returns a copy with every side in [other] allowed.
  DismissDirections add(DismissDirections other) => this | other;

  /// Returns a copy with every side in [other] disallowed.
  DismissDirections remove(DismissDirections other) =>
      DismissDirections(_value & ~other._value);
}
