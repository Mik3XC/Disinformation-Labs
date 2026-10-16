import AppKit
import PDFKit
import WorkshopCore

@MainActor
enum FOIASmokeChecks {
    static func run(output: URL) throws -> Int {
        var checks = 0
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw NSError(domain: "FOIASmokeChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
            checks += 1
        }
        let sample = Draft.foiaSample
        let sampleData = try PaperRenderer.pdf(draft: sample)
        try sampleData.write(to: output.appendingPathComponent("fictional-foia-mockup.pdf"))
        let pdf = PDFDocument(data: sampleData)!
        try check(pdf.pageCount >= 2 && pdf.page(at: 0)?.string?.contains("ARCHIVE COVER SHEET") == true, "FOIA cover included")
        try check(pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String == "FICTIONAL FOIA MOCKUP - " + sample.title, "FOIA PDF title identifies simulation")
        for i in 0..<pdf.pageCount {
            let text = pdf.page(at: i)?.string ?? ""
            try check(text.contains("FICTIONAL SIMULATION") && text.contains("NOT AN AUTHENTIC") && text.contains("SIM-NR-1983-014"), "Cover and record pages retain provenance and ID")
            try check(text.contains("PAGE \(i + 1) OF \(pdf.pageCount)"), "FOIA page number matches PDF sequence")
        }
        var redacted = sample; redacted.foia?.includeCoverSheet = false; redacted.body = "FOIA_PRIVATE_SENTINEL secret material"; redacted.redaction = 1
        let hidden = PDFDocument(data: try PaperRenderer.pdf(draft: redacted))!
        try check(hidden.pageCount == 1 && hidden.string?.contains("ARCHIVE COVER SHEET") == false, "Cover can be disabled")
        try check(hidden.string?.contains("FOIA_PRIVATE_SENTINEL") == false && hidden.string?.contains("secret") == false, "Black bars do not embed original words")
        let attributed = PaperRenderer.attributed(redacted)
        try check(attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor == NSColor.black, "FOIA replacements draw black bar backgrounds")
        redacted.body = ""
        try check(PaperRenderer.pages(redacted).count == 1, "Empty FOIA body still produces a record page")
        for medium in Medium.allCases {
            var long = sample; long.medium = medium; long.redaction = 0
            long.foia?.includeCoverSheet = false
            long.body = (1...35).map { "Paragraph \($0). This fictional records exercise checks pagination, text retention, and clear attribution.\n\n" }.joined() + "END-OF-FOIA-DOCUMENT"
            let document = PDFDocument(data: try PaperRenderer.pdf(draft: long))!
            try check(document.pageCount > 1 && document.string?.contains("END-OF-FOIA-DOCUMENT") == true, "FOIA long body retained for \(medium)")
            for i in 0..<document.pageCount {
                let text = document.page(at: i)?.string ?? ""
                try check(text.contains("FOIA MOCKUP") && text.contains("NOT AN AUTHENTIC"), "Every long FOIA page retains markings")
            }
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("FOIACheck-\(UUID().uuidString)/workspace.json")
        defer { try? FileManager.default.removeItem(at: temporary.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: temporary)
        store.createFOIAMockup()
        var draft = store.selectedDraft!; draft.foia?.recordDate = "Test date"; draft.foia?.includeCoverSheet = false; store.update(draft)
        let restored = WorkspaceStore(fileURL: temporary).selectedDraft
        try check(restored?.isFOIAMockup == true && restored?.foia?.recordDate == "Test date" && restored?.foia?.includeCoverSheet == false, "FOIA settings survive store relaunch")
        store.duplicate()
        try check(store.selectedDraft?.foia == draft.foia && store.selectedDraft?.id != draft.id, "FOIA duplication keeps settings with fresh identity")
        return checks
    }
}
