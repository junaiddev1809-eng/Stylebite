import Flutter
import UIKit
import GoogleMaps
import GoogleMobileAds
import google_mobile_ads
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Correct Maps API Key from your project config
    GMSServices.provideAPIKey("AIzaSyAameF7Yhy3dP91lobJBqqRVqcZanbVeQk")

    // With FirebaseAppDelegateProxyEnabled = NO (see Info.plist), Firebase no
    // longer swizzles app-delegate methods — which also means nothing calls
    // registerForRemoteNotifications() automatically anymore. This can be
    // called before/without alert authorization: it's what actually produces
    // the device token (didRegisterForRemoteNotificationsWithDeviceToken
    // below), independent of whether the user has granted visible-alert
    // permission yet.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      engineBridge.pluginRegistry,
      factoryId: "reelNativeAdFactory",
      nativeAdFactory: ReelNativeAdFactory()
    )
  }

  // FirebaseAppDelegateProxyEnabled is set to NO in Info.plist, so Firebase's
  // automatic method swizzling is disabled and this device token has to be
  // forwarded to FirebaseMessaging by hand.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("didFailToRegisterForRemoteNotificationsWithError: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

private final class ReelNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]?
  ) -> NativeAdView {
    let adView = NativeAdView()
    adView.backgroundColor = .black

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.backgroundColor = .black
    mediaView.mediaContent = nativeAd.mediaContent
    adView.mediaView = mediaView
    adView.addSubview(mediaView)

    let overlay = UIStackView()
    overlay.axis = .vertical
    overlay.spacing = 6
    overlay.translatesAutoresizingMaskIntoConstraints = false
    overlay.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 20, right: 16)
    overlay.isLayoutMarginsRelativeArrangement = true
    overlay.backgroundColor = UIColor.black.withAlphaComponent(0.72)
    adView.addSubview(overlay)

    let sponsored = UILabel()
    sponsored.text = "Sponsored"
    sponsored.textColor = .white
    sponsored.font = .systemFont(ofSize: 12, weight: .medium)

    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.textColor = .white
    headline.font = .systemFont(ofSize: 18, weight: .bold)
    headline.numberOfLines = 2

    let body = UILabel()
    body.text = nativeAd.body
    body.textColor = .lightGray
    body.font = .systemFont(ofSize: 14)
    body.numberOfLines = 2
    body.isHidden = nativeAd.body == nil

    let cta = UIButton(type: .system)
    cta.setTitle(nativeAd.callToAction, for: .normal)
    cta.setTitleColor(.white, for: .normal)
    cta.backgroundColor = UIColor.systemBlue
    cta.layer.cornerRadius = 10
    cta.heightAnchor.constraint(equalToConstant: 46).isActive = true
    cta.isHidden = nativeAd.callToAction == nil
    cta.isUserInteractionEnabled = false

    [sponsored, headline, body, cta].forEach(overlay.addArrangedSubview)
    adView.headlineView = headline
    adView.bodyView = body
    adView.callToActionView = cta

    NSLayoutConstraint.activate([
      mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
      mediaView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      overlay.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      overlay.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
    ])

    adView.nativeAd = nativeAd
    return adView
  }
}
