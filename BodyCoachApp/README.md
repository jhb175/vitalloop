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
- iPhone “计划”Tab 已接入目标进度、7 日复盘和目标调整建议。
- iPhone “趋势”Tab 已接入本地每日摘要历史，展示 14 日综合趋势、维度趋势和最近摘要列表。
- iOS / watchOS 已接入 VitalLoop AppIcon asset catalog；iPhone 与 Watch 图标资源分开管理，避免 Xcode 资源警告。
- Watch app 已作为 `Embed Watch Content` 嵌入 iPhone target；配对模拟器验证时，iPhone 端 `WCSession` 可识别 Watch app 已安装并可达。
- iPhone 设置页已新增 Apple Watch 同步诊断，可查看激活状态、Watch app 安装状态、可达状态和最近同步事件。
- Watch 首页右上角会显示最近一次同步时间；未收到 iPhone 摘要时才显示同步事件 / 等待状态。
- GitHub Pages 隐私政策页面位于 `site/privacy-policy.html`，App 内设置页已接入预期 URL；推送到 GitHub 并启用 Pages 后才会公网生效。

## 本地验证命令

```sh
xcodebuild -project BodyCoachApp/BodyCoachApp.xcodeproj -scheme BodyCoachApp -destination 'generic/platform=iOS' -derivedDataPath BodyCoachApp/.build/iOSDerived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project BodyCoachApp/BodyCoachApp.xcodeproj -scheme BodyCoachWatch -destination 'generic/platform=watchOS' -derivedDataPath BodyCoachApp/.build/WatchDerived CODE_SIGNING_ALLOWED=NO build
xcodebuild test -scheme BodyCoachCore -destination 'platform=macOS'
```

## 构建缓存清理

本项目的体积主要来自 Xcode / SwiftPM 生成物，而不是 Markdown 文档或资源文件。`xcodebuild` 使用 `-derivedDataPath BodyCoachApp/.build/...` 后，会在仓库内保存 iOS、watchOS、Swift module、asset catalog、索引和中间产物；多次用不同 derived data 目录构建时会累积到 1GB 以上。

手动预览可清理内容：

```sh
scripts/clean-build-cache.sh
```

执行清理：

```sh
scripts/clean-build-cache.sh --execute
```

只清理超过 7 天未修改的生成目录：

```sh
scripts/clean-build-cache.sh --older-than 7 --execute
```

如果需要定期自动清理，可以把下面命令加入本机 cron 或 launchd，每周执行一次：

```sh
/Users/jihongbin/Desktop/codex项目/applewatch好习惯/scripts/clean-build-cache.sh --older-than 7 --execute
```

## 配对模拟器同步验收

推荐优先用 Xcode 运行 `BodyCoachApp` 到已配对的 iPhone 模拟器，再运行 `BodyCoachWatch` 到对应 Apple Watch 模拟器。

命令行烟测时需要先确认 iPhone / Watch 已配对并处于 connected 状态：

```sh
xcrun simctl list pairs
```

本次已验证的安装顺序：

```sh
xcrun simctl install <iPhone device id> BodyCoachApp.app
xcrun simctl install <Watch device id> BodyCoachWatch.app
xcrun simctl launch <iPhone device id> com.ramsey.bodycoach
xcrun simctl launch <Watch device id> com.ramsey.bodycoach.watchkitapp
```

验收标准：

- iPhone 日志中 `WCSession` 显示 `appInstalled: YES`。
- 两端启动后 iPhone 日志显示 `reachable: YES`。
- Watch 首页右上角显示同步时间，而不是“预览”。
- Watch 综合分与 iPhone 发出的摘要一致。

如果你要在真机或模拟器上运行，需要在 Xcode 的 Signing & Capabilities 里选择你的 Apple Developer Team。
