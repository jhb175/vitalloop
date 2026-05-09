import BodyCoachCore
import SwiftData
import SwiftUI

struct BodyCoachRootView: View {
    @Environment(\.modelContext) private var modelContext

    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore

    var body: some View {
        TabView {
            TodayDashboardView(
                summary: store.summary,
                dashboardSnapshot: store.dashboardSnapshot,
                dashboardTrends: store.dashboardTrends,
                permissionState: store.permissionState,
                dataSource: store.dataSource,
                lastUpdated: store.lastUpdated,
                subjectiveCheckIn: store.latestSubjectiveCheckIn,
                connectAppleHealth: {
                    await store.connectAppleHealth()
                }
            )
                .tabItem {
                    Label("今日", systemImage: "heart.fill")
                }

            TrendHistoryView(persistenceStore: persistenceStore)
                .tabItem {
                    Label("趋势", systemImage: "waveform.path.ecg")
                }

            GoalPlanView(store: store, persistenceStore: persistenceStore)
                .tabItem {
                    Label("计划", systemImage: "checklist")
                }

            CheckInLogView(store: store)
                .tabItem {
                    Label("记录", systemImage: "plus")
                }

            SettingsPrivacyView(store: store, persistenceStore: persistenceStore)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .tint(Color.bcMint)
        .task {
            persistenceStore.configure(modelContext: modelContext)
            store.configurePersistence(persistenceStore)
            store.activateWatchSync()
        }
    }
}

private struct TodayDashboardView: View {
    let summary: DailyBodySummary
    let dashboardSnapshot: BodyDashboardSnapshot
    let dashboardTrends: BodyDashboardTrends
    let permissionState: HealthPermissionState
    let dataSource: BodySummaryDataSource
    let lastUpdated: Date?
    let subjectiveCheckIn: WatchSubjectiveCheckInPayload?
    let connectAppleHealth: () async -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    HealthConnectionCard(
                        permissionState: permissionState,
                        dataSource: dataSource,
                        lastUpdated: lastUpdated,
                        connectAppleHealth: connectAppleHealth
                    )
                    HeroStatusCard(summary: summary, dataSource: dataSource)
                    SubjectiveCheckInCard(checkIn: subjectiveCheckIn)

                    Text("今日监测")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.bcInk)

                    RhythmCard()

                    LazyVGrid(columns: columns, spacing: 12) {
                        MetricTile(title: "活动能量", display: dashboardSnapshot.activeEnergyDisplay, color: .bcMint, trend: dashboardTrends.activeEnergy)
                        MetricTile(title: "睡眠", display: dashboardSnapshot.sleepDisplay, color: .bcAmber, trend: dashboardTrends.sleep)
                        MetricTile(title: "恢复信号", display: dashboardSnapshot.recoveryDisplay, color: .bcBlue, trend: dashboardTrends.recovery)
                        MetricTile(title: "体重趋势", display: dashboardSnapshot.weightTrendDisplay, color: .bcViolet, trend: dashboardTrends.weight)
                    }

                    InsightTable(summary: summary, dashboardSnapshot: dashboardSnapshot)
                    RecommendationSection(recommendations: summary.recommendations)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(BodyCoachBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VitalLoopWordmark()
                Spacer()
                Text("晚上好")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bcInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.34), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }

            Text("身体总览")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.bcInk)
        }
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
    let connectAppleHealth: () async -> Void

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
                            await connectAppleHealth()
                            isConnecting = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .font(.caption.weight(.bold))
                            Text(isConnecting ? "连接中" : "连接 Apple 健康")
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
                    .disabled(isConnecting || permissionState == .requesting)
                }
            }
        }
    }

    private var showsConnectButton: Bool {
        switch permissionState {
        case .notRequested, .noData, .denied:
            return true
        case .unavailable, .requesting, .authorized, .partialData:
            return false
        }
    }

    private var iconName: String {
        switch permissionState {
        case .authorized:
            return "heart.text.square.fill"
        case .requesting:
            return "arrow.triangle.2.circlepath"
        case .unavailable, .denied, .noData:
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
        case .requesting:
            return .bcBlue
        case .unavailable, .denied, .noData, .partialData:
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
            return "没有读到今日健康样本，当前使用模拟数据预览。"
        case .requesting:
            return "正在向系统请求读取活动、睡眠、心率、HRV 和体重。"
        case .unavailable:
            return "当前设备无法读取 HealthKit，先使用模拟数据继续预览。"
        case .denied:
            return "没有读取到 Apple 健康数据。你可以在系统设置中检查 VitalLoop 的健康权限。"
        case .notRequested:
            return "连接后会本地读取活动、睡眠、心率、HRV 和体重摘要；原始数据默认不上传。"
        }
    }
}

