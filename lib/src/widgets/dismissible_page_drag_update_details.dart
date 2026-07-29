import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// {@template dismissible_page_drag_update_details}
/// Details outputted by the dismissible page onDragUpdate callback.
/// {@endtemplate}
@immutable
class DismissiblePageDragUpdateDetails {
  /// {@macro dismissible_page_drag_update_details}
  const DismissiblePageDragUpdateDetails({
    required this.shape,
    required this.opacity,
    this.offset = Offset.zero,
    this.overallDragValue = 0.0,
    this.scale = 1.0,
    this.isDismissed = false,
  });

  /// The overall drag value representing the progress of the dismissal gesture.
  ///
  /// This value ranges from 0.0 (no drag) to 1.0 (maximum drag threshold).
  /// It is calculated based on the maximum of horizontal and vertical drag
  /// distances relative to the screen dimensions.
  final double overallDragValue;

  /// The current Page Shape of the dismissible page.
  ///
  /// Resolved from the page Shape Strategy for the current Drag Progress.
  final ShapeBorder shape;

  /// The current opacity of the background.
  ///
  /// Decreases from the page starting opacity as the drag progresses.
  final double opacity;

  /// The current scale factor of the page content.
  ///
  /// Interpolated between 1.0 and the page min scale based on drag progress.
  final double scale;

  /// The current offset of the page from its original position.
  ///
  /// This represents the translation of the page in both x and y directions
  /// as the user drags to dismiss.
  final Offset offset;

  /// Whether the page is dismissed.
  final bool isDismissed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DismissiblePageDragUpdateDetails &&
          runtimeType == other.runtimeType &&
          offset == other.offset;

  @override
  int get hashCode => offset.hashCode;

  /// Converts this object to a map representation.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'overallDragValue': overallDragValue,
    'shape': shape,
    'opacity': opacity,
    'scale': scale,
    'offset': offset,
    'isDismissed': isDismissed,
  };

  @override
  String toString() => toMap().toString();

  /// Creates a copy of this [DismissiblePageDragUpdateDetails] with the given
  /// properties updated.
  DismissiblePageDragUpdateDetails copyWith({
    double? overallDragValue,
    ShapeBorder? shape,
    double? opacity,
    double? scale,
    Offset? offset,
    bool? isDismissed,
  }) {
    return DismissiblePageDragUpdateDetails(
      overallDragValue: overallDragValue ?? this.overallDragValue,
      shape: shape ?? this.shape,
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}
