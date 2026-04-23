# LUMINANCE

A real-time behavioral analysis engine for reducing screen time on Android, built with Flutter and native Kotlin services.

---

## System Architecture

Luminance operates across three layers: a **native Android service layer** for real-time usage interception, a **Flutter application layer** for UI and business logic, and a **cloud persistence layer** via Firebase Firestore for cross-session analytics.

```
+------------------------------------------------------+
|                   Flutter UI Layer                    |
|   HomeScreen / Dashboard / Settings / AI Guidance     |
+------------------------------------------------------+
|              DashboardDataService (Singleton)         |
|   Guilt Index | Penalty Score | Predictive Limits     |
+------------------------------------------------------+
|          MethodChannel: com.luminance/usage           |
+------------------------------------------------------+
|              Native Android (Kotlin)                  |
|   MainActivity        |  LuminanceBlockerService      |
|   UsageStatsManager   |  AccessibilityService         |
|   Event-Based Tracking|  Full-Screen Overlay Lock     |
+------------------------------------------------------+
|              Firebase Firestore                       |
|   usersData | usageHistory | streaks | tasksPool      |
+------------------------------------------------------+
```

---

## Native Layer (Kotlin)

### Screen Time Tracking  `MainActivity.kt`

Usage data is collected via Android's `UsageStatsManager` using **event-based tracking** rather than aggregate stats. This mirrors Google's Digital Wellbeing methodology:

- Queries `UsageEvents` from midnight to now
- Tracks `MOVE_TO_FOREGROUND` and `MOVE_TO_BACKGROUND` event pairs per package
- Accumulates elapsed milliseconds between paired events
- Handles still-open apps by computing `now - lastForegroundTimestamp`
- Excludes launchers, keyboards, system UI, dialers, and pure system packages (identified via `FLAG_SYSTEM` without `FLAG_UPDATED_SYSTEM_APP`)

Exposed over `MethodChannel('com.luminance/usage')` with the following endpoints:

| Method                        | Returns              | Description                                         |
|-------------------------------|----------------------|-----------------------------------------------------|
| `getForegroundScreenTime`     | `Double` (hours)     | Total foreground time today                         |
| `getTopAppUsage`              | `Map<String, Double>`| Per-app hours, sorted descending, labelled by name  |
| `getTopAppUsagePackages`      | `Map<String, Double>`| Same, keyed by package name                         |
| `getUnlockCount`              | `Int`                | Count of `KEYGUARD_HIDDEN` events today             |
| `getNightUsageStats`          | `Map<String, Any>`   | Apps opened 10PM-6AM, passive heuristic (<5 events) |
| `getWeeklyUsageData`          | `List<Double>`       | 7-day foreground hours array                        |
| `getForegroundApp`            | `String?`            | Current foreground package name                     |

### App Blocker  `LuminanceBlockerService.kt`

An `AccessibilityService` that intercepts `TYPE_WINDOW_STATE_CHANGED` events in real time:

1. When a restricted app enters foreground, starts a 1-second polling loop
2. Computes `todayBaseUsage + currentSessionDuration` against the configured limit
3. On limit breach, renders a **full-screen opaque overlay** (`TYPE_APPLICATION_OVERLAY`) with:
   - A programmatically drawn 8-petal lotus (custom `Canvas` drawing, not an image asset)
   - 4-second breathing scale animation (0.9x to 1.1x, infinite repeat)
   - Randomized formal motivational quote
   - Single exit button that triggers `GLOBAL_ACTION_HOME`

**Child Mode:** When enabled, automatically restricts social media and gaming packages to a 10-second limit using keyword matching against a hardcoded list of 23 package identifiers.

---

## Analytics Engine  `DashboardDataService`

A singleton service that aggregates native data, computes behavioral scores, and syncs to Firestore.

### Guilt Index

Measures the proportion of screen time spent on high-dopamine applications:

```
guiltIndex = (guiltAppMinutes / totalScreenTimeMinutes) * 100
```

Guilt-classified keywords: `instagram`, `tiktok`, `youtube`, `facebook`, `snapchat`, `game`, `netflix`, `prime`

### Penalty Score (0-100)

A composite risk metric with four weighted components:

| Component        | Trigger                   | Formula                                              | Max  |
|------------------|---------------------------|------------------------------------------------------|------|
| Over Usage       | Exceeds daily goal        | `((actual - goal) / goal) * 20`, clamped             | 40   |
| Wasteful Binging | Guilt Index > 40%         | `(guiltIndex / 100) * 30`                            | 30   |
| Night Usage      | Apps opened 10PM-6AM      | `nightAppsOpened * 4`, clamped                       | 20   |
| Pickups          | Unlocks > 40/day          | `(unlockCount - 40) / 5`, clamped                    | 10   |

