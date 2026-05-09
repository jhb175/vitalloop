# VitalLoop 下一阶段开发计划

更新时间：2026-05-09 16:55

## 当前状态

已经完成：

- 英文产品名：`VitalLoop`
- Logo / wordmark SVG 品牌草案
- Xcode 工程：`BodyCoachApp/BodyCoachApp.xcodeproj`
- iPhone SwiftUI 首页骨架
- Apple Watch SwiftUI 数据总览骨架
- `BodyCoachCore` 评分核心 Swift Package
- 模拟数据到 UI 的完整展示链路

当前已经接入 HealthKit 读取骨架、个人基线、趋势展示、体重异常过滤、WatchConnectivity 今日摘要同步、Watch 快速记录回传、SwiftData 本地存储、减脂目标管理和每日摘要落库。

## 下一阶段目标

把 VitalLoop 从“模拟数据 UI 骨架”推进到“可读取真实健康数据并生成每日建议的本地 MVP”。

阶段完成标准：

- iPhone 能请求 HealthKit 权限。
- 能读取睡眠、活动能量、步数、静息心率、HRV、体重。
- 本地保存每日摘要和用户目标。
- `BodyCoachCore` 从真实摘要生成评分和建议。
- Watch 能显示 iPhone 计算后的今日摘要。
- 所有原始健康数据默认本地处理，不上传云端。

## Phase 1：品牌与工程整理

目标：

- 将 `VitalLoop` 作为工程内正式显示名。
- 把 logo 变成可复用 SwiftUI 组件。
- 保留 SVG 品牌资产用于 Figma / App Store / 后续图标导出。

已完成：

- `BodyCoachApp/Shared/VitalLoopLogoView.swift`
- iPhone 首页接入 `VitalLoopWordmark`
- Watch 顶部接入 `VitalLoopLogoMark`
- Xcode `CFBundleDisplayName` 改为 `VitalLoop`

待补：

- 创建正式 AppIcon asset catalog。
- 用当前 SVG 导出 1024px PNG 图标。
- 添加 light / dark small-size logo QA。

## Phase 2：HealthKit 数据层

目标：

- 建立 HealthKit 授权和读取服务。
- 将 HealthKit 原始数据转换成 `BodyMetrics`。

新增模块建议：

- `BodyCoachApp/Shared/Health/HealthKitClient.swift`
- `BodyCoachApp/Shared/Health/HealthMetricSnapshot.swift`
- `BodyCoachApp/Shared/Health/HealthPermissionState.swift`

第一批读取指标：

- `HKQuantityTypeIdentifier.activeEnergyBurned`
- `HKQuantityTypeIdentifier.stepCount`
- `HKCategoryTypeIdentifier.sleepAnalysis`
- `HKQuantityTypeIdentifier.restingHeartRate`
- `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`
- `HKQuantityTypeIdentifier.bodyMass`
- `HKWorkoutType`

实现要求：

- 明确缺失数据状态，不把缺失当作 0。
- 所有读取先按日聚合。
- HRV 和静息心率必须和个人基线比较，不直接用通用阈值判断好坏。
- 权限被拒绝时 UI 显示可解释状态。

当前进展：

- 已新增 `HealthKitClient` 授权与今日摘要读取骨架。
- 已新增 `HealthMetricSnapshot`，将 HealthKit 日摘要映射到 `BodyMetrics`。
- 已新增 `BodySummaryStore`，HealthKit 授权改为用户点击“连接 Apple 健康”后触发，失败或无数据时回退模拟数据。
- 已在 iPhone 首页展示 Apple 健康连接状态和数据源。
- 已新增 `BodyDashboardSnapshot`，让首页指标卡和评分输入使用同一个数据源。
- HealthKit 读取已支持单项容错、部分数据状态、无数据状态、昨晚睡眠窗口和最近体重趋势。
- 已新增 `BaselineCalculator`，用最近 28 天样本计算睡眠、HRV、静息心率个人基线，并填入评分输入。
- 已新增 `BodyDashboardTrends`，首页 4 个指标趋势图开始使用 HealthKit 7 日历史数据，并显示趋势覆盖度。
- 已新增 `WeightTrendFilter`，体重样本会过滤明显异常值后再进入最新体重、7 日变化和趋势图。
- 首页指标卡已新增逐项数据说明，明确展示缺失数据、缺失基线和当前可信度限制。
- 详细记录见 `docs/healthkit-implementation-notes.md`。

## Phase 3：本地存储与目标管理

目标：

- 保存用户目标、每日摘要、主观记录。
- 第一版目标先支持减脂。

建议先用 SwiftData：

- `UserGoal`
- `DailySummaryRecord`
- `SubjectiveCheckIn`
- `WeightEntry`

减脂目标字段：

- 当前体重
- 目标体重
- 目标日期
- 每周建议下降范围
- 运动偏好
- 饮食限制
- 工作时间 / 可运动时间

关键边界：

- 不做极端热量缺口建议。
- 不做医疗建议。
- 不根据单日体重波动大幅调整计划。

当前进展：

