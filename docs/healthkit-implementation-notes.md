# HealthKit Implementation Notes

更新时间：2026-05-09

## 本次实现范围

已新增 HealthKit 读取骨架，并接入 iPhone 首页状态展示。

新增文件：

- `BodyCoachApp/Shared/Health/HealthPermissionState.swift`
- `BodyCoachApp/Shared/Health/HealthMetricSnapshot.swift`
- `BodyCoachApp/Shared/Health/HealthKitClient.swift`
- `BodyCoachApp/Shared/Health/BaselineCalculator.swift`
- `BodyCoachApp/Shared/BodyDashboardSnapshot.swift`
- `BodyCoachApp/iOS/State/BodySummaryStore.swift`
- `BodyCoachApp/BodyCoachApp.entitlements`

已接入：

- iPhone target HealthKit entitlement
- `NSHealthShareUsageDescription`
- App 启动时请求 HealthKit 读取权限
- 完全无数据 / 设备不支持 / 未授权时 fallback 到模拟数据
- 单项指标读取失败时不影响其他指标
- 首页显示 Apple 健康连接状态和当前数据源
- 首页核心指标卡使用统一数据源，不再硬编码模拟数值

## 本轮修正

针对代码检查中发现的问题，已完成：

- 增加 `BodyDashboardSnapshot`，作为首页指标、评分输入和模拟数据的统一 UI 数据源。
- 首页活动、睡眠、恢复、体重卡片不再硬编码固定数值。
- HealthKit 单项查询改为容错模式，某个指标失败不再让全部数据回退模拟数据。
- HealthKit 状态从单一 `authorized` 扩展为 `authorized`、`partialData`、`noData`、`unavailable`、`denied`。
- 睡眠读取窗口改为昨晚窗口，不再只按今天 00:00 到当前时间统计。
- 静息心率和 HRV 允许读取最近 7 天最新值。
- 体重读取最近 14 天最新值，并尝试计算 7 日体重变化。
- 新增 `BaselineCalculator`，使用最近 28 天样本计算睡眠、HRV、静息心率个人基线。
- 基线计算采用中位数，并在样本足够时裁掉最高/最低约 10% 作为基础异常值过滤。

## 当前读取指标

- 活动能量：`activeEnergyBurned`
- 步数：`stepCount`
- 睡眠：`sleepAnalysis`
- 静息心率：`restingHeartRate`
- HRV：`heartRateVariabilitySDNN`
- 体重：`bodyMass`
- 锻炼分钟：`HKWorkoutType`

## 当前限制

- 已实现基础个人基线计算，但还没有按工作日/周末、训练日/休息日拆分。
- 体重趋势已尝试从最近 14 天样本推导，但还没有做异常值过滤。
- Watch 端暂未直接接 HealthKit，后续通过 iPhone 同步今日摘要。
- HealthKit 授权后用户可能只授权部分指标，当前通过字段数量显示部分数据状态，后续需要逐项权限/数据缺失说明。
- 真实数据读取需要在 Xcode 中选择开发者 Team 后运行到支持 HealthKit 的设备或模拟器。

## 下一步

1. 对体重趋势做异常值过滤。
2. 增加逐项 HealthKit 数据缺失说明。
3. 将首页趋势图从模拟曲线改为真实历史数据。
4. 开始 WatchConnectivity，同步 iPhone 计算后的今日摘要到 Watch。