### Predictive Limit Suggestions  `getSuggestedLimit()`

Computes per-app daily thresholds based on 7-day rolling averages from Firestore:

- **Social / Games / Entertainment** (matched by keyword): 30% reduction from weekly average
- **Heavy users** (>3 hours/day on matched apps): 15% reduction instead ("Little by Little" strategy to avoid behavioral shock)
- **All other apps**: 10% reduction
- **Floor**: 15 minutes minimum regardless of calculation

### App Categorization

Runtime classification of installed apps into 6 categories via keyword matching:

`Social Media` | `Games` | `Video/Entertainment` | `Messages` | `Surfing` | `Tools & Other`

---

## Notification System

### Sarcasm Engine  `SarcasmEngine`

A foreground polling service (10-second interval via `Timer.periodic`) that:

1. Queries the current foreground app via MethodChannel
2. Checks against user-configured notification settings (`SharedPreferences`)
3. Tracks per-app session duration
4. On threshold breach, fires a sarcastic push notification via `flutter_local_notifications`
5. Rate-limited: one notification per app per configured interval

### Background Scheduling

Uses `workmanager` for periodic task execution when the app is backgrounded. Child Mode registers a 5-minute periodic task for continuous reminder notifications.

---

## Data Persistence

### Firestore Schema

**`usersData/{uid}`** -- User profile, goals, streak state, task assignments

**`usageHistory/{uid_date}`** -- Daily snapshots: `totalUsageSeconds`, `appsUsed` map, `addictionScore`, `guiltIndex`, `timestamp`

**`streaks/{uid_date}`** -- Daily streak records: `currentStreak`, `glowStreaks`, `tasksDone`, `screenTimeHours`

**`tasksPool`** -- Server-side task pool; 3 random tasks allocated daily per user

### Local State  `SharedPreferences`

- `app_block_settings` -- JSON map of per-app blocking configuration
- `app_notification_settings` -- JSON map of per-app notification thresholds
- `currentStreak`, `maxStreak`, `glowDays`, `totalTasksCompleted` -- Streak counters
- `childMode` -- Boolean flag for restricted mode
- `dailyTasksJson`, `lastTaskAllocationDate` -- Task allocation cache

---

## Dashboard (6-Page Slider)

1. **Usage Sanctuary** -- Total screen time with animated breathing lotus, guilt index card, streak summary
2. **Streaks Dashboard** -- Max streak, victories (tasks completed), glow days (100% task completion days), AI inference
3. **Risk Assessment** -- Penalty score dial with interactive breakdown dialog showing per-component attribution and progress bars
4. **Weekly Benchmarks** -- 7-day macro averages for usage hours and guilt index
5. **Usage vs Guilt Trends** -- Dual-line chart (`fl_chart`) correlating daily screen time against guilt index over 7 days
6. **Daily App Audit** -- Sorted list of all apps used today with duration; top 5 highlighted

---

## AI Integration

**Provider:** Groq API (model: `llama-3.1-8b-instant`)

Used in three contexts:
- **DigiGuide Chat** (`AiGuidanceScreen`) -- Conversational coaching with full usage context injected into system prompt
- **Home Screen Insight** -- 2-sentence personalized daily insight based on current stats
- **Streak Inference** (`DashboardDataService`) -- Task completion pattern analysis

---

## Tech Stack

| Layer       | Technology                                           |
|-------------|------------------------------------------------------|
| Framework   | Flutter (Dart), SDK ^3.11.4                          |
| Native      | Kotlin, Android UsageStatsManager, AccessibilityService |
| Backend     | Firebase Auth, Cloud Firestore                       |
| AI          | Groq API (Llama 3.1 8B)                             |
| Charts      | fl_chart                                             |
| State       | Provider, SharedPreferences                          |
| Audio       | audioplayers (432Hz, 852Hz, 285Hz solfeggio therapy) |
| Scheduling  | workmanager                                          |
| Notifications | flutter_local_notifications                        |

---

## Setup

```bash
git clone https://github.com/kelinavipu/Luminance.git
flutter pub get
flutter run
```

**Required Android Permissions:**
- Usage Access (`ACTION_USAGE_ACCESS_SETTINGS`)
- Overlay Permission (`ACTION_MANAGE_OVERLAY_PERMISSION`)
- Accessibility Service (for `LuminanceBlockerService`)
- Battery Optimization disabled (critical for MIUI/Redmi devices)

**API Key:** Replace `YOUR_GROQ_KEY_HERE` in `ai_guidance_screen.dart`, `dashboard_data_service.dart`, and `home_screen.dart` with a valid Groq API key.

---

## License

MIT
