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

    @State private var stress = 5
    @State private var fatigue = 4
    @State private var hunger = 6

    private var payload: WatchSummaryPayload {
        store.displayPayload
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                WatchTopBar(status: payload.status.displayName, syncLabel: store.syncStatusLabel)

                WatchStatusCard(
                    score: payload.score,
                    headline: payload.headline,
                    actionText: primaryActionText
                )

                WatchCheckInCard(
                    stress: $stress,
                    fatigue: $fatigue,
                    hunger: $hunger,
                    syncDetail: store.checkInSyncDetail,
                    deliveryLabel: store.checkInDeliveryLabel
                ) {
                    store.sendCheckIn(stress: stress, fatigue: fatigue, hunger: hunger)
                }

                WatchSyncCard(
                    deliveryLabel: store.checkInDeliveryLabel,
                    latestCheckIn: store.latestCheckIn,
                    usesLiveSync: store.usesLiveSync
                )

                WatchSignalStrip(metrics: compactMetrics)
            }
            .padding(.horizontal, 9)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .onAppear(perform: loadLatestCheckIn)
        .onChange(of: store.latestCheckIn?.id) { _, _ in
            loadLatestCheckIn()
        }
    }

    private var primaryActionText: String {
        payload.recommendations
            .sorted { $0.priority < $1.priority }
            .first?
            .title ?? payload.detail
    }

    private var compactMetrics: [WatchMetricPayload] {
        [
            metric(for: .heartRate),
            metric(for: .sleep),
            metric(for: .activeEnergy)
        ]
    }

    private func metric(for kind: WatchMetricKind) -> WatchMetricPayload {
        payload.metrics.first { $0.kind == kind }
            ?? WatchSummaryPayload.sample.metrics.first { $0.kind == kind }
            ?? WatchMetricPayload(title: "--", value: "--", unit: "", kind: kind, bars: [])
    }

    private func loadLatestCheckIn() {
        guard let latestCheckIn = store.latestCheckIn else {
            return
        }

        stress = latestCheckIn.stress
        fatigue = latestCheckIn.fatigue
        hunger = latestCheckIn.hunger
    }
}

private struct WatchTopBar: View {
    let status: String
    let syncLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                Text("今日")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 4)

                Text(status)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.watchMint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.watchMint.opacity(0.14), in: Capsule())
            }

            HStack(spacing: 4) {
                Image(systemName: "iphone")
                    .font(.system(size: 9, weight: .bold))
                Text(syncLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(Color.watchSoft)
        }
    }
}

private struct WatchStatusCard: View {
    let score: Int
    let headline: String
    let actionText: String

    var body: some View {
        WatchCard(cornerRadius: 22, padding: 10) {
            HStack(alignment: .center, spacing: 9) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(Color.watchMint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text("\(score)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.68)

                    Text(actionText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.watchSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct WatchCheckInCard: View {
    @Binding var stress: Int
    @Binding var fatigue: Int
    @Binding var hunger: Int

    let syncDetail: String
    let deliveryLabel: String
    let save: () -> Void

    var body: some View {
        WatchCard(cornerRadius: 23, padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("快速记录")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer(minLength: 6)

                    Text(deliveryLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.watchMint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Text(syncDetail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.watchSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                WatchLoadStepperRow(title: "压力", value: $stress, color: .watchRose, iconName: "flame.fill")
                WatchLoadStepperRow(title: "疲劳", value: $fatigue, color: .watchAmber, iconName: "bolt.fill")
                WatchLoadStepperRow(title: "饥饿", value: $hunger, color: .watchViolet, iconName: "fork.knife")

                Button(action: save) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.black)
                            .frame(width: 27, height: 27)
                            .background(Color.watchMint, in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text("保存记录")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("压力 \(stress) · 疲劳 \(fatigue) · 饥饿 \(hunger)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.watchSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .background(Color.watchMint.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("保存压力\(stress)疲劳\(fatigue)饥饿\(hunger)")
            }
        }
    }
}

private struct WatchLoadStepperRow: View {
    let title: String
    @Binding var value: Int
    let color: Color
    let iconName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.14), in: Circle())

            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 4)

            StepButton(systemName: "minus", color: color, isDisabled: value <= 1) {
                value = max(1, value - 1)
            }

            Text("\(value)")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 26)

            StepButton(systemName: "plus", color: color, isDisabled: value >= 10) {
                value = min(10, value + 1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

private struct StepButton: View {
    let systemName: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(isDisabled ? Color.watchMuted : .black)
                .frame(width: 28, height: 28)
                .background(isDisabled ? Color.white.opacity(0.08) : color, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(systemName == "plus" ? "增加" : "减少")
    }
}

private struct WatchSyncCard: View {
    let deliveryLabel: String
    let latestCheckIn: WatchSubjectiveCheckInPayload?
    let usesLiveSync: Bool

    var body: some View {
        WatchCard(cornerRadius: 19, padding: 9) {
            HStack(spacing: 8) {
                Image(systemName: usesLiveSync ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(usesLiveSync ? Color.watchMint : Color.watchBlue)
                    .frame(width: 28, height: 28)
                    .background((usesLiveSync ? Color.watchMint : Color.watchBlue).opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("同步")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(latestCheckIn?.compactSummary ?? deliveryLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.watchSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct WatchSignalStrip: View {
    let metrics: [WatchMetricPayload]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("关键数据")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.watchSoft)

            HStack(spacing: 6) {
                ForEach(Array(metrics.prefix(3).enumerated()), id: \.offset) { _, metric in
                    WatchSignalPill(metric: metric)
                }
            }
        }
    }
}

private struct WatchSignalPill: View {
    let metric: WatchMetricPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(metric.title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.watchSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(metric.value)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(metric.unit)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.watchMint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct WatchCard<Content: View>: View {
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
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
    }
}

private struct WatchBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.02, blue: 0.02),
                Color(red: 0.02, green: 0.03, blue: 0.04),
                Color(red: 0.02, green: 0.02, blue: 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private extension Color {
    static let watchSoft = Color(red: 0.72, green: 0.78, blue: 0.84)
    static let watchMuted = Color(red: 0.42, green: 0.47, blue: 0.52)
    static let watchMint = Color(red: 0.47, green: 0.92, blue: 0.73)
    static let watchBlue = Color(red: 0.31, green: 0.72, blue: 1.0)
    static let watchAmber = Color(red: 1.0, green: 0.72, blue: 0.42)
    static let watchViolet = Color(red: 0.67, green: 0.58, blue: 1.0)
    static let watchRose = Color(red: 1.0, green: 0.35, blue: 0.48)
}

#Preview {
    WatchRootView(store: WatchSummaryStore())
}
