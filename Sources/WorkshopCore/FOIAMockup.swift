import Foundation

public enum DocumentLayout: String, Codable, CaseIterable, Identifiable {
    case memorandum = "Memorandum"
    case foia = "FOIA mockup"
    public var id: String { rawValue }
}

/// Fictional production metadata, independent of any source PDF or real release.
public struct FOIAMockup: Codable, Equatable {
    public var office: String = "North Range Records Office"
    public var recordDate: String = "UNDATED"
    public var releaseDate: String = "UNDATED"
    public var withholdingLabel: String = "WITHHELD / MOCK"
    public var includeCoverSheet: Bool = true
    public init() {}

    public mutating func normalize() {
        office = Self.line(office, limit: 60)
        recordDate = Self.line(recordDate, limit: 24)
        releaseDate = Self.line(releaseDate, limit: 24)
        withholdingLabel = Self.line(withholdingLabel, limit: 32)
    }
    private static func line(_ value: String, limit: Int) -> String {
        String(value.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ").prefix(limit))
    }
}

extension Draft {
    public var isFOIAMockup: Bool { documentLayout == .foia }
    public var foiaSettings: FOIAMockup { var value = foia ?? FOIAMockup(); value.normalize(); return value }
    public var mockRecordID: String {
        let safe = reference.uppercased().unicodeScalars.filter { (65...90).contains($0.value) || (48...57).contains($0.value) || $0 == "-" }
        let identifier = String(String.UnicodeScalarView(safe)).prefix(24)
        return "SIM-" + (identifier.isEmpty ? "RECORD" : String(identifier))
    }
    public var mockReleaseStatus: String { redaction > 0 ? "SIMULATED RELEASE IN PART" : "SIMULATED RELEASE IN FULL" }
    public static var foiaSample: Draft {
        var draft = Draft(title: "North Range archive review", recipient: "Fictional records review group", reference: "NR-1983-014",
            body: "MEMORANDUM FOR THE RECORD\n\n1. PURPOSE\nThis fictional exercise reviews the cataloging of a training packet at the invented North Range facility. No actual operation, person, or government release is represented.\n\n2. RECORD SUMMARY\nThe packet contains a site sketch, a session worksheet, and an inventory of ordinary calibration equipment. The review team requests a consistent page sequence and a separate list of missing attachments.\n\n3. REVIEW NOTES\nThe description supplied by the observer is incomplete. The records clerk should preserve the original wording and record the uncertainty without adding an inferred explanation.\n\n4. DISPOSITION\nRetain this mock packet as a design exercise. Any withheld portions shown here are simulated redactions.\n\nEND OF FICTIONAL RECORD", medium: .xerox, distress: 0.25, redaction: 0.12)
        draft.documentLayout = .foia
        var settings = FOIAMockup(); settings.recordDate = "14 NOV 1983"; settings.releaseDate = "16 OCT 2026"
        draft.foia = settings
        return draft
    }
}
