package com.stylebite.app

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GoogleMobileAdsPlugin.registerNativeAdFactory(
      flutterEngine,
      "reelNativeAdFactory",
      ReelNativeAdFactory(this),
    )
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "reelNativeAdFactory")
    super.cleanUpFlutterEngine(flutterEngine)
  }
}

private class ReelNativeAdFactory(context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
  private val context = context

  override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
    val adView = NativeAdView(context).apply {
      setBackgroundColor(Color.BLACK)
      layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
      )
    }

    val mediaView = MediaView(context).apply {
      layoutParams = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
      )
      setBackgroundColor(Color.BLACK)
    }
    adView.mediaView = mediaView
    // Image-only creatives can come back without media content; assigning null
    // here would blow up inside the SDK.
    nativeAd.mediaContent?.let { mediaView.mediaContent = it }
    adView.addView(mediaView)

    val details = LinearLayout(context).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(dp(16), dp(12), dp(16), dp(20))
      background = GradientDrawable(
        GradientDrawable.Orientation.BOTTOM_TOP,
        intArrayOf(Color.BLACK, Color.TRANSPARENT),
      )
      layoutParams = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
        Gravity.BOTTOM,
      )
    }
    val sponsored = TextView(context).apply {
      text = "Sponsored"
      setTextColor(Color.WHITE)
      textSize = 12f
    }
    val headline = TextView(context).apply {
      text = nativeAd.headline
      setTextColor(Color.WHITE)
      textSize = 18f
      setTypeface(typeface, 1)
      maxLines = 2
    }
    val body = TextView(context).apply {
      text = nativeAd.body
      setTextColor(Color.LTGRAY)
      textSize = 14f
      visibility = if (nativeAd.body == null) View.GONE else View.VISIBLE
    }
    val cta = Button(context).apply {
      text = nativeAd.callToAction
      isAllCaps = false
      visibility = if (nativeAd.callToAction == null) View.GONE else View.VISIBLE
    }
    details.addView(sponsored)
    details.addView(headline)
    details.addView(body)
    details.addView(cta)
    adView.addView(details)

    adView.headlineView = headline
    adView.bodyView = body
    adView.callToActionView = cta
    adView.setNativeAd(nativeAd)
    return adView
  }

  private fun dp(value: Int): Int = (value * context.resources.displayMetrics.density).toInt()
}
