import Foundation
import WorkshopCore

var count = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    guard condition() else { fputs("FAIL: \(label)\n", stderr); exit(1) }
    count += 1
}
check(Vault.records.count == 6, "Seed record count")
check(Set(Vault.records.map(\.id)).count == Vault.records.count, "Unique dossier IDs")
check(Vault.search("DOTY").count >= 3, "Case insensitive search")
check(Vault.search("Richard Aquarius").count == 1, "Multi-term search")
check(Vault.search("", domain: .paranormal).count == 2, "Domain filter")
check(Vault.search("", bookmarks: ["MJ-012"]).map(\.id) == ["MJ-012"], "Bookmark filter")
check(Vault.search("no-such-record").isEmpty, "Empty search")
check(Vault.records.filter { $0.status == .sourced }.allSatisfy { !$0.sources.isEmpty }, "Sourced records have references")
let body = "alpha beta\n\ngamma delta"
check(Redaction.apply(body, level: 0) == body, "Zero redaction unchanged")
check(!Redaction.apply(body, level: 1).contains("alpha"), "Full redaction")
check(Redaction.apply(body, level: 1).components(separatedBy: "\n").count == 3, "Preserve paragraph breaks")
check(Redaction.apply(body, level: .nan) == body, "Non-finite redaction")
check(Redaction.apply(body, level: 0.5) == Redaction.apply(body, level: 0.5), "Deterministic redaction")
var draft = Draft.sample
draft.body = String(repeating: "x", count: 31_000); draft.distress = 3; draft.redaction = -1; draft.normalize()
check(draft.body.count == 30_000 && draft.distress == 1 && draft.redaction == 0, "Input bounds")
check(draft.plainText.contains("FICTIONAL SIMULATION") && draft.plainText.contains("NOT AN AUTHENTIC"), "Text provenance")
let temp = FileManager.default.temporaryDirectory.appendingPathComponent("WorkshopChecks-\(UUID().uuidString)/workspace.json")
defer { try? FileManager.default.removeItem(at: temp.deletingLastPathComponent()) }
do {
    let state = Workspace(drafts: [draft], notes: ["AQ-083": "Source needed"], bookmarks: ["AQ-083"])
    try WorkspaceFile.save(state, to: temp)
    let loaded = try WorkspaceFile.load(from: temp)
    check(loaded == state, "Workspace round-trip")
    try Data("invalid".utf8).write(to: temp)
    do { _ = try WorkspaceFile.load(from: temp); check(false, "Reject corrupt file") }
    catch { check(true, "Reject corrupt file") }
    try Data("{\"version\":2,\"drafts\":[],\"notes\":{},\"bookmarks\":[]}".utf8).write(to: temp)
    do { _ = try WorkspaceFile.load(from: temp); check(false, "Reject future schema") }
    catch { check(true, "Reject future schema") }
} catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
runNewsChecks()
runSimilarityChecks()
runCountryChecks()
runCoverageChecks()
runPublicationChecks()
print("PASS: \(count) model checks")
if CommandLine.arguments.contains("--live-news") {
    Task.detached {
        do {
            let args = CommandLine.arguments
            let position = args.firstIndex(of: "--live-news")!
            let code = position + 1 < args.count ? args[position + 1] : "US"
            guard let country = NewsCountry(rawValue: code) else { fputs("FAIL: unsupported country code\n", stderr); exit(1) }
            let snapshot = try await NewsFeed.fetch(search: PlaceCatalog.defaultPlace(for: country).search)
            guard !snapshot.stories.isEmpty else { fputs("FAIL: live news returned no headlines\n", stderr); exit(1) }
            print("PASS: live \(country.name) English RSS: \(snapshot.stories.count) headlines; first publisher: \(snapshot.stories[0].publisher)")
            exit(0)
        } catch { fputs("FAIL: live feed: \(error)\n", stderr); exit(1) }
    }
    dispatchMain()
}
