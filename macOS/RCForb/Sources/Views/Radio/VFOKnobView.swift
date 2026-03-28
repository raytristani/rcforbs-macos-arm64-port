import SwiftUI

struct VFOKnobView: View {
    let size: CGFloat
    let vfo: String
    let step: Int
    let frequency: Int
    let onFrequencyChange: (Int) -> Void

    @State private var rotation: Double = 0
    @State private var lastAngle: Double? = nil

    var body: some View {
        ZStack {
            if let knobImage = loadKnobImage() {
                Image(nsImage: knobImage)
                    .resizable()
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotation))
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#888888"), Color(hex: "#444444")],
                            center: .center, startRadius: 0, endRadius: size / 2
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let center = CGPoint(x: size / 2, y: size / 2)
                    let angle = atan2(
                        value.location.y - center.y,
                        value.location.x - center.x
                    ) * 180.0 / .pi

                    if let last = lastAngle {
                        var delta = angle - last
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }

                        rotation += delta

                        let steps = Int((delta / 10).rounded())
                        if steps != 0 {
                            let newFreq = frequency + steps * step
                            if newFreq > 0 {
                                onFrequencyChange(newFreq)
                            }
                        }
                    }
                    lastAngle = angle
                }
                .onEnded { _ in
                    lastAngle = nil
                }
        )
        .onScrollGesture { scrollDelta in
            let direction = scrollDelta > 0 ? 1 : -1
            rotation += Double(direction) * 5
            let newFreq = frequency + direction * step
            if newFreq > 0 {
                onFrequencyChange(newFreq)
            }
        }
    }

    private func loadKnobImage() -> NSImage? {
        if let url = ResourceBundle.bundle.url(forResource: "knob_xlarge", withExtension: "png", subdirectory: "Images") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: "knob_xlarge", withExtension: "png", subdirectory: "Images") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

extension View {
    func onScrollGesture(action: @escaping (CGFloat) -> Void) -> some View {
        self.background(ScrollGestureView(action: action))
    }
}

struct ScrollGestureView: NSViewRepresentable {
    let action: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollTrackingView {
        let view = ScrollTrackingView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: ScrollTrackingView, context: Context) {
        nsView.action = action
    }
}

class ScrollTrackingView: NSView {
    var action: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        action?(event.deltaY)
    }
}
