import 'dart:async';
import 'dart:math';

import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_builder.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_chrome.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_drag_update_details.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_interaction_mode.dart';
import 'package:dismissible_page/src/widgets/dismissible_page_scroll_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

part 'constrained_dismissible_page.dart';
part 'dismissible_page_state.dart';
part 'free_dismissible_page.dart';

/// {@template dismissible_page}
/// A page that can be dismissed by dragging, optionally coordinated with a
/// nested scrollable.
///
/// - [ConstrainedDismissiblePage] — Constrained Motion: each gesture locks
///   onto one [Axis], then moves only toward sides allowed by
///   [DismissDirections] (combine atoms with [DismissDirections.add], e.g.
///   `DismissDirections.up.add(DismissDirections.startToEnd)`). Use when
///   dismissal should stay axis-locked (lists, sheets, directional exits).
/// - [FreeDismissiblePage] — Free Motion: the full plane participates and a
///   single Dismiss Threshold decides dismiss vs reverse. Use for
///   stories-style / free-drag UX. Independent of [DismissDirections].
///
/// [DismissiblePageInteractionMode] is orthogonal to motion: prefer
/// [DismissiblePageInteractionMode.scroll] when the child has a primary
/// scrollable, and [DismissiblePageInteractionMode.gesture] when it never
/// scrolls.
/// {@endtemplate}
sealed class DismissiblePage extends StatefulWidget {
  /// {@macro dismissible_page}
  const DismissiblePage({
    required this.builder,
    required this.onDismissed,
    this.interactionMode = DismissiblePageInteractionMode.scroll,
    this.disabled = false,
    this.onDragStart,
    this.onDragEnd,
    this.onDragUpdate,
    this.isFullScreen = true,
    this.backgroundColor,
    this.dragStartBehavior = DragStartBehavior.down,
    this.dragSensitivity = 0.7,
    this.minScale = .85,
    this.minRadius = 7,
    this.maxRadius = 30,
    this.maxTransformValue = .4,
    this.startingOpacity = 1,
    this.enableBackgroundOpacity = true,
    this.minOpacity = 0,
    this.reverseDuration = const Duration(milliseconds: 200),
    this.reverseCurve = Curves.easeInOut,
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
  });

  /// Creates a [ConstrainedDismissiblePage].
  ///
  /// {@macro constrained_dismissible_page}
  const factory DismissiblePage.constrained({
    required DismissiblePageBuilder builder,
    required VoidCallback onDismissed,
    DismissDirections directions,
    DismissThresholds thresholds,
    DismissiblePageInteractionMode interactionMode,
    bool disabled,
    VoidCallback? onDragStart,
    VoidCallback? onDragEnd,
    ValueChanged<DismissiblePageDragUpdateDetails>? onDragUpdate,
    bool isFullScreen,
    Color? backgroundColor,
    DragStartBehavior dragStartBehavior,
    double dragSensitivity,
    double minScale,
    double minRadius,
    double maxRadius,
    double maxTransformValue,
    double startingOpacity,
    bool enableBackgroundOpacity,
    double minOpacity,
    Duration reverseDuration,
    Curve reverseCurve,
    HitTestBehavior hitTestBehavior,
    Key? key,
  }) = ConstrainedDismissiblePage;

  /// Creates a [FreeDismissiblePage].
  ///
  /// {@macro free_dismissible_page}
  const factory DismissiblePage.free({
    required DismissiblePageBuilder builder,
    required VoidCallback onDismissed,
    double threshold,
    DismissiblePageInteractionMode interactionMode,
    bool disabled,
    VoidCallback? onDragStart,
    VoidCallback? onDragEnd,
    ValueChanged<DismissiblePageDragUpdateDetails>? onDragUpdate,
    bool isFullScreen,
    Color? backgroundColor,
    DragStartBehavior dragStartBehavior,
    double dragSensitivity,
    double minScale,
    double minRadius,
    double maxRadius,
    double maxTransformValue,
    double startingOpacity,
    bool enableBackgroundOpacity,
    double minOpacity,
    Duration reverseDuration,
    Curve reverseCurve,
    HitTestBehavior hitTestBehavior,
    Key? key,
  }) = FreeDismissiblePage;

  /// Builds the content to dismiss.
  ///
  /// The provided [ScrollController] must be attached to the primary
  /// scrollable when [interactionMode] is
  /// [DismissiblePageInteractionMode.scroll].
  final DismissiblePageBuilder builder;

  /// Called when a gesture completes a dismissal.
  final VoidCallback onDismissed;

  /// How dismissal is coordinated with nested scrolling.
  final DismissiblePageInteractionMode interactionMode;

  /// When true, drag-to-dismiss is disabled while content stays interactive.
  final bool disabled;

  /// Called when a dismiss drag starts.
  final VoidCallback? onDragStart;

  /// Called when a dismiss drag ends without dismissing.
  final VoidCallback? onDragEnd;

  /// Called with presentation details on every drag frame.
  final ValueChanged<DismissiblePageDragUpdateDetails>? onDragUpdate;

  /// Whether the page ignores device padding.
  final bool isFullScreen;

  /// Page background painted behind the transformed content.
  final Color? backgroundColor;

  /// How drag start is recognized.
  final DragStartBehavior dragStartBehavior;

  /// Scales how far a drag translates the page.
  final double dragSensitivity;

  /// Content scale at full drag progress.
  final double minScale;

  /// Border radius at rest.
  final double minRadius;

  /// Border radius at full drag progress.
  final double maxRadius;

  /// Maximum translation as a fraction of the axis extent (0.0–1.0).
  final double maxTransformValue;

  /// Background opacity at rest.
  final double startingOpacity;

  /// Whether the background opacity follows drag progress.
  final bool enableBackgroundOpacity;

  /// Floor for background opacity as progress increases.
  final double minOpacity;

  /// Duration of the settle animation when a gesture reverses.
  final Duration reverseDuration;

  /// Easing curve of the settle animation when a gesture reverses.
  final Curve reverseCurve;

  /// Hit-test behavior of the drag recognizer.
  final HitTestBehavior hitTestBehavior;
}
