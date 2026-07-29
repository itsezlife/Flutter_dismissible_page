import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

/// Shared example configuration resolved once at app startup.
final class Config {
  const Config({
    required this.screenBorderRadius,
    required this.pageShape,
  });

  /// Historical package-style Shape Snap without device radii.
  factory Config.fallback() {
    final rest = platformPageShape(BorderRadius.zero);
    final dragged = platformPageShape(_fallbackDraggedRadius);
    return Config(
      screenBorderRadius: _fallbackDraggedRadius,
      pageShape: DismissiblePageShape.snap(rest: rest, dragged: dragged),
    );
  }

  /// Builds config from plugin radii, or [Config.fallback] when [screenRadius]
  /// is null.
  factory Config.fromScreenRadius(ScreenRadius? screenRadius) {
    final borderRadius = switch (screenRadius) {
      final ScreenRadius r => BorderRadius.only(
        topLeft: Radius.circular(r.topLeft),
        topRight: Radius.circular(r.topRight),
        bottomLeft: Radius.circular(r.bottomLeft),
        bottomRight: Radius.circular(r.bottomRight),
      ),
      null => _fallbackDraggedRadius,
    };
    final rest = platformPageShape(BorderRadius.zero);
    final dragged = platformPageShape(borderRadius);
    return Config(
      screenBorderRadius: borderRadius,
      pageShape: DismissiblePageShape.snap(rest: rest, dragged: dragged),
    );
  }

  /// Fallback when radii are unavailable (desktop, older Android, tests).
  static const BorderRadius _fallbackDraggedRadius = BorderRadius.all(
    Radius.circular(30),
  );

  /// Mutable shared instance; starts as [Config.fallback] until [initialize]
  /// runs.
  static Config current = Config.fallback();

  /// Physical screen corner radii in logical pixels (or the fallback).
  final BorderRadius screenBorderRadius;

  /// Default demo Shape Strategy: Shape Snap to the platform Page Shape.
  final DismissiblePageShape pageShape;

  /// Caller-managed builder that lerps rest → dragged (teaches the builder
  /// API).
  DismissiblePageShape get builderPageShape {
    final rest = platformPageShape(BorderRadius.zero);
    final dragged = platformPageShape(screenBorderRadius);
    return DismissiblePageShape.builder(
      (progress) => ShapeBorder.lerp(rest, dragged, progress)!,
    );
  }

  /// Reads device corners once and replaces [current].
  static Future<void> initialize() async {
    final screenRadius = await ScreenCornerRadius.get();
    current = Config.fromScreenRadius(screenRadius);
  }
}

/// Platform-appropriate Page Shape for the given corner radii.
///
/// iOS uses a continuous squircle ([RoundedSuperellipseBorder]); Android and
/// other platforms use a circular [RoundedRectangleBorder].
ShapeBorder platformPageShape(BorderRadiusGeometry borderRadius) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => RoundedSuperellipseBorder(
      borderRadius: borderRadius,
    ),
    _ => RoundedRectangleBorder(borderRadius: borderRadius),
  };
}
