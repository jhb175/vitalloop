# VitalLoop TestFlight First Build Runbook

Use this runbook after local verification and real-device HealthKit / Watch sync checks are complete.

## Prerequisites

- App Store Connect app record exists for VitalLoop.
- iPhone bundle id is `com.ramsey.bodycoach`.
- Watch bundle id is `com.ramsey.bodycoach.watchkitapp`.
- Xcode is signed in to the Apple Developer account for team `B9RPMQ9JW7`, or an App Store Connect API key is available.
- GitHub Pages is enabled and `https://jhb175.github.io/vitalloop/privacy-policy.html` is publicly reachable.
- `docs/real-device-healthkit-checklist.md` and `docs/real-device-watch-sync-checklist.md` have been completed for the current build.
- `CURRENT_PROJECT_VERSION` is incremented before every new upload.

## Local Preflight

```sh
scripts/beta-preflight.sh
```

This must pass before creating the archive.

## Archive

```sh
scripts/beta-preflight.sh --archive --allow-provisioning-updates
```

Expected archive output:

```text
BodyCoachApp/.build/Archives/VitalLoop.xcarchive
```

## Export IPA

```sh
scripts/beta-preflight.sh --export --allow-provisioning-updates
```

Expected export output:

```text
BodyCoachApp/.build/Exports/TestFlight
```

## Upload To App Store Connect

If Xcode has a signed-in account with upload permissions:

```sh
scripts/beta-preflight.sh --upload --allow-provisioning-updates
```

If using an App Store Connect API key:

```sh
scripts/beta-preflight.sh --upload --allow-provisioning-updates \
  --api-key-path /path/to/AuthKey_KEYID.p8 \
  --api-key-id KEYID \
  --api-key-issuer-id ISSUER_ID
```

## Post-Upload Checks

1. Open App Store Connect and confirm the build appears under TestFlight processing.
2. Confirm the uploaded version is `1.0` and build number is `1` or the intended increment.
3. Confirm the build includes the Watch app.
4. Add internal testers first.
5. Add beta review notes using the non-medical disclaimer from `docs/app-store-release-checklist.md`.
6. Install from TestFlight on a paired iPhone and Apple Watch.
7. Repeat the HealthKit and Watch sync real-device checklists against the TestFlight build.
8. Point testers to the beta feedback template and triage new issues using `docs/beta-feedback-triage.md`.

## Common Failures

- Provisioning failure: run Xcode once, select the team in Signing & Capabilities, then rerun with `--allow-provisioning-updates`.
- Upload authentication failure: confirm the Apple ID role or API key has App Manager, Developer, or Admin access.
- Duplicate build number: increment `CURRENT_PROJECT_VERSION` for both iPhone and Watch targets before uploading again.
- Missing Watch app: confirm the iPhone target still has the `Embed Watch Content` build phase and the Watch target bundle id matches this runbook.
