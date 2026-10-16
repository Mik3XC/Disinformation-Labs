import Foundation
import WorkshopCore

func runFOIAMockupChecks() {
    do {
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        var old = try JSONSerialization.jsonObject(with: encoder.encode(Draft.sample)) as! [String: Any]
        old.removeValue(forKey: "documentLayout"); old.removeValue(forKey: "foia")
        let legacy = try decoder.decode(Draft.self, from: JSONSerialization.data(withJSONObject: old))
        check(!legacy.isFOIAMockup && legacy.foia == nil, "Old drafts decode without FOIA fields")
        let sample = Draft.foiaSample
        let restored = try decoder.decode(Draft.self, from: encoder.encode(sample))
        check(restored == sample, "FOIA settings round-trip")
        check(sample.plainText.contains("FOIA MOCKUP") && sample.plainText.contains("FICTIONAL OFFICE") && sample.plainText.contains("NOT AN AUTHENTIC"), "FOIA text export provenance")
        check(sample.plainText.contains("SIM-NR-1983-014") && sample.plainText.contains("14 NOV 1983"), "FOIA text export metadata")
        var draft = sample
        draft.body = "PRIVATE_SENTINEL"; draft.redaction = 1
        check(!draft.plainText.contains("PRIVATE_SENTINEL") && draft.plainText.contains("[REDACTED]"), "FOIA text export removes original redacted words")
        draft.reference = "\n💡 / "
        check(draft.mockRecordID == "SIM-RECORD", "Empty sanitized reference has mock fallback")
        draft.reference = String(repeating: "A", count: 100)
        check(draft.mockRecordID.count == 28, "Mock identifier stays within page margin")
        draft.foia?.office = "Office\n\tLine"
        draft.foia?.recordDate = String(repeating: "9", count: 100)
        draft.normalize()
        check(draft.foia?.office == "Office Line" && draft.foia?.recordDate.count == 24, "Imported FOIA metadata normalized")
        draft.documentLayout = .memorandum
        check(!draft.isFOIAMockup && draft.foia != nil, "Changing layout retains FOIA metadata")
        draft.documentLayout = .foia; draft.foia = nil
        check(draft.foiaSettings.office == FOIAMockup().office, "Missing FOIA metadata uses defaults")
        draft.redaction = 0
        check(draft.mockReleaseStatus.contains("IN FULL"), "Unredacted mock release status")
    } catch { fputs("FAIL: FOIA model checks: \(error)\n", stderr); exit(1) }
}
