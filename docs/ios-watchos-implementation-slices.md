# iOS / watchOS 实现拆分

更新时间：2026-05-09 13:05

## 模块边界

### BodyCoachCore

已创建。负责纯业务逻辑：

- `BodyMetrics`
- `BodyCoachScorer`
- `DailyBodySummary`
- `ScoreBreakdown`
- `DailyRecommendation`

不依赖 SwiftUI、HealthKit、SwiftData、WatchConnectivity。

### BodyCoachHealth

下一步创建。负责 HealthKit：

- 权限请求。
- 读取每日活动、步数、睡眠、静息心率、HRV、体重。
- 计算滚动基线。
- 输出 `BodyMetrics`。

### BodyCoachStore

负责本地持久化：

- 用户目标。
- 每日摘要缓存。
- 主观记录。
- 体重记录。
- 隐私设置。

第一版建议使用 SwiftData；如果创建 App 工程前需要更轻，可先用 Codable JSON。

### BodyCoachApp iOS

负责 iPhone SwiftUI UI：

- 首页：对应 v7 首页。
- 趋势页。
- 计划页。
- 记录页。
- 设置页。

UI 不直接计算分数，只调用 `BodyCoachCore` 或读取 `DailyBodySummary`。

### BodyCoachWatch

负责 watchOS UI：

- 今日状态。
- 今日任务。
- 快速记录。
- 轻提醒。

第一版 Watch 可以只读 iPhone 生成的摘要；第二阶段再支持独立 HealthKit 读取。

## 推荐开发顺序

1. 完成 `BodyCoachCore` v1。
2. 创建 iOS/watchOS App 工程。
3. 在 iOS 端用模拟 `BodyMetrics` 接入 v7 首页。
4. 做本地记录模型。
5. 接 HealthKit Adapter。
6. 做 Watch 只读首页。
7. 加 Watch 快速记录。
8. 优化 Liquid Glass 真实 SwiftUI 质感。

## 第一批可实现页面

### iPhone 首页

数据来源：先用模拟 `DailyBodySummary`。

组件：

- `BodyOverviewScreen`
- `StatusHeroCard`
- `SignalGrid`
- `DailyRhythmCard`
- `BodyRadarCard`
- `WeightTrendCard`
- `RecommendationList`
- `BodyCoachTabBar`

### iPhone 记录页

数据来源：本地手动输入。

组件：

- `WeightLogRow`
- `SubjectiveScaleControl`
- `MealQuickLog`
- `DailyNoteField`

### Watch 首页

数据来源：iPhone 同步摘要或本地模拟数据。

组件：

- `WatchStatusView`
- `WatchActionList`
- `WatchQuickLogView`

## 设计落地注意

- Liquid Glass 只用于大容器、导航和重要卡片，不要每个小元素都玻璃化。
- 背景图案不能覆盖文字层。
- 深色模式要避免“纯黑 + 彩色发光”过度游戏化。
- 浅色模式要避免透明卡片边界太弱。
- 首页首屏必须先回答：今天身体状态怎样、为什么、我该做什么。

## 技术风险

- HealthKit 睡眠数据可能缺失或碎片化，需要降级逻辑。
- HRV 个体差异很大，不能跨用户套固定阈值。
- Watch 端独立计算会增加复杂度，第一版建议 iPhone 汇总。
- Liquid Glass 是 iOS 26+ 能力，需要为较低系统准备 material fallback。
