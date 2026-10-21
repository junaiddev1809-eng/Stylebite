# StyleBite

StyleBite is a vibrant and feature-rich Flutter application designed for social interaction, fashion exploration, and competitive contests. Built with a focus on high performance and modern UI/UX, it leverages **GetX** for state management and **Firebase** for its backend infrastructure.

## 🚀 Key Features

*   **Social & Engagement**:
    *   **Dynamic Home Feed**: Support for both image and video (Reels) content.
    *   **Explore & Search**: Discover new style trends, posts, and users.
    *   **Real-time Messaging**: Full chat system with online/offline presence tracking via `ChatPresenceService`.
    *   **Memories**: Capture and look back at past style moments.
*   **Contest System**:
    *   **Competition**: Create, join, and manage style contests.
    *   **Leaderboards**: Real-time rankings and contest results.
    *   **Invitations**: Private contest invite system.
*   **User Experience**:
    *   **Smooth Auth**: Email, Google, and Apple Sign-in integration.
    *   **Earnings**: Dedicated dashboard for tracking creator rewards.
    *   **Upload**: Advanced media picker and image editing interface.
*   **Infrastructure**:
    *   **Push Notifications**: Handled via `PushNotificationService` with deep-linking support for contests and chats.
    *   **Monetization**: Integrated Google Mobile Ads.
    *   **Localization**: Location-based services using Google Maps.

## 🎨 Branding & UI
The app follows a warm, energetic color palette defined in `AppColors`:

| Type | Hex | Preview |
| :--- | :--- | :--- |
| **Primary** | `#FF4D6D` | ![#FF4D6D](https://via.placeholder.com/15/FF4D6D?text=+) |
| **Secondary** | `#FF8A5B` | ![#FF8A5B](https://via.placeholder.com/15/FF8A5B?text=+) |
| **Accent** | `#FFD166` | ![#FFD166](https://via.placeholder.com/15/FFD166?text=+) |
| **Background**| `#F9F6F5` | ![#F9F6F5](https://via.placeholder.com/15/F9F6F5?text=+) |

## 🛠 Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.11.1)
*   **State Management**: [GetX](https://pub.dev/packages/get)
*   **Backend**: Firebase (Auth, Cloud Messaging, Firestore/Realtime DB)
*   **Media**: `video_player`, `image_picker`, `pro_image_editor`, `cached_network_image`
*   **Ads**: `google_mobile_ads`
*   **Navigation**: GetX Routing with custom `AppBackNavigation` handlers.

## 📁 Project Structure

```text
lib/
├── app/              # Routes and global app config
├── core/             # Shared utilities
│   ├── theme/        # AppColors, AppTheme, and styles
│   └── utils/        # Push notifications, local storage, device info
└── modules/          # Feature-based modules
    ├── auth/         # Authentication logic (Login, Signup, Reset)
    ├── home/         # Main feed and dashboard
    ├── contest/      # Contest details, rankings, and invitations
    ├── messages/     # Chat UI, presence, and event bus
    ├── reel/         # Short-form video playback
    ├── upload/       # Content creation and media processing
    ├── profile/      # User profiles and settings
    ├── earnings/     # Monetization and creator dashboard
    └── ...           # Search, Explore, Notifications, Leaderboards
```

## ⚙️ Setup & Installation

1.  **Dependencies**: Run `flutter pub get`.
2.  **Firebase**: 
    *   Android: Place `google-services.json` in `android/app/`.
    *   iOS: Place `GoogleService-Info.plist` in `ios/Runner/`.
3.  **Permissions**: Ensure `AndroidManifest.xml` and `Info.plist` have the required keys for Camera, Microphone, and Location.
4.  **Run**: Execute `flutter run` on a physical device or emulator.

## 🔗 Deep Linking
The app currently supports **Internal Deep Linking** via Push Notification payloads. It can route users directly to:
*   Specific Contests (`contest_id`)
*   Chat Conversations (`conversation_id` / `username`)

---
*Developed as part of the StyleBite ecosystem.*
