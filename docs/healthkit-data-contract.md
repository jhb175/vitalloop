# HealthKit 数据契约 v1

更新时间：2026-05-09 12:49

## 目标

HealthKit Adapter 的职责是把 Apple Health / Apple Watch 的原始数据转换成 `BodyCoachCore.BodyMetrics`。核心评分模块不直接依赖 HealthKit，这样算法可以单独测试，也方便后续接入模拟数据、本地记录或云端摘要。

## 第一版读取项

| 数据 | HealthKit 来源 | 用途 | 备注 |
| --- | --- | --- | --- |
| 活动能量 | activeEnergyBurned | 活动分、减脂建议 | 趋势参考，不做绝对热量承诺 |
| 步数 | stepCount | 活动分、低强度补足建议 | 每日总量 |
| 锻炼 | workout | 活动分、训练负荷 | 先只统计分钟数 |
| 睡眠 | sleepAnalysis | 睡眠分、恢复建议 | 先统计睡眠分钟 |
| 静息心率 | restingHeartRate | 恢复分 | 与个人基线比较 |
| HRV | heartRateVariabilitySDNN | 恢复分 | 与个人基线比较 |
| 体重 | bodyMass | 体重趋势分 | 需要用户或体脂秤记录 |

## 主观记录

以下数据不来自 HealthKit，第一版由用户在 iPhone 或 Watch 快速记录：

- 压力感：0 到 10
- 疲劳感：0 到 10
- 饥饿感：0 到 10
- 饮食大致记录：正常 / 偏多 / 偏少 / 高蛋白 / 高油高糖

## 基线计算

第一版建议使用本地滚动基线：

- 睡眠基线：过去 14 天有效睡眠均值。
- 静息心率基线：过去 21 天均值。
- HRV 基线：过去 21 天中位数或均值。
- 活动能量目标：用户目标 + 历史活动能力共同决定。
- 体重趋势：过去 7 天变化。

缺少基线时使用保守默认值，但必须降低数据完整度。

## 隐私边界

- 原始 HealthKit 数据默认只留在本地。
- 云端 AI 只能接收用户明确授权后的摘要数据。
- 摘要数据应避免包含逐分钟心率、精确位置、完整睡眠时间线等敏感细节。
- App 内文案不能暗示医疗诊断能力。

## 输出到核心模块

HealthKit Adapter 最终产物是：

```swift
BodyMetrics(
    sleepMinutes: 394,
    sleepBaselineMinutes: 450,
    activeEnergyKcal: 684,
    activeEnergyGoalKcal: 650,
    stepCount: 8400,
    restingHeartRateBpm: 61,
    restingHeartRateBaselineBpm: 60,
    hrvMs: 41,
    hrvBaselineMs: 43,
    weightKg: 76.8,
    weightSevenDayDeltaKg: -0.4,
    subjectiveStress: 4,
    subjectiveFatigue: 5,
    hungerLevel: 5,
    workoutMinutes: 32
)
```

## 关键质疑

- Apple Watch 的热量消耗不是绝对准确值，只适合做个人趋势。
- HRV 波动很大，不能单独判断压力，必须结合睡眠、静息心率和主观记录。
- 睡眠数据质量受设备佩戴影响，缺失时不要强行给精确建议。
- 减脂建议不能只看体重日变化，要看 7 天及更长趋势。
