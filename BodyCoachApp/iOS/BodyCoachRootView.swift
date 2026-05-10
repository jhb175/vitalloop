import BodyCoachCore
import SwiftData
import SwiftUI

struct BodyCoachRootView: View {
    @Environment(\.modelContext) private var modelContext

    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore
    let reminderStore: BodyCoachReminderStore

    @State private var selectedTab: BodyCoachTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayDashboardView(
                store: store,
                persistenceStore: persistenceStore
            )
                .tabItem {
                    Label("今日", systemImage: "heart.fill")
                }
                .tag(BodyCoachTab.today)

            TrendHistoryView(persistenceStore: persistenceStore)
                .tabItem {
                    Label("趋势", systemImage: "waveform.path.ecg")
                }
                .tag(BodyCoachTab.trends)

            GoalPlanView(store: store, persistenceStore: persistenceStore)
                .tabItem {
                    Label("计划", systemImage: "checklist")
                }
                .tag(BodyCoachTab.plan)

            CheckInLogView(store: store, persistenceStore: persistenceStore)
                .tabItem {
                    Label("记录", systemImage: "plus")
                }
                .tag(BodyCoachTab.logs)

            SettingsPrivacyView(store: store, persistenceStore: persistenceStore, reminderStore: reminderStore)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(BodyCoachTab.settings)
        }
        .tint(Color.bcMint)
        .task {
            persistenceStore.configure(modelContext: modelContext)
            store.configurePersistence(persistenceStore)
            store.activateWatchSync()
            reminderStore.activateNotificationRouting()
            await store.refreshAppleHealthIfPreviouslyConnected()
        }
        .onChange(of: reminderStore.pendingRouteRequest) { _, request in
            handleReminderRouteRequest(request)
        }
    }

    private func handleReminderRouteRequest(_ request: BodyCoachReminderRouteRequest?) {
        guard let request else {
            return
        }

        switch request.route {
        case .weight, .meal:
            selectedTab = .logs
        case .sleep:
            selectedTab = .today
        }

        reminderStore.consumePendingRouteRequest(id: request.id)
    }
}

private enum BodyCoachTab: Hashable {
    case today
    case trends
    case plan
    case logs
    case settings
}

private struct TodayDashboardView: View {
    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    HeroStatusCard(summary: store.summary, dataSource: store.dataSource)
                    SubjectiveCheckInCard(checkIn: store.latestSubjectiveCheckIn)

                    Text("今日监测")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    RhythmCard()

                    LazyVGrid(columns: columns, spacing: 12) {
                        MetricTile(title: "活动能量", display: store.dashboardSnapshot.activeEnergyDisplay, color: .bcMint, trend: store.dashboardTrends.activeEnergy)
                        MetricTile(title: "睡眠", display: store.dashboardSnapshot.sleepDisplay, color: .bcAmber, trend: store.dashboardTrends.sleep)
                        MetricTile(title: "恢复信号", display: store.dashboardSnapshot.recoveryDisplay, color: .bcBlue, trend: store.dashboardTrends.recovery)
                        MetricTile(title: "体重趋势", display: store.dashboardSnapshot.weightTrendDisplay, color: .bcViolet, trend: store.dashboardTrends.weight)
                    }

                    InsightTable(summary: store.summary, dashboardSnapshot: store.dashboardSnapshot)
                    RecommendationSection(recommendations: store.summary.recommendations)
                    TodayPlanActionSection(actions: todayPlanActions)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(BodyCoachBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var todayPlanActions: [String] {
        PlanActionGenerator.actions(
            goal: persistenceStore.currentGoal,
            records: persistenceStore.recentDailySummaries,
            preferredWorkoutMinutes: persistenceStore.currentGoal?.preferredWorkoutMinutes
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.bcInk)
                Text("身体信号 · 每日决策")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.bcSoft)
            }

            Spacer()

            Text(store.dataSource.displayName)
                .font(.caption.weight(.bold))
                .foregroundStyle(store.dataSource == .healthKit ? Color.bcMint : Color.bcBlue)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background((store.dataSource == .healthKit ? Color.bcMint : Color.bcBlue).opacity(0.14), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke((store.dataSource == .healthKit ? Color.bcMint : Color.bcBlue).opacity(0.28), lineWidth: 1)
                }
        }
    }
}

private struct FirstRunGuideCard: View {
    let permissionState: HealthPermissionState
    let subjectiveCheckIn: WatchSubjectiveCheckInPayload?
    let currentGoal: UserGoal?
    let recentDailySummaries: [DailySummaryRecord]
    let connectAppleHealth: () async -> Void

    @State private var isConnecting = false

    private var steps: [FirstRunGuideStep] {
        [
            FirstRunGuideStep(
                title: "连接 Apple 健康",
                detail: healthStepDetail,
                iconName: "heart.text.square.fill",
                isComplete: isHealthConnected,
                color: isHealthConnected ? .bcMint : .bcAmber
            ),
            FirstRunGuideStep(
                title: "同步 Apple Watch",
                detail: watchStepDetail,
                iconName: "applewatch",
                isComplete: subjectiveCheckIn != nil,
                color: subjectiveCheckIn == nil ? .bcBlue : .bcMint
            ),
            FirstRunGuideStep(
                title: "设置目标",
                detail: goalStepDetail,
                iconName: "target",
                isComplete: currentGoal != nil,
                color: currentGoal == nil ? .bcViolet : .bcMint
            ),
            FirstRunGuideStep(
                title: "保留每日摘要",
                detail: summaryStepDetail,
                iconName: "calendar.badge.clock",
                isComplete: !recentDailySummaries.isEmpty,
                color: recentDailySummaries.isEmpty ? .bcMuted : .bcMint
            )
        ]
    }

    private var completedStepCount: Int {
        steps.filter(\.isComplete).count
    }

    private var shouldShowCard: Bool {
        completedStepCount < steps.count
    }

    var body: some View {
        if shouldShowCard {
            GlassCard(cornerRadius: 24, padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("首次设置")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.bcInk)
                            Text("\(completedStepCount)/\(steps.count) 已完成")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.bcSoft)
                        }

                        Spacer()

                        Text(firstActionLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(firstActionColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(firstActionColor.opacity(0.14), in: Capsule())
                    }

                    VStack(spacing: 8) {
                        ForEach(steps) { step in
                            FirstRunGuideStepRow(step: step)
                        }
                    }

                    if showsHealthAction {
                        Button {
                            Task {
                                isConnecting = true
                                await connectAppleHealth()
                                isConnecting = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "heart.text.square")
                                Text(isConnecting ? "读取中" : "连接 Apple 健康")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.bcMint.opacity(0.16), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.bcMint.opacity(0.4), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isConnecting || permissionState == .requesting || permissionState == .refreshing)
                    }
                }
            }
        }
    }

    private var isHealthConnected: Bool {
        switch permissionState {
        case .authorized, .partialData:
            return true
        case .notRequested, .requesting, .refreshing, .unavailable, .denied, .noData, .readFailed:
            return false
        }
    }

    private var showsHealthAction: Bool {
        switch permissionState {
        case .notRequested, .denied, .noData, .readFailed:
            return true
        case .authorized, .partialData, .requesting, .refreshing, .unavailable:
            return false
        }
    }

    private var firstActionLabel: String {
        guard let firstIncomplete = steps.first(where: { !$0.isComplete }) else {
            return "已完成"
        }

        return firstIncomplete.title
    }

    private var firstActionColor: Color {
        steps.first(where: { !$0.isComplete })?.color ?? .bcMint
    }

    private var healthStepDetail: String {
        switch permissionState {
        case .authorized:
            return "今日健康摘要已接入。"
        case .partialData:
            return "已接入部分信号，缺失项会降低可信度。"
        case .requesting:
            return "正在等待系统权限返回。"
        case .refreshing:
            return "正在自动读取 Apple 健康。"
        case .noData:
            return "已授权但今天暂无样本，佩戴 Watch 或添加样本后重读。"
        case .denied:
            return "需要在系统设置中允许读取健康数据。"
        case .readFailed:
            return "读取失败，检查权限后重新读取。"
        case .unavailable:
            return "当前设备不支持 HealthKit。"
        case .notRequested:
            return "先授权读取摘要，评分会从模拟数据切换为本机数据。"
        }
    }

    private var watchStepDetail: String {
        guard let subjectiveCheckIn else {
            return "在 Watch 快速记录压力、疲劳、饥饿后回到 iPhone 查看。"
        }

        return "\(subjectiveCheckIn.capturedAt.formatted(date: .omitted, time: .shortened)) 已收到 Watch 记录。"
    }

    private var goalStepDetail: String {
        guard let currentGoal else {
            return "到计划页填写当前体重、目标体重和目标日期。"
        }

        return "\(currentGoal.goalType.displayName)目标已保存。"
    }

    private var summaryStepDetail: String {
        if recentDailySummaries.isEmpty {
            return "首次刷新后会保存每日摘要，用于趋势和 7 日复盘。"
        }

        return "已有 \(recentDailySummaries.count) 条摘要用于趋势复盘。"
    }
}

private struct FirstRunGuideStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let iconName: String
    let isComplete: Bool
    let color: Color
}

private struct FirstRunGuideStepRow: View {
    let step: FirstRunGuideStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : step.iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(step.color)
                .frame(width: 26, height: 26)
                .background(step.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(step.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text(step.isComplete ? "完成" : "待办")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(step.color)
                }

                Text(step.detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SubjectiveCheckInCard: View {
    let checkIn: WatchSubjectiveCheckInPayload?

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: checkIn == nil ? "applewatch" : "waveform.path.ecg")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(statusColor)
                    .frame(width: 38, height: 38)
                    .background(statusColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Spacer()
                        if let checkIn {
                            Text(checkIn.statusLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(statusColor)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(statusColor.opacity(0.13), in: Capsule())
                        }
                    }

                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .lineLimit(2)
                }
            }
        }
    }

    private var title: String {
        checkIn == nil ? "主观记录未同步" : "Watch 主观记录"
    }

    private var detail: String {
        guard let checkIn else {
            return "在 Apple Watch 快速记录压力、疲劳、饥饿后，会同步到这里。"
        }

        return "\(checkIn.compactSummary)，\(checkIn.capturedAt.formatted(date: .omitted, time: .shortened)) 来自 \(checkIn.source)。"
    }

    private var statusColor: Color {
        guard let checkIn else {
            return .bcMuted
        }

        switch checkIn.averageLoad {
        case 0 ..< 4:
            return .bcMint
        case 4 ..< 7:
            return .bcAmber
        default:
            return .bcViolet
        }
    }
}

private struct HeroStatusCard: View {
    let summary: DailyBodySummary
    let dataSource: BodySummaryDataSource

    var body: some View {
        GlassCard(cornerRadius: 32) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    ScoreDial(score: summary.score.overall, size: 132)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(summary.score.status.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcMint)
                        Text(summary.score.status.headline)
                            .font(.system(size: 27, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.bcInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(summary.score.conciseExplanation)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.bcSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    StatusChip(title: "可训练", color: .bcMint)
                    StatusChip(title: "需恢复", color: .bcAmber)
                    StatusChip(title: dataSource.displayName, color: .bcBlue)
                }
            }
        }
    }
}

private struct HealthConnectionCard: View {
    let permissionState: HealthPermissionState
    let dataSource: BodySummaryDataSource
    let lastUpdated: Date?
    let lastHealthReadError: String?
    let connectAppleHealth: () async -> Void
    let refreshAppleHealth: () async -> Void

    @State private var isConnecting = false

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(iconColor)
                        .frame(width: 38, height: 38)
                        .background(iconColor.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(permissionState.displayTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Text(detailText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.bcSoft)
                            .lineLimit(3)
                    }

                    Spacer()

                    Text(dataSource.displayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(iconColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(iconColor.opacity(0.12), in: Capsule())
                }

                if showsConnectButton {
                    Button {
                        Task {
                            isConnecting = true
                            if shouldRequestAuthorization {
                                await connectAppleHealth()
                            } else {
                                await refreshAppleHealth()
                            }
                            isConnecting = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .font(.caption.weight(.bold))
                            Text(connectButtonTitle)
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Color.bcInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.bcMint.opacity(0.16), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.bcMint.opacity(0.4), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnecting || permissionState == .requesting || permissionState == .refreshing)
                }
            }
        }
    }

    private var shouldRequestAuthorization: Bool {
        switch permissionState {
        case .notRequested, .denied:
            return true
        case .authorized, .partialData, .noData, .readFailed, .requesting, .refreshing, .unavailable:
            return false
        }
    }

    private var showsConnectButton: Bool {
        switch permissionState {
        case .notRequested, .authorized, .partialData, .noData, .readFailed, .denied:
            return true
        case .unavailable, .requesting, .refreshing:
            return false
        }
    }

    private var connectButtonTitle: String {
        if isConnecting {
            return "读取中"
        }

        switch permissionState {
        case .authorized, .partialData, .noData, .readFailed:
            return "重新读取 Apple 健康"
        case .denied, .notRequested:
            return "连接 Apple 健康"
        case .requesting, .refreshing:
            return "读取中"
        case .unavailable:
            return "不可用"
        }
    }

    private var iconName: String {
        switch permissionState {
        case .authorized:
            return "heart.text.square.fill"
        case .requesting, .refreshing:
            return "arrow.triangle.2.circlepath"
        case .unavailable, .denied, .noData, .readFailed:
            return "exclamationmark.shield.fill"
        case .partialData:
            return "heart.text.square"
        case .notRequested:
            return "heart.text.square"
        }
    }

    private var iconColor: Color {
        switch permissionState {
        case .authorized:
            return .bcMint
        case .requesting, .refreshing:
            return .bcBlue
        case .unavailable, .denied, .noData, .readFailed, .partialData:
            return .bcAmber
        case .notRequested:
            return .bcMuted
        }
    }

    private var detailText: String {
        switch permissionState {
        case .authorized:
            if let lastUpdated {
                return "已读取今日健康摘要，更新时间 \(lastUpdated.formatted(date: .omitted, time: .shortened))。"
            }
            return "已授权，正在准备今日健康摘要。"
        case let .partialData(available, expected):
            return "已读取 \(available)/\(expected) 类信号，缺失部分会降低可信度。"
        case .noData:
            return "已连接过 Apple 健康，但今天没有读到健康样本。佩戴 Apple Watch 产生睡眠、心率或活动数据后再刷新。"
        case let .readFailed(message):
            let detail = lastHealthReadError ?? message
            return "读取健康数据时发生错误：\(detail)。请确认健康权限后重试。"
        case .requesting:
            return "正在向系统请求读取活动、睡眠、心率、HRV 和体重。"
        case .refreshing:
            return "已连接过 Apple 健康，正在自动刷新今日摘要。"
        case .unavailable:
            return "当前设备无法读取 HealthKit，先使用模拟数据继续预览。"
        case let .denied(message):
            let detail = lastHealthReadError ?? message
            return "系统未授予健康读取权限：\(detail)。请在设置中允许 VitalLoop 读取健康数据。"
        case .notRequested:
            return "连接后会本地读取活动、睡眠、心率、HRV 和体重摘要；原始数据默认不上传。"
        }
    }
}

