import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:stylebite/core/utils/app_device_service.dart';
import 'package:stylebite/core/utils/app_back_navigation.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/core/utils/push_notification_service.dart';
import 'package:stylebite/core/utils/deep_link_service.dart';
import 'package:stylebite/core/navigation/app_route_observer.dart';
import 'package:stylebite/core/theme/app_scroll_behavior.dart';
import 'package:stylebite/firebase_options.dart';
import 'package:stylebite/core/utils/app_session.dart';
import 'package:stylebite/modules/messages/services/chat_presence_service.dart';
import 'app/routes/app_pages.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.initStorage();
  // Warm feed fonts before first paint so text metrics don't reflow later.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.beVietnamPro(),
      GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
      GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700),
      GoogleFonts.plusJakartaSans(),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
    ]);
  } catch (_) {}
  runApp(const StyleBiteApp());
  unawaited(SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF9F6F5),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  try {
    await AppDeviceService.init();
  } catch (_) {}
  try {
    if (DefaultFirebaseOptions.isSupported) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  try {
    if (DefaultFirebaseOptions.isSupported) {
      await PushNotificationService.init();
    }
  } catch (_) {}
  try {
    await DeepLinkService.init();
  } catch (_) {}
  try {
    if (DefaultFirebaseOptions.isSupported) {
      await MobileAds.instance.initialize();
    }
  } catch (_) {}
}

class StyleBiteApp extends StatefulWidget {
  const StyleBiteApp({super.key});

  @override
  State<StyleBiteApp> createState() => _StyleBiteAppState();
}

class _StyleBiteAppState extends State<StyleBiteApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.maximumSize = 120;
      imageCache.maximumSizeBytes = 48 << 20;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppSession.attachRealtimeIfNeeded();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ChatPresenceService.instance.markOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'StyleBite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 220),
      enableLog: false,
      navigatorObservers: [appRouteObserver],
      scrollBehavior: const AppScrollBehavior(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      builder: (context, child) {
        // Single app-wide back gate. canPop:false stops the engine from also
        // popping while we handle it — AppBackNavigation locks duplicates
        // from predictive-back / PopScope double invokes.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            AppBackNavigation.handleBack();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
