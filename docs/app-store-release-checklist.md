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

Use the GitHub Pages support page:

```text
https://jhb175.github.io/vitalloop/support.html
```

For TestFlight feedback, use:

```text
https://github.com/jhb175/vitalloop/issues/new?template=beta-feedback.yml
```

### Marketing URL

Use the GitHub Pages site root:

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

Official Apple references:

- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/

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

Use real devices when possible because HealthKit and WatchConnectivity behavior is more representative than simulator-only screenshots. Follow `docs/real-device-healthkit-checklist.md` and `docs/real-device-watch-sync-checklist.md` before capturing final beta screenshots.
Detailed screenshot order, review criteria, and official Apple references are in `docs/app-store-screenshot-plan.md`.

## Pre-Submission Checklist

1. Select the official Apple Developer Team in Xcode.
2. Decide whether to keep or replace the current bundle ids.
3. Enable GitHub Pages and verify the marketing, support, and privacy URLs are public.
4. Confirm the support page points testers to GitHub Issues and the beta feedback template.
5. Fill App Store Connect privacy nutrition labels to match the local-first implementation.
6. Capture fresh iPhone and Watch screenshots.
7. Run `scripts/beta-preflight.sh`.
8. Archive with a Release configuration and upload to App Store Connect.

Real device HealthKit and Watch sync validation should be completed before step 6 so screenshots show connected data, Watch sync time, and a successful Watch check-in loop.
Use `docs/testflight-first-build-runbook.md` for the first TestFlight archive, export, and upload flow.
Use `docs/beta-feedback-triage.md` for internal beta issue intake and release-blocker triage.
Use `docs/beta-fix-release-runbook.md` for follow-up TestFlight builds after feedback fixes.
Use `docs/app-store-screenshot-plan.md` for screenshot capture order and review.

## TestFlight Preflight

Run the full local beta preflight before archiving:

```sh
scripts/beta-preflight.sh
```

This checks:

- iPhone and Watch bundle ids are present.
- iPhone and Watch marketing versions match.
- iPhone and Watch build numbers match.
- Marketing, support, and privacy policy URLs are `https` URLs.
- Privacy policy URL is an `https` URL.
- GitHub Pages marketing, support, and privacy static files exist.
- `PrivacyInfo.xcprivacy` includes tracking and UserDefaults required reason declarations.
- HealthKit entitlement is present.
- Privacy policy includes the non-medical disclaimer.
- Existing unit tests and generic iOS / watchOS builds pass.

For metadata-only checks, use:

```sh
scripts/beta-preflight.sh --skip-build
```

CI runs this metadata preflight before the full local verification script.

## Release Archive

After selecting the official Apple Developer Team and confirming bundle ids, create a Release archive:

```sh
xcodebuild \
  -project BodyCoachApp/BodyCoachApp.xcodeproj \
  -scheme BodyCoachApp \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath BodyCoachApp/.build/Archives/VitalLoop.xcarchive \
  archive
```

The same command is printed by `scripts/beta-preflight.sh`. You can ask the script to run it directly:

```sh
scripts/beta-preflight.sh --archive --allow-provisioning-updates
```

The archive step requires valid signing and may fail until the official Apple Developer Team and provisioning are configured.

For local IPA export or App Store Connect upload, use:

```sh
scripts/beta-preflight.sh --export --allow-provisioning-updates
scripts/beta-preflight.sh --upload --allow-provisioning-updates
```