private struct HealthDataCoverageCard: View {
    let snapshot: BodyDashboardSnapshot
    let permissionState: HealthPermissionState
    let dataSource: BodySummaryDataSource

    private var items: [HealthSignalCoverageItem] {
        [
            HealthSignalCoverageItem(
                title: "活动能量",
                isAvailable: isHealthDataAvailable(snapshot.activeEnergyKcal != nil),
                availableDetail: availableActiveEnergyDetail,
                missingDetail: "影响活动分。请确认健康权限里的活动能量已开启。"
            ),
            HealthSignalCoverageItem(
                title: "睡眠",
                isAvailable: isHealthDataAvailable(snapshot.sleepMinutes != nil),
                availableDetail: snapshot.sleepDisplay.note,
                missingDetail: "影响睡眠分。需要佩戴 Apple Watch 入睡，或开启睡眠专注/睡眠记录。"
            ),
            HealthSignalCoverageItem(
                title: "HRV",
                isAvailable: isHealthDataAvailable(snapshot.hrvMs != nil),
                availableDetail: availableHRVDetail,
                missingDetail: "影响恢复分。HRV 通常由 Apple Watch 在睡眠或静息时自动写入。"
            ),
            HealthSignalCoverageItem(
                title: "静息心率",
                isAvailable: isHealthDataAvailable(snapshot.restingHeartRateBpm != nil),
                availableDetail: availableRestingHeartRateDetail,
                missingDetail: "影响恢复分。请确认 Apple Watch 佩戴和心率权限。"
            ),
            HealthSignalCoverageItem(
                title: "体重",
                isAvailable: isHealthDataAvailable(snapshot.weightKg != nil),
                availableDetail: snapshot.weightTrendDisplay.note,
                missingDetail: "影响体重趋势。可在记录页手动补记，或连接支持 HealthKit 的体重秤。"
            ),
            HealthSignalCoverageItem(
                title: "锻炼",
                isAvailable: isHealthDataAvailable(snapshot.workoutMinutes != nil),
                availableDetail: availableWorkoutDetail,
                missingDetail: "影响活动解释。今日未记录锻炼时仍会参考活动能量和步数。"
            )
        ]
    }

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("健康数据覆盖")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text(coverageLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(coverageColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(coverageColor.opacity(0.14), in: Capsule())
                }

                Text(coverageDetail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(items) { item in
                        HealthSignalCoverageRow(item: item)
                    }
                }
            }
        }
    }

    private var coverageLabel: String {
        guard dataSource == .healthKit else {
            return "待连接"
        }

        return "\(snapshot.availableFieldCount)/\(snapshot.expectedFieldCount)"
    }

    private var coverageColor: Color {
        switch permissionState {
        case .authorized:
            return .bcMint
        case .partialData, .noData, .readFailed:
            return .bcAmber
        case .requesting, .refreshing:
            return .bcBlue
        default:
            return .bcMuted
        }
    }

    private var coverageDetail: String {
        switch dataSource {
        case .healthKit:
            if missingCount == 0 {
                return "今日核心信号已接入，评分可信度较高。"
            }

            return "缺少 \(missingCount) 类信号，评分会自动降低可信度，并在建议中避开强判断。"
        case .sample:
            return "当前显示模拟数据。连接 Apple 健康后，这里会显示真实缺失原因。"
        }
    }

    private func isHealthDataAvailable(_ isAvailable: Bool) -> Bool {
        dataSource == .healthKit && isAvailable
    }

    private var missingCount: Int {
        items.filter { !$0.isAvailable }.count
    }

    private var availableActiveEnergyDetail: String {
        guard let activeEnergy = snapshot.activeEnergyKcal else {
            return ""
        }

        if let steps = snapshot.stepCount {
            return "\(activeEnergy.roundedString) kcal，步数 \(steps.roundedString)。"
        }

        return "\(activeEnergy.roundedString) kcal，缺少步数辅助解释。"
    }

    private var availableHRVDetail: String {
        guard let hrv = snapshot.hrvMs else {
            return ""
        }

        if let baseline = snapshot.hrvBaselineMs {
            return "\(hrv.roundedString) ms，基线 \(baseline.roundedString) ms。"
        }

        return "\(hrv.roundedString) ms，暂缺 28 天基线。"
    }

    private var availableRestingHeartRateDetail: String {
        guard let restingHeartRate = snapshot.restingHeartRateBpm else {
            return ""
        }

        if let baseline = snapshot.restingHeartRateBaselineBpm {
            return "\(restingHeartRate.roundedString) bpm，基线 \(baseline.roundedString) bpm。"
        }

        return "\(restingHeartRate.roundedString) bpm，暂缺 28 天基线。"
    }

    private var availableWorkoutDetail: String {
        guard let workoutMinutes = snapshot.workoutMinutes else {
            return ""
        }

        return "\(workoutMinutes.roundedString) 分钟锻炼。"
    }
}

private struct HealthSignalCoverageItem: Identifiable {
    let id = UUID()
    let title: String
    let isAvailable: Bool
    let availableDetail: String
    let missingDetail: String

    var detail: String {
        isAvailable ? availableDetail : missingDetail
    }
}

private struct HealthSignalCoverageRow: View {
    let item: HealthSignalCoverageItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.isAvailable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(item.isAvailable ? Color.bcMint : Color.bcAmber)
                .frame(width: 26, height: 26)
                .background((item.isAvailable ? Color.bcMint : Color.bcAmber).opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text(item.isAvailable ? "可用" : "缺失")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(item.isAvailable ? Color.bcMint : Color.bcAmber)
                }

