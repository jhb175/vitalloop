# VitalLoop App Store Screenshot Plan

Last updated: 2026-05-10

Official Apple references:

- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Upload screenshots and previews: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots
- Product page guidance: https://developer.apple.com/app-store/product-page/

## Requirements To Observe

- Upload 1 to 10 screenshots for each supported platform.
- Use `.png`, `.jpg`, or `.jpeg`.
- App previews are optional for the first beta.
- If the app UI is the same across sizes and localizations, provide the highest resolution screenshots required and let App Store Connect scale down where supported.
- Apple Watch apps require Apple Watch screenshots; keep the same Watch screenshot size across all localizations.
- Screenshots should show real app UI. Redact personal health details before upload.

## iPhone Screenshot Set

Capture portrait screenshots from a real device or simulator using realistic beta data:

1. Today: first-run setup complete, HealthKit connected, score visible.
2. Today: health data coverage and explanation visible.
3. Trends: 14-day trend chart and period review.
4. Plan: goal progress, weekly review, and adjustment advice.
5. Records: filters, search, and recent logs.
6. Records: edit or delete confirmation flow if needed.
7. Settings: privacy, reminder status, Watch diagnostics, Beta feedback.

## Apple Watch Screenshot Set

Capture from the paired Watch after iPhone summary sync:

1. Watch dashboard with synced score and sync time.
2. Watch quick check-in sliders for stress, fatigue, and hunger.
3. Watch recommendation or task area if space allows.

## Screenshot Review Checklist

- No private HealthKit details, Apple ID, or notification content is visible.
- First 1 to 3 iPhone screenshots communicate the core product value without relying on text outside the app UI.
- Watch screenshots show synced state, not preview fallback.
- If dark mode is used, the full set is visually consistent.
- Screenshot order matches the App Store Connect metadata draft.
- Final screenshots are stored outside ignored build-cache folders.

## App Store Connect Metadata To Pair With Screenshots

- App name: `VitalLoop`.
- Subtitle: `Body status, habits, and recovery`.
- Support URL: `https://jhb175.github.io/vitalloop/support.html`.
- Marketing URL: `https://jhb175.github.io/vitalloop/`.
- Privacy Policy URL: `https://jhb175.github.io/vitalloop/privacy-policy.html`.
