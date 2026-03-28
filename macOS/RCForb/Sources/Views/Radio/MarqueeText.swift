import SwiftUI

/// A single-line text view that scrolls back and forth (stock-ticker style)
/// when the text is too wide to fit its container.
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    /// Points scrolled per second
    private let scrollSpeed: Double = 30.0
    /// Pause in seconds at each end
    private let pauseDuration: Double = 1.5

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startTime: Date = .now
    @State private var measured = false

    private var overflow: CGFloat {
        max(textWidth - containerWidth, 0)
    }

    var body: some View {
        GeometryReader { geo in
            let _ = updateContainer(geo.size.width)
            TimelineView(.animation(paused: overflow <= 0 || !measured)) { timeline in
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear { measureText(textGeo.size.width, container: geo.size.width) }
                                .onChange(of: text) { measureText(textGeo.size.width, container: geo.size.width) }
                        }
                    )
                    .offset(x: currentOffset(at: timeline.date))
            }
        }
        .clipped()
    }

    private func updateContainer(_ width: CGFloat) {
        if containerWidth != width {
            DispatchQueue.main.async { containerWidth = width }
        }
    }

    private func measureText(_ tw: CGFloat, container cw: CGFloat) {
        textWidth = tw
        containerWidth = cw
        startTime = .now
        measured = true
    }

    private func currentOffset(at date: Date) -> CGFloat {
        guard overflow > 0 else { return 0 }

        let scrollDuration = Double(overflow) / scrollSpeed
        let cycleDuration = pauseDuration + scrollDuration + pauseDuration + scrollDuration
        let elapsed = date.timeIntervalSince(startTime).truncatingRemainder(dividingBy: cycleDuration)

        if elapsed < pauseDuration {
            // Paused at start
            return 0
        } else if elapsed < pauseDuration + scrollDuration {
            // Scrolling left
            let progress = (elapsed - pauseDuration) / scrollDuration
            return -overflow * CGFloat(progress)
        } else if elapsed < pauseDuration + scrollDuration + pauseDuration {
            // Paused at end
            return -overflow
        } else {
            // Scrolling right
            let progress = (elapsed - pauseDuration - scrollDuration - pauseDuration) / scrollDuration
            return -overflow * CGFloat(1.0 - progress)
        }
    }
}