                Text(item.detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SettingsPrivacyView: View {
    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore
    let reminderStore: BodyCoachReminderStore

    @State private var showsDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header

                    SettingsNavigationCard(
                        iconName: "lock.shield.fill",
                        title: "数据与授权",
                        detail: "管理 Apple 健康、Apple Watch、通知授权和数据覆盖诊断。",
                        color: .bcMint
                    ) {
                        DataAuthorizationSettingsView(
                            store: store,
                            persistenceStore: persistenceStore,
                            reminderStore: reminderStore
                        )
                    }

                    SettingsSection(title: "通知提醒") {
                        ReminderSettingsRow(
                            iconName: "scalemass.fill",
                            title: "体重记录",
                            detail: "每天同一时间称重，体重趋势会更稳定。",
                            isEnabled: reminderStore.isWeightReminderEnabled,
                            time: reminderStore.weightReminderTime,
                            color: .bcMint,
                            setEnabled: reminderStore.setWeightReminderEnabled,
                            setTime: reminderStore.updateWeightReminderTime
                        )
                        ReminderSettingsRow(
                            iconName: "bed.double.fill",
                            title: "睡眠准备",
                            detail: "睡前提醒用于降低晚间干扰，帮助恢复分更可靠。",
                            isEnabled: reminderStore.isSleepReminderEnabled,
                            time: reminderStore.sleepReminderTime,
                            color: .bcBlue,
                            setEnabled: reminderStore.setSleepReminderEnabled,
                            setTime: reminderStore.updateSleepReminderTime
                        )
                        ReminderSettingsRow(
                            iconName: "fork.knife",
                            title: "饮食简记",
                            detail: "晚间补一条饮食记录，便于周复盘发现模式。",
                            isEnabled: reminderStore.isMealReminderEnabled,
                            time: reminderStore.mealReminderTime,
                            color: .bcAmber,
                            setEnabled: reminderStore.setMealReminderEnabled,
                            setTime: reminderStore.updateMealReminderTime
                        )
                    }

                    SettingsNavigationCard(
                        iconName: "ellipsis.circle.fill",
                        title: "更多与支持",
                        detail: "隐私说明、本地数据、Beta 反馈和上架材料。",
                        color: .bcBlue
                    ) {
                        MoreSupportSettingsView(
                            persistenceStore: persistenceStore,
                            showsDeleteConfirmation: $showsDeleteConfirmation
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
            .background(BodyCoachBackground())
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("删除本地记录？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                Button("删除本地记录", role: .destructive) {
                    store.clearLocalData()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这会删除 VitalLoop 保存在本机的目标、摘要、主观记录和体重记录。Apple 健康中的原始数据不会被删除。")
            }
        }
        .task {
            reminderStore.refreshAuthorizationStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            VitalLoopWordmark()
            Text("设置与隐私")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
            Text("管理健康数据使用、本地记录和上架前需要明确展示的隐私说明。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.bcSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsNavigationCard<Destination: View>: View {
    let iconName: String
    let title: String
    let detail: String
    let color: Color
    let destination: Destination

    init(iconName: String, title: String, detail: String, color: Color, @ViewBuilder destination: () -> Destination) {
        self.iconName = iconName
        self.title = title
        self.detail = detail
        self.color = color
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            GlassCard(cornerRadius: 24, padding: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 38, height: 38)
                        .background(color.opacity(0.13), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Text(detail)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.bcSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color.opacity(0.9))
                        .padding(.top, 10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceReadinessState {
    let badge: String
    let detail: String
    let color: Color
}

private struct DataAuthorizationSettingsView: View {
    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore
    let reminderStore: BodyCoachReminderStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                pageHeader

                HealthConnectionCard(
                    permissionState: store.permissionState,
                    dataSource: store.dataSource,
                    lastUpdated: store.lastUpdated,
                    lastHealthReadError: store.lastHealthReadError,
                    connectAppleHealth: {
                        await store.connectAppleHealth()
                    },
                    refreshAppleHealth: {
                        await store.refreshAppleHealth()
                    }
                )

                FirstRunGuideCard(
                    permissionState: store.permissionState,
                    subjectiveCheckIn: store.latestSubjectiveCheckIn,
                    currentGoal: persistenceStore.currentGoal,
                    recentDailySummaries: persistenceStore.recentDailySummaries,
                    connectAppleHealth: {
                        await store.connectAppleHealth()
                    }
                )

                HealthDataCoverageCard(
                    snapshot: store.dashboardSnapshot,
                    permissionState: store.permissionState,
                    dataSource: store.dataSource
                )

                SettingsSection(title: "接口状态") {
                    DeviceReadinessRow(
                        iconName: "heart.text.square.fill",
                        title: "Apple 健康",
                        badge: healthReadiness.badge,
                        detail: healthReadiness.detail,
                        color: healthReadiness.color
                    )
                    DeviceReadinessRow(
                        iconName: "applewatch",
                        title: "Watch App",
                        badge: watchInstallReadiness.badge,
                        detail: watchInstallReadiness.detail,
                        color: watchInstallReadiness.color
                    )
                    DeviceReadinessRow(
                        iconName: "antenna.radiowaves.left.and.right",
                        title: "连接通道",
                        badge: watchReachabilityReadiness.badge,
                        detail: watchReachabilityReadiness.detail,
                        color: watchReachabilityReadiness.color
                    )
                    DeviceReadinessRow(
                        iconName: "arrow.left.arrow.right.circle.fill",
                        title: "同步回传",
                        badge: syncRoundTripReadiness.badge,
                        detail: syncRoundTripReadiness.detail,
                        color: syncRoundTripReadiness.color
                    )
                    DeviceReadinessRow(
                        iconName: "bolt.horizontal.circle.fill",
                        title: "即时测试",
                        badge: watchConnectivityTestReadiness.badge,
                        detail: watchConnectivityTestReadiness.detail,
                        color: watchConnectivityTestReadiness.color
                    )
                    SettingsActionRow(
                        iconName: "bolt.horizontal.circle.fill",
                        title: "发送 Watch 连接测试",
                        detail: "打开两端 App 后，用这一步确认即时通信链路。",
                        color: .bcMint
                    ) {
                        store.runWatchConnectivityTest()
                    }
                }

                SettingsSection(title: "通知授权") {
                    SettingsInfoRow(
                        iconName: "bell.badge.fill",
                        title: "提醒状态",
                        detail: notificationStatusText,
                        color: notificationStatusColor
                    )

                    if let lastReminderOpenText {
                        SettingsInfoRow(
                            iconName: "arrowshape.turn.up.right.fill",
                            title: "最近跳转",
                            detail: lastReminderOpenText,
                            color: .bcBlue
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 96)
        }
        .background(BodyCoachBackground())
        .navigationTitle("数据与授权")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            reminderStore.refreshAuthorizationStatus()
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("数据与授权")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
            Text("集中管理 HealthKit、Apple Watch、通知权限和数据覆盖诊断。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.bcSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var healthReadiness: DeviceReadinessState {
        switch store.permissionState {
        case .authorized:
            return DeviceReadinessState(
                badge: "通过",
                detail: lastUpdatedDetail(prefix: "已读取 Apple 健康摘要"),
                color: .bcMint
            )
        case let .partialData(available, expected):
            return DeviceReadinessState(
                badge: "部分",
                detail: "已读取 \(available)/\(expected) 类健康信号，缺失项会降低评分可信度。请在系统健康权限里确认睡眠、心率、HRV、体重和活动都已允许读取。",
                color: .bcAmber
            )
        case .requesting:
            return DeviceReadinessState(
                badge: "请求中",
                detail: "正在等待系统健康权限面板返回结果。",
                color: .bcBlue
            )
        case .refreshing:
            return DeviceReadinessState(
                badge: "读取中",
                detail: "已连接过 Apple 健康，正在自动读取今日摘要。",
                color: .bcBlue
            )
        case .noData:
            return DeviceReadinessState(
                badge: "无数据",
                detail: "权限流程可用，但今日没有读到健康样本。真机验收时先佩戴 Apple Watch 产生睡眠、心率或活动数据。",
                color: .bcAmber
            )
        case let .readFailed(message):
            return DeviceReadinessState(
                badge: "读取失败",
                detail: "HealthKit 返回错误：\(message)。请确认系统健康权限和设备数据后重试。",
                color: .bcAmber
            )
        case let .denied(message):
            return DeviceReadinessState(
                badge: "未授权",
                detail: "需要在系统设置里允许 VitalLoop 读取健康数据，再回到本页重新读取 Apple 健康。系统返回：\(message)",
                color: .bcAmber
            )
        case .unavailable:
            return DeviceReadinessState(
                badge: "不支持",
                detail: "当前设备不支持 HealthKit，只能用模拟数据做界面预览。",
                color: .bcMuted
            )
        case .notRequested:
            return DeviceReadinessState(
                badge: "待连接",
                detail: "在本页点击连接 Apple 健康，授权后这里会显示读取结果和更新时间。",
                color: .bcMuted
            )
        }
    }

    private var watchInstallReadiness: DeviceReadinessState {
        let diagnostics = store.watchSyncDiagnostics
        if diagnostics.isCounterpartInstalled {
            return DeviceReadinessState(
                badge: "已安装",
                detail: "iPhone 已识别配对 Apple Watch 上安装了 VitalLoop Watch app。",
                color: .bcMint
            )
        }

        return DeviceReadinessState(
            badge: "未安装",
            detail: "需要通过 Xcode 或 TestFlight 同时安装 iPhone app 与 Watch app，并确认两台设备已配对。",
            color: .bcAmber
        )
    }

    private var watchReachabilityReadiness: DeviceReadinessState {
        let diagnostics = store.watchSyncDiagnostics
        if diagnostics.activationState == "已激活", diagnostics.isReachable {
            return DeviceReadinessState(
                badge: "可达",
                detail: "WatchConnectivity 已激活且当前可达，可以进行即时摘要同步和主观记录回传。",
                color: .bcMint
            )
        }

        if diagnostics.activationState == "已激活" {
            return DeviceReadinessState(
                badge: "后台",
                detail: "WatchConnectivity 已激活但当前不可达。打开两端 App 到前台，或等待系统通过后台队列同步。",
                color: .bcBlue
            )
        }

        return DeviceReadinessState(
            badge: diagnostics.activationState,
            detail: "打开 iPhone 和 Apple Watch 端 App，等待 WatchConnectivity 完成激活。",
            color: .bcAmber
        )
    }

    private var syncRoundTripReadiness: DeviceReadinessState {
        let diagnostics = store.watchSyncDiagnostics
        if let error = diagnostics.lastError, !error.isEmpty {
            return DeviceReadinessState(
                badge: "异常",
                detail: "\(diagnostics.lastEvent)：\(error)",
                color: .bcAmber
            )
        }

        if let receivedAt = diagnostics.lastCheckInReceivedAt {
            return DeviceReadinessState(
                badge: "已回传",
                detail: "iPhone 已在 \(receivedAt.formatted(date: .abbreviated, time: .shortened)) 收到 Watch 主观记录。",
                color: .bcMint
            )
        }

        if let acknowledgedAt = diagnostics.lastCheckInAcknowledgedAt {
            return DeviceReadinessState(
                badge: "已确认",
                detail: "最近一次主观记录在 \(acknowledgedAt.formatted(date: .abbreviated, time: .shortened)) 得到对端确认。",
                color: .bcMint
            )
        }

        if let receivedAt = diagnostics.lastReceivedAt {
            return DeviceReadinessState(
                badge: "已同步",
                detail: "最近一次摘要同步时间 \(receivedAt.formatted(date: .abbreviated, time: .shortened))。下一步在 Watch 上保存一条主观记录验证回传。",
                color: .bcBlue
            )
        }

        return DeviceReadinessState(
            badge: "待验证",
            detail: "先打开两端 App，再在 Watch 快速记录压力、疲劳和饥饿，确认 iPhone 记录页出现新记录。",
            color: .bcMuted
        )
    }

    private var watchConnectivityTestReadiness: DeviceReadinessState {
        let diagnostics = store.watchSyncDiagnostics
        if let acknowledgedAt = diagnostics.lastConnectivityTestAcknowledgedAt {
            let latency = diagnostics.lastConnectivityTestRoundTripMs.map { "，往返 \($0)ms" } ?? ""
            return DeviceReadinessState(
                badge: "通过",
                detail: "Watch 已在 \(acknowledgedAt.formatted(date: .abbreviated, time: .shortened)) 确认即时连接测试\(latency)。",
                color: .bcMint
            )
        }

        if let sentAt = diagnostics.lastConnectivityTestSentAt {
            return DeviceReadinessState(
                badge: "已发送",
                detail: "已在 \(sentAt.formatted(date: .abbreviated, time: .shortened)) 发送测试，等待 Watch 回复。保持两端 App 在前台。",
                color: .bcBlue
            )
        }

        return DeviceReadinessState(
            badge: "未测试",
            detail: "打开 iPhone 与 Watch 端 App 后，点击下方按钮验证即时双向通信。",
            color: .bcMuted
        )
    }

    private func lastUpdatedDetail(prefix: String) -> String {
        guard let lastUpdated = store.lastUpdated else {
            return "\(prefix)，等待下一次刷新更新时间。当前数据来源：\(store.dataSource.displayName)。"
        }

        return "\(prefix)，更新时间 \(lastUpdated.formatted(date: .abbreviated, time: .shortened))。当前数据来源：\(store.dataSource.displayName)。"
    }

    private var notificationStatusText: String {
        if let error = reminderStore.lastReminderError {
            return "\(reminderStore.enabledReminderSummary)。最近调度失败：\(error)"
        }

        let scheduleText = reminderStore.pendingNotificationCount > 0
            ? "系统已排队 \(reminderStore.pendingNotificationCount) 个每日提醒"
            : "系统暂无已排队提醒"

        switch reminderStore.authorizationStatus {
        case .notDetermined:
            return "\(reminderStore.enabledReminderSummary)。开启任一提醒后，系统会请求本地通知权限。"
        case .denied:
            return "\(reminderStore.enabledReminderSummary)。系统通知权限未开启，需要到设置中允许 VitalLoop 通知。"
        case .authorized, .provisional, .ephemeral:
            return "\(reminderStore.enabledReminderSummary)。已允许本地通知，\(scheduleText)。点击体重或饮食提醒会进入记录页，点击睡眠提醒会进入今日页。"
        @unknown default:
            return "\(reminderStore.enabledReminderSummary)。通知权限状态未知。"
        }
    }

    private var notificationStatusColor: Color {
        switch reminderStore.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .bcMint
        case .denied:
            return .bcAmber
        default:
            return .bcSoft
        }
    }

    private var lastReminderOpenText: String? {
        guard let route = reminderStore.lastOpenedReminder,
              let openedAt = reminderStore.lastOpenedReminderAt
        else {
            return nil
        }

        return "\(openedAt.formatted(date: .abbreviated, time: .shortened)) 点击 \(route.displayName) 提醒，已路由到 \(route == .sleep ? "今日页" : "记录页")。"
    }
}

private struct MoreSupportSettingsView: View {
    let persistenceStore: BodyCoachPersistenceStore
    @Binding var showsDeleteConfirmation: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                pageHeader

                SettingsSection(title: "隐私与健康数据") {
                    SettingsInfoRow(
                        iconName: "heart.text.square.fill",
                        title: "Apple 健康数据用途",
                        detail: "VitalLoop 只读取活动、睡眠、心率、HRV 和体重摘要，用于本地生成身体状态评分和今日建议。"
                    )
                    SettingsInfoRow(
                        iconName: "lock.shield.fill",
                        title: "本地优先",
                        detail: "当前版本不上传原始 HealthKit 数据，也不把健康数据用于广告、营销或数据挖掘。"
                    )
                    SettingsInfoRow(
                        iconName: "stethoscope",
                        title: "非医疗诊断",
                        detail: "评分和建议只用于生活方式参考，不能替代医生、营养师或其他专业医疗意见。"
                    )
                }

                SettingsSection(title: "本地数据") {
                    SettingsInfoRow(
                        iconName: "externaldrive.fill",
                        title: "保存内容",
                        detail: "本机保存目标、每日摘要、体重记录，以及 Watch 快速记录的压力、疲劳和饥饿。"
                    )
                    SettingsActionRow(
                        iconName: "trash",
                        title: "删除本地记录",
                        detail: "仅删除 VitalLoop 本机记录，不会删除 Apple 健康原始数据。",
                        color: .bcAmber,
                        role: .destructive
                    ) {
                        showsDeleteConfirmation = true
                    }

                    if let error = persistenceStore.lastPersistenceError {
                        SettingsInfoRow(
                            iconName: "exclamationmark.triangle.fill",
                            title: "本地存储状态",
                            detail: error,
                            color: .bcAmber
                        )
                    }
                }

                SettingsSection(title: "Beta 反馈") {
                    SettingsInfoRow(
                        iconName: "bubble.left.and.exclamationmark.bubble.right.fill",
                        title: "反馈范围",
                        detail: "优先反馈 HealthKit 授权、Watch 同步、提醒跳转、记录编辑和 TestFlight 安装问题。提交前不要附带完整健康原始数据。",
                        color: .bcBlue
                    )

                    if let url = AppPrivacyLinks.betaFeedbackURL {
                        SettingsLinkRow(
                            iconName: "square.and.pencil",
                            title: "提交 Beta 反馈",
                            detail: "打开当前版本的反馈入口。",
                            destination: url,
                            color: .bcMint
                        )
                    }

                    if let url = AppPrivacyLinks.supportIssuesURL {
                        SettingsLinkRow(
                            iconName: "tray.full.fill",
                            title: "查看反馈列表",
                            detail: "查看已提交的问题和处理进度。",
                            destination: url,
                            color: .bcBlue
                        )
                    }
                }

                SettingsSection(title: "隐私政策") {
                    SettingsInfoRow(
                        iconName: "doc.text.fill",
                        title: "App 内政策摘要",
                        detail: "隐私政策、支持页和营销页已接入 GitHub Pages。提交前需要确认三条 URL 都可公网访问，并与 App Store Connect 填写一致。"
                    )
                    SettingsInfoRow(
                        iconName: "checklist.checked",
                        title: "上架材料状态",
                        detail: appStoreReadinessText,
                        color: .bcBlue
                    )

                    if let url = AppPrivacyLinks.privacyPolicyURL {
                        SettingsLinkRow(
                            iconName: "safari",
                            title: "打开隐私政策网页",
                            detail: "查看 TestFlight 和 App Store Connect 使用的公开政策。",
                            destination: url,
                            color: .bcMint
                        )
                    }

                    if let url = AppPrivacyLinks.supportURL {
                        SettingsLinkRow(
                            iconName: "questionmark.circle.fill",
                            title: "打开支持页面",
                            detail: "查看支持说明、联系方式和已知限制。",
                            destination: url,
                            color: .bcBlue
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 96)
        }
        .background(BodyCoachBackground())
        .navigationTitle("更多与支持")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("更多与支持")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
            Text("低频说明、支持入口和本地数据管理集中放在这里。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.bcSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appStoreReadinessText: String {
        "已具备 AppIcon、HealthKit 权限说明、Privacy Manifest、隐私政策、支持页、营销页和非医疗说明。提交前仍需真机截图、正式 Bundle ID / Team 与 App Store 隐私营养标签。"
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                content
            }
        }
    }
}

private struct DeviceReadinessRow: View {
    let iconName: String
    let title: String
    let badge: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12), in: Capsule())
                }

                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsActionRow: View {
    let iconName: String
    let title: String
    let detail: String
    let color: Color
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role) {
            action()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(color)
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color.opacity(0.88))
                    .padding(.top, 8)
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsLinkRow: View {
    let iconName: String
    let title: String
    let detail: String
    let destination: URL
    let color: Color

    var body: some View {
        Link(destination: destination) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(color)
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color.opacity(0.88))
                    .padding(.top, 8)
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct ReminderSettingsRow: View {
    let iconName: String
    let title: String
    let detail: String
    let isEnabled: Bool
    let time: Date
    let color: Color
    let setEnabled: @MainActor @Sendable (Bool) -> Void
    let setTime: @MainActor @Sendable (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcInk)

                        Spacer()

                        Toggle("", isOn: Binding(get: { isEnabled }, set: { value in setEnabled(value) }))
                            .labelsHidden()
                            .tint(color)
                    }

                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isEnabled {
                DatePicker(
                    "提醒时间",
                    selection: Binding(get: { time }, set: { value in setTime(value) }),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.bcInk)
                .tint(color)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsInfoRow: View {
    let iconName: String
    let title: String
    let detail: String
    var color: Color = .bcMint

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TrendHistoryView: View {
    let persistenceStore: BodyCoachPersistenceStore

    @State private var selectedRange: TrendRange = .fourteenDays

    private var records: [DailySummaryRecord] {
        Array(persistenceStore.recentDailySummaries.prefix(selectedRange.days).reversed())
    }

    private var recentSummaryRecords: [DailySummaryRecord] {
        Array(persistenceStore.recentDailySummaries.prefix(min(7, selectedRange.days)).reversed())
    }

    private var weightTrendRecords: [WeightEntry] {
        Array(persistenceStore.recentWeightEntries.prefix(selectedRange.days).reversed())
    }

    private var checkInTrendRecords: [SubjectiveCheckIn] {
        Array(persistenceStore.recentSubjectiveCheckIns.prefix(selectedRange.days).reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header

                    if records.isEmpty {
                        TrendEmptyStateCard()
                    } else {
                        trendOverviewCard
                        trendExplanationCard
                        trendAlertCard
                        periodReviewCard
                        dimensionGrid
                        manualTrendGrid
                        recentSummaryList
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
            .background(BodyCoachBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            persistenceStore.loadRecentDailySummaries(limit: 30)
            persistenceStore.loadRecentLogs(limit: 30)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            VitalLoopWordmark()
            Text("趋势")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
            Text("基于本机保存的每日摘要观察身体状态变化，不展示原始 HealthKit 明细。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.bcSoft)
                .fixedSize(horizontal: false, vertical: true)

            Picker("趋势范围", selection: $selectedRange) {
                ForEach(TrendRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 8)
        }
    }

    private var trendOverviewCard: some View {
        GlassCard(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(selectedRange.displayName)状态")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Text(trendDirectionText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(trendDirectionColor)
                    }

                    Spacer()

                    Text("\(records.count)/\(selectedRange.days) 天")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bcBlue.opacity(0.14), in: Capsule())
                }

                ScoreTrendChart(records: records)
                    .frame(height: 132)
                    .accessibilityLabel("\(selectedRange.displayName)综合分趋势")

                HStack(spacing: 10) {
                    GoalMetric(title: "平均", value: averageText(\.overallScore), unit: "分", color: .bcMint)
                    GoalMetric(title: "最高", value: maxScoreText, unit: "分", color: .bcBlue)
                    GoalMetric(title: "低恢复", value: lowRecoveryDaysText, unit: "天", color: .bcAmber)
                }

                Text(overviewSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var trendAlertCard: some View {
        if !trendAlerts.isEmpty {
            GlassCard(cornerRadius: 24, padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("异常提示")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.bcInk)

                        Spacer()

                        Text("\(trendAlerts.count) 项")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.bcAmber)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.bcAmber.opacity(0.14), in: Capsule())
                    }

                    VStack(spacing: 8) {
                        ForEach(trendAlerts) { alert in
                            TrendAlertRow(alert: alert)
                        }
                    }
                }
            }
        }
    }

    private var trendExplanationCard: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("趋势解释")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text(selectedRange.reviewTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcBlue)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.bcBlue.opacity(0.14), in: Capsule())
                }

                VStack(spacing: 8) {
                    ForEach(trendExplanationItems) { item in
                        TrendExplanationRow(item: item)
                    }
                }
            }
        }
    }

    private var periodReviewCard: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(selectedRange.reviewTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text(reviewQualityText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(reviewQualityColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(reviewQualityColor.opacity(0.14), in: Capsule())
                }

                HStack(spacing: 10) {
                    GoalMetric(title: "覆盖", value: "\(records.count)/\(selectedRange.days)", unit: "天", color: .bcMint)
                    GoalMetric(title: "可信度", value: averageCompletenessText, unit: "%", color: .bcViolet)
                    GoalMetric(title: "低恢复", value: lowRecoveryDaysText, unit: "天", color: .bcAmber)
                }

                Text(periodReviewSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(periodReviewActions.enumerated()), id: \.offset) { index, action in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(Color(red: 0.03, green: 0.08, blue: 0.07))
                                .frame(width: 20, height: 20)
                                .background(Color.bcMint, in: Circle())

                            Text(action)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.bcSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var dimensionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            TrendDimensionCard(title: "睡眠", value: averageText(\.sleepScore), detail: dimensionDetail(\.sleepScore), color: .bcAmber, records: records, keyPath: \.sleepScore)
            TrendDimensionCard(title: "恢复", value: averageText(\.recoveryScore), detail: dimensionDetail(\.recoveryScore), color: .bcBlue, records: records, keyPath: \.recoveryScore)
            TrendDimensionCard(title: "活动", value: averageText(\.activityScore), detail: dimensionDetail(\.activityScore), color: .bcMint, records: records, keyPath: \.activityScore)
            TrendDimensionCard(title: "体重趋势", value: averageText(\.weightTrendScore), detail: dimensionDetail(\.weightTrendScore), color: .bcViolet, records: records, keyPath: \.weightTrendScore)
        }
    }

    private var manualTrendGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记录趋势")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.bcInk)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                WeightTrendCard(records: weightTrendRecords)
                SubjectiveLoadTrendCard(records: checkInTrendRecords)
            }
        }
    }

