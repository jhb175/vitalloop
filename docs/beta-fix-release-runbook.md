# VitalLoop Beta Fix Release Runbook

Use this after each internal TestFlight feedback cycle.

## Entry Criteria

- New feedback has been triaged using `docs/beta-feedback-triage.md`.
- Every issue selected for the next build has a severity and area label.
- P0 and P1 issues are fixed before external tester expansion.
- Fix scope is small enough to verify with the existing preflight plus the affected real-device checklist.

## Fix Loop

1. Pull latest `main`.
2. Reproduce the issue or document why it cannot be reproduced locally.
3. Fix the smallest behavior that resolves the issue.
4. Run targeted checks for the changed area.
5. Run `scripts/beta-preflight.sh`.
6. Bump build number:

```sh
scripts/bump-build-number.sh
```

7. Run metadata preflight to confirm iPhone and Watch build numbers match:

```sh
scripts/beta-preflight.sh --skip-build
```

8. Commit with the issue number in the message when available.
9. Archive and upload:

```sh
scripts/beta-preflight.sh --upload --allow-provisioning-updates
```

10. Ask the reporter to retest in the next TestFlight build.

## Exit Criteria

- No open P0 issues.
- No open `release-blocker` issues.
- HealthKit checklist passes on the new TestFlight build if any HealthKit behavior changed.
- Watch sync checklist passes on the new TestFlight build if any WatchConnectivity or Watch UI behavior changed.
- App Store screenshots are refreshed if a visible UI changed.
- `docs/app-store-release-checklist.md` still reflects the shipped build state.

## Build Number Rule

App Store Connect rejects duplicate build numbers. `scripts/bump-build-number.sh` updates all four project build settings:

- iPhone Debug
- iPhone Release
- Watch Debug
- Watch Release

Run `scripts/beta-preflight.sh --skip-build` after every bump because it fails if iPhone and Watch build numbers diverge.
