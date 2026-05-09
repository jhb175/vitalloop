import SwiftUI

struct VitalLoopLogoMark: View {
    var showBackground = true

    var body: some View {
        ZStack {
            if showBackground {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.vlBase)
            }

            Circle()
                .stroke(Color.vlRingBase, lineWidth: 9)
                .frame(width: 64, height: 64)
            Circle()
                .trim(from: 0.04, to: 0.77)
                .stroke(
                    LinearGradient(colors: [.vlMint, .vlBlue, .vlViolet], startPoint: .bottomLeading, endPoint: .topTrailing),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(18))
                .frame(width: 64, height: 64)

            Circle()
                .stroke(Color.vlInnerBase, lineWidth: 6)
                .frame(width: 43, height: 43)
            Circle()
                .trim(from: 0.08, to: 0.64)
                .stroke(
                    LinearGradient(colors: [.vlBlue, .vlViolet], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(136))
                .frame(width: 43, height: 43)

            Circle()
                .stroke(Color.vlCoreBase, lineWidth: 4)
                .frame(width: 24, height: 24)
            Circle()
                .trim(from: 0.1, to: 0.58)
                .stroke(
                    LinearGradient(colors: [.vlWarm, .vlMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-28))
                .frame(width: 24, height: 24)

            Circle()
                .fill(Color.vlMint.opacity(0.18))
                .frame(width: 8, height: 8)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("VitalLoop")
    }
}

struct VitalLoopWordmark: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            VitalLoopLogoMark()
                .frame(width: compact ? 34 : 48, height: compact ? 34 : 48)

            VStack(alignment: .leading, spacing: compact ? 0 : 2) {
                Text("VitalLoop")
                    .font(.system(size: compact ? 17 : 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.vlText)
                if !compact {
                    Text("Body signals. Daily decisions.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.vlMuted)
                }
            }
        }
    }
}

extension Color {
    static let vlBase = Color(red: 0.03, green: 0.06, blue: 0.06)
    static let vlText = Color(red: 0.94, green: 0.97, blue: 0.96)
    static let vlMuted = Color(red: 0.58, green: 0.65, blue: 0.64)
    static let vlRingBase = Color(red: 0.08, green: 0.14, blue: 0.13)
    static let vlInnerBase = Color(red: 0.07, green: 0.11, blue: 0.13)
    static let vlCoreBase = Color(red: 0.09, green: 0.15, blue: 0.14)
    static let vlMint = Color(red: 0.48, green: 0.94, blue: 0.75)
    static let vlBlue = Color(red: 0.27, green: 0.74, blue: 0.96)
    static let vlViolet = Color(red: 0.62, green: 0.55, blue: 1.0)
    static let vlWarm = Color(red: 1.0, green: 0.72, blue: 0.42)
}