    private var recentSummaryList: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("最近摘要")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    Text("本地记录")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bcMint.opacity(0.14), in: Capsule())
                }

                ForEach(Array(recentSummaryRecords.reversed().enumerated()), id: \.element.id) { index, record in
                    TrendRecordRow(record: record)
                    if index < recentSummaryRecords.count - 1 {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }

    private var trendDirectionText: String {
        guard let delta = overallDelta else {
            return "记录不足，先积累连续摘要"
        }

        if delta >= 5 {
            return "较周期初提升 \(Int(delta.rounded())) 分"
        }

        if delta <= -5 {
            return "较周期初下降 \(abs(Int(delta.rounded()))) 分"
        }

        return "整体稳定，波动在正常范围"
    }

    private var trendDirectionColor: Color {
        guard let delta = overallDelta else {
            return .bcMuted
        }

        if delta <= -5 {
            return .bcAmber
        }

        return delta >= 5 ? .bcMint : .bcBlue
    }

    private var overallDelta: Double? {
        guard let first = records.first, let last = records.last, records.count >= 2 else {
            return nil
        }

        return Double(last.overallScore - first.overallScore)
    }

    private var maxScoreText: String {
        records.map(\.overallScore).max().map(String.init) ?? "--"
    }

    private var lowRecoveryDaysText: String {
        String(records.filter { $0.recoveryScore < 62 || $0.sleepScore < 65 }.count)
    }

    private var lowRecoveryDays: Int {
        records.filter { $0.recoveryScore < 62 || $0.sleepScore < 65 }.count
    }

    private var averageCompleteness: Double {
        average(records.map { Double($0.dataCompleteness) }) ?? 0
    }

    private var averageCompletenessText: String {
        records.isEmpty ? "--" : Int(averageCompleteness.rounded()).description
    }

    private var reviewQualityText: String {
        guard records.count >= 3 else {
            return "待积累"
        }

        if averageCompleteness < 60 {
            return "可信度低"
        }

        if lowRecoveryDays >= lowRecoveryAlertThreshold {
            return "需降压"
        }

        if (average(records.map { Double($0.overallScore) }) ?? 0) >= 74 {
            return "可维持"
        }

        return "观察中"
    }

    private var reviewQualityColor: Color {
        switch reviewQualityText {
        case "可维持":
            return .bcMint
        case "待积累":
            return .bcMuted
        case "可信度低", "需降压":
            return .bcAmber
        default:
            return .bcBlue
        }
    }

    private var overviewSummary: String {
        guard records.count >= 3 else {
            return "趋势至少需要 3 天摘要。每天刷新一次身体总览后，这里会逐步形成可用判断。"
        }

        let averageOverall = average(records.map { Double($0.overallScore) }) ?? 0

        if averageCompleteness < 60 {
            return "近期数据可信度偏低，先补齐睡眠、体重和主观记录，再判断计划是否有效。"
        }

        if lowRecoveryDays >= lowRecoveryAlertThreshold {
            return "当前周期恢复或睡眠低分偏多，减脂和训练计划需要先降压，不建议盲目提高活动量。"
        }

        if averageOverall >= 74 {
            return "近期状态较稳定，可以维持当前节奏，并继续观察体重和恢复趋势。"
        }

        return "近期状态中等，建议优先稳定睡眠和日常活动，再做目标节奏调整。"
    }

    private var trendExplanationItems: [TrendExplanationItem] {
        var items: [TrendExplanationItem] = []

        if let item = overallDeltaExplanation {
            items.append(item)
        }

        if let item = weakestDimensionExplanation {
            items.append(item)
        }

        if let item = manualRecordExplanation {
            items.append(item)
        }

        if averageCompleteness < 70 {
            items.append(
                TrendExplanationItem(
                    iconName: "questionmark.folder.fill",
                    title: "数据覆盖影响判断",
                    detail: "当前平均可信度 \(Int(averageCompleteness.rounded()))%。如果缺少睡眠、体重或主观记录，趋势更适合作为方向提醒。",
                    color: .bcAmber
                )
            )
        }

        if items.isEmpty {
            items.append(
                TrendExplanationItem(
                    iconName: "checkmark.circle.fill",
                    title: "主要指标稳定",
                    detail: "综合分、恢复和睡眠没有明显异常，先维持当前计划，并继续积累每日摘要。",
                    color: .bcMint
                )
            )
        }

        return Array(items.prefix(4))
    }

    private var overallDeltaExplanation: TrendExplanationItem? {
        guard let overallDelta else {
            return nil
        }

        if overallDelta >= 5 {
            return TrendExplanationItem(
                iconName: "chart.line.uptrend.xyaxis",
                title: "综合分在改善",
                detail: "较周期初提升 \(Int(overallDelta.rounded())) 分，通常来自恢复、睡眠或活动得分同步改善。",
                color: .bcMint
            )
        }

        if overallDelta <= -5 {
            return TrendExplanationItem(
                iconName: "chart.line.downtrend.xyaxis",
                title: "综合分在走弱",
                detail: "较周期初下降 \(abs(Int(overallDelta.rounded()))) 分，优先排查最近几天的睡眠、恢复和压力负荷。",
                color: .bcAmber
            )
        }

        return TrendExplanationItem(
            iconName: "equal.circle.fill",
            title: "综合分基本稳定",
            detail: "周期内波动小于 5 分，单日变化暂不需要改变计划。",
            color: .bcBlue
        )
    }

    private var weakestDimensionExplanation: TrendExplanationItem? {
        guard records.count >= 2 else {
            return nil
        }

        let dimensions: [(title: String, first: Int, last: Int, average: Double, color: Color)] = [
            ("睡眠", records.first?.sleepScore ?? 0, records.last?.sleepScore ?? 0, average(records.map { Double($0.sleepScore) }) ?? 0, .bcAmber),
            ("恢复", records.first?.recoveryScore ?? 0, records.last?.recoveryScore ?? 0, average(records.map { Double($0.recoveryScore) }) ?? 0, .bcBlue),
            ("活动", records.first?.activityScore ?? 0, records.last?.activityScore ?? 0, average(records.map { Double($0.activityScore) }) ?? 0, .bcMint),
            ("体重趋势", records.first?.weightTrendScore ?? 0, records.last?.weightTrendScore ?? 0, average(records.map { Double($0.weightTrendScore) }) ?? 0, .bcViolet)
        ]

        guard let weakest = dimensions.min(by: { left, right in
            let leftDrop = left.last - left.first
            let rightDrop = right.last - right.first
            if leftDrop == rightDrop {
                return left.average < right.average
            }

            return leftDrop < rightDrop
        }) else {
            return nil
        }

        let delta = weakest.last - weakest.first
        if delta <= -4 {
            return TrendExplanationItem(
                iconName: "arrow.down.circle.fill",
                title: "\(weakest.title)拖累趋势",
                detail: "\(weakest.title)较周期初下降 \(abs(delta)) 分，是当前最需要优先处理的方向。",
                color: weakest.color
            )
        }

        if weakest.average < 64 {
            return TrendExplanationItem(
                iconName: "exclamationmark.circle.fill",
                title: "\(weakest.title)均值偏低",
                detail: "\(weakest.title)平均约 \(Int(weakest.average.rounded())) 分，即使没有继续下滑，也会限制综合状态。",
                color: weakest.color
            )
        }

        return nil
    }

    private var manualRecordExplanation: TrendExplanationItem? {
        if let loadDelta, loadDelta >= 1.0 {
            return TrendExplanationItem(
                iconName: "waveform.path.ecg",
                title: "主观负荷上升",
                detail: "压力、疲劳、饥饿平均值上升 \(loadDelta.oneDecimalString)，这可能解释恢复建议变保守。",
                color: .bcAmber
            )
        }

        if let weightDelta, abs(weightDelta) >= 0.4 {
            return TrendExplanationItem(
                iconName: "scalemass.fill",
                title: "体重记录有变化",
                detail: "手动体重较周期初 \(weightDelta >= 0 ? "上升" : "下降") \(abs(weightDelta).oneDecimalString)kg。先确认称重时间一致，再判断饮食调整。",
                color: weightDelta <= 0 ? .bcMint : .bcViolet
            )
        }

        return nil
    }

    private var periodReviewSummary: String {
        guard records.count >= 3 else {
            return "当前周期摘要不足 3 天，先连续刷新身体总览，避免用单日分数判断趋势。"
        }

        let averageOverall = average(records.map { Double($0.overallScore) }) ?? 0

        if averageCompleteness < 60 {
            return "\(selectedRange.reviewTitle)结论：数据覆盖不足，先把记录习惯补齐，再评估训练或饮食计划是否需要调整。"
        }

        if lowRecoveryDays >= lowRecoveryAlertThreshold {
            return "\(selectedRange.reviewTitle)结论：恢复压力偏高，下一周期优先降低训练强度、固定睡眠窗口，并观察主观负荷。"
        }

        if averageOverall >= 74, (overallDelta ?? 0) >= -4 {
            return "\(selectedRange.reviewTitle)结论：状态稳定，可以维持当前节奏，不需要因为短期体重波动改变目标。"
        }

        return "\(selectedRange.reviewTitle)结论：状态中等，下一周期先做小幅调整，重点观察睡眠、恢复和记录完整度。"
    }

    private var periodReviewActions: [String] {
        if records.count < 3 {
            return [
                "每天刷新一次身体总览，至少积累 3 天摘要。",
                "记录页补体重和主观状态，让趋势解释有足够依据。"
            ]
        }

        var actions: [String] = []

        if averageCompleteness < 70 {
            actions.append("先补齐睡眠、体重和主观记录，提升趋势可信度。")
        }

        if lowRecoveryDays >= lowRecoveryAlertThreshold {
            actions.append("下一周期安排 2 天低强度或休息日，避免继续堆训练量。")
        }

        if let loadDelta, loadDelta >= 1.0 {
            actions.append("主观负荷上升时，在记录备注里标注压力、加班或饮食原因。")
        }

        if let weightDelta, weightDelta > 0.4 {
            actions.append("体重上升先确认称重时间一致，再减少高油外卖或夜间加餐。")
        }

        if actions.isEmpty {
            actions.append("维持当前节奏，继续观察综合分和体重趋势。")
            actions.append("每周只调整一个变量，避免同时改训练和饮食。")
        }

        return Array(actions.prefix(3))
    }

    private var trendAlerts: [TrendAlert] {
        guard records.count >= 3 else {
            return []
        }

        var alerts: [TrendAlert] = []
        if averageCompleteness < 65 {
            alerts.append(
                TrendAlert(
                    iconName: "exclamationmark.triangle.fill",
                    title: "数据可信度偏低",
                    detail: "当前周期平均完整度 \(Int(averageCompleteness.rounded()))%。原因多半是缺少睡眠、体重或主观记录，先补齐数据再判断计划效果。",
                    color: .bcAmber
                )
            )
        }

        if lowRecoveryDays >= lowRecoveryAlertThreshold {
            alerts.append(
                TrendAlert(
                    iconName: "bed.double.fill",
                    title: "恢复低分偏多",
                    detail: "\(selectedRange.displayName)内有 \(lowRecoveryDays) 天睡眠或恢复偏低。常见原因是睡眠不足、压力偏高或训练密度过高，下一步先稳睡眠。",
                    color: .bcBlue
                )
            )
        }

        if let overallDelta, overallDelta <= -6 {
            alerts.append(
                TrendAlert(
                    iconName: "chart.line.downtrend.xyaxis",
                    title: "综合状态下滑",
                    detail: "综合分较周期初下降 \(abs(Int(overallDelta.rounded()))) 分。优先看趋势解释里的拖累项，再决定是否调整训练或饮食。",
                    color: .bcAmber
                )
            )
        }

        if let weightDelta, weightDelta > 0.5 {
            alerts.append(
                TrendAlert(
                    iconName: "scalemass.fill",
                    title: "体重趋势上升",
                    detail: "手动体重较周期初上升 \(weightDelta.oneDecimalString)kg。可能来自称重时间、盐分水分或热量盈余，先确认记录一致性。",
                    color: .bcViolet
                )
            )
        }

        if let loadDelta, loadDelta >= 1.2 {
            alerts.append(
                TrendAlert(
                    iconName: "waveform.path.ecg",
                    title: "主观负荷上升",
                    detail: "压力、疲劳、饥饿平均值上升 \(loadDelta.oneDecimalString)。这通常会压低恢复判断，优先补备注原因并降低训练压力。",
                    color: .bcAmber
                )
            )
        }

        return Array(alerts.prefix(3))
    }

    private var lowRecoveryAlertThreshold: Int {
        max(2, Int((Double(records.count) * 0.3).rounded(.up)))
    }

    private var weightDelta: Double? {
        guard let first = weightTrendRecords.first?.weightKg,
              let last = weightTrendRecords.last?.weightKg,
              weightTrendRecords.count >= 2
        else {
            return nil
        }

        return last - first
    }

    private var loadDelta: Double? {
        guard let first = checkInTrendRecords.first?.averageLoad,
              let last = checkInTrendRecords.last?.averageLoad,
              checkInTrendRecords.count >= 2
        else {
            return nil
        }

        return last - first
    }

    private func averageText(_ keyPath: KeyPath<DailySummaryRecord, Int>) -> String {
        average(records.map { Double($0[keyPath: keyPath]) }).map { Int($0.rounded()).description } ?? "--"
    }

    private func dimensionDetail(_ keyPath: KeyPath<DailySummaryRecord, Int>) -> String {
        guard records.count >= 2,
              let first = records.first,
              let last = records.last
        else {
            return "待积累"
        }

        let delta = last[keyPath: keyPath] - first[keyPath: keyPath]
        if delta >= 4 {
            return "上升 \(delta)"
        }

        if delta <= -4 {
            return "下降 \(abs(delta))"
        }

        return "稳定"
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }
}

