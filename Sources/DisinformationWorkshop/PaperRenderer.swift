import AppKit
import SwiftUI
import WorkshopCore

/// The native preview and exported PDF share the same layout and page drawing.
enum PaperRenderer {
    static let pageSize = CGSize(width: 612, height: 792)
    static let textRect = CGRect(x: 54, y: 244, width: 504, height: 434)
    static func bodyRect(_ draft: Draft) -> CGRect { draft.isFOIAMockup ? FOIAPaperRenderer.textRect : textRect }
    static func font(_ draft: Draft) -> NSFont {
        switch draft.medium {
        case .typewriter: return NSFont(name: "Courier", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        case .telefax: return .monospacedSystemFont(ofSize: 11, weight: .regular)
        case .xerox: return NSFont(name: "Courier-Bold", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .medium)
        }
    }
    static func attributed(_ draft: Draft) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 4; paragraph.paragraphSpacing = 4
        let text = NSMutableAttributedString(string: draft.redactedBody.isEmpty ? " " : draft.redactedBody, attributes: [
            .font: font(draft), .foregroundColor: NSColor(white: 0.12 + draft.distress * 0.12, alpha: 1), .paragraphStyle: paragraph
        ])
        if draft.isFOIAMockup {
            let matches = text.string as NSString
            var search = NSRange(location: 0, length: matches.length)
            while search.length > 0 {
                let range = matches.range(of: "[REDACTED]", range: search)
                guard range.location != NSNotFound else { break }
                // Only replacement markers exist in the PDF; original words never enter the renderer.
                text.addAttributes([.foregroundColor: NSColor.black, .backgroundColor: NSColor.black], range: range)
                search = NSRange(location: NSMaxRange(range), length: matches.length - NSMaxRange(range))
            }
        }
        return text
    }
    static func pages(_ draft: Draft) -> [NSAttributedString] {
        let storage = NSTextStorage(attributedString: attributed(draft))
        let manager = NSLayoutManager(); storage.addLayoutManager(manager)
        var result: [NSAttributedString] = []
        var consumed = 0
        while consumed < storage.length {
            let container = NSTextContainer(containerSize: bodyRect(draft).size)
            container.lineFragmentPadding = 0; manager.addTextContainer(container)
            manager.ensureLayout(for: container)
            let glyphs = manager.glyphRange(for: container)
            let range = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            guard range.length > 0 else { break }
            result.append(storage.attributedSubstring(from: range))
            consumed = NSMaxRange(range)
        }
        if result.isEmpty { result = [NSAttributedString(string: " ")] }
        if draft.isFOIAMockup && draft.foiaSettings.includeCoverSheet { result.insert(NSAttributedString(string: ""), at: 0) }
        return result
    }
    static func draw(draft: Draft, page: NSAttributedString, index: Int, count: Int) {
        if draft.isFOIAMockup { FOIAPaperRenderer.draw(draft: draft, page: page, index: index, count: count); return }
        let paper: NSColor
        switch draft.medium {
        case .typewriter: paper = NSColor(red: 0.96, green: 0.935 - draft.distress * 0.04, blue: 0.86 - draft.distress * 0.07, alpha: 1)
        case .telefax: paper = NSColor(white: 0.96 - draft.distress * 0.04, alpha: 1)
        case .xerox: paper = NSColor(white: 0.93 - draft.distress * 0.04, alpha: 1)
        }
        paper.setFill(); NSBezierPath(rect: CGRect(origin: .zero, size: pageSize)).fill()
        let ink = NSColor(white: 0.17, alpha: 1)
        let stamp = NSColor(red: 0.57, green: 0.19, blue: 0.14, alpha: 1)
        // Repeatable texture; does not change between preview and export.
        NSColor(white: 0.1, alpha: draft.distress * 0.12).setFill()
        for i in 0..<Int(draft.distress * 2000) {
            let x = CGFloat((i * 79 + 31) % 612), y = CGFloat((i * 131 + 71) % 792)
            let size = CGFloat(i % 3 + 1) * 0.35
            NSBezierPath(ovalIn: CGRect(x: x, y: y, width: size, height: size)).fill()
        }
        if draft.medium == .telefax {
            NSColor(white: 0, alpha: draft.distress * 0.07).setFill()
            for y in stride(from: 0, to: 792, by: 5) { NSBezierPath(rect: CGRect(x: 0, y: CGFloat(y), width: 612, height: 0.45)).fill() }
        } else if draft.medium == .xerox {
            NSColor(white: 0, alpha: draft.distress * 0.10).setFill()
            NSBezierPath(rect: CGRect(x: 10, y: 0, width: 9, height: 792)).fill()
        }
        func label(_ text: String, _ rect: CGRect, size: CGFloat, bold: Bool = false, color: NSColor? = nil) {
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
            NSAttributedString(string: text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular), .foregroundColor: color ?? ink, .paragraphStyle: style]).draw(in: rect)
        }
        label("SYNDROME / DISINFORMATION WORKSHOP", CGRect(x: 54, y: 38, width: 504, height: 18), size: 9, bold: true)
        stamp.setStroke()
        let stampRect = CGRect(x: 54, y: 73, width: 504, height: 33)
        let stampPath = NSBezierPath(rect: stampRect); stampPath.lineWidth = 1.3; stampPath.stroke()
        label("FICTIONAL SIMULATION / CREATIVE STUDY COPY", CGRect(x: 67, y: 83, width: 478, height: 17), size: 10, bold: true, color: stamp)
        label(draft.header.rawValue.uppercased(), CGRect(x: 54, y: 127, width: 504, height: 19), size: 10)
        label(draft.title.uppercased(), CGRect(x: 54, y: 150, width: 504, height: 30), size: 20, bold: true)
        label("TO:  " + draft.recipient, CGRect(x: 54, y: 190, width: 504, height: 17), size: 10)
        label("REF: " + draft.reference, CGRect(x: 54, y: 208, width: 504, height: 17), size: 10)
        ink.setStroke(); let line = NSBezierPath(); line.move(to: CGPoint(x: 54, y: 233)); line.line(to: CGPoint(x: 558, y: 233)); line.lineWidth = 0.6; line.stroke()
        let storage = NSTextStorage(attributedString: page), manager = NSLayoutManager()
        let container = NSTextContainer(containerSize: textRect.size); container.lineFragmentPadding = 0
        storage.addLayoutManager(manager); manager.addTextContainer(container)
        manager.drawGlyphs(forGlyphRange: manager.glyphRange(for: container), at: textRect.origin)
        label("NOT AN AUTHENTIC GOVERNMENT RECORD", CGRect(x: 54, y: 709, width: 504, height: 18), size: 10, bold: true, color: stamp)
        label(draft.medium.rawValue.uppercased(), CGRect(x: 54, y: 744, width: 390, height: 15), size: 8)
        label(String(format: "%02d / %02d", index + 1, count), CGRect(x: 488, y: 744, width: 70, height: 15), size: 9)
    }
    static func pdf(draft: Draft) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { throw CocoaError(.fileWriteUnknown) }
        var box = CGRect(origin: .zero, size: pageSize)
        let metadata = [kCGPDFContextTitle as String: draft.isFOIAMockup ? "FICTIONAL FOIA MOCKUP - " + draft.title : draft.title,
                        kCGPDFContextCreator as String: "Disinformation Labs - Fictional Simulation",
                        kCGPDFContextSubject as String: "Creative study copy - not an authentic government record"] as CFDictionary
        guard let context = CGContext(consumer: consumer, mediaBox: &box, metadata) else { throw CocoaError(.fileWriteUnknown) }
        let content = pages(draft)
        for (index, page) in content.enumerated() {
            context.beginPDFPage(nil); context.saveGState()
            context.translateBy(x: 0, y: pageSize.height); context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            draw(draft: draft, page: page, index: index, count: content.count)
            NSGraphicsContext.restoreGraphicsState(); context.restoreGState(); context.endPDFPage()
        }
        context.closePDF(); return data as Data
    }
}

struct PaperPreview: NSViewRepresentable {
    let draft: Draft
    let page: NSAttributedString
    let index: Int
    let count: Int
    func makeNSView(context: Context) -> PaperView { PaperView() }
    func updateNSView(_ view: PaperView, context: Context) {
        view.draft = draft; view.page = page; view.index = index; view.count = count; view.needsDisplay = true
    }
    final class PaperView: NSView {
        var draft = Draft.sample
        var page = NSAttributedString(string: "")
        var index = 0, count = 1
        override var isFlipped: Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform(); transform.scale(by: bounds.width / 612); transform.concat()
            PaperRenderer.draw(draft: draft, page: page, index: index, count: count)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
