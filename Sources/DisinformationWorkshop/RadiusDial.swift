import SwiftUI

struct RadiusDial: View {
    @Binding var miles: Double
    private var fraction: Double { (max(10, min(1000, miles)) - 10) / 990 }
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(Theme.line, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: fraction * 0.75).stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(135))
            VStack(spacing: 2) { Text("\(Int(miles))").font(.system(size: 20, weight: .medium, design: .monospaced)).monospacedDigit(); Text("MILES").font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.muted) }
        }.frame(width: 84, height: 84).padding(7).contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                var angle = atan2(value.location.y - 49, value.location.x - 49) * 180 / .pi
                if angle > 45 { angle -= 360 }
                miles = (10 + max(0, min(1, (angle + 225) / 270)) * 990).rounded()
            })
            .accessibilityElement(children: .ignore).accessibilityLabel("Search radius").accessibilityValue("\(Int(miles)) miles")
            .accessibilityAdjustableAction { direction in
                switch direction { case .increment: miles = min(1000, miles + 10); case .decrement: miles = max(10, miles - 10); @unknown default: break }
            }
    }
}
