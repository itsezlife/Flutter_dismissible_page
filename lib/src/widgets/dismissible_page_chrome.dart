import 'package:dismissible_page/dismissible_page_engine.dart';
import 'package:flutter/material.dart';

/// Motion-agnostic chrome that renders already-computed drag presentation.
///
/// Constrained and Free page States own gesture/motion; this shell only paints
/// offset, scale, radius, opacity, and background configuration.
class DismissiblePageChrome extends StatelessWidget {
  /// Creates chrome for a dismissible page frame.
  const DismissiblePageChrome({
    required this.presentation,
    required this.contentPadding,
    required this.child,
    this.backgroundColor,
    this.enableBackgroundOpacity = true,
    super.key,
  });

  /// Already-computed presentation details for this frame.
  final DragPresentation presentation;

  /// Padding around the transformed content.
  final EdgeInsetsGeometry contentPadding;

  /// Page background. When null, no background box is painted.
  final Color? backgroundColor;

  /// Whether [backgroundColor] opacity follows [DragPresentation.opacity].
  final bool enableBackgroundOpacity;

  /// Page content beneath the transform and clip.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final resolvedBackground = switch ((
      backgroundColor,
      enableBackgroundOpacity,
    )) {
      (final color?, _) when color == Colors.transparent => color,
      (final color?, true) => color.withValues(alpha: presentation.opacity),
      (final color, _) => color,
    };

    Widget content = Transform.translate(
      offset: presentation.offset,
      child: Transform.scale(
        scale: presentation.scale,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(presentation.radius)),
          child: child,
        ),
      ),
    );

    if (resolvedBackground case final background?) {
      content = ColoredBox(color: background, child: content);
    }

    return Padding(
      padding: contentPadding,
      child: content,
    );
  }
}
