# VitalLoop Beta Feedback Triage

Use GitHub Issues as the first beta feedback inbox until a dedicated support site exists.

## Intake

- App Settings links to the beta issue template.
- TestFlight notes should point testers to `https://github.com/jhb175/vitalloop/issues/new?template=beta-feedback.yml`.
- Ask testers not to attach raw HealthKit exports or sensitive health records.
- Prefer screenshots of app states after redacting private details.

## Labels

- `beta-feedback`: all TestFlight feedback.
- `healthkit`: HealthKit permission, missing data, or data quality issues.
- `watch-sync`: Watch app install, reachability, summary sync, or check-in return issues.
- `notifications`: local reminder scheduling and notification tap routing.
- `records`: weight, meal, subjective logs, filters, edits, and deletion.
- `release-blocker`: issue blocks TestFlight expansion or App Store review.
- `needs-info`: cannot reproduce without device, build, or steps.

## Severity

- P0: data loss, launch crash, app cannot be installed, or HealthKit permission loop blocks the app.
- P1: Watch sync loop fails, records cannot be saved, reminders cannot be configured, or screenshots cannot be captured.
- P2: confusing copy, stale status, layout issue, or incomplete explanation that does not block core flows.
- P3: polish request, nice-to-have metric, or future feature idea.

## Daily Beta Review

1. Review new `beta-feedback` issues.
2. Confirm app version, build number, device model, iOS version, and watchOS version are present.
3. Reproduce using the closest local path: simulator for UI issues, real devices for HealthKit and WatchConnectivity.
4. Add one severity label and one area label.
5. Move unclear reports to `needs-info` with the missing questions.
6. Fix P0/P1 before expanding testers.
7. After a fix, add the commit hash and ask the tester to recheck the next build.

## Release Gate

Do not expand beyond internal testers if any open `release-blocker` issue exists. Before external beta:

- No open P0 issues.
- No unresolved HealthKit permission loop.
- No unresolved Watch quick check-in return failure.
- `scripts/beta-preflight.sh` passes on the release branch.
- Real-device HealthKit and Watch sync checklists pass on the TestFlight build.
