import 'dart:math';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:example/config/config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Which public page variant the demo Properties panel configures.
enum DemoMotionKind {
  /// [ConstrainedDismissiblePage] — axis-locked motion + [DismissDirections].
  constrained,

  /// [FreeDismissiblePage] — full-plane Free Motion (no directions).
  free,
}

/// Which Shape Strategy preset the Properties panel selects.
enum DemoShapeKind {
  /// Shape Snap using device corners from shared [Config].
  deviceSnap,

  /// Package default Shape Snap (`kDefaultDismissiblePageShape`).
  packageDefault,

  /// Builder that lerps rest → device dragged shape across Drag Progress.
  builder,
}

class DismissiblePageModel {
  DismissiblePageModel() {
    stories = [
      StoryModel(title: 'Random', imageUrl: randomNature),
      StoryModel(title: 'Photos', imageUrl: randomNature),
      StoryModel(title: 'From', imageUrl: randomFood),
      StoryModel(title: 'Unsplash', imageUrl: randomNature),
    ];
  }

  String get randomFood =>
      'https://picsum.photos/${Random().nextInt(200) + 400}/${Random().nextInt(200) + 600}?random=${Random().nextInt(1000)}';

  String get randomNature =>
      'https://picsum.photos/${Random().nextInt(200) + 400}/${Random().nextInt(200) + 600}?random=${Random().nextInt(1000)}';

  List<StoryModel> stories = [];
  final contacts = {
    'GitHub': 'https://github.com/Tkko',
    'LinkedIn': 'https://www.linkedin.com/in/thornike/',
    'Medium': 'https://thornike.medium.com/',
    'Pub': 'https://pub.dev/publishers/fman.ge/packages',
  };

  Duration transitionDuration = const Duration(milliseconds: 250);
  Duration reverseTransitionDuration = const Duration(milliseconds: 250);
  bool isFullScreen = true;
  bool disabled = false;
  double startingOpacity = 1;
  double minScale = .85;
  double maxTransformValue = .5;
  double dragSensitivity = .7;
  Color backgroundColor = Colors.black;

  /// Constrained vs Free page variant (orthogonal to Interaction Mode).
  DemoMotionKind motionKind = DemoMotionKind.constrained;

  /// Shape Strategy preset (replaces scalar min/max radius knobs).
  DemoShapeKind shapeKind = DemoShapeKind.deviceSnap;

  /// Resolved Shape Strategy for the selected [shapeKind].
  DismissiblePageShape get shape => switch (shapeKind) {
    DemoShapeKind.deviceSnap => Config.current.pageShape,
    DemoShapeKind.packageDefault => kDefaultDismissiblePageShape,
    DemoShapeKind.builder => Config.current.builderPageShape,
  };

  /// Allowed sides for Constrained Motion. Ignored when [motionKind] is free.
  DismissDirections directions = DismissDirections.vertical;

  /// Per-side thresholds for Constrained Motion.
  DismissThresholds thresholds = const DismissThresholds();

  /// Single threshold for Free Motion.
  double freeThreshold = 0.15;

  DragStartBehavior dragStartBehavior = DragStartBehavior.down;
  Duration reverseDuration = const Duration(milliseconds: 200);
  HitTestBehavior behavior = HitTestBehavior.opaque;
}

class StoryModel {
  StoryModel({
    required this.title,
    required this.imageUrl,
  });

  final String altUrl = 'assets/images/photo_not_found.png';
  final storyId = UniqueKey();
  final String title;
  final String imageUrl;
}
