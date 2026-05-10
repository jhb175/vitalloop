import SwiftData
import SwiftUI

@main
struct BodyCoachApp: App {
    @State private var summaryStore = BodySummaryStore()
    @State private var persistenceStore = BodyCoachPersistenceStore()
    @State private var reminderStore = BodyCoachReminderStore()
    @State private var localStoreState = BodyCoachApp.makeLocalStoreState()

    var body: some Scene {
        WindowGroup {
            switch localStoreState {
            case let .ready(modelContainer):
                BodyCoachRootView(store: summaryStore, persistenceStore: persistenceStore, reminderStore: reminderStore)
                    .modelContainer(modelContainer)
            case let .failed(message):
                LocalStoreUnavailableView(message: message) {
                    localStoreState = BodyCoachApp.makeLocalStoreState()
                }
            }
        }
    }

    private static func makeLocalStoreState() -> LocalStoreState {
        do {
            let modelContainer = try ModelContainer(
                for: Schema(versionedSchema: BodyCoachSchemaV1.self),
                migrationPlan: BodyCoachSchemaMigrationPlan.self
            )

            return .ready(modelContainer)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

private enum LocalStoreState {
    case ready(ModelContainer)
    case failed(String)
}

private struct LocalStoreUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            background

            VStack(spacing: 18) {
                VitalLoopWordmark()

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Self.amber)
                        .frame(width: 54, height: 54)
                        .background(Self.amber.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("本地数据暂不可用")
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(Self.ink)

                            Text("VitalLoop 无法打开本机存储，因此已停止进入主界面，避免继续写入造成数据不一致。Apple 健康中的原始数据不会被删除。")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Self.soft)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("系统返回：\(message)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Self.amber)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            retry()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("重试打开本地数据")
                                Spacer()
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Self.ink)
                            .padding(.vertical, 11)
                            .padding(.horizontal, 12)
                            .background(Self.mint.opacity(0.16), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Self.mint.opacity(0.38), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)

                        if let supportURL = AppPrivacyLinks.supportURL {
                            Link(destination: supportURL) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("打开支持页面")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Self.blue)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.11, green: 0.13, blue: 0.14).opacity(0.94),
                                    Color(red: 0.04, green: 0.05, blue: 0.06).opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.38), radius: 24, x: 0, y: 16)
                }
            }
            .padding(20)
        }
    }

    private var background: some View {
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
                .fill(Self.mint.opacity(0.2))
                .frame(width: 230, height: 230)
                .blur(radius: 80)
                .offset(x: -150, y: -260)

            Circle()
                .fill(Self.blue.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 95)
                .offset(x: 160, y: -110)
        }
        .ignoresSafeArea()
    }

    private static let ink = Color(red: 0.94, green: 0.97, blue: 0.98)
    private static let soft = Color(red: 0.74, green: 0.79, blue: 0.84)
    private static let mint = Color(red: 0.47, green: 0.92, blue: 0.73)
    private static let blue = Color(red: 0.31, green: 0.72, blue: 1.0)
    private static let amber = Color(red: 1.0, green: 0.72, blue: 0.42)
}
