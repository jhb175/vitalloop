# VitalLoop Real Device Watch Sync Checklist

Use this checklist on a paired iPhone and Apple Watch before TestFlight or App Store screenshots. Simulator smoke tests are useful, but real devices are required to confirm WatchConnectivity timing, Watch app installation, and background delivery behavior.

## Preconditions

- iPhone and Apple Watch are paired to the same Apple ID account.
- Both devices are unlocked, near each other, and have Bluetooth and Wi-Fi enabled.
- VitalLoop iPhone app and VitalLoop Watch app are installed from the same Xcode run or the same TestFlight build.
- iPhone target bundle id is `com.ramsey.bodycoach`.
- Watch target bundle id is `com.ramsey.bodycoach.watchkitapp`.
- HealthKit has been connected or the app has realistic sample data for the current day.

## Validation Steps

1. Open VitalLoop on iPhone.
2. Open VitalLoop on Apple Watch.
3. On iPhone, go to Settings and find `真机联调检查`.
4. Confirm `Watch App` shows `已安装`.
5. Keep both apps in the foreground for 10 to 20 seconds.
6. Confirm `连接通道` becomes `可达`. If it stays `后台`, continue testing background delivery but note that instant messaging is not currently reachable.
7. On iPhone, tap `发送 Watch 连接测试`.
8. Confirm `即时测试` changes to `通过` and shows a recent confirmation time. Record the round-trip latency if it is shown.
9. On Apple Watch, confirm the dashboard shows a synced score and a sync time instead of the preview state.
10. On Apple Watch, open quick check-in and save stress, fatigue, and hunger values.
11. On iPhone, confirm `同步回传` changes to `已回传`.
12. On iPhone, open Records and confirm a new subjective record appears with source `Apple Watch`.
13. Return to Today and confirm the score or recommendation text refreshes after the Watch check-in.
14. Force quit the Watch app, reopen it, and confirm the latest synced summary is still visible.
15. Lock the Watch for one minute, unlock it, and save another quick check-in. Confirm iPhone receives it after both apps are foregrounded.

## Expected Results

- The Watch app is recognized as installed on the paired device.
- Instant connection test passes when both apps are foregrounded and reachable.
- The Watch dashboard displays the iPhone-generated summary instead of static preview data.
- Watch quick check-ins are stored locally on iPhone as `SubjectiveCheckIn` records.
- iPhone Settings, Records, and Today all reflect the latest Watch check-in.

## Evidence To Capture

- iPhone Settings screenshot showing `Watch App`, `连接通道`, `同步回传`, and `即时测试`.
- Apple Watch dashboard screenshot showing synced score and sync time.
- Apple Watch quick check-in screenshot.
- iPhone Records screenshot showing the new `Apple Watch` subjective record.
- Device model, iOS version, Watch model, watchOS version, build number, and test date.

## Common Fixes

- If `Watch App` is `未安装`, reinstall from Xcode or TestFlight and wait for the Watch app to finish installing.
- If `连接通道` is `后台`, open both apps to the foreground and keep the devices unlocked and nearby.
- If instant test fails, verify both apps are from the same build and bundle ids match the expected values.
- If the Watch dashboard stays in preview state, refresh Today on iPhone or reopen both apps to trigger a new application context update.
- If check-ins do not appear in Records, confirm the Watch save button completed and check iPhone Settings `Apple Watch 同步` for the latest error.
