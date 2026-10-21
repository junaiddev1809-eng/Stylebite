# StyleBite Project Overview

StyleBite is a high-performance fashion-centric social media and contest platform built with **Flutter**. It enables users to explore styles, participate in competitive fashion contests, and engage with a global community through a highly interactive and media-rich experience.

---

## 🛠 Tech Stack Overview

*   **Framework:** Flutter (Android & iOS)
*   **State Management:** [GetX](https://pub.dev/packages/get) (Reactive State, Dependency Injection, and Routing)
*   **Networking:** [Http](https://pub.dev/packages/http) & [Dio](https://pub.dev/packages/dio) for RESTful API communication.
*   **Backend Services:** Firebase Core, Firebase Auth, Firebase Cloud Messaging (FCM).
*   **Local Storage:** [Shared Preferences](https://pub.dev/packages/shared_preferences) for persistence.
*   **Media Suite:** `video_player` (Reels), `pro_image_editor` (Image Processing), `cached_network_image` (Caching).
*   **Ads:** [Google Mobile Ads](https://pub.dev/packages/google_mobile_ads).

---

## 🚀 Detailed Functionalities & Tech Stacks

### 1. User Authentication
*   **Authentication is working with Firebase Auth, Google Sign-In, and Sign-In with Apple.**
*   **Session Management is working with JWT tokens and Shared Preferences.**
*   *Features:* Secure social login, persistent user sessions, and profile synchronization with the backend.

### 2. Real-Time Messaging System
*   **Direct Messaging is working with REST APIs and Firebase Cloud Messaging (FCM).**
*   **Chat Event Synchronization is working with a custom Event Bus and GetX.**
*   **User Presence (Online/Offline) is working with WidgetsBindingObserver and REST PATCH requests.**
*   *Features:* Real-time message delivery signaled via FCM, "Wait for Reply" anti-spam logic, and blocking/unblocking users.

### 3. Fashion Feed & Reels
*   **Short-form Video (Reels) is working with the Video Player package and custom lifecycle controllers.**
*   **Image Feed is working with Cached Network Image and Flutter Cache Manager.**
*   **Infinite Scrolling is working with GetX ScrollControllers and Paginated REST APIs.**
*   *Features:* Auto-playing videos on scroll, high-performance image caching, and reactive engagement metrics (likes, comments).

### 4. Competitive Contests
*   **Contest Creation & Management is working with REST APIs and GetX State.**
*   **Media Submissions are working with Multipart HTTP requests for high-res uploads.**
*   **Live Leaderboards are working with Reactive RxLists and periodic background polling.**
*   *Features:* End-to-end contest lifecycle, voting systems, and real-time rank tracking.

### 5. Content Creation Suite
*   **Professional Image Editing is working with Pro Image Editor.**
*   **Media Acquisition is working with Image Picker (Camera & Gallery).**
*   **File Management is working with Path Provider for local temporary storage.**
*   *Features:* Filters, stickers, cropping, and text overlays for fashion posts.

### 6. Geolocation & Map Services
*   **Location Discovery is working with Google Maps Flutter and Geolocator.**
*   **Address Resolution is working with Geocoding and Google Places Autocomplete.**
*   *Features:* Tagging posts with locations, finding nearby contests, and interactive map views.

### 7. Monetization & Analytics
*   **Ad Integration is working with Google Mobile Ads (AdMob) for Native and Banner ads.**
*   **Earnings Dashboard is working with REST APIs to track creator performance.**
*   *Features:* Seamless ad placement in feeds and a dedicated wallet/earnings module for creators.

### 8. Growth & Engagement Tools
*   **Deep Linking is working with App Links for direct routing into contests and chats.**
*   **QR Interaction is working with Mobile Scanner and QR Flutter.**
*   **Content Sharing is working with Share Plus.**
*   *Features:* One-tap navigation from external links, scan-to-follow profiles, and cross-platform sharing.

---

## 📂 Architecture Overview

The project follows a **Modular Clean Architecture** powered by GetX:

*   **`lib/app/`**: Global routing tables (`AppPages`) and app-wide constants.
*   **`lib/core/`**: Reusable utilities, themes, and global services (API Helpers, Notification Handlers, Local Storage).
*   **`lib/modules/`**: Feature-specific modules (e.g., `auth`, `home`, `messages`, `contest`, `reel`).
    *   `controllers/`: Business logic and reactive state management.
    *   `screens/`: Module-specific UI layouts.
    *   `widgets/`: Components unique to the module.
    *   `models/`: Type-safe data structures for JSON serialization.

---

## 📈 Current Project State
*   **Version:** 1.0.5+7
*   **Environment:** Flutter SDK ^3.11.1
*   **Maintenance:** Modular structure allows for easy scaling of new fashion-related features.
