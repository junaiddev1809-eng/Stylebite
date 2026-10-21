import 'package:flutter/foundation.dart';

/// One mute choice for every reel. Tapping the speaker on any reel updates
/// this, and every other reel — including the next one in either direction —
/// plays with that same choice.
class SharedVideoMute {
  SharedVideoMute._();

  static final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  static void setMuted(bool value) {
    if (muted.value == value) {
      muted.notifyListeners();
      return;
    }
    muted.value = value;
  }
}
