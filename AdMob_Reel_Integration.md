# AdMob Reel Integration: Backend-Driven Triggers & Revenue Tracking

This document outlines the implementation strategy for showing non-skippable ads (Interstitial/Rewarded Interstitial) during reel playback based on backend configuration and video progress.

## 1. Requirements Overview
- **Backend Control:** Each reel object contains a flag (`show_ad`) and a trigger point (`ad_trigger_ratio`).
- **Trigger Logic:** Ad shows only after the user has watched a specific percentage (e.g., 30%) of the reel.
- **Ad Type:** Non-skippable (Interstitial).
- **Revenue Tracking:** Send impression-level revenue data (ILRD) back to the backend.

## 2. Updated Data Model
The backend provides the following fields in the Reel API response:
- `show_ad`: (Boolean) Whether to trigger an ad for this specific reel.
- `ad_trigger_ratio`: (Float, e.g., 0.3) The playback progress (0.0 to 1.0) at which the ad should show.

## 3. Implementation Logic

### A. Configuration (lib/core/utils/config.dart)
Added the Ad Unit IDs for Interstitial ads:
```dart
const androidAdmobInterstitialAdUnitId = "ca-app-pub-3940256099942544/1033173712";
const iosAdmobInterstitialAdUnitId = "ca-app-pub-3940256099942544/4411468910";
```

### B. Ad Service (Revenue Reporting)
Created `AppAdService` in `lib/core/utils/ad_service.dart`. It handles:
- Loading the `InterstitialAd`.
- Implementing `onPaidEvent` to report revenue to `ads/revenue-report` endpoint.

### C. Video Progress Trigger
1.  **Video Player**: Updated `AppCachedVideoPlayer` to include an `onProgressChanged` callback.
2.  **Screen**: `ReelScreen` passes the progress from the player to the controller.
3.  **Controller**: `ReelController.handleVideoProgress(reelId, progress)` checks if the `adTriggerRatio` is met.

### D. Loading and Showing the Ad
- **Pre-loading**: `ReelController` calls `_preLoadInterstitialForReel` when a reel is changed or warmed. This ensures the ad is ready before the trigger point.
- **Trigger**: Once progress >= `adTriggerRatio`, the controller pauses the video and calls `ad.show()`.
- **Cleanup**: The ad is disposed of on dismissal, and the video resumes.

## 4. Key Considerations

1.  **Pre-loading**: Ads are loaded ahead of time to ensure a seamless transition.
2.  **Session Management**: A `_shownAdReelIds` Set prevents the same reel from triggering multiple ads in a single session.
3.  **Error Handling**: If an ad fails to load or show, the video simply continues without interruption.
4.  **Revenue Tracking**: ILRD is captured automatically for every successful impression.
