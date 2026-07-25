import 'package:flutter/widgets.dart';

/// {@template dismissible_page_builder}
/// Builder that receives a [ScrollController] for scroll-aware mode.
/// {@endtemplate}
typedef DismissiblePageBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);
