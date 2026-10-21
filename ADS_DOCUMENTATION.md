# StyleBite Ads & Monetization Documentation

This document explains the full implementation of the Ads and Monetization system in the StyleBite app, covering both the frontend logic and backend integration.

---

## 1. Watch Time Reporting
**Endpoint:** `POST /api/views/batch`  
**Purpose:** Tracks how long users watch reels to unlock monetization eligibility for creators.

### Implementation Logic (`ReelController`):
- **Tracking:** A 1-second ticker monitors the current reel. If the video is playing (not paused), it increments watch seconds in a local buffer (`_watchTimeBuffer`).
- **Batching:** To optimize performance, the app does not send a request for every view. It reports in batches:
    - Every **30 seconds**.
    - OR whenever the user has scrolled through **10 unique reels**.
- **Payload Structure:**
```json
{ 
  "views": [ 
    { "post_id": 123, "watch_seconds": 18, "view_source": "reel" } 
  ] 
}
```

---

## 2. Earning Eligibility
**Endpoint:** `GET /api/ads/eligibility`  
**Purpose:** Checks if a creator meets the thresholds (Followers & Watch Hours) to enable ads.

### Implementation Logic (`EarningsController` & `MyEarningsScreen`):
- Fetches data on screen initialization and refresh.
- **UI Progress:** Displays progress bars for:
    - **Followers:** (e.g., 2 / 500)
    - **Watch Hours:** (e.g., 0.02 / 1,000) - supports high precision decimals.
- **Labels:** Dynamically formats "Need X more followers" or "Need Y more watch hours".

---

## 3. Enable Ads Toggle
**Endpoint:** `POST /api/ads/toggle`  
**Purpose:** Allows eligible creators to turn on/off ads on their content.

### Implementation Logic:
- **Visibility:** The toggle switch "Enable ads on my reels" **only appears** if `isEligible` is `true`.
- **Optimistic UI:** The switch flips immediately for a smooth experience. If the backend call fails, it reverts to the previous state and shows an error.

---

## 4. Ad Types & Attribution
The system uses two types of ads, each attributed to creators differently for revenue sharing.

### A. Scroll Ads (Native Ads)
- **Placement:** Inserted automatically every few reels in the main feed.
- **Attribution:** Revenue is credited to the creator of the **previous reel**. The app sends the previous reel's `post_id` with the impression so the backend can attribute the revenue correctly.
- **Implementation:** `ReelAdSlot` stores the `attributedPostId` when the ad is placed in the feed.

### B. Mid-Reel Ads (Interstitial Ads)
- **Placement:** Triggered while watching a specific reel.
- **Eligibility (Backend Controlled):** A reel is only eligible for a mid-reel ad if the backend sends `"show_ad": true` in the reel's data object.
- **Trigger Logic:** If eligible, the ad is shown when the video reaches a specific watch threshold:
    - Default threshold is **40%** (`0.4`).
    - Can be customized per-reel via the backend field `"ad_trigger_ratio": 0.5`.
- **Attribution:** Revenue is credited to the creator of the **current reel**. The app sends the current reel's `post_id` with the impression.
- **Frequency Control:** A client-side cooldown of **5 reels** is enforced between interstitial ads to protect the user experience.

---

## 5. Revenue Reporting (ILRD)
**Endpoint:** `POST /api/ads/impressions`  
**Purpose:** Reports accurate, impression-level revenue data (Paid Events) to the backend.

### Implementation Logic (`AppAdService`):
- Uses AdMob's `onPaidEvent` handler.
- Captures the exact revenue (`valueMicros`) and currency from AdMob.
- **Attribution Rules:** 
    - `post_id` represents the attributed reel:
        - For **scroll** ads, it is the **previous reel's post_id**.
        - For **mid_reel** ads, it is the **current reel's post_id**.
- **Payload Structure:**
```json
{ 
  "impressions": [ 
    { 
      "post_id": 123, 
      "ad_type": "scroll", 
      "revenue": 0.00123, 
      "currency": "USD", 
      "ad_unit_id": "ca-app-pub-..." 
    } 
  ] 
}
```

---

## 6. Compliance & SDKs
- **SDK:** Google Mobile Ads SDK.
- **GDPR/UMP:** The app initializes the User Messaging Platform (UMP) on startup to handle consent forms for European users and comply with Store policies.
- **ILRD:** Impression-Level Revenue Data is used to ensure the revenue split between StyleBite and the Creator is accurate.

---

## 7. Formatting Rules
- **Watch Hours:** Displayed as integers when the remaining amount is large, and with 1-2 decimal places when the amount is small (e.g., 0.98 hours).
- **Currency:** Managed via `EarningsController.formatMoney`, automatically converting backend values to the user's wallet currency (e.g., PKR, USD).
