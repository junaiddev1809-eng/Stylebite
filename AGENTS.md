# AGENTS.md

Guidance for AI coding agents working in the StyleBite Flutter app.

## Project overview

StyleBite is a Flutter social app for fashion/style content (posts, reels, contests,
messaging). State management is **GetX** (`get` package) — routing, DI, and reactive
state all go through it. Backend is a mix of a custom REST API
(`https://stylebiteapp.com/api/`) and Firebase (Auth support, Cloud Messaging). See
[README.md](README.md) for feature/tech-stack summary and
[Backend_socket_requirements.md](Backend_socket_requirements.md) for the Pusher Channels
chat contract.

## Commands

```bash
flutter pub get        # install dependencies
flutter run             # run on a connected device/emulator
flutter analyze         # static analysis (uses analysis_options.yaml / flutter_lints)
flutter test             # run tests (there is currently no meaningful test suite — see Testing below)
flutter build apk        # Android release build
flutter build ios        # iOS release build
```

There is no CI config in this repo; `flutter analyze` is the closest thing to a required
gate before committing.

## Architecture

Code lives under `lib/`, split between an older `modules/` tree (most features) and a
newer `features/` tree (a couple of screens mid-migration). New feature work should
default to the `modules/` pattern shown below unless told otherwise.

```
lib/
├── app/routes/         # AppRoutes (route name constants) + AppPages (GetPage list)
├── core/
│   ├── constants/      # app-wide constants (asset paths, UI constants)
│   ├── media/          # media picking/caching services
│   ├── navigation/     # route observer
│   ├── theme/          # AppColors, AppFonts, AppTheme
│   ├── utils/          # ApiHelper, LocalStorage, config.dart, validators, services
│   └── widgets/        # shared widgets (buttons, text fields, cached image/video, etc.)
├── features/           # newer, partially-migrated screens (home, intro, splash)
└── modules/<feature>/  # most features live here, each with its own subset of:
    ├── api/            # raw HTTP calls for this feature (uses ApiHelper)
    ├── repositories/    # maps raw API JSON into typed models, one level above api/
    ├── controllers/     # GetxController — owns Rx state, calls repository
    ├── models/          # plain Dart model classes (fromJson/toJson)
    ├── screen/           # GetView<T> widgets (screen name may be `screen/` or `screens/`)
    └── widgets/          # feature-local widgets
```

Typical data flow for a feature: `screen` (GetView) reads reactive state from a
`controller` (GetxController) → controller calls a `repository` → repository calls an
`api` class → `api` class calls `ApiHelper` (`lib/core/utils/api_helper.dart`).
Not every module has all five folders — simpler features skip `api`/`repositories` and
call `ApiHelper` directly from the controller.

Routing: add new routes to `lib/app/routes/app_routes.dart` (name constant) and
`lib/app/routes/app_pages.dart` (`GetPage` entry). Navigation goes through `Get.to*` /
`Get.off*` calls, not `Navigator`.

## Conventions

- **State management**: GetX only. Reactive fields use `.obs` / `Rx*` types
  (`RxBool`, `RxString`, `RxList<T>`, `Rxn<T>`), read in widgets via `Obx(...)` or
  `GetView<T>`. Do not introduce another state management approach (Provider, Bloc,
  Riverpod) into this codebase.
- **Networking**: all HTTP calls go through `ApiHelper` (`lib/core/utils/api_helper.dart`),
  which centralizes base URL handling, auth headers, 401/session-expiry handling, and
  logging. Don't call `package:http` directly from feature code — add a method to the
  feature's `api/` class (or `ApiHelper` itself) instead.
- **Config/secrets**: environment-ish values (base URL, API keys, AdMob unit IDs, feature
  tuning constants) live as top-level `const` in `lib/core/utils/config.dart`. There is no
  `.env`/flavor setup — switching environments means editing `config.dart` directly
  (see the commented-out local `baseUrl` line).
- **Models**: plain Dart classes with `fromJson`/`toJson`, no code generation
  (no `freezed`/`json_serializable`). Keep that pattern for new models.
- **Naming**: `snake_case.dart` file names, `PascalCase` classes, feature folders are
  lower_snake_case matching the module name (with a few legacy PascalCase exceptions,
  e.g. `modules/SelectLocationScreen/`).
- **Errors/feedback**: use the shared helpers in `lib/core/utils/app_helper.dart`
  (e.g. `errorSnackBar`) rather than ad hoc `SnackBar`/`Toast` calls.
- **Logging**: this codebase uses `dart:developer`'s `log(...)` and, in places, `print`
  for debug output — match existing style in the file you're editing rather than adding a
  new logging framework.

## Testing

There's a small, targeted test suite under `test/modules/messages/` (chat socket service,
chat detail controller, chat list footer, chat block navigation) using `flutter_test` +
`mocktail` — that's the pattern to follow for new tests (mock at the same seams those tests
do, e.g. `ChatSocketService`'s `@visibleForTesting` helpers). Outside of `messages/`, coverage
is essentially nonexistent — don't assume `flutter test` proves correctness for other
modules. For UI/behavior changes there, run the app (`flutter run`) and manually exercise the
affected screen — GetX navigation and reactive state issues are easy to miss statically.
`flutter analyze` should still pass with no new warnings.

## Platform-specific notes

- **Firebase**: requires `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist` (both already present in this repo — don't commit
  changes to these unless intentionally updating Firebase config).
- **Permissions**: camera/microphone/location permissions are declared in
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. New features
  touching media or location need to check those files.
- **Ads**: Google Mobile Ads unit IDs and native-ad factory wiring live in
  `lib/core/utils/config.dart`, `android/app/src/main/kotlin/.../MainActivity.kt`, and
  `ios/Runner/AppDelegate.swift` — the `reelNativeAdFactoryId` string must match across
  all three. See [ADS_DOCUMENTATION.md](ADS_DOCUMENTATION.md) and
  [AdMob_Reel_Integration.md](AdMob_Reel_Integration.md).
- **Deep links**: handled via `lib/core/utils/deep_link_service.dart` and push
  notification payloads (`lib/core/utils/push_notification_service.dart`), not universal
  links/app links config beyond what's already wired up.

## Other docs in this repo

- [README.md](README.md) — feature overview, tech stack, branding
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) — project status summary
- [Backend_socket_requirements.md](Backend_socket_requirements.md) — Pusher Channels chat contract
- [ADS_DOCUMENTATION.md](ADS_DOCUMENTATION.md), [AdMob_Reel_Integration.md](AdMob_Reel_Integration.md) — ads integration details
- [add-between-reel-logic.md](add-between-reel-logic.md) — reel-feed ad placement logic
- [lib/modules/contest/QA_CHECKLIST.md](lib/modules/contest/QA_CHECKLIST.md) — manual QA checklist for the contest feature