private struct SettingsPrivacyView: View {
    let store: BodySummaryStore
    let persistenceStore: BodyCoachPersistenceStore

    @State private var showsDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

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

                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("删除本地记录")
                                Spacer()
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.bcAmber)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if let error = persistenceStore.lastPersistenceError {
                            Text("本地存储状态：\(error)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.bcAmber)
                        }
                    }

                    SettingsSection(title: "Apple Watch 同步") {
                        SettingsInfoRow(
                            iconName: "applewatch",
                            title: "连接状态",
                            detail: watchSyncConnectionDetail
                        )
                        SettingsInfoRow(
                            iconName: "arrow.left.arrow.right.circle.fill",
                            title: "最近事件",
                            detail: watchSyncEventDetail
                        )
                    }

                    SettingsSection(title: "隐私政策") {
                        SettingsInfoRow(
                            iconName: "doc.text.fill",
                            title: "App 内政策摘要",
                            detail: "正式上架前需要提供可访问的隐私政策网页，并在 App Store Connect 与 App 内同时展示链接。"
                        )

                        if let url = AppPrivacyLinks.privacyPolicyURL {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "safari")
                                    Text("打开隐私政策网页")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.bcMint)
                                .padding(.vertical, 4)
                            }
                        }
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
    }

    private var watchSyncConnectionDetail: String {
        let diagnostics = store.watchSyncDiagnostics
        let installed = diagnostics.isCounterpartInstalled ? "Watch app 已安装" : "Watch app 未安装"
        let reachability = diagnostics.isReachable ? "当前可达" : "当前不可达"
        return "\(diagnostics.activationState) · \(installed) · \(reachability)"
    }

    private var watchSyncEventDetail: String {
        let diagnostics = store.watchSyncDiagnostics
        if let error = diagnostics.lastError, !error.isEmpty {
            return "\(diagnostics.lastEvent)：\(error)"
        }

        if let receivedAt = diagnostics.lastReceivedAt {
            return "\(diagnostics.lastEvent) · \(receivedAt.formatted(date: .omitted, time: .shortened))"
        }

        return diagnostics.lastEvent
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

private struct SettingsInfoRow: View {
    let iconName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.bcMint)
                .frame(width: 32, height: 32)
                .background(Color.bcMint.opacity(0.13), in: Circle())

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
    }
}

private struct TrendHistoryView: View {
    let persistenceStore: BodyCoachPersistenceStore

    private var records: [DailySummaryRecord] {
        Array(persistenceStore.recentDailySummaries.prefix(14).reversed())
    }

    private var lastSevenRecords: [DailySummaryRecord] {
        Array(persistenceStore.recentDailySummaries.prefix(7).reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if records.isEmpty {
                        TrendEmptyStateCard()
                    } else {
                        trendOverviewCard
                        dimensionGrid
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
            persistenceStore.loadRecentDailySummaries()
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
        }
    }

    private var trendOverviewCard: some View {
        GlassCard(cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("14 日状态")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.bcInk)
                        Text(trendDirectionText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(trendDirectionColor)
                    }

                    Spacer()

                    Text("\(records.count)/14 天")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bcBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bcBlue.opacity(0.14), in: Capsule())
                }

                ScoreTrendChart(records: records)
                    .frame(height: 132)
                    .accessibilityLabel("14 日综合分趋势")

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

    private var dimensionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            TrendDimensionCard(title: "睡眠", value: averageText(\.sleepScore), detail: dimensionDetail(\.sleepScore), color: .bcAmber, records: records, keyPath: \.sleepScore)
            TrendDimensionCard(title: "恢复", value: averageText(\.recoveryScore), detail: dimensionDetail(\.recoveryScore), color: .bcBlue, records: records, keyPath: \.recoveryScore)
            TrendDimensionCard(title: "活动", value: averageText(\.activityScore), detail: dimensionDetail(\.activityScore), color: .bcMint, records: records, keyPath: \.activityScore)
            TrendDimensionCard(title: "体重趋势", value: averageText(\.weightTrendScore), detail: dimensionDetail(\.weightTrendScore), color: .bcViolet, records: records, keyPath: \.weightTrendScore)
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