private enum TrendRange: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30

    var id: Int {
        rawValue
    }

    var days: Int {
        rawValue
    }

    var displayName: String {
        switch self {
        case .sevenDays:
            return "7天"
        case .fourteenDays:
            return "14天"
        case .thirtyDays:
            return "30天"
        }
    }

    var reviewTitle: String {
        switch self {
        case .sevenDays:
            return "周回顾"
        case .fourteenDays:
            return "双周回顾"
        case .thirtyDays:
            return "月回顾"
        }
    }
}

private struct TrendExplanationItem: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let detail: String
    let color: Color
}

private struct TrendExplanationRow: View {
    let item: TrendExplanationItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(item.color)
                .frame(width: 30, height: 30)
                .background(item.color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                Text(item.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TrendAlert: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let detail: String
    let color: Color
}

private struct TrendAlertRow: View {
    let alert: TrendAlert

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alert.iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(alert.color)
                .frame(width: 30, height: 30)
                .background(alert.color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                Text(alert.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TrendEmptyStateCard: View {
    var body: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.bcMint)
                    .frame(width: 48, height: 48)
                    .background(Color.bcMint.opacity(0.14), in: Circle())

                Text("还没有趋势记录")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.bcInk)

                Text("每天刷新一次身体总览后，VitalLoop 会在本机保存每日摘要。积累 3 天后开始形成趋势判断。")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ScoreTrendChart: View {
    let records: [DailySummaryRecord]

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.055))

                VStack {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                        Spacer()
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)

                if points.count >= 2 {
                    Path { path in
                        for (index, point) in points.enumerated() {
                            if index == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [.bcMint, .bcBlue], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )

                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(Color.bcMint)
                            .frame(width: 7, height: 7)
                            .position(point)
                    }
                } else {
                    Text("趋势不足")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        let values = records.map { Double($0.overallScore) }
        guard !values.isEmpty else {
            return []
        }

        let minValue = max((values.min() ?? 0) - 8, 0)
        let maxValue = min((values.max() ?? 100) + 8, 100)
        let range = max(maxValue - minValue, 1)
        let horizontalPadding: CGFloat = 18
        let verticalPadding: CGFloat = 18
        let drawableWidth = max(size.width - horizontalPadding * 2, 1)
        let drawableHeight = max(size.height - verticalPadding * 2, 1)

        return values.enumerated().map { index, value in
            let x = horizontalPadding + drawableWidth * CGFloat(index) / CGFloat(max(values.count - 1, 1))
            let normalized = (value - minValue) / range
            let y = verticalPadding + drawableHeight * CGFloat(1 - min(max(normalized, 0), 1))
            return CGPoint(x: x, y: y)
        }
    }
}

private struct TrendDimensionCard: View {
    let title: String
    let value: String
    let detail: String
    let color: Color
    let records: [DailySummaryRecord]
    let keyPath: KeyPath<DailySummaryRecord, Int>

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcSoft)
                    Spacer()
                    Text(detail)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                }

                Sparkline(values: normalizedValues, color: color)
                    .frame(height: 42)
                    .accessibilityLabel("\(title)趋势")

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.bcInk)
                    Text("均分")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }
            }
        }
    }

    private var normalizedValues: [Double] {
        let values = records.map { Double($0[keyPath: keyPath]) }
        guard values.count >= 2 else {
            return [0.5, 0.5]
        }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let range = max(maxValue - minValue, 1)
        return values.map { value in
            0.12 + ((value - minValue) / range) * 0.76
        }
    }
}

private struct WeightTrendCard: View {
    let records: [WeightEntry]

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("体重")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcSoft)

                    Spacer()

                    Text(records.count >= 2 ? deltaText : "待积累")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(deltaColor)
                }

                TrendValueSparkline(values: records.map(\.weightKg), color: .bcViolet)
                    .frame(height: 42)
                    .accessibilityLabel("体重记录趋势")

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(latestWeightText)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.bcInk)
                    Text("kg")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }

                Text(detailText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.bcSoft)
                    .lineLimit(2)
            }
        }
    }

    private var latestWeightText: String {
        records.last?.weightKg.oneDecimalString ?? "--"
    }

    private var delta: Double? {
        guard let first = records.first?.weightKg, let last = records.last?.weightKg, records.count >= 2 else {
            return nil
        }

        return last - first
    }

    private var deltaText: String {
        guard let delta else {
            return "待积累"
        }

        return "\(delta.signedOneDecimalString)kg"
    }

    private var deltaColor: Color {
        guard let delta else {
            return .bcMuted
        }

        if delta < -0.2 {
            return .bcMint
        }

        if delta > 0.2 {
            return .bcAmber
        }

        return .bcBlue
    }

    private var detailText: String {
        guard records.count >= 2 else {
            return "记录页保存体重后，这里会显示手动体重趋势。"
        }

        return "近 \(records.count) 次记录，最新来自 \(records.last?.source ?? "iPhone")。"
    }
}

private struct SubjectiveLoadTrendCard: View {
    let records: [SubjectiveCheckIn]

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("主观负荷")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcSoft)

                    Spacer()

                    Text(loadDirectionText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(loadDirectionColor)
                }

                TrendValueSparkline(values: records.map(\.averageLoad), color: .bcAmber)
                    .frame(height: 42)
                    .accessibilityLabel("主观负荷趋势")

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(latestLoadText)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.bcInk)
                    Text("/10")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }

                if let latest = records.last {
                    Text("压力 \(latest.stress) · 疲劳 \(latest.fatigue) · 饥饿 \(latest.hunger)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.bcSoft)
                        .lineLimit(2)
                } else {
                    Text("记录压力、疲劳、饥饿后，这里会展示负荷走向。")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.bcSoft)
                        .lineLimit(2)
                }
            }
        }
    }

    private var latestLoadText: String {
        records.last?.averageLoad.oneDecimalString ?? "--"
    }

    private var loadDelta: Double? {
        guard let first = records.first?.averageLoad, let last = records.last?.averageLoad, records.count >= 2 else {
            return nil
        }

        return last - first
    }

    private var loadDirectionText: String {
        guard let loadDelta else {
            return "待积累"
        }

        if loadDelta >= 1 {
            return "负荷上升"
        }

        if loadDelta <= -1 {
            return "负荷下降"
        }

        return "基本稳定"
    }

    private var loadDirectionColor: Color {
        guard let loadDelta else {
            return .bcMuted
        }

        if loadDelta >= 1 {
            return .bcAmber
        }

        return loadDelta <= -1 ? .bcMint : .bcBlue
    }
}

private struct TrendRecordRow: View {
    let record: DailySummaryRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(record.date.formatted(.dateTime.day()))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.bcInk)
                Text(record.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.bcMuted)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(statusText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Text(record.dataSourceRawValue == "healthKit" ? "Apple 健康" : "模拟")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }

                Text(record.summaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text("\(record.overallScore)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(scoreColor)
        }
    }

    private var statusText: String {
        switch record.statusRawValue {
        case BodyStatus.strong.rawValue:
            return BodyStatus.strong.displayName
        case BodyStatus.normal.rawValue:
            return BodyStatus.normal.displayName
        case BodyStatus.caution.rawValue:
            return BodyStatus.caution.displayName
        case BodyStatus.recovery.rawValue:
            return BodyStatus.recovery.displayName
        default:
            return "状态摘要"
        }
    }

    private var scoreColor: Color {
        if record.recoveryScore < 62 || record.sleepScore < 65 {
            return .bcAmber
        }

        if record.overallScore >= 74 {
            return .bcMint
        }

        return .bcBlue
    }
}

private struct CheckInLogView: View {
    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore

    @State private var stress = 5.0
    @State private var fatigue = 4.0
    @State private var hunger = 5.0
    @State private var weightText = ""
    @State private var weightNote = ""
    @State private var mealKind: MealLogKind = .normal
    @State private var mealNote = ""
    @State private var didLoadLatestCheckIn = false
    @State private var logFilter: LogDateFilter = .sevenDays
    @State private var logKindFilter: LogKindFilter = .all
    @State private var logSearchText = ""
    @State private var editingLog: EditableLog?
    @State private var pendingDeleteLog: EditableLog?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    latestCheckInCard
                    quickEntryCard
                    weightEntryCard
                    mealEntryCard
                    recentLogCard
                    subjectiveHistoryCard
                    watchSyncCard
                    explanationCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
            .background(BodyCoachBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            loadLatestCheckInIfNeeded()
        }
        .onChange(of: store.latestSubjectiveCheckIn?.id) { _, _ in
            reloadLogsForCurrentFilter()
            loadLatestCheckIn()
        }
        .onChange(of: logFilter) { _, _ in
            reloadLogsForCurrentFilter()
        }
        .sheet(item: $editingLog) { log in
            LogEditSheet(
                log: log,
                save: saveEditedLog,
                delete: deleteLog
            )
        }
        .confirmationDialog(
            "删除这条记录？",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                confirmPendingDelete()
            }

