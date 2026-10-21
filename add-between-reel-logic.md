# In-Feed Reel Ad Logic (StyleBite)

This document explains how native ads are integrated into the vertical reels feed to ensure a smooth, non-intrusive user experience.

## 1. Ad Placement (When & Where)
The frequency of ads is controlled via `lib/core/utils/config.dart`:
- **`reelsBeforeFirstAd = 3`**: The first ad appears after the 3rd reel (on the 4th page).
- **`reelsBetweenAds = 4`**: Subsequent ads appear after every 4 reels.
- **Sequence:** Reel → Reel → Reel → **AD** → Reel → Reel → Reel → Reel → **AD**...

## 2. Ad Pooling (Pre-loading)
To avoid "Loading..." indicators or blank pages mid-scroll:
- **`reelNativeAdPoolSize = 2`**: The `ReelController` maintains a pool of 2 pre-loaded ads.
- Ads are fetched in the background. A slot is **only** created once an ad has successfully loaded from Google AdMob.

## 3. Smooth Synchronization
The logic in `_syncAdSlots()` ensures the feed remains stable:
- **No Content Shifting:** Ads are only injected ahead of the user (at least 2 pages away from the current view). This prevents the video the user is currently watching from jumping or shifting unexpectedly.
- **Dead-end Prevention:** An ad is never allowed to be the last item in the feed; at least one reel must exist after an ad slot.

## 4. Index Mapping
The `PageView` sees a single continuous list. The `ReelController` uses two helper functions to manage the "Virtual" vs "Real" indices:
- **`nativeAdAt(index)`**: Checks if a specific page index is assigned to an ad.
- **`mapToReelIndex(index)`**: Calculates which video from the API response should be shown, skipping the indices occupied by ads. This ensures no video content is lost.

## 5. Native UI
Instead of using Interstitials (which block the screen), we use **Native Ads**:
- **Android:** Custom layout defined in `MainActivity.kt` using `NativeAdView` and `MediaView`.
- **iOS:** Defined in `AppDelegate.swift` (Native Factory).
- This allows the ad to look and behave like a reel. The user can simply swipe up to skip the ad, just like any other video.

## 6. Configuration (Production vs Test)
- **Test IDs:** Used during development (rotate between image/video).
- **Production IDs:** Configured in `config.dart`.
- **Media Restriction:** In the AdMob Dashboard, the "Media Type" is set to **Video** to ensure users only see video ads once the account is approved.
