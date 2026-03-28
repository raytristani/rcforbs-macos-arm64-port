import SwiftUI

/// Slider with user-override semantics:
/// - Once the user drags a slider, their value sticks (stored in ConnectionManager.sliderOverrides)
/// - Server updates are ignored for overridden sliders
/// - "Reset" button clears all overrides, restoring server values
struct RadioSlider: View {
    let name: String
    let serverValue: Double
    let min: Double
    let max: Double
    let step: Double
    let onChange: (Double) -> Void
    @EnvironmentObject var cm: ConnectionManager

    @State private var localValue: Double = 0
    @State private var isDragging = false
    @State private var hasAppeared = false

    private var isOverridden: Bool {
        cm.sliderOverrides[name] != nil
    }

    private var displayValue: Double {
        cm.sliderOverrides[name] ?? serverValue
    }

    var body: some View {
        Slider(value: $localValue, in: min...max, step: step) { editing in
            isDragging = editing
            if !editing {
                // Drag ended — lock in the user's choice
                cm.sliderOverrides[name] = localValue
                onChange(localValue)
            }
        }
        .tint(Color.cream)
        .onAppear {
            if !hasAppeared {
                localValue = clamp(displayValue)
                hasAppeared = true
            }
        }
        .onChange(of: serverValue) {
            // Only accept server value if user hasn't overridden this slider
            if !isDragging && !isOverridden {
                localValue = clamp(serverValue)
            }
        }
        .onChange(of: cm.sliderOverrides) {
            // Reset was pressed — sliderOverrides cleared, snap back to server
            if !isOverridden && !isDragging {
                localValue = clamp(serverValue)
            }
        }
        .onChange(of: localValue) {
            guard isDragging else { return }
            // Debounced send while dragging
            onChange(localValue)
        }
    }

    private func clamp(_ v: Double) -> Double {
        Swift.min(Swift.max(v, min), max)
    }
}
