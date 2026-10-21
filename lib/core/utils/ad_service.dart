import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'config.dart';
import 'api_helper.dart';

class AppAdService {
  static final AppAdService _instance = AppAdService._internal();
  factory AppAdService() => _instance;
  AppAdService._internal();

  /// Loads an interstitial ad and provides it via a callback.
  void loadInterstitialAd({
    required String postId,
    required String adType,
    required Function(InterstitialAd) onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    final adUnitId = Platform.isIOS
        ? iosAdmobInterstitialAdUnitId
        : androidAdmobInterstitialAdUnitId;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdImpression: (ad) => debugPrint('Interstitial ad impression.'),
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
            },
          );
          
          ad.onPaidEvent = (ad, valueMicros, precision, currencyCode) {
            debugPrint('DEBUG: AdMob Paid Event (Interstitial) for Post $postId. Revenue: ${valueMicros / 1000000.0} $currencyCode');
            reportImpression(
              postId: postId,
              adType: adType,
              revenue: valueMicros / 1000000.0,
              currency: currencyCode,
              adUnitId: ad.adUnitId,
            );
          };

          onAdLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          onAdFailedToLoad?.call(error);
        },
      ),
    );
  }

  /// Reports impression-level revenue data (ILRD) to the backend.
  Future<void> reportImpression({
    required String postId,
    required String adType,
    required double revenue,
    required String currency,
    required String adUnitId,
  }) async {
    debugPrint('DEBUG: Reporting Impression to Backend: Post $postId, Type $adType, Revenue $revenue $currency');
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'ads/impressions',
        body: {
          'impressions': [
            {
              'post_id': int.tryParse(postId) ?? postId,
              'ad_type': adType,
              'revenue': revenue,
              'currency': currency,
              'ad_unit_id': adUnitId,
            }
          ]
        },
      );
      if (response != null && response.statusCode == 200) {
        debugPrint('DEBUG: Impression reported successfully.');
      }
    } catch (e) {
      debugPrint('DEBUG: Failed to report ad impression: $e');
    }
  }
}
