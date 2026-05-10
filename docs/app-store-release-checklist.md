# VitalLoop App Store Release Checklist

Last updated: 2026-05-10

## Current Build State

- Product name shown in the app: `VitalLoop`.
- iPhone bundle id: `com.ramsey.bodycoach`.
- Watch bundle id: `com.ramsey.bodycoach.watchkitapp`.
- Marketing version: `1.0`.
- Build number: `1`.
- Privacy policy URL used in the app: `https://jhb175.github.io/vitalloop/privacy-policy.html`.
- Privacy manifest: `BodyCoachApp/PrivacyInfo.xcprivacy`.
- HealthKit capability: enabled for the iPhone target.

## App Store Connect Metadata Draft

### App Name

VitalLoop

### Subtitle

Body status, habits, and recovery

### Promotional Text

VitalLoop turns Apple Health summaries and quick Apple Watch check-ins into local, explainable daily body status guidance.

### Short Description

VitalLoop helps you review activity, sleep, recovery, body weight trends, and subjective stress signals in one local-first iPhone and Apple Watch app. It provides daily scores, trends, reminders, and habit-focused suggestions for lifestyle planning.

### Keywords Draft

health,habits,recovery,sleep,weight,fitness,watch,wellness,trend,body

### Support URL

Use the repository issues page until a formal support site is available:

```text
https://github.com/jhb175/vitalloop/issues
```

### Marketing URL

Optional for the first beta. If required, use the GitHub Pages site root after Pages is enabled:

```text
https://jhb175.github.io/vitalloop/
```

### Privacy Policy URL

```text
https://jhb175.github.io/vitalloop/privacy-policy.html
```

## Permission And Review Notes

### HealthKit Purpose String

VitalLoop reads activity, sleep, heart rate, heart rate variability, and body weight summaries to generate local body status scores, trends, and daily habit suggestions.

### Notifications Purpose

VitalLoop schedules local reminders for weight logging, sleep preparation, and meal notes. Notification taps route users to the relevant in-app tab.

### Medical Disclaimer

VitalLoop is not a medical device. Scores and suggestions are for lifestyle reference only and do not provide medical diagnosis, treatment, or professional health advice.

## Privacy Nutrition Label Guidance

- Data collection: current version does not upload personal or HealthKit data to a server.
- Tracking: no tracking.
- Third-party advertising: none.
- Health and fitness data: processed on device for app functionality.
- User-entered goals, subjective check-ins, meal notes, and weight notes: stored locally on device.
- Deletion: users can delete local VitalLoop records in Settings and Privacy. This does not delete source Apple Health data.

Confirm these answers in App Store Connect before submission because the final legal responsibility belongs to the account holder.

## Screenshot Checklist

Required before TestFlight or App Store review:

- iPhone Today tab with HealthKit connected or realistic review data.
- iPhone Trends tab showing trend explanation and period review.
- iPhone Plan tab showing goal progress and weekly review.
- iPhone Records tab showing search, type filter, and recent logs.
- iPhone Settings tab showing privacy, reminder status, Watch diagnostics, and privacy policy link.
- Apple Watch home screen with synced score and sync time.
- Apple Watch quick check-in screen for stress, fatigue, and hunger.

Use real devices when possible because HealthKit and WatchConnectivity behavior is more representative than simulator-only screenshots.

## Pre-Submission Checklist

1. Select the official Apple Developer Team in Xcode.
2. Decide whether to keep or replace the current bundle ids.
3. Enable GitHub Pages and verify the privacy policy URL is public.
4. Replace the support URL with a formal support page or confirm GitHub Issues is acceptable for beta.
5. Fill App Store Connect privacy nutrition labels to match the local-first implementation.
6. Capture fresh iPhone and Watch screenshots.
7. Run `scripts/verify-local.sh`.
8. Archive with a Release configuration and upload to App Store Connect.
