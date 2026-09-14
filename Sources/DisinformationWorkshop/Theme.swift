import SwiftUI
import WorkshopCore

enum Theme {
    static let background = Color(red: 0.055, green: 0.070, blue: 0.075)
    static let sidebar = Color(red: 0.075, green: 0.090, blue: 0.095)
    static let panel = Color(red: 0.094, green: 0.112, blue: 0.115)
    static let line = Color.white.opacity(0.09)
    static let muted = Color(red: 0.59, green: 0.65, blue: 0.64)
    static let accent = Color(red: 0.78, green: 0.90, blue: 0.48)
    static let amber = Color(red: 0.92, green: 0.71, blue: 0.40)
    static let text = Color(red: 0.90, green: 0.92, blue: 0.87)
    static func status(_ status: EvidenceStatus) -> Color {
        switch status { case .sourced: return accent; case .disputed: return amber; case .fictional: return Color(red: 0.62, green: 0.73, blue: 0.86) }
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.muted
    var body: some View { Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(color) }
}
struct StatusBadge: View {
    let status: EvidenceStatus
    var body: some View {
        Text(status.rawValue).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(0.7)
            .foregroundStyle(Theme.status(status)).padding(.horizontal, 8).padding(.vertical, 5)
            .background(Theme.status(status).opacity(0.09), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.status(status).opacity(0.22)))
    }
}
struct ActionButton: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 13).padding(.vertical, 9)
            .foregroundStyle(prominent ? Theme.background : Theme.text)
            .background(prominent ? Theme.accent : Color.white.opacity(configuration.isPressed ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
struct EmptyPanel: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.questionmark").font(.system(size: 35)).foregroundStyle(Theme.accent)
            Text(title).font(.title3.weight(.medium))
            Text(message).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 320)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