            Button("取消", role: .cancel) {
                pendingDeleteLog = nil
            }
        } message: {
            Text("删除后会刷新本地记录和今日评分。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            VitalLoopWordmark()
            Text("快速记录")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
            Text("补充压力、疲劳和饥饿感。它会进入今日评分，但只作为生活方式参考。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.bcSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var latestCheckInCard: some View {
        GlassCard(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: latestCheckInIconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(latestCheckInColor)
                        .frame(width: 42, height: 42)
                        .background(latestCheckInColor.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("最近主观记录")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.bcInk)
                            Spacer()
                            Text(latestStatusLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(latestCheckInColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(latestCheckInColor.opacity(0.14), in: Capsule())
                        }

                        Text(latestDetailText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.bcSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    CheckInMetricPill(title: "压力", value: latestStressText, color: .bcViolet)
                    CheckInMetricPill(title: "疲劳", value: latestFatigueText, color: .bcAmber)
                    CheckInMetricPill(title: "饥饿", value: latestHungerText, color: .bcBlue)
                }
            }
        }
    }

    private var quickEntryCard: some View {
        GlassCard(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("手机补记")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    Text("1-10")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }

                SubjectiveSliderRow(title: "压力", value: $stress, color: .bcViolet)
                SubjectiveSliderRow(title: "疲劳", value: $fatigue, color: .bcAmber)
                SubjectiveSliderRow(title: "饥饿", value: $hunger, color: .bcBlue)

                Button {
                    store.saveSubjectiveCheckIn(
                        stress: stressInt,
                        fatigue: fatigueInt,
                        hunger: hungerInt
                    )
                    reloadLogsForCurrentFilter()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("保存主观记录")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.03, green: 0.08, blue: 0.07))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.bcMint, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weightEntryCard: some View {
        GlassCard(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("体重记录")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    if let latest = persistenceStore.recentWeightEntries.first {
                        Text("\(latest.weightKg.oneDecimalString) kg")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.bcMint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.bcMint.opacity(0.14), in: Capsule())
                    }
                }

                TextField("今天体重，例如 76.8", text: $weightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                TextField("备注，可选", text: $weightNote)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcInk)
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    saveWeightEntry()
                } label: {
                    HStack {
                        Image(systemName: "scalemass.fill")
                        Text("保存体重")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.bcMint.opacity(canSaveWeight ? 0.2 : 0.08), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.bcMint.opacity(canSaveWeight ? 0.42 : 0.14), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSaveWeight)
            }
        }
    }

    private var mealEntryCard: some View {
        GlassCard(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("饮食简记")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    if let latest = persistenceStore.recentMealLogs.first {
                        Text(latest.kind.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.bcAmber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.bcAmber.opacity(0.14), in: Capsule())
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(MealLogKind.allCases, id: \.self) { kind in
                        Button {
                            mealKind = kind
                        } label: {
                            Text(kind.displayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(mealKind == kind ? Color(red: 0.03, green: 0.08, blue: 0.07) : Color.bcInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(mealKind == kind ? Color.bcAmber : Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("一句话记录，例如 晚餐偏油 / 蛋白够", text: $mealNote)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcInk)
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    saveMealLog()
                } label: {
                    HStack {
                        Image(systemName: "fork.knife.circle.fill")
                        Text("保存饮食简记")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.03, green: 0.08, blue: 0.07))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.bcAmber, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentLogCard: some View {
        GlassCard(cornerRadius: 26, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("记录列表")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Text("\(filteredLogRows.count) 条 · \(logFilter.displayName) · \(logKindFilter.displayName)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.bcMuted)
                    }

                    Spacer()

                    Picker("记录范围", selection: $logFilter) {
                        ForEach(LogDateFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 210)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)

                    TextField("搜索记录、备注或来源", text: $logSearchText)
                        .textFieldStyle(.plain)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcInk)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Picker("记录类型", selection: $logKindFilter) {
                    ForEach(LogKindFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if filteredLogRows.isEmpty {
                    Text(emptyLogText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredLogRows) { row in
                            RecentLogRowView(
                                row: row,
                                edit: {
                                    editingLog = row.editableLog
                                },
                                delete: {
                                    requestDelete(row.editableLog)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var subjectiveHistoryCard: some View {
        GlassCard(cornerRadius: 26, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("主观记录历史")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text("\(filteredSubjectiveCheckIns.count) 条")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcViolet)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.bcViolet.opacity(0.14), in: Capsule())
                }

                if filteredSubjectiveCheckIns.isEmpty {
                    Text("当天可以记录多次。每条都会保留时间和来源，最新一条用于今日评分。")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSubjectiveCheckIns, id: \.id) { record in
                            CheckInHistoryRowView(
                                record: record,
                                edit: {
                                    editingLog = .subjective(record)
                                },
                                delete: {
                                    requestDelete(.subjective(record))
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var watchSyncCard: some View {
        let diagnostics = store.watchSyncDiagnostics

        return GlassCard(cornerRadius: 24, padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.bcMint)
                    .frame(width: 38, height: 38)
                    .background(Color.bcMint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Watch 回传状态")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Spacer()
                        Text(diagnostics.isReachable ? "可达" : "不可达")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(diagnostics.isReachable ? Color.bcMint : Color.bcAmber)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background((diagnostics.isReachable ? Color.bcMint : Color.bcAmber).opacity(0.14), in: Capsule())
                    }

                    Text(watchSyncDetail(diagnostics))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var explanationCard: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.bcBlue)
                    .frame(width: 38, height: 38)
                    .background(Color.bcBlue.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("怎么影响评分")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Text("主观记录会补充身体数据看不到的压力、疲劳和饥饿感。它会影响恢复解释和今日建议优先级，但不会被当作医疗诊断。")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var latestCheckIn: WatchSubjectiveCheckInPayload? {
        store.latestSubjectiveCheckIn
    }

    private var canSaveWeight: Bool {
        parsedWeightKg != nil
    }

    private var parsedWeightKg: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    private var recentLogRows: [RecentLogRow] {
        let checkIns = persistenceStore.recentSubjectiveCheckIns.map { record in
            RecentLogRow(
                id: record.id,
                kind: .subjective,
                date: record.capturedAt,
                iconName: "waveform.path.ecg",
                title: "主观状态",
                detail: "压力 \(record.stress) · 疲劳 \(record.fatigue) · 饥饿 \(record.hunger)",
                source: record.source,
                color: .bcViolet,
                editableLog: .subjective(record)
            )
        }

        let weights = persistenceStore.recentWeightEntries.map { record in
            RecentLogRow(
                id: record.id,
                kind: .weight,
                date: record.capturedAt,
                iconName: "scalemass.fill",
                title: "体重",
                detail: "\(record.weightKg.oneDecimalString) kg\(record.note.isEmpty ? "" : " · \(record.note)")",
                source: record.source,
                color: .bcMint,
                editableLog: .weight(record)
            )
        }

        let meals = persistenceStore.recentMealLogs.map { record in
            RecentLogRow(
                id: record.id,
                kind: .meal,
                date: record.capturedAt,
                iconName: "fork.knife",
                title: "饮食",
                detail: "\(record.kind.displayName)\(record.note.isEmpty ? "" : " · \(record.note)")",
                source: record.source,
                color: .bcAmber,
                editableLog: .meal(record)
            )
        }

        return (checkIns + weights + meals).sorted { $0.date > $1.date }
    }

    private var filteredLogRows: [RecentLogRow] {
        recentLogRows.filter { row in
            logFilter.contains(row.date)
                && logKindFilter.contains(row.kind)
                && matchesSearch(row)
        }
    }

    private var filteredSubjectiveCheckIns: [SubjectiveCheckIn] {
        persistenceStore.recentSubjectiveCheckIns.filter { record in
            logFilter.contains(record.capturedAt) && matchesSubjectiveSearch(record)
        }
    }

    private var emptyLogText: String {
        if !trimmedLogSearchText.isEmpty {
            return "没有匹配“\(trimmedLogSearchText)”的记录。可以清空搜索或切换筛选条件。"
        }

        if logKindFilter != .all {
            return "\(logFilter.displayName)内没有\(logKindFilter.displayName)记录。可以切换为全部类型。"
        }

        switch logFilter {
        case .today:
            return "今天还没有本地记录。保存主观状态、体重或饮食简记后，会显示在这里。"
        case .sevenDays:
            return "最近 7 天还没有本地记录。先补一条主观状态或体重记录。"
        case .all:
            return "还没有本地记录。保存主观状态、体重或饮食简记后，会显示在这里。"
        }
    }

    private var trimmedLogSearchText: String {
        logSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: {
                pendingDeleteLog != nil
            },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteLog = nil
                }
            }
        )
    }

    private var latestStatusLabel: String {
        latestCheckIn?.statusLabel ?? "待记录"
    }

    private var latestDetailText: String {
        guard let latestCheckIn else {
            return "可以从 Apple Watch 快速记录，也可以在这里补记。保存后今日评分和建议会立刻刷新。"
        }

        return "\(latestCheckIn.capturedAt.formatted(date: .abbreviated, time: .shortened)) 来自 \(latestCheckIn.source)。\(latestCheckIn.compactSummary)。"
    }

    private var latestStressText: String {
        latestCheckIn.map { String($0.stress) } ?? "--"
    }

    private var latestFatigueText: String {
        latestCheckIn.map { String($0.fatigue) } ?? "--"
    }

    private var latestHungerText: String {
        latestCheckIn.map { String($0.hunger) } ?? "--"
    }

    private var latestCheckInIconName: String {
        guard latestCheckIn != nil else {
            return "plus.circle.fill"
        }

        if (latestCheckIn?.averageLoad ?? 0) >= 7 {
            return "exclamationmark.circle.fill"
        }

        return "checkmark.circle.fill"
    }

    private var latestCheckInColor: Color {
        guard let latestCheckIn else {
            return .bcMuted
        }

        switch latestCheckIn.averageLoad {
        case 0 ..< 4:
            return .bcMint
        case 4 ..< 7:
            return .bcBlue
        default:
            return .bcAmber
        }
    }

    private var stressInt: Int {
        Int(stress.rounded())
    }

    private var fatigueInt: Int {
        Int(fatigue.rounded())
    }

    private var hungerInt: Int {
        Int(hunger.rounded())
    }

    private func loadLatestCheckInIfNeeded() {
        guard !didLoadLatestCheckIn else {
            return
        }

        didLoadLatestCheckIn = true
        reloadLogsForCurrentFilter()
        loadLatestCheckIn()
    }

    private func reloadLogsForCurrentFilter() {
        persistenceStore.loadRecentLogs(limit: logFilter.fetchLimit)
    }

    private func loadLatestCheckIn() {
        guard let latestCheckIn else {
            return
        }

        stress = Double(latestCheckIn.stress)
        fatigue = Double(latestCheckIn.fatigue)
        hunger = Double(latestCheckIn.hunger)
    }

    private func watchSyncDetail(_ diagnostics: WatchSyncDiagnostics) -> String {
        var parts = [
            diagnostics.activationState,
            diagnostics.isCounterpartInstalled ? "Watch app 已安装" : "Watch app 未安装"
        ]

        if let receivedAt = diagnostics.lastCheckInReceivedAt {
            parts.append("最近接收 \(receivedAt.formatted(date: .omitted, time: .shortened))")
        } else if let acknowledgedAt = diagnostics.lastCheckInAcknowledgedAt {
            parts.append("最近确认 \(acknowledgedAt.formatted(date: .omitted, time: .shortened))")
        } else {
            parts.append(diagnostics.lastEvent)
        }

        if let error = diagnostics.lastError, !error.isEmpty {
            parts.append("错误：\(error)")
        }

        return parts.joined(separator: " · ")
    }

    private func matchesSearch(_ row: RecentLogRow) -> Bool {
        let query = trimmedLogSearchText
        guard !query.isEmpty else {
            return true
        }

        return row.searchText.localizedCaseInsensitiveContains(query)
    }

    private func matchesSubjectiveSearch(_ record: SubjectiveCheckIn) -> Bool {
        let query = trimmedLogSearchText
        guard !query.isEmpty else {
            return true
        }

        let searchText = [
            "主观状态",
            "压力 \(record.stress)",
            "疲劳 \(record.fatigue)",
            "饥饿 \(record.hunger)",
            record.source,
            record.statusLabel,
            record.capturedAt.formatted(date: .abbreviated, time: .shortened)
        ].joined(separator: " ")

        return searchText.localizedCaseInsensitiveContains(query)
    }

    private func saveWeightEntry() {
        guard let parsedWeightKg else {
            return
        }

        persistenceStore.saveWeightEntry(weightKg: parsedWeightKg, note: weightNote)
        reloadLogsForCurrentFilter()
        weightText = ""
        weightNote = ""
    }

    private func saveMealLog() {
        persistenceStore.saveMealLog(kind: mealKind, note: mealNote)
        reloadLogsForCurrentFilter()
        mealNote = ""
    }

    private func saveEditedLog(_ draft: EditableLogDraft) {
        switch draft.kind {
        case .subjective:
            guard let stress = draft.stress, let fatigue = draft.fatigue, let hunger = draft.hunger else {
                return
            }

            persistenceStore.updateSubjectiveCheckIn(id: draft.id, stress: stress, fatigue: fatigue, hunger: hunger)
            store.refreshSubjectiveCheckInFromPersistence()
            loadLatestCheckIn()
        case .weight:
            guard let weightKg = draft.weightKg else {
                return
            }

            persistenceStore.updateWeightEntry(id: draft.id, weightKg: weightKg, note: draft.note)
        case .meal:
            guard let mealKind = draft.mealKind else {
                return
            }

            persistenceStore.updateMealLog(id: draft.id, kind: mealKind, note: draft.note)
        }

        reloadLogsForCurrentFilter()
    }

    private func deleteLog(_ log: EditableLog) {
        switch log {
        case let .subjective(record):
            persistenceStore.deleteSubjectiveCheckIn(id: record.id)
            store.refreshSubjectiveCheckInFromPersistence()
            loadLatestCheckIn()
        case let .weight(record):
            persistenceStore.deleteWeightEntry(id: record.id)
        case let .meal(record):
            persistenceStore.deleteMealLog(id: record.id)
        }

        reloadLogsForCurrentFilter()
    }

    private func requestDelete(_ log: EditableLog) {
        pendingDeleteLog = log
    }

    private func confirmPendingDelete() {
        guard let log = pendingDeleteLog else {
            return
        }

        pendingDeleteLog = nil
        deleteLog(log)
    }
}

private struct SubjectiveSliderRow: View {
    let title: String
    @Binding var value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.14), in: Capsule())
            }

            Slider(value: $value, in: 1 ... 10, step: 1)
                .tint(color)
                .accessibilityLabel(title)
        }
    }
}

private struct CheckInMetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.bcMuted)
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
    }
}

private enum LogDateFilter: String, CaseIterable, Identifiable {
    case today
    case sevenDays
    case all

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .today:
            return "今天"
        case .sevenDays:
            return "7天"
        case .all:
            return "全部"
        }
    }

    var fetchLimit: Int? {
        nil
    }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .sevenDays:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(-6 * 86_400)
            return date >= start
        case .all:
            return true
        }
    }
}

private enum LogKindFilter: String, CaseIterable, Identifiable {
    case all
    case subjective
    case weight
    case meal

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .subjective:
            return "主观"
        case .weight:
            return "体重"
        case .meal:
            return "饮食"
        }
    }

    func contains(_ kind: EditableLogKind) -> Bool {
        switch (self, kind) {
        case (.all, _), (.subjective, .subjective), (.weight, .weight), (.meal, .meal):
            return true
        default:
            return false
        }
    }
}