                ForEach(Array(lastSevenRecords.reversed().enumerated()), id: \.element.id) { index, record in
                    TrendRecordRow(record: record)
                    if index < lastSevenRecords.count - 1 {
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

    private var overviewSummary: String {
        guard records.count >= 3 else {
            return "趋势至少需要 3 天摘要。每天刷新一次身体总览后，这里会逐步形成可用判断。"
        }

        let averageOverall = average(records.map { Double($0.overallScore) }) ?? 0
        let averageCompleteness = average(records.map { Double($0.dataCompleteness) }) ?? 0
        let lowRecoveryDays = records.filter { $0.recoveryScore < 62 || $0.sleepScore < 65 }.count

        if averageCompleteness < 60 {
            return "近期数据可信度偏低，先补齐睡眠、体重和主观记录，再判断计划是否有效。"
        }

        if lowRecoveryDays >= 4 {
            return "近两周恢复或睡眠低分偏多，减脂和训练计划需要先降压，不建议盲目提高活动量。"
        }

        if averageOverall >= 74 {
            return "近期状态较稳定，可以维持当前节奏，并继续观察体重和恢复趋势。"
        }

        return "近期状态中等，建议优先稳定睡眠和日常活动，再做目标节奏调整。"
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

    @State private var stress = 5.0
    @State private var fatigue = 4.0
    @State private var hunger = 5.0
    @State private var didLoadLatestCheckIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    latestCheckInCard
                    quickEntryCard
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
            loadLatestCheckIn()
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
        loadLatestCheckIn()
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
                VStack(alignment: .leading, spacing: 16) {
                    header
                    currentGoalCard
                    goalFormCard
                    weeklyReviewCard
                    adjustmentAdviceCard
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
        guard let goal = persistenceStore.currentGoal else {
            if let weight = store.dashboardSnapshot.weightKg {
                startWeightText = weight.oneDecimalString
            }
            return
        }

        startWeightText = goal.startWeightKg?.oneDecimalString ?? store.dashboardSnapshot.weightKg?.oneDecimalString ?? ""
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
        store.dashboardSnapshot.weightKg ?? goal.startWeightKg
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
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.13, blue: 0.14).opacity(0.92),
                                Color(red: 0.07, green: 0.09, blue: 0.10).opacity(0.88),
                                Color(red: 0.04, green: 0.05, blue: 0.06).opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.03),
                                        Color.bcMint.opacity(0.02),
                                        Color.black.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.34),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.black.opacity(0.36), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.38), radius: 24, x: 0, y: 16)
                    .shadow(color: Color.bcMint.opacity(0.07), radius: 18, x: -8, y: -8)
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

private struct BodyCoachBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.09),
                    Color(red: 0.02, green: 0.03, blue: 0.04),
                    Color(red: 0.08, green: 0.08, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.bcMint.opacity(0.2))
                .frame(width: 230, height: 230)
                .blur(radius: 80)
                .offset(x: -150, y: -260)

            Circle()
                .fill(Color.bcBlue.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 95)
                .offset(x: 160, y: -110)

            Circle()
                .fill(Color.bcViolet.opacity(0.15))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: 150, y: 360)
        }
        .ignoresSafeArea()
    }
}

private extension Color {
    static let bcInk = Color(red: 0.94, green: 0.97, blue: 0.98)
    static let bcSoft = Color(red: 0.74, green: 0.79, blue: 0.84)
    static let bcMuted = Color(red: 0.52, green: 0.57, blue: 0.64)
    static let bcMint = Color(red: 0.47, green: 0.92, blue: 0.73)
    static let bcBlue = Color(red: 0.31, green: 0.72, blue: 1.0)
    static let bcAmber = Color(red: 1.0, green: 0.72, blue: 0.42)
    static let bcViolet = Color(red: 0.67, green: 0.58, blue: 1.0)
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
    BodyCoachRootView(store: BodySummaryStore(), persistenceStore: BodyCoachPersistenceStore())
        .modelContainer(
            for: [
                UserGoal.self,
                DailySummaryRecord.self,
                SubjectiveCheckIn.self,
                WeightEntry.self
            ],
            inMemory: true
        )
}
