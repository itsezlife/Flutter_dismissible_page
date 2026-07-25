import 'package:flutter/material.dart';

/// Defines how dismiss gestures are coordinated with nested scrollables.
enum DismissiblePageInteractionMode {
  /// Uses a custom [ScrollController]/[ScrollPosition] pair that arbitrates
  /// scroll deltas between page dismissal and inner scrolling.
  ///
  /// Arbitration covers the nested scrollable's own axis. A gesture shell may
  /// coexist with it when dismissal is also allowed off that axis.
  scroll,

  /// Dismisses from a drag recognizer only, without Scroll Arbitration.
  gesture,
}
