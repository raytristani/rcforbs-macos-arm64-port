import SwiftUI
import UIKit

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
                Image(uiImage: knobImage)
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
        .gesture(
            RotationGesture()
                .onChanged { angle in
                    let degrees = angle.degrees
                    let steps = Int((degrees / 10).rounded())
                    if steps != 0 {
                        let newFreq = frequency + steps * step
                        if newFreq > 0 {
                            rotation += degrees
                            onFrequencyChange(newFreq)
                        }
                    }
                }
        )
    }

    private func loadKnobImage() -> UIImage? {
        if let url = Bundle.main.url(forResource: "knob_xlarge", withExtension: "png", subdirectory: "Images") {
            return UIImage(contentsOfFile: url.path)
        }
        if let url = Bundle.main.url(forResource: "knob_xlarge", withExtension: "png", subdirectory: "Images") {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}
