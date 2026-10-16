import AppKit
import WorkshopCore

enum FOIAPaperRenderer {
    static let textRect = CGRect(x: 58, y: 302, width: 496, height: 368)

    static func draw(draft: Draft, page: NSAttributedString, index: Int, count: Int) {
        let settings = draft.foiaSettings
        let ink = NSColor(white: 0.12, alpha: 1)
        let stamp = NSColor(red: 0.48, green: 0.16, blue: 0.13, alpha: 1)
        let paper = draft.medium == .typewriter
            ? NSColor(red: 0.98, green: 0.965 - draft.distress * 0.03, blue: 0.92 - draft.distress * 0.05, alpha: 1)
            : NSColor(white: 0.985 - draft.distress * 0.045, alpha: 1)
        paper.setFill(); NSBezierPath(rect: CGRect(origin: .zero, size: PaperRenderer.pageSize)).fill()
        NSColor(white: 0.12, alpha: draft.distress * 0.17).setFill()
        for i in 0..<Int(draft.distress * 2600) {
            let size = CGFloat(i % 4 + 1) * 0.3
            let x = CGFloat((i * 73 + 29) % 612), y = CGFloat((i * 137 + 53) % 792)
            NSBezierPath(ovalIn: CGRect(x: x, y: y, width: size, height: size)).fill()
        }
        if draft.medium == .xerox {
            NSColor(white: 0.1, alpha: draft.distress * 0.2).setFill()
            NSBezierPath(rect: CGRect(x: 12, y: 16, width: 3, height: 760)).fill()
            for y in [164, 395, 627] { NSBezierPath(ovalIn: CGRect(x: 21, y: y, width: 7, height: 10)).fill() }
        } else if draft.medium == .telefax {
            NSColor(white: 0.1, alpha: draft.distress * 0.05).setFill()
            for y in stride(from: 0, to: 792, by: 5) { NSBezierPath(rect: CGRect(x: 0, y: CGFloat(y), width: 612, height: 0.4)).fill() }
        }
        func label(_ text: String, x: CGFloat = 54, y: CGFloat, width: CGFloat = 504, height: CGFloat = 18, size: CGFloat = 10, bold: Bool = false, color: NSColor? = nil, centered: Bool = false) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            paragraph.alignment = centered ? .center : .left
            NSAttributedString(string: text.components(separatedBy: .newlines).joined(separator: " "), attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular),
                .foregroundColor: color ?? ink, .paragraphStyle: paragraph
            ]).draw(in: CGRect(x: x, y: y, width: width, height: height))
        }
        func rule(_ y: CGFloat) {
            ink.setStroke(); let path = NSBezierPath()
            path.move(to: CGPoint(x: 54, y: y)); path.line(to: CGPoint(x: 558, y: y)); path.lineWidth = 0.6; path.stroke()
        }

        label("\(draft.mockReleaseStatus) / \(settings.releaseDate)", y: 24, size: 9, bold: true, centered: true)
        label("MOCK RECORD ID: \(draft.mockRecordID)", y: 41, size: 9, centered: true)
        rule(65)
        label("FOIA MOCKUP / FICTIONAL SIMULATION", y: 78, height: 25, size: 15, bold: true, color: stamp, centered: true)
        label("DISINFORMATION LABS / CREATIVE STUDY COPY", y: 105, size: 9, centered: true)

        // Always-visible fixed markings are drawn separately from editable text and redactions.
        NSGraphicsContext.saveGraphicsState()
        let watermark = NSAffineTransform(); watermark.translateX(by: 306, yBy: 448); watermark.rotate(byDegrees: -28); watermark.concat()
        label("FICTIONAL MOCKUP", x: -230, y: -25, width: 460, height: 50, size: 38, bold: true, color: NSColor(white: 0.58, alpha: 0.16), centered: true)
        NSGraphicsContext.restoreGraphicsState()

        if settings.includeCoverSheet && index == 0 {
            label(settings.office.uppercased(), y: 226, size: 12, bold: true, centered: true)
            label("FICTIONAL OFFICE / SIMULATED RECORDS PACKET", y: 252, size: 9, centered: true)
            let titleStyle = NSMutableParagraphStyle(); titleStyle.alignment = .center
            NSAttributedString(string: draft.title.uppercased(), attributes: [.font: NSFont.monospacedSystemFont(ofSize: 19, weight: .bold), .foregroundColor: ink, .paragraphStyle: titleStyle])
                .draw(in: CGRect(x: 66, y: 304, width: 480, height: 112))
            label("ARCHIVE COVER SHEET", y: 453, size: 12, bold: true, centered: true)
            label("RECORD DATE: \(settings.recordDate)", y: 494, centered: true)
            label("\(count - 1) RECORD PAGE(S) + THIS COVER", y: 517, size: 9, centered: true)
            label("Prepared for: \(draft.recipient)", y: 554, size: 9, centered: true)
            label("Original fictional text. No actual release is represented.", y: 598, size: 9, centered: true)
        } else {
            label(settings.office.uppercased(), y: 134, size: 11, bold: true)
            label("FICTIONAL OFFICE / MEMORANDUM FOR THE RECORD", y: 154, size: 9)
            rule(177)
            label("RECORD DATE", y: 187, size: 8)
            label(settings.recordDate, y: 201, size: 10)
            label("SIMULATED RELEASE DATE", x: 316, y: 187, width: 242, size: 8)
            label(settings.releaseDate, x: 316, y: 201, width: 242, size: 10)
            rule(225)
            label("SUBJECT: " + draft.title.uppercased(), y: 237, size: 12, bold: true)
            label("TO: " + draft.recipient, y: 260, size: 9)
            label("REFERENCE: \(draft.mockRecordID)", y: 278, size: 9)
            let storage = NSTextStorage(attributedString: page), manager = NSLayoutManager()
            let container = NSTextContainer(containerSize: textRect.size); container.lineFragmentPadding = 0
            storage.addLayoutManager(manager); manager.addTextContainer(container)
            manager.drawBackground(forGlyphRange: manager.glyphRange(for: container), at: textRect.origin)
            manager.drawGlyphs(forGlyphRange: manager.glyphRange(for: container), at: textRect.origin)
        }
        rule(682)
        label(draft.redaction > 0 ? "SIMULATED WITHHOLDING: \(settings.withholdingLabel)" : "NO SIMULATED WITHHOLDINGS", y: 691, size: 8)
        label("NOT AN AUTHENTIC GOVERNMENT RECORD", y: 711, size: 11, bold: true, color: stamp, centered: true)
        label("\(draft.mockRecordID)-\(String(format: "%04d", index + 1))", y: 744, width: 340, size: 8)
        label("PAGE \(index + 1) OF \(count)", x: 412, y: 744, width: 146, size: 9)
        label("SIMULATED RELEASE / FOIA MOCKUP", y: 764, size: 8, centered: true)
    }
}
