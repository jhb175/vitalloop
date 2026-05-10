# VitalLoop Real Device HealthKit Checklist

Last updated: 2026-05-10

Use this checklist on an iPhone that supports Apple Health. Pair an Apple Watch if you want sleep, heart rate, HRV, and activity signals to be representative.

## Preconditions

- iPhone target uses the official Apple Developer Team.
- iPhone app is installed on a real device.
- HealthKit capability is enabled for the iPhone target.
- Apple Watch has produced at least one recent heart rate, activity, and sleep sample.
- Optional but recommended: record one current body weight in Apple Health or through a HealthKit-compatible scale.

## Test Steps

1. Open VitalLoop on iPhone.
2. Open the Today tab.
3. Tap `连接 Apple 健康`.
4. In the system permission sheet, allow activity, sleep, heart rate, HRV, and body weight.
5. Return to VitalLoop and wait for the Today tab to refresh.
6. Confirm the Health connection card shows either `已连接 Apple 健康` or `Apple 健康数据不完整`.
7. Confirm the data source chip says `Apple 健康`.
8. Open Settings and Privacy.
9. In `真机联调检查`, confirm `Apple 健康` is `通过` or `部分`.
10. If the result is `部分`, compare the missing coverage rows on Today with the permissions enabled in Apple Health.
11. Tap `重新读取 Apple 健康` on Today after adding or changing Apple Health samples.

## Expected Results

- Full data path: Settings shows `Apple 健康` as `通过`.
- Partial data path: Settings shows `部分`, and Today explains which signals are missing.
- No data path: Settings shows `无数据`, and Today keeps sample data while explaining that HealthKit returned no usable samples.
- Read failure path: Settings shows `读取失败`, including the HealthKit error text.
- Denied path: Settings shows `未授权`, and Today offers `连接 Apple 健康` again after permissions are fixed.

## Evidence To Capture

- Screenshot of Today after HealthKit connection.
- Screenshot of Today data coverage rows.
- Screenshot of Settings `真机联调检查`.
- Device model, iOS version, Watch model, watchOS version.
- Whether the test used real sleep, heart rate, HRV, activity, and weight samples.

## Common Fixes

- If HealthKit is denied, open iOS Settings > Privacy and Security > Health > VitalLoop and allow the required categories.
- If sleep is missing, wear Apple Watch overnight or add a sleep sample manually for testing.
- If HRV is missing, wait for Apple Watch to generate HRV or use the partial data path as the expected beta result.
- If body weight is missing, add one body weight sample in Apple Health or use VitalLoop's Records tab for manual weight tracking.
- If values remain stale, tap `重新读取 Apple 健康` on Today.