private struct CheckInHistoryRowView: View {
    let record: SubjectiveCheckIn
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)
                .background(statusColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text(record.source)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                HStack(spacing: 8) {
                    miniMetric(title: "压力", value: record.stress)
                    miniMetric(title: "疲劳", value: record.fatigue)
                    miniMetric(title: "饥饿", value: record.hunger)
                }
            }

            Menu {
                Button {
                    edit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    delete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcMuted)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var iconName: String {
        record.averageLoad >= 7 ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        switch record.averageLoad {
        case 0 ..< 4:
            return .bcMint
        case 4 ..< 7:
            return .bcBlue
        default:
            return .bcAmber
        }
    }

    private func miniMetric(title: String, value: Int) -> some View {
        Text("\(title) \(value)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.bcSoft)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06), in: Capsule())
    }
}

private enum EditableLogKind {
    case subjective
    case weight
    case meal

    var displayName: String {
        switch self {
        case .subjective:
            return "主观"
        case .weight:
            return "体重"
        case .meal:
            return "饮食"
        }
    }
}

private enum EditableLog: Identifiable {
    case subjective(SubjectiveCheckIn)
    case weight(WeightEntry)
    case meal(MealLogEntry)

    var id: UUID {
        switch self {
        case let .subjective(record):
            return record.id
        case let .weight(record):
            return record.id
        case let .meal(record):
            return record.id
        }
    }

    var kind: EditableLogKind {
        switch self {
        case .subjective:
            return .subjective
        case .weight:
            return .weight
        case .meal:
            return .meal
        }
    }

    var title: String {
        switch self {
        case .subjective:
            return "编辑主观记录"
        case .weight:
            return "编辑体重"
        case .meal:
            return "编辑饮食简记"
        }
    }

    var capturedAt: Date {
        switch self {
        case let .subjective(record):
            return record.capturedAt
        case let .weight(record):
            return record.capturedAt
        case let .meal(record):
            return record.capturedAt
        }
    }
}

private struct EditableLogDraft {
    let id: UUID
    let kind: EditableLogKind
    var stress: Int?
    var fatigue: Int?
    var hunger: Int?
    var weightKg: Double?
    var mealKind: MealLogKind?
    var note: String
}

private struct RecentLogRow: Identifiable {
    let id: UUID
    let kind: EditableLogKind
    let date: Date
    let iconName: String
    let title: String
    let detail: String
    let source: String
    let color: Color
    let editableLog: EditableLog

    var searchText: String {
        [
            kind.displayName,
            title,
            detail,
            source,
            date.formatted(date: .abbreviated, time: .shortened)
        ].joined(separator: " ")
    }
}

private struct RecentLogRowView: View {
    let row: RecentLogRow
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: row.iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(row.color)
                .frame(width: 30, height: 30)
                .background(row.color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(row.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    Text(row.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }

                Text(row.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .lineLimit(2)
            }

            Text(row.source)
                .font(.caption2.weight(.bold))
                .foregroundStyle(row.color)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(row.color.opacity(0.12), in: Capsule())

            Menu {
                Button {
                    edit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    delete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcMuted)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LogEditSheet: View {
    let log: EditableLog
    let save: (EditableLogDraft) -> Void
    let delete: (EditableLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stress = 5.0
    @State private var fatigue = 4.0
    @State private var hunger = 5.0
    @State private var weightText = ""
    @State private var note = ""
    @State private var mealKind: MealLogKind = .normal
    @State private var showsDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(log.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }

                switch log {
                case .subjective:
                    Section("主观状态") {
                        SubjectiveSliderRow(title: "压力", value: $stress, color: .bcViolet)
                        SubjectiveSliderRow(title: "疲劳", value: $fatigue, color: .bcAmber)
                        SubjectiveSliderRow(title: "饥饿", value: $hunger, color: .bcBlue)
                    }
                case .weight:
                    Section("体重") {
                        TextField("体重 kg", text: $weightText)
                            .keyboardType(.decimalPad)
                        TextField("备注", text: $note, axis: .vertical)
                            .lineLimit(2 ... 4)
                    }
                case .meal:
                    Section("饮食") {
                        Picker("类型", selection: $mealKind) {
                            ForEach(MealLogKind.allCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }

                        TextField("备注", text: $note, axis: .vertical)
                            .lineLimit(2 ... 4)
                    }
                }

                Section {
                    Button("删除记录", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle(log.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            loadDraft()
        }
        .confirmationDialog(
            "删除这条记录？",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                delete(log)
                dismiss()
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后会刷新本地记录和今日评分。")
        }
    }

    private var canSave: Bool {
        switch log {
        case .subjective, .meal:
            return true
        case .weight:
            return weightText.decimalValue != nil
        }
    }

    private var draft: EditableLogDraft {
        EditableLogDraft(
            id: log.id,
            kind: log.kind,
            stress: Int(stress.rounded()),
            fatigue: Int(fatigue.rounded()),
            hunger: Int(hunger.rounded()),
            weightKg: weightText.decimalValue,
            mealKind: mealKind,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func loadDraft() {
        switch log {
        case let .subjective(record):
            stress = Double(record.stress)
            fatigue = Double(record.fatigue)
            hunger = Double(record.hunger)
        case let .weight(record):
            weightText = record.weightKg.oneDecimalString
            note = record.note
        case let .meal(record):
            mealKind = record.kind
            note = record.note
        }
    }
}

private struct GoalPlanView: View {
    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore

    @State private var startWeightText = ""
    @State private var targetWeightText = ""
    @State private var weeklyLossText = "0.5"
    @State private var workoutMinutesText = "35"
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var usesTargetDate = true
    @State private var dietaryNotes = ""
    @State private var workScheduleNotes = ""
    @State private var didLoadGoal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    currentGoalCard
                    goalQualityCard
                    goalFormCard
                    weeklyReviewCard
                    adjustmentAdviceCard
                    weeklyActionCard
                    planBoundaryCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
            .background(BodyCoachBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            loadGoalIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            VitalLoopWordmark()
            Text("减脂计划")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
            Text("先设置目标和可执行边界，今日建议会结合身体信号动态调整。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.bcSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentGoalCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("当前目标")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    Text(persistenceStore.currentGoal?.goalType.displayName ?? "未设置")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bcMint.opacity(0.14), in: Capsule())
                }

                if let goal = persistenceStore.currentGoal {
                    GoalProgressMeter(progress: goalProgressRatio(goal), color: goalProgressColor(goal))

                    HStack(spacing: 10) {
                        GoalMetric(title: "当前", value: currentWeight(for: goal)?.oneDecimalString ?? "--", unit: "kg", color: .bcBlue)
                        GoalMetric(title: "目标", value: goal.targetWeightKg?.oneDecimalString ?? "--", unit: "kg", color: .bcMint)
                        GoalMetric(title: "剩余", value: remainingWeightLoss(for: goal)?.oneDecimalString ?? "--", unit: "kg", color: .bcAmber)
                    }

                    Text(goalProgressText(goal))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("还没有减脂目标。设置后，VitalLoop 会把目标体重、周期、运动时间和饮食约束纳入今日建议。")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var goalFormCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("目标设置")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.bcInk)

                HStack(spacing: 12) {
                    DecimalField(title: "当前体重", text: $startWeightText, unit: "kg")
                    DecimalField(title: "目标体重", text: $targetWeightText, unit: "kg")
                }

                HStack(spacing: 12) {
                    DecimalField(title: "周下降目标", text: $weeklyLossText, unit: "kg")
                    DecimalField(title: "训练时长", text: $workoutMinutesText, unit: "分钟")
                }

                Toggle(isOn: $usesTargetDate) {
                    Text("设置目标日期")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                }
                .tint(Color.bcMint)

                if usesTargetDate {
                    DatePicker("目标日期", selection: $targetDate, displayedComponents: .date)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                        .tint(Color.bcMint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("饮食约束")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                    TextField("例如：不吃牛肉、晚餐在公司、控制外卖", text: $dietaryNotes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2 ... 4)
                        .foregroundStyle(Color.bcInk)
                        .padding(12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("工作与可运动时间")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                    TextField("例如：10:00-19:00 上班，午休可走路", text: $workScheduleNotes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2 ... 4)
                        .foregroundStyle(Color.bcInk)
                        .padding(12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    saveGoal()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("保存减脂目标")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.03, green: 0.08, blue: 0.07))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.bcMint, in: Capsule())
                }
                .buttonStyle(.plain)

                if let error = persistenceStore.lastPersistenceError {
                    Text("本地存储状态：\(error)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.bcAmber)
                }
            }
        }
    }

    private var goalQualityCard: some View {
        let quality = goalQuality

        return GlassCard(cornerRadius: 24, padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: quality.symbolName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(quality.color)
                    .frame(width: 38, height: 38)
                    .background(quality.color.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("目标质量检查")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcInk)

                        Spacer()

                        Text(quality.badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(quality.color)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(quality.color.opacity(0.14), in: Capsule())
                    }

                    Text(quality.message)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var weeklyReviewCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("7 日复盘")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    Text(reviewCoverageText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bcBlue.opacity(0.14), in: Capsule())
                }

                PlanReviewBars(records: weeklyReviewRecords)
                    .frame(height: 86)

                HStack(spacing: 10) {
                    GoalMetric(title: "均分", value: weeklyAverageScoreText, unit: "分", color: .bcMint)
                    GoalMetric(title: "恢复", value: weeklyRecoveryText, unit: "分", color: .bcBlue)
                    GoalMetric(title: "可信度", value: weeklyCompletenessText, unit: "%", color: .bcViolet)
                }

                Text(weeklyReviewSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var adjustmentAdviceCard: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: adjustmentAdvice.symbolName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(adjustmentAdvice.color)
                    .frame(width: 38, height: 38)
                    .background(adjustmentAdvice.color.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目标调整建议")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Spacer()
                        Text(adjustmentAdvice.badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(adjustmentAdvice.color)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(adjustmentAdvice.color.opacity(0.14), in: Capsule())
                    }

                    Text(adjustmentAdvice.message)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var weeklyActionCard: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("本周行动")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    Spacer()

                    Text("3 项")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.bcMint.opacity(0.14), in: Capsule())
                }

                VStack(spacing: 8) {
                    ForEach(Array(weeklyActions.enumerated()), id: \.offset) { index, action in
                        PlanActionRow(index: index + 1, text: action)
                    }
                }
            }
        }
    }

    private var planBoundaryCard: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.bcAmber)
                    .frame(width: 38, height: 38)
                    .background(Color.bcAmber.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("计划边界")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Text("当前版本不会计算极端热量缺口，也不会根据单日体重波动突然加大训练。目标只用于调整建议优先级和解释。")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.bcSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func loadGoalIfNeeded() {
        guard !didLoadGoal else {
            return
        }

        didLoadGoal = true
        persistenceStore.loadRecentLogs()

        let latestWeight = latestManualWeightKg ?? store.dashboardSnapshot.weightKg
        guard let goal = persistenceStore.currentGoal else {
            if let weight = latestWeight {
                startWeightText = weight.oneDecimalString
            }
            return
        }

        startWeightText = goal.startWeightKg?.oneDecimalString ?? latestWeight?.oneDecimalString ?? ""
        targetWeightText = goal.targetWeightKg?.oneDecimalString ?? ""
        weeklyLossText = goal.weeklyWeightLossTargetKg?.oneDecimalString ?? "0.5"
        workoutMinutesText = goal.preferredWorkoutMinutes.map(String.init) ?? "35"
        if let date = goal.targetDate {
            targetDate = date
            usesTargetDate = true
        } else {
            usesTargetDate = false
        }
        dietaryNotes = goal.dietaryNotes
        workScheduleNotes = goal.workScheduleNotes
    }

    private func saveGoal() {
        store.saveFatLossGoal(
            startWeightKg: startWeightText.decimalValue,
            targetWeightKg: targetWeightText.decimalValue,
            targetDate: usesTargetDate ? targetDate : nil,
            weeklyWeightLossTargetKg: weeklyLossText.decimalValue,
            preferredWorkoutMinutes: workoutMinutesText.integerValue,
            dietaryNotes: dietaryNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            workScheduleNotes: workScheduleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func goalProgressText(_ goal: UserGoal) -> String {
        guard let target = goal.targetWeightKg
        else {
            return "请补齐当前体重和目标体重，建议才会更有针对性。"
        }

        let current = currentWeight(for: goal) ?? goal.startWeightKg
        guard let current else {
            return "缺少当前体重，暂时只能保存目标，不能判断进度。"
        }

        let remaining = max(current - target, 0)
        var parts = ["计划下降 \(remaining.oneDecimalString)kg"]

        if let date = goal.targetDate {
            parts.append("目标日期 \(date.formatted(date: .abbreviated, time: .omitted))")
        }

        if let weekly = goal.weeklyWeightLossTargetKg {
            parts.append("每周约 \(weekly.oneDecimalString)kg")
        }

        return parts.joined(separator: " · ")
    }

    private func currentWeight(for goal: UserGoal) -> Double? {
        latestManualWeightKg ?? store.dashboardSnapshot.weightKg ?? goal.startWeightKg
    }

    private var latestManualWeightKg: Double? {
        persistenceStore.recentWeightEntries.first?.weightKg
    }

    private func remainingWeightLoss(for goal: UserGoal) -> Double? {
        guard let current = currentWeight(for: goal),
              let target = goal.targetWeightKg
        else {
            return nil
        }

        return max(current - target, 0)
    }

    private func goalProgressRatio(_ goal: UserGoal) -> Double {
        guard let start = goal.startWeightKg,
              let target = goal.targetWeightKg,
              start > target,
              let current = currentWeight(for: goal)
        else {
            return 0
        }

        let total = start - target
        let completed = start - current
        return min(max(completed / total, 0), 1)
    }

    private func goalProgressColor(_ goal: UserGoal) -> Color {
        switch goalProgressRatio(goal) {
        case 0.66 ... 1:
            return .bcMint
        case 0.25 ..< 0.66:
            return .bcBlue
        default:
            return .bcAmber
        }
    }

    private var weeklyReviewRecords: [DailySummaryRecord] {
        Array(persistenceStore.recentDailySummaries.prefix(7).reversed())
    }

    private var reviewCoverageText: String {
        "\(weeklyReviewRecords.count)/7 天"
    }

    private var weeklyAverageScore: Double? {
        average(weeklyReviewRecords.map { Double($0.overallScore) })
    }

    private var weeklyAverageScoreText: String {
        weeklyAverageScore.map { Int($0.rounded()).description } ?? "--"
    }

    private var weeklyRecoveryText: String {
        average(weeklyReviewRecords.map { Double($0.recoveryScore) }).map { Int($0.rounded()).description } ?? "--"
    }

    private var weeklyCompletenessText: String {
        average(weeklyReviewRecords.map { Double($0.dataCompleteness) }).map { Int($0.rounded()).description } ?? "--"
    }

    private var weeklyReviewSummary: String {
        guard weeklyReviewRecords.count >= 3 else {
            return "连续摘要不足 3 天。先保持 Apple Watch 佩戴、体重记录和主观记录，再做周调整。"
        }

        let averageScore = weeklyAverageScore ?? 0
        let averageRecovery = average(weeklyReviewRecords.map { Double($0.recoveryScore) }) ?? 0
        let lowRecoveryDays = weeklyReviewRecords.filter { $0.recoveryScore < 62 || $0.sleepScore < 65 }.count

        if lowRecoveryDays >= 3 {
            return "本周恢复或睡眠偏低的天数较多，减脂计划应优先稳住睡眠，不建议增加训练强度。"
        }

        if averageScore >= 74 && averageRecovery >= 66 {
            return "本周身体信号整体稳定，可以维持当前训练时长和饮食节奏。"
        }

        return "本周状态中等，建议先提高数据完整度和日常步行稳定性，再调整热量缺口。"
    }

    private var adjustmentAdvice: GoalAdjustmentAdvice {
        guard let goal = persistenceStore.currentGoal else {
            return GoalAdjustmentAdvice(
                badge: "待设置",
                symbolName: "target",
                color: .bcMuted,
                message: "先设置当前体重、目标体重和目标日期，VitalLoop 才能判断目标节奏是否合理。"
            )
        }

        guard let current = currentWeight(for: goal),
              let target = goal.targetWeightKg,
              current > target
        else {
            return GoalAdjustmentAdvice(
                badge: "缺体重",
                symbolName: "scale.3d",
                color: .bcAmber,
                message: "缺少当前体重或目标体重。先补齐体重输入，避免用错误基线生成计划。"
            )
        }

        let remaining = current - target
        let requiredWeeklyLoss = requiredWeeklyLossKg(remaining: remaining, targetDate: goal.targetDate)
        let selectedWeekly = goal.weeklyWeightLossTargetKg
        let scoreAverage = weeklyAverageScore
        let recoveryAverage = average(weeklyReviewRecords.map { Double($0.recoveryScore) })

        if let requiredWeeklyLoss, requiredWeeklyLoss > 0.8 {
            return GoalAdjustmentAdvice(
                badge: "偏激进",
                symbolName: "exclamationmark.triangle.fill",
                color: .bcAmber,
                message: "按当前日期需要每周下降 \(requiredWeeklyLoss.oneDecimalString)kg，节奏偏快。建议延长目标日期或把周下降控制在 0.3-0.7kg。"
            )
        }

        if let selectedWeekly, selectedWeekly > 0.8 {
            return GoalAdjustmentAdvice(
                badge: "需放缓",
                symbolName: "speedometer",
                color: .bcAmber,
                message: "你设置的每周下降 \(selectedWeekly.oneDecimalString)kg 偏快。先保证睡眠和恢复，不要用极端热量缺口推进。"
            )
        }

        if let recoveryAverage, recoveryAverage < 62 {
            return GoalAdjustmentAdvice(
                badge: "先恢复",
                symbolName: "bed.double.fill",
                color: .bcBlue,
                message: "近 7 日恢复均分偏低。下一周不要上调训练量，优先把睡眠和低强度活动做稳定。"
            )
        }

        if let scoreAverage, scoreAverage >= 74 {
            return GoalAdjustmentAdvice(
                badge: "可维持",
                symbolName: "checkmark.seal.fill",
                color: .bcMint,
                message: "近期状态支持当前计划。继续保持训练时长、饮食结构和体重记录，不需要频繁改目标。"
            )
        }

        return GoalAdjustmentAdvice(
            badge: "保守推进",
            symbolName: "arrow.triangle.2.circlepath",
            color: .bcMint,
            message: "目标节奏暂时合理。下一步重点是提高记录连续性，让每周复盘更可信。"
        )
    }

    private var goalQuality: GoalAdjustmentAdvice {
        guard let goal = persistenceStore.currentGoal else {
            return GoalAdjustmentAdvice(
                badge: "待设置",
                symbolName: "target",
                color: .bcMuted,
                message: "先填写当前体重、目标体重、周下降目标和可运动时间，保存后这里会检查计划是否可执行。"
            )
        }

        guard let current = currentWeight(for: goal), let target = goal.targetWeightKg else {
            return GoalAdjustmentAdvice(
                badge: "缺核心数据",
                symbolName: "exclamationmark.circle.fill",
                color: .bcAmber,
                message: "当前体重或目标体重不完整。先在记录页补一次体重，再保存计划。"
            )
        }

        guard current > target else {
            return GoalAdjustmentAdvice(
                badge: "目标反向",
                symbolName: "arrow.down.right.circle.fill",
                color: .bcAmber,
                message: "目标体重需要低于当前体重。若不是减脂目标，后续需要单独增加其他目标类型。"
            )
        }

        let remaining = current - target
        let requiredWeeklyLoss = requiredWeeklyLossKg(remaining: remaining, targetDate: goal.targetDate)

        if remaining > current * 0.2 {
            return GoalAdjustmentAdvice(
                badge: "跨度偏大",
                symbolName: "flag.checkered.circle.fill",
                color: .bcAmber,
                message: "目标下降超过当前体重 20%。建议拆成阶段目标，先完成 5%-10% 的第一阶段。"
            )
        }

        if let requiredWeeklyLoss, requiredWeeklyLoss > 0.8 {
            return GoalAdjustmentAdvice(
                badge: "日期偏紧",
                symbolName: "calendar.badge.exclamationmark",
                color: .bcAmber,
                message: "按目标日期需要每周下降 \(requiredWeeklyLoss.oneDecimalString)kg，建议延长日期或降低目标幅度。"
            )
        }

        if let weekly = goal.weeklyWeightLossTargetKg, weekly > 0.8 {
            return GoalAdjustmentAdvice(
                badge: "周目标偏快",
                symbolName: "speedometer",
                color: .bcAmber,
                message: "周下降目标高于 0.8kg。更稳妥的范围通常是 0.3-0.7kg，并根据恢复状态调整。"
            )
        }

        if goal.preferredWorkoutMinutes == nil || (goal.preferredWorkoutMinutes ?? 0) < 20 {
            return GoalAdjustmentAdvice(
                badge: "执行边界弱",
                symbolName: "figure.walk.circle.fill",
                color: .bcBlue,
                message: "建议补充可持续的运动时间。哪怕每天 20-35 分钟，也比偶尔高强度更适合稳定推进。"
            )
        }

        return GoalAdjustmentAdvice(
            badge: "可执行",
            symbolName: "checkmark.seal.fill",
            color: .bcMint,
            message: "当前目标、日期和运动边界基本匹配。后续根据 7 日复盘决定是否微调，不要按单日波动改计划。"
        )
    }

    private var weeklyActions: [String] {
        PlanActionGenerator.actions(
            goal: persistenceStore.currentGoal,
            records: weeklyReviewRecords,
            preferredWorkoutMinutes: persistenceStore.currentGoal?.preferredWorkoutMinutes
        )
    }

    private func requiredWeeklyLossKg(remaining: Double, targetDate: Date?) -> Double? {
        guard let targetDate else {
            return nil
        }

        let weeks = targetDate.timeIntervalSince(Date()) / (7 * 24 * 60 * 60)
        guard weeks > 0.5 else {
            return nil
        }

        return remaining / weeks
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }
}

private struct GoalAdjustmentAdvice {
    let badge: String
    let symbolName: String
    let color: Color
    let message: String
}

private enum PlanActionGenerator {
    static func actions(
        goal: UserGoal?,
        records: [DailySummaryRecord],
        preferredWorkoutMinutes: Int?
    ) -> [String] {
        guard let goal else {
            return [
                "补齐当前体重和目标体重，并保存第一版减脂目标。",
                "连续 3 天记录体重、压力、疲劳和饥饿。",
                "连接 Apple 健康，确认睡眠和恢复信号可用。"
            ]
        }

        let recoveryAverage = average(records.map { Double($0.recoveryScore) })
        let completenessAverage = average(records.map { Double($0.dataCompleteness) }) ?? 0
        var actions: [String] = []

        if completenessAverage < 65 {
            actions.append("优先补齐睡眠、体重和主观记录，让复盘可信度超过 65%。")
        }

        if let recoveryAverage, recoveryAverage < 62 {
            actions.append("今天训练不加量，把睡眠时间和低强度活动先做稳定。")
        } else {
            let minutes = preferredWorkoutMinutes ?? goal.preferredWorkoutMinutes ?? 30
            actions.append("维持每次 \(minutes) 分钟以内的可持续训练，不按单日状态突然加量。")
        }

        if let weekly = goal.weeklyWeightLossTargetKg {
            actions.append("按每周 \(weekly.oneDecimalString)kg 的节奏观察，不因单日体重波动改变目标。")
        } else {
            actions.append("设置一个 0.3-0.7kg 的周下降参考值，便于下周复盘。")
        }

        actions.append("记录 1 条饮食简记，标记是否偏多、偏少或高油高糖。")
        return Array(actions.prefix(3))
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }
}

private struct PlanActionRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color(red: 0.03, green: 0.08, blue: 0.07))
                .frame(width: 24, height: 24)
                .background(Color.bcMint, in: Circle())

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.bcSoft)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct GoalProgressMeter: View {
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("目标进度")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcMuted)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.78), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(progress)))
                }
            }
            .frame(height: 10)
        }
        .accessibilityLabel("目标进度 \(Int((progress * 100).rounded()))%")
    }
}

