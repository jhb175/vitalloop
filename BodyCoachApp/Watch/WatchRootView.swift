import BodyCoachCore
import SwiftUI

struct WatchRootView: View {
    let store: WatchSummaryStore

    var body: some View {
        WatchDashboardPage(store: store)
        .background(WatchBackground())
    }
}

private struct WatchDashboardPage: View {
    let store: WatchSummaryStore

    private var payload: WatchSummaryPayload {
        store.payload
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchHeader(title: "数据总览", subtitle: payload.status.displayName, syncLabel: syncLabel)

                WatchHeroStrip(score: payload.score, headline: payload.headline, detail: payload.detail)

                WatchQuickLogShortcut(store: store)

                HStack(spacing: 7) {
                    metricCard(for: .heartRate)
                    metricCard(for: .activeEnergy)
                }

                HStack(spacing: 7) {
                    metricCard(for: .sleep)
                    metricCard(for: .hrv)
                }

                HStack(spacing: 7) {
                    metricCard(for: .steps)
                    metricCard(for: .weight)
                }

                WatchInlineQuickLog(store: store)

                WatchRecommendationStack(recommendations: payload.recommendations)
            }
            .padding(.horizontal, 9)
            .padding(.top, 6)
            .padding(.bottom, 26)
        }
    }

    private var syncLabel: String {
        guard store.usesLiveSync else {
            return store.syncStatusLabel
        }

        return store.syncStatusLabel
    }

    private func metricCard(for kind: WatchMetricKind) -> WatchMetricCard {
        let metric = payload.metrics.first { $0.kind == kind } ?? fallbackMetric(for: kind)
        return WatchMetricCard(
            title: metric.title,
            value: metric.value,
            unit: metric.unit,
            color: color(for: metric.kind),
            bars: metric.bars
        )
    }

    private func fallbackMetric(for kind: WatchMetricKind) -> WatchMetricPayload {
        WatchSummaryPayload.sample.metrics.first { $0.kind == kind } ?? WatchMetricPayload(title: "--", value: "--", unit: "", kind: kind, bars: [0.3, 0.4, 0.5, 0.45, 0.55])
    }

    private func color(for kind: WatchMetricKind) -> Color {
        switch kind {
        case .heartRate:
            return .watchRose
        case .activeEnergy, .weight:
            return .watchMint
        case .sleep:
            return .watchAmber
        case .hrv:
            return .watchBlue
        case .steps:
            return .watchViolet
        }
    }
}

