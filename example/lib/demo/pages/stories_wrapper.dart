import 'package:dismissible_page/dismissible_page.dart';
import 'package:example/demo/models/models.dart';
import 'package:example/demo/pages/dismissible_page_demo.dart';
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

class _StoriesWrapperState extends State<StoriesWrapper>
    with TickerProviderStateMixin {
  late int dWidth;
  late PageController pageCtrl;

  List<StoryModel> get stories => widget.pageModel.stories;

  bool get isLastPage => stories.length == pageCtrl.page!.round() + 1;

  @override
  void initState() {
    pageCtrl = PageController(initialPage: widget.parentIndex);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    dWidth = MediaQuery.widthOf(context).floor();
    super.didChangeDependencies();
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
    // Demo-only pager chrome. PageView / TabBarView are not an Interaction
    // Mode of this package — content here is never scrollable for dismiss,
    // so gesture mode is the correct choice.
    return DismissibleDemo(
      pageModel: widget.pageModel,
      interactionMode: DismissiblePageInteractionMode.gesture,
      builder: (context, _) => CubicPageView(
        controller: pageCtrl,
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
