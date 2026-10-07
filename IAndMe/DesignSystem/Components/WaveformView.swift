import SwiftUI

/// Draws amplitude bars. Used live while recording and for saved recordings with playback progress.
struct WaveformView: View {
    var levels: [Float]
    var progress: Double = 0
    var tint: Color = Theme.Colors.accent
    var inactiveTint: Color = Theme.Colors.inkTertiary.opacity(0.35)
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var minHeight: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int((proxy.size.width + spacing) / (barWidth + spacing)))
            let bars = resampled(to: count)
            HStack(alignment: .center, spacing: spacing) {
                ForEach(bars.indices, id: \.self) { index in
                    let fraction = Double(index) / Double(max(1, bars.count - 1))
                    Capsule()
                        .fill(fraction <= progress && progress > 0 ? tint : (progress > 0 ? inactiveTint : tint))
                        .frame(width: barWidth, height: max(minHeight, CGFloat(bars[index]) * proxy.size.height))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .accessibilityHidden(true)
    }

    private func resampled(to count: Int) -> [Float] {
        guard !levels.isEmpty else { return Array(repeating: 0.05, count: count) }
        if levels.count == count { return levels }
        if levels.count > count { return Waveform.condense(levels, to: count) }
        // Stretch shorter arrays by repeating neighbours.
        return (0..<count).map { i in
            let source = Int(Double(i) / Double(count) * Double(levels.count))
            return levels[min(levels.count - 1, source)]
        }
    }
}

/// A rolling waveform for live recording, with bars that slide in from the right.
struct LiveWaveformView: View {
    var levels: [Float]
    var tint: Color = Theme.Colors.accent
    var animates: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let barWidth: CGFloat = 3
            let spacing: CGFloat = 3
            let count = max(1, Int((proxy.size.width + spacing) / (barWidth + spacing)))
            let visible = Array(levels.suffix(count))
            let padding = max(0, count - visible.count)
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<padding, id: \.self) { _ in
                    Capsule().fill(tint.opacity(0.15)).frame(width: barWidth, height: 3)
                }
                ForEach(visible.indices, id: \.self) { index in
                    Capsule()
                        .fill(tint)
                        .frame(width: barWidth, height: max(3, CGFloat(visible[index]) * proxy.size.height))
                        .animation(animates ? .linear(duration: 0.05) : nil, value: visible[index])
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .accessibilityHidden(true)
    }
}
