import 'package:dismissible_page/dismissible_page.dart';
import 'package:example/demo/models/models.dart';
import 'package:example/demo/pages/story_page.dart';
import 'package:example/demo/widgets/cubic_page_view.dart';
import 'package:flutter/material.dart';

class StoriesWrapper extends StatefulWidget {
  const StoriesWrapper({
    required this.parentIndex,
    required this.pageModel,
    super.key,
  });

  final int parentIndex;
  final DismissiblePageModel pageModel;

  @override
  State<StoriesWrapper> createState() => _StoriesWrapperState();
}

class _StoriesWrapperState extends State<StoriesWrapper> {
  late final DismissiblePageViewController pageCtrl;

  List<StoryModel> get stories => widget.pageModel.stories;

  bool get isLastPage => stories.length == pageCtrl.page!.round() + 1;

  @override
  void initState() {
    pageCtrl = DismissiblePageViewController(initialPage: widget.parentIndex);
    super.initState();
  }

  void nextPage() {
    if (isLastPage) {
      Navigator.maybePop(context);
      return;
    }
    next();
  }

  void previousPage() {
    if (pageCtrl.page!.round() == 0) {
      Navigator.maybePop(context);
      return;
    }
    previous();
  }

  void next() {
    pageCtrl.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
    );
  }

  void previous() {
    pageCtrl.previousPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageModel = widget.pageModel;
    return DismissiblePageView(
      controller: pageCtrl,
      onDismissed: () => Navigator.of(context).maybePop(),
      directions: pageModel.directions,
      thresholds: pageModel.thresholds,
      isFullScreen: pageModel.isFullScreen,
      minRadius: pageModel.minRadius,
      maxRadius: pageModel.maxRadius,
      dragSensitivity: pageModel.dragSensitivity,
      maxTransformValue: pageModel.maxTransformValue,
      disabled: pageModel.disabled,
      backgroundColor: pageModel.backgroundColor,
      dragStartBehavior: pageModel.dragStartBehavior,
      minScale: pageModel.minScale,
      startingOpacity: pageModel.startingOpacity,
      hitTestBehavior: pageModel.behavior,
      reverseDuration: pageModel.reverseDuration,
      builder: (context, controller) => CubicPageView(
        controller: controller,
        children: stories.map((story) {
          return StoryPage(
            story: story,
            nextGroup: nextPage,
            previousGroup: previousPage,
          );
        }).toList(),
      ),
    );
  }
}
