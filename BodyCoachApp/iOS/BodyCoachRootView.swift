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

            PlaceholderSection(title: "趋势", subtitle: "睡眠、活动、恢复和体重的 7 日变化。", symbolName: "chart.line.uptrend.xyaxis")
                .tabItem {
                    Label("趋势", systemImage: "waveform.path.ecg")
                }

            GoalPlanView(store: store, persistenceStore: persistenceStore)
                .tabItem {
                    Label("计划", systemImage: "checklist")
                }

            PlaceholderSection(title: "记录", subtitle: "压力、疲劳、饥饿和饮食简记。", symbolName: "plus.circle")
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
                    .foregroundStyle(Color.bcMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
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
                    HStack(spacing: 12) {
                        GoalMetric(title: "起始", value: goal.startWeightKg?.oneDecimalString ?? "--", unit: "kg", color: .bcBlue)
                        GoalMetric(title: "目标", value: goal.targetWeightKg?.oneDecimalString ?? "--", unit: "kg", color: .bcMint)
                        GoalMetric(title: "周目标", value: goal.weeklyWeightLossTargetKg?.oneDecimalString ?? "--", unit: "kg", color: .bcAmber)
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
        guard let start = goal.startWeightKg,
              let target = goal.targetWeightKg
        else {
            return "请补齐当前体重和目标体重，建议才会更有针对性。"
        }

        let remaining = max(start - target, 0)
        var parts = ["计划下降 \(remaining.oneDecimalString)kg"]

        if let date = goal.targetDate {
            parts.append("目标日期 \(date.formatted(date: .abbreviated, time: .omitted))")
        }

        if let weekly = goal.weeklyWeightLossTargetKg {
            parts.append("每周约 \(weekly.oneDecimalString)kg")
        }

        return parts.joined(separator: " · ")
    }
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
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.03), Color.black.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 16)
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
