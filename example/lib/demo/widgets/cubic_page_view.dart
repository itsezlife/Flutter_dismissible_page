import 'dart:ui';

import 'package:example/demo/widgets/snap_scroll_physics.dart';
import 'package:flutter/material.dart';

class CubicPageView extends StatefulWidget {
  const CubicPageView({
    required this.controller,
    required this.children,
    super.key,
    this.physics = const SnapScrollPhysics(),
  });

  final PageController controller;
  final List<Widget> children;

  /// Page settle physics. Defaults to a fixed-duration curve snap (no spring).
  final ScrollPhysics physics;

  @override
  State<CubicPageView> createState() => _CubicPageViewState();
}

class _CubicPageViewState extends State<CubicPageView> {
  late PageController _controller;
  late ValueNotifier<double> currentPageValueNotifier;

  List<Widget> get children => widget.children;

  @override
  void initState() {
    _controller = widget.controller;
    currentPageValueNotifier = ValueNotifier<double>(
      _controller.initialPage.toDouble(),
    );
    _controller.addListener(_handlePageChanged);
    super.initState();
  }

  void _handlePageChanged() {
    if (_controller.page case final page?) {
      currentPageValueNotifier.value = page;
    }
  }

  @override
  void dispose() {
    // Controller ownership stays with the parent that created it.
    _controller.removeListener(_handlePageChanged);
    currentPageValueNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final rotateSign = textDirection == TextDirection.rtl ? -1.0 : 1.0;

    return PageView.builder(
      controller: _controller,
      // SnapScrollPhysics owns page snapping; leaving pageSnapping true would
      // wrap us in stock PageScrollPhysics and restore the spring ballistic.
      pageSnapping: false,
      physics: widget.physics,
      itemCount: children.length,
      itemBuilder: (_, index) {
        return ValueListenableBuilder(
          valueListenable: currentPageValueNotifier,
          builder: (context, currentPageValue, child) {
            AlignmentDirectional? alignment;
            if (index == currentPageValue.floor()) {
              alignment = AlignmentDirectional.centerEnd;
            }
            if (index == currentPageValue.ceil()) {
              alignment = AlignmentDirectional.centerStart;
            }

            if (alignment != null) {
              return Transform(
                alignment: alignment,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.003)
                  ..rotateY(
                    rotateSign *
                        -lerpDouble(0, 50, index - currentPageValue)! *
                        3.14 /
                        180,
                  ),
                child: children[index],
              );
            }

            return children[index];
          },
        );
      },
    );
  }
}
