# VitalLoop Xcode App

这是当前阶段用于 Xcode 验收的最小 iOS + watchOS 工程。

## 打开方式

在 Xcode 中打开：

```sh
BodyCoachApp/BodyCoachApp.xcodeproj
```

可用 scheme：

- `BodyCoachApp`：iPhone 端首页骨架，当前产品名显示为 VitalLoop。
- `BodyCoachWatch`：Apple Watch 端数据总览 / 今日任务 / 快速记录骨架，已接入 VitalLoop 紧凑标识。
- `BodyCoachCore`：共享评分算法 Swift Package。

## 当前范围

- iPhone 首页已接入 `BodyCoachCore` 评分结果，并支持 HealthKit 摘要读取。
- HealthKit 授权改为用户点击“连接 Apple 健康”后触发，不再启动即请求权限。
- Watch 首页已改成数据优先，并通过 WatchConnectivity 接收 iPhone 摘要。
- Watch 快速记录支持压力、疲劳、饥饿回传到 iPhone。
- iPhone 已接入 SwiftData，本地保存 Watch 主观记录，并提供设置页删除本地记录。
- Watch 主观记录已进入评分输入，会影响恢复分、综合分和今日建议。
- iPhone “计划”Tab 已支持减脂目标设置，并写入 `UserGoal`。
- 今日评分刷新后会写入 `DailySummaryRecord`，减脂目标会影响解释和建议。
- GitHub Pages 隐私政策页面位于 `site/privacy-policy.html`，App 内设置页已接入预期 URL；推送到 GitHub 并启用 Pages 后才会公网生效。

## 本地验证命令

```sh
xcodebuild -project BodyCoachApp/BodyCoachApp.xcodeproj -scheme BodyCoachApp -destination 'generic/platform=iOS' -derivedDataPath BodyCoachApp/.build/iOSDerived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project BodyCoachApp/BodyCoachApp.xcodeproj -scheme BodyCoachWatch -destination 'generic/platform=watchOS' -derivedDataPath BodyCoachApp/.build/WatchDerived CODE_SIGNING_ALLOWED=NO build
```

如果你要在真机或模拟器上运行，需要在 Xcode 的 Signing & Capabilities 里选择你的 Apple Developer Team。
