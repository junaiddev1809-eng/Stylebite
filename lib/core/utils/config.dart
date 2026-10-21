import 'package:flutter/foundation.dart';

const bool useAwsTestBackend = false;

/// When true, EVERY API call goes to local Laravel.
/// Keep false so the existing app stays on the live backend, and only
/// [updatedLocalApiPrefixes] hit the new local module APIs.
const bool useLocalBackend = false;

const remoteBaseUrl = useAwsTestBackend
    ? "https://aws.stylebiteapp.com"
    : "https://stylebiteapp.com";

/// Android emulator reaches the host via 10.0.2.2. Windows/iOS/desktop
/// debug builds should hit loopback directly.
String get localBaseUrl {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

String get baseUrl => useLocalBackend ? localBaseUrl : remoteBaseUrl;
String get kcBaseAPIUrl => '$baseUrl/api/';
String get kcLocalAPIUrl => '$localBaseUrl/api/';

/// Routes that should still hit this PC instead of the live API.
/// Leave this empty for Play Store builds. Every call then uses
/// https://stylebiteapp.com.
const updatedLocalApiPrefixes = <String>[];

bool usesUpdatedLocalModule(String endpoint) {
  if (useLocalBackend) {
    return true;
  }
  if (updatedLocalApiPrefixes.isEmpty) {
    return false;
  }
  final path = endpoint.split('?').first.replaceFirst(RegExp(r'^/+'), '');
  return updatedLocalApiPrefixes.any((prefix) {
    if (prefix.endsWith('/')) {
      return path == prefix.substring(0, prefix.length - 1) ||
          path.startsWith(prefix);
    }
    return path == prefix || path.startsWith('$prefix?') || path.startsWith('$prefix/');
  });
}

String apiRootForEndpoint(String endpoint) {
  return usesUpdatedLocalModule(endpoint) ? kcLocalAPIUrl : kcBaseAPIUrl;
}

/// Live chat sockets stay on the remote backend unless the whole app is local.
const bool realtimeEnabled = !useLocalBackend;
const googleMapsApiKey = "AIzaSyAameF7Yhy3dP91lobJBqqRVqcZanbVeQk";

const pusherAppKey = useAwsTestBackend
    ? "3ru2rnluw2l7kjnr7b2e"
    : "5269e3033be86866f95e";
const String? pusherCluster = useAwsTestBackend ? null : "ap2";
const String? pusherHost = useAwsTestBackend ? "aws.stylebiteapp.com" : null;
const pusherPort = 443;
const pusherUseTLS = true;
const googleSignInServerClientId =
    "144396214843-6fe3bp9iit9jrd4iuvedls0elmt53hg6.apps.googleusercontent.com";

/// Global ads kill switch. While `true`, no native or interstitial ads are
/// loaded or shown anywhere in the app. Flip to `false` to resume ads.
const bool adsPaused = true;

// Banner Ads
const androidAdmobBannerAdUnitId =
    "ca-app-pub-3940256099942544/6300978111"; // Test ID
const iosAdmobBannerAdUnitId =
    "ca-app-pub-3940256099942544/2934735716"; // Test ID

// In-feed native ads.
const androidReelNativeAdUnitId =
    'ca-app-pub-3940256099942544/2247696110'; // TODO-sheezy: Replace with Android Production ID
// const iosReelNativeAdUnitId = 'ca-app-pub-2862469167890846/9319168960'; // Production ID from Dashboard
const iosReelNativeAdUnitId = 'ca-app-pub-3940256099942544/3986624511'; // Test ID // TODO-sheezy: Replace with IOS Production ID

// Interstitial Ads
const androidAdmobInterstitialAdUnitId =
    "ca-app-pub-3940256099942544/1033173712"; // Test ID
const iosAdmobInterstitialAdUnitId =
    "ca-app-pub-3940256099942544/4411468910"; // Test ID

/// Must match the factory registered in `MainActivity.kt` and `AppDelegate.swift`.
const reelNativeAdFactoryId = 'reelNativeAdFactory';

/// Reels the user sees before the first ad page.
const reelsBeforeFirstAd = 3;

/// Reels between two consecutive ad pages.
const reelsBetweenAds = 4;

/// How many native ads to keep loaded and ready to drop into the feed. Slots are
/// only created from ads that are already loaded, so the feed never shows a
/// blank "loading" page.
const reelNativeAdPoolSize = 2;
