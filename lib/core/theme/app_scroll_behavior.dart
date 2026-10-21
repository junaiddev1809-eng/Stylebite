import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kIsWeb) {
      return const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