private struct WatchRecommendationStack: View {
    let recommendations: [WatchRecommendationPayload]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日任务")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("优先 3 项")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.watchSoft)
            }

            ForEach(recommendations.prefix(3), id: \.title) { recommendation in
                WatchGlassCard(cornerRadius: 19, padding: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: recommendation.type.symbolName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.14), in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(recommendation.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(recommendation.rationale)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.watchSoft)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct WatchQuickLogShortcut: View {
    let store: WatchSummaryStore

    var body: some View {
        Button {
            store.sendCheckIn(stress: 5, fatigue: 4, hunger: 6)
        } label: {
            WatchGlassCard(cornerRadius: 18, padding: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(Color.watchMint, in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("快速记录")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("压力 5 · 疲劳 4 · 饥饿 6")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.watchSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 4)

                    Text(statusText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.watchMint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("快速记录压力五疲劳四饥饿六")
    }

    private var statusText: String {
        guard let sentAt = store.lastCheckInSentAt else {
            return "保存"
        }

        return sentAt.formatted(date: .omitted, time: .shortened)
    }
}

private struct WatchInlineQuickLog: View {
    let store: WatchSummaryStore

    @State private var stress = 5.0
    @State private var fatigue = 4.0
    @State private var hunger = 6.0

    var body: some View {
        WatchGlassCard(cornerRadius: 22, padding: 10) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("快速记录")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(syncLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.watchSoft)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Text(latestSummary)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.watchMint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.watchMint.opacity(0.13), in: Capsule())
                }

                QuickLogRow(title: "压力", value: $stress, color: .watchRose)
                QuickLogRow(title: "疲劳", value: $fatigue, color: .watchAmber)
                QuickLogRow(title: "饥饿", value: $hunger, color: .watchViolet)

                Button {
                    store.sendCheckIn(stress: stressInt, fatigue: fatigueInt, hunger: hungerInt)
                } label: {
                    WatchActionBar(title: actionTitle, detail: actionDetail)
                }
                .buttonStyle(.plain)
            }
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

    private var syncLabel: String {
        guard let sentAt = store.lastCheckInSentAt else {
            return "记录后会同步到 iPhone"
        }

        return "已保存 \(sentAt.formatted(date: .omitted, time: .shortened))"
    }

    private var latestSummary: String {
        store.latestCheckIn?.statusLabel ?? "30 秒"
    }

    private var actionTitle: String {
        store.latestCheckIn == nil ? "保存" : "更新"
    }

    private var actionDetail: String {
        "压力 \(stressInt) · 疲劳 \(fatigueInt) · 饥饿 \(hungerInt)"
    }
}

private struct WatchHeader: View {
    let title: String
    let subtitle: String
    var syncLabel: String = "同步"

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
                HStack(spacing: 4) {
                    VitalLoopLogoMark(showBackground: false)
                        .frame(width: 16, height: 16)
                    Text("VitalLoop")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .layoutPriority(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.watchMint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.watchMint.opacity(0.12), in: Capsule())

                Spacer(minLength: 4)

                Text(syncLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.watchSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                    .frame(maxWidth: 48, alignment: .trailing)
            }

            Text(title)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct WatchHeroStrip: View {
    let score: Int
    let headline: String
    let detail: String

    var body: some View {
        WatchGlassCard(cornerRadius: 24, padding: 10) {
            HStack(alignment: .center, spacing: 9) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(Color.watchMint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -1) {
                        Text("\(score)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("分")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.watchSoft)
                    }
                }
                .frame(width: 58, height: 58)
                .layoutPriority(1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.68)
                    Text(detail)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.watchSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct WatchMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let bars: [Double]

    var body: some View {
        WatchGlassCard(cornerRadius: 18, padding: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.watchSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                WatchMiniBars(values: bars, color: color)
                    .frame(height: 22)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(unit)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WatchActionBar: View {
    let title: String
    let detail: String

    var body: some View {
        WatchGlassCard(cornerRadius: 20, padding: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.black)
                    .frame(width: 29, height: 29)
                    .background(Color.watchMint, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.watchSoft)
                    Text(detail)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer()
            }
        }
    }
}

private struct QuickLogRow: View {
    let title: String
    @Binding var value: Double
    let color: Color

    var body: some View {
        WatchGlassCard(cornerRadius: 19, padding: 10) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(value.rounded())) / 10")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.13), in: Capsule())
                }

                Slider(value: $value, in: 1 ... 10, step: 1)
                    .tint(color)
                    .accessibilityLabel(title)
            }
        }
    }
}

private struct WatchMiniBars: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: max(4, (proxy.size.width - 10) / CGFloat(values.count)), height: max(7, proxy.size.height * value))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct WatchGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 10
    let content: Content

    init(cornerRadius: CGFloat = 20, padding: CGFloat = 10, @ViewBuilder content: () -> Content) {
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
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.04), Color.black.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    }
            }
    }
}

private struct WatchBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.04),
                    Color(red: 0.01, green: 0.015, blue: 0.02),
                    Color(red: 0.04, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.watchMint.opacity(0.2))
                .frame(width: 120, height: 120)
                .blur(radius: 48)
                .offset(x: -70, y: -120)

            Circle()
                .fill(Color.watchBlue.opacity(0.18))
                .frame(width: 140, height: 140)
                .blur(radius: 60)
                .offset(x: 90, y: -30)
        }
        .ignoresSafeArea()
    }
}

private extension Color {
    static let watchSoft = Color(red: 0.72, green: 0.78, blue: 0.84)
    static let watchMint = Color(red: 0.47, green: 0.92, blue: 0.73)
    static let watchBlue = Color(red: 0.31, green: 0.72, blue: 1.0)
    static let watchAmber = Color(red: 1.0, green: 0.72, blue: 0.42)
    static let watchViolet = Color(red: 0.67, green: 0.58, blue: 1.0)
    static let watchRose = Color(red: 1.0, green: 0.35, blue: 0.48)
}

#Preview {
    WatchRootView(store: WatchSummaryStore())
}
