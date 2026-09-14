import AppKit
import SwiftUI

@main
struct RenderIcon {
    @MainActor
    static func main() throws {
        let renderer = ImageRenderer(content: SyndromeAppIcon())
        renderer.scale = 1
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            fatalError("Could not render app icon")
        }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
