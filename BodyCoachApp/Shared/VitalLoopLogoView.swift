import SwiftUI

struct VitalLoopLogoMark: View {
    var showBackground = true

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let outerSize = size * 0.89
            let innerSize = size * 0.6
            let coreSize = size * 0.33

            ZStack {
                if showBackground {
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .fill(Color.vlBase)
                }

                Circle()
                    .stroke(Color.vlRingBase, lineWidth: size * 0.125)
                    .frame(width: outerSize, height: outerSize)
                Circle()
                    .trim(from: 0.04, to: 0.77)
                    .stroke(
                        LinearGradient(colors: [.vlMint, .vlBlue, .vlViolet], startPoint: .bottomLeading, endPoint: .topTrailing),
                        style: StrokeStyle(lineWidth: size * 0.125, lineCap: .round)
                    )
                    .rotationEffect(.degrees(18))
                    .frame(width: outerSize, height: outerSize)

                Circle()
                    .stroke(Color.vlInnerBase, lineWidth: size * 0.083)
                    .frame(width: innerSize, height: innerSize)
                Circle()
                    .trim(from: 0.08, to: 0.64)
                    .stroke(
                        LinearGradient(colors: [.vlBlue, .vlViolet], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: size * 0.083, lineCap: .round)
                    )
                    .rotationEffect(.degrees(136))
                    .frame(width: innerSize, height: innerSize)

                Circle()
                    .stroke(Color.vlCoreBase, lineWidth: size * 0.056)
                    .frame(width: coreSize, height: coreSize)
                Circle()
                    .trim(from: 0.1, to: 0.58)
                    .stroke(
                        LinearGradient(colors: [.vlWarm, .vlMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: size * 0.056, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-28))
                    .frame(width: coreSize, height: coreSize)

                Circle()
                    .fill(Color.vlMint.opacity(0.18))
                    .frame(width: size * 0.11, height: size * 0.11)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
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
