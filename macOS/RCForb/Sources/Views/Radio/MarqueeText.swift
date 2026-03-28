import SwiftUI

/// A single-line text view that scrolls horizontally (marquee / stock-ticker
/// style) when the text is too wide to fit its container.
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    /// Duration in seconds per point of overflow, controls scroll speed.
    private let speed: Double = 0.04

    private var overflow: CGFloat {
        max(textWidth - containerWidth, 0)
    }

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeo in
                        Color.clear
                            .onAppear {
                                textWidth = textGeo.size.width
                                containerWidth = geo.size.width
                                startAnimationIfNeeded()
                            }
                            .onChange(of: text) {
                                // Re-measure after text changes
                                textWidth = textGeo.size.width
                                containerWidth = geo.size.width
                                resetAnimation()
                            }
                    }
                )
                .offset(x: offset)
        }
        .clipped()
    }

    private func startAnimationIfNeeded() {
        guard overflow > 0, !animating else { return }
        animating = true
        scrollLeft()
    }

    private func resetAnimation() {
        animating = false
        offset = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAnimationIfNeeded()
        }
    }

    private func scrollLeft() {
        guard animating else { return }
        withAnimation(.linear(duration: speed * Double(overflow))) {
            offset = -overflow
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + speed * Double(overflow) + 1.0) {
            scrollRight()
        }
    }

    private func scrollRight() {
        guard animating else { return }
        withAnimation(.linear(duration: speed * Double(overflow))) {
            offset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + speed * Double(overflow) + 1.0) {
            scrollLeft()
        }
    }
}