- 已新增 `BodyCoachLocalModels`，包含 `UserGoal`、`DailySummaryRecord`、`SubjectiveCheckIn`、`WeightEntry`。
- 已新增 `BodyCoachPersistenceStore`，作为 iPhone 端 SwiftData 读写入口。
- iPhone App 已接入 SwiftData `modelContainer`。
- Watch 主观记录同步到 iPhone 后会写入 `SubjectiveCheckIn`。
- iPhone 启动时会读取最近一次 `SubjectiveCheckIn` 并恢复到首页卡片。
- iPhone 新增“设置与隐私”Tab，展示健康数据用途、本地优先、非医疗诊断和隐私政策摘要。
- 设置页新增“删除本地记录”，可清理本机 SwiftData 数据。
- Watch 主观记录已合并进 `BodyMetrics`，会影响恢复分、综合分和今日建议。
- iPhone 新增“计划”Tab，支持设置减脂目标、当前体重、目标体重、目标日期、周下降目标、训练时长、饮食约束和工作时间。
- `UserGoal` 已接入 SwiftData 读写，App 启动后会恢复最近一次目标。
- `DailySummaryRecord` 已接入 SwiftData 写入，今日评分刷新后会按日期覆盖保存本地摘要。
- 减脂目标已传入 `BodyCoachCore`，会影响解释、运动建议时长和目标节奏建议。
- 已新增 GitHub Pages 静态站点文件 `site/privacy-policy.html`、`site/.nojekyll` 和发布 workflow。
- App 设置页已接入预期隐私政策 URL：`https://ramsey-ux.github.io/vitalloop/privacy-policy.html`。
- 已新增 `.gitignore`，排除 macOS `._*` 和 `.DS_Store` 元数据文件，避免影响 Pages 发布。

待补：

- 推送到 GitHub 后启用 Pages，并确认隐私政策公网 URL 可访问。
- 当前目录不是 git 仓库，本会话也没有可用的 `gh`，因此远端 Pages 需要推送到 GitHub 后由 workflow 生效。
- 替换隐私政策里的占位联系邮箱。

## Phase 4：评分服务工程化

目标：

- 把 `BodyCoachCore` 从纯函数 demo 升级为 App 内服务。
- 支持解释、置信度和缺失数据提示。

需要新增：

- `DailySummaryService`
- `BaselineCalculator`
- `RecommendationPlanner`

算法原则：

- 评分不是医学诊断。
- 评分是行动建议的排序器。
- 用户必须看得懂为什么今天建议轻训练、恢复或正常训练。
- 数据完整度不应长期作为健康分的一部分，后续要拆成“可信度”展示。

## Phase 5：WatchConnectivity 同步

目标：

- iPhone 计算今日摘要。
- Watch 显示摘要并支持快速记录主观状态。

同步内容：

- 今日综合分
- 状态标签
- 核心指标：活动、睡眠、恢复、步数、心率
- 今日 1-3 条建议
- Watch 快速记录：压力、疲劳、饥饿

实现要求：

- Watch 端不读取复杂历史数据。
- Watch 端优先展示“现在该看什么 / 做什么”。
- 离线时显示最近一次同步摘要和时间。

当前进展：

- 已新增 `WatchSyncPayload`，用于同步今日摘要、状态、指标、趋势和建议。
- 已新增 `WatchSyncService`，封装 `WCSession` 激活、`applicationContext` 后台同步和可达时即时消息。
- iPhone `BodySummaryStore` 会在 HealthKit 刷新成功、部分数据、无数据或回退模拟数据后推送摘要。
- Watch `WatchSummaryStore` 会接收最近一次摘要；没有收到同步时使用 sample fallback。
- Watch 数据总览和今日任务已从同步 payload 读取数据，不再只显示固定模拟内容。
- 已新增 `WatchSubjectiveCheckInPayload`，支持 Watch 回传压力、疲劳、饥饿。
- Watch 快速记录页已改成 1-10 分滑杆，保存后同步到 iPhone。
- iPhone 首页已新增最近一次 Watch 主观记录卡片。
- iPhone 已将 Watch 主观记录写入本地 SwiftData，并在启动时恢复最近一次记录。
- iPhone 会用 Watch 主观记录刷新评分和同步摘要。
- 当前只同步摘要层数据，不同步原始 HealthKit 明细。

待补：

- 真机或配对模拟器验证实时同步。
- 同步失败、过期摘要和离线状态的 UI 文案细化。

## Phase 6：UI 验收与迭代

iPhone 验收点：

- 首页是否比二级数据页更像“总览”。
- 数据表格是否清晰，不是单个指标详情堆叠。
- 深色背景上文字对比度是否足够。
- 品牌 logo 是否融入，不抢状态信息。

Watch 验收点：

- 46mm 屏幕内无溢出。
- 首屏优先看到数据，不是只看大评分。
- 复杂文本不超过 2 行。
- 快速记录 30 秒内完成。

## 近期执行顺序

1. 推送到 GitHub 并启用 Pages，确认隐私政策公网 URL 可访问。
2. 准备 App Store 隐私材料和正式联系邮箱。
3. 做配对模拟器或真机同步验收。
4. 创建 AppIcon asset catalog，并接入当前 VitalLoop logo。
5. 增强计划页：目标进度图、每周复盘和目标调整建议。
6. 将 `DailySummaryRecord` 历史接入趋势页。