private struct PlanReviewBars: View {
    let records: [DailySummaryRecord]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(displayRecords, id: \.id) { item in
                VStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(item.record.map(color(for:)) ?? Color.white.opacity(0.08))
                        .frame(height: item.record.map { height(for: $0) } ?? 18)
                        .overlay(alignment: .top) {
                            if let record = item.record, record.dataCompleteness < 60 {
                                Circle()
                                    .fill(Color.bcAmber)
                                    .frame(width: 5, height: 5)
                                    .offset(y: -8)
                            }
                        }

                    Text(item.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private var displayRecords: [PlanReviewBarItem] {
        let calendar = Calendar.current
        let days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: Date()))
        }
        return days.map { day in
            let record = records.first { calendar.isDate($0.date, inSameDayAs: day) }
            let label = calendar.isDateInToday(day) ? "今" : day.formatted(.dateTime.weekday(.narrow))
            return PlanReviewBarItem(id: day.timeIntervalSince1970, label: label, record: record)
        }
    }

    private func height(for record: DailySummaryRecord) -> CGFloat {
        let normalized = CGFloat(min(max(record.overallScore, 35), 100)) / 100
        return 18 + normalized * 54
    }

    private func color(for record: DailySummaryRecord) -> Color {
        if record.recoveryScore < 62 || record.sleepScore < 65 {
            return .bcAmber
        }

        if record.overallScore >= 74 {
            return .bcMint
        }

        return .bcBlue
    }
}

private struct PlanReviewBarItem {
    let id: TimeInterval
    let label: String
    let record: DailySummaryRecord?
}

private struct GoalMetric: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.bcMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.bcInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(unit)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.bcMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct DecimalField: View {
    let title: String
    @Binding var text: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.bcMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("--", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.bcInk)
                    .textFieldStyle(.plain)
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcMuted)
            }
            .padding(12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RhythmCard: View {
    private let values: [Double] = [0.34, 0.45, 0.55, 0.82, 0.9, 0.86, 0.62, 0.5, 0.38, 0.31, 0.42, 0.68, 0.76, 0.91, 0.7, 0.58, 0.52, 0.74, 0.82, 0.45, 0.34]

    var body: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("日内节律")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Text("0:00 - 24:00")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.bcMuted)
                    }
                    Spacer()
                    Text("睡眠 · 工作 · 运动窗口 · 恢复")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.bcSoft)
                }

                MiniBars(values: values)
                    .frame(height: 84)

                HStack {
                    TimelineLabel(title: "睡眠", color: .bcViolet)
                    Spacer()
                    TimelineLabel(title: "工作", color: .bcAmber)
                    Spacer()
                    TimelineLabel(title: "运动窗口", color: .bcMint)
                    Spacer()
                    TimelineLabel(title: "恢复", color: .bcBlue)
                }
            }
        }
    }
}

private struct MetricTile: View {
    let title: String
    let display: MetricDisplay
    let color: Color
    let trend: DashboardTrendSeries

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcSoft)
                    Spacer()
                    Text(trend.coverageLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                    Text(display.status)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.15), in: Capsule())
                }

                if trend.hasEnoughData {
                    Sparkline(values: trend.normalizedValues, color: color)
                        .frame(height: 44)
                        .accessibilityLabel("\(title) 7 日趋势")
                } else {
                    TrendUnavailableView(color: color)
                        .frame(height: 44)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(display.value)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.bcInk)
                    Text(display.unit)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.bcMuted)
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: display.noteTone == .warning ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(display.noteTone == .warning ? Color.bcAmber : color)
                        .padding(.top, 1)
                    Text(display.note)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(display.noteTone == .warning ? Color.bcAmber.opacity(0.95) : Color.bcSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct TrendUnavailableView: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.bold))
                    Text("趋势不足")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(color.opacity(0.86))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            }
            .accessibilityLabel("趋势数据不足")
    }
}

private struct InsightTable: View {
    let summary: DailyBodySummary
    let dashboardSnapshot: BodyDashboardSnapshot

    var body: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("身体信号表")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bcInk)
                    Spacer()
                    Text("可信度 \(summary.score.dataCompleteness)%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcMint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bcMint.opacity(0.14), in: Capsule())
                }

                SignalRow(title: "恢复", value: "\(summary.score.recovery)", detail: recoveryDetail, color: .bcBlue)
                Divider().overlay(Color.white.opacity(0.08))
                SignalRow(title: "睡眠", value: "\(summary.score.sleep)", detail: sleepDetail, color: .bcAmber)
                Divider().overlay(Color.white.opacity(0.08))
                SignalRow(title: "活动", value: "\(summary.score.activity)", detail: activityDetail, color: .bcMint)
                Divider().overlay(Color.white.opacity(0.08))
                SignalRow(title: "体重", value: "\(summary.score.weightTrend)", detail: weightDetail, color: .bcViolet)
            }
        }
    }

    private var recoveryDetail: String {
        if let hrv = dashboardSnapshot.hrvMs, let resting = dashboardSnapshot.restingHeartRateBpm {
            return "HRV \(Int(hrv.rounded()))ms，静息心率 \(Int(resting.rounded())) bpm。"
        }

        if dashboardSnapshot.hrvMs != nil || dashboardSnapshot.restingHeartRateBpm != nil {
            return "恢复信号不完整，暂时只作趋势参考。"
        }

        return "缺少 HRV 和静息心率，恢复判断可信度较低。"
    }

    private var sleepDetail: String {
        guard let sleep = dashboardSnapshot.sleepMinutes else {
            return "缺少睡眠数据，建议先佩戴手表睡眠。"
        }

        return sleep >= 420 ? "睡眠时长达到基础目标。" : "睡眠时长偏短，今晚优先提前入睡。"
    }

    private var activityDetail: String {
        guard let activeEnergy = dashboardSnapshot.activeEnergyKcal else {
            return "缺少活动能量，先保持轻活动记录。"
        }

        let goal = dashboardSnapshot.activeEnergyGoalKcal ?? 800
        return activeEnergy >= goal ? "活动量已达到今日目标。" : "活动量未满，适合低强度补足。"
    }

    private var weightDetail: String {
        if let delta = dashboardSnapshot.weightSevenDayDeltaKg {
            return "7 日体重变化 \(delta.signedOneDecimalString)kg。"
        }

        if let weight = dashboardSnapshot.weightKg {
            return "最近体重 \(weight.oneDecimalString)kg，缺少 7 日趋势。"
        }

        return "缺少体重记录，暂不判断趋势。"
    }
}

private struct SignalRow: View {
    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 38, height: 38)
                .overlay {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
        }
    }
}

private struct RecommendationSection: View {
    let recommendations: [DailyRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日建议")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.bcInk)

            ForEach(recommendations.prefix(3), id: \.title) { recommendation in
                GlassCard(cornerRadius: 24, padding: 14) {
                    HStack(spacing: 14) {
                        Image(systemName: recommendation.type.symbolName)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Color.bcInk)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(recommendation.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.bcInk)
                            Text(recommendation.rationale)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.bcSoft)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct TodayPlanActionSection: View {
    let actions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日计划行动")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.bcInk)

                Spacer()

                Text("来自计划")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.bcMint.opacity(0.14), in: Capsule())
            }

            GlassCard(cornerRadius: 24, padding: 14) {
                VStack(spacing: 8) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                        PlanActionRow(index: index + 1, text: action)
                    }
                }
            }
        }
    }
}

private struct PlaceholderSection: View {
    let title: String
    let subtitle: String
    let symbolName: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: symbolName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.bcMint)
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                Text(subtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.bcSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BodyCoachBackground())
        }
    }
}

private struct ScoreDial: View {
    let score: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 18)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(Color.bcMint, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: 0.68)
                .stroke(Color.bcBlue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(30))
                .padding(22)
            Circle()
                .trim(from: 0, to: 0.58)
                .stroke(Color.bcAmber, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-20))
                .padding(38)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.bcInk)
                Text("综合分")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.bcMuted)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct StatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.15), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.45), lineWidth: 1)
            }
    }
}

private struct TimelineLabel: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
    }
}

private struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 16
    let content: Content

    init(cornerRadius: CGFloat = 28, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.bcCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.bcStroke, lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
            }
    }
}

private struct MiniBars: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 5
            let width = max(4, (proxy.size.width - spacing * CGFloat(values.count - 1)) / CGFloat(values.count))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                        .fill(color(for: index).opacity(index % 3 == 0 ? 0.95 : 0.55))
                        .frame(width: width, height: max(12, proxy.size.height * value))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func color(for index: Int) -> Color {
        switch index {
        case 3 ... 6:
            return .bcMint
        case 11 ... 14:
            return .bcMint
        case 17 ... 18:
            return .bcBlue
        default:
            return .white.opacity(0.18)
        }
    }
}

private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = proxy.size.height * CGFloat(1 - min(max(value, 0), 1))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct TrendValueSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))

            if normalizedValues.count >= 2 {
                Sparkline(values: normalizedValues, color: color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("趋势不足")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(color.opacity(0.86))
            }
        }
    }

    private var normalizedValues: [Double] {
        guard values.count >= 2, let minValue = values.min(), let maxValue = values.max() else {
            return []
        }

        let range = max(maxValue - minValue, 0.1)
        return values.map { value in
            0.12 + ((value - minValue) / range) * 0.76
        }
    }
}

private struct BodyCoachBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.bcBackgroundTop,
                Color.bcBackground,
                Color.bcBackgroundBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private extension Color {
    static let bcBackground = Color(red: 0.035, green: 0.048, blue: 0.052)
    static let bcBackgroundTop = Color(red: 0.055, green: 0.078, blue: 0.071)
    static let bcBackgroundBottom = Color(red: 0.025, green: 0.032, blue: 0.042)
    static let bcCard = Color(red: 0.105, green: 0.122, blue: 0.125)
    static let bcStroke = Color.white.opacity(0.13)
    static let bcInk = Color(red: 0.94, green: 0.965, blue: 0.955)
    static let bcSoft = Color(red: 0.72, green: 0.77, blue: 0.79)
    static let bcMuted = Color(red: 0.49, green: 0.54, blue: 0.58)
    static let bcMint = Color(red: 0.55, green: 0.91, blue: 0.72)
    static let bcBlue = Color(red: 0.43, green: 0.68, blue: 0.92)
    static let bcAmber = Color(red: 0.96, green: 0.68, blue: 0.39)
    static let bcViolet = Color(red: 0.62, green: 0.56, blue: 0.86)
}

private extension String {
    var decimalValue: Double? {
        let normalized = replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    var integerValue: Int? {
        guard let decimalValue else {
            return nil
        }

        return Int(decimalValue.rounded())
    }
}

#Preview {
    BodyCoachRootView(
        store: BodySummaryStore(),
        persistenceStore: BodyCoachPersistenceStore(),
        reminderStore: BodyCoachReminderStore()
    )
        .modelContainer(
            for: [
                UserGoal.self,
                DailySummaryRecord.self,
                SubjectiveCheckIn.self,
                WeightEntry.self,
                MealLogEntry.self
            ],
            inMemory: true
        )
}
