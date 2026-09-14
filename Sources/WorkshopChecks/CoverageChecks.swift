import Foundation
import WorkshopCore

func runCoverageChecks() {
    for country in NewsCountry.allCases {
        let regions = CoverageCatalog.regions(in: country)
        check(!regions.isEmpty && regions.allSatisfy { $0.latitude.isFinite && $0.longitude.isFinite }, "Regional map coordinates: \(country.name)")
        check(Set(regions.map(\.id)).count == regions.count, "Unique regional groups: \(country.name)")
        let outline = CoverageCatalog.outlines[country.rawValue] ?? []
        check(!outline.isEmpty && outline.allSatisfy { $0.count > 2 && $0.allSatisfy { $0.count == 2 && (-180...180).contains($0[0]) && (-90...90).contains($0[1]) } }, "Bundled outline: \(country.name)")
    }
    check(CoverageCatalog.regions(in: .unitedStates).count == 52, "All states, DC, and Puerto Rico on coverage map")
    check(CoverageCatalog.suggestedRegions(title: "California and New Mexico reporting", country: .unitedStates).contains("CA"), "Full state names suggest regions")
    check(CoverageCatalog.suggestedRegions(title: "Observatory reports in Albuquerque", country: .unitedStates) == ["NM"], "Unique city suggests its state")
    check(CoverageCatalog.suggestedRegions(title: "Springfield repairs", country: .unitedStates).isEmpty, "Ambiguous city does not assign multiple states")
    check(CoverageCatalog.suggestedRegions(title: "Observatory reports in Toronto", country: .canada) == ["Ontario"], "Canada city suggests province")
    check(CoverageCatalog.suggestedRegions(title: "West Virginia reporting", country: .unitedStates) == ["WV"], "Nested state names are not counted twice")
    check(CoverageCatalog.suggestedRegions(title: "Trump says AI needs fewer rules", country: .unitedStates).isEmpty, "Person name without location context is not a town assignment")
    check(CoverageCatalog.suggestedRegions(title: "Apple releases software", country: .unitedStates).isEmpty, "Brand name without location context is not a town assignment")
    check(CoverageCatalog.suggestedRegions(title: "Reports in China", country: .unitedStates).isEmpty, "Foreign country name is not assigned to a US town")
    check(CoverageCatalog.suggestedRegions(title: "IN OR", country: .unitedStates).isEmpty, "State-code common words are not inferred")
    func story(_ id: String, _ title: String, publisher: String = "Example") -> NewsStory {
        NewsStory(title: title, url: URL(string: "https://example.org/" + id)!, publisher: publisher, published: nil)
    }
    let first = story("1", "California and New Mexico election reporting")
    let second = story("2", "Observatory review in Albuquerque")
    let third = story("3", "A national science report", publisher: "Other")
    let articles = [first, first, second, third]
    let basic = CoverageReport.build(country: .unitedStates, stories: articles, assessments: [:])
    check(basic.items.count == 3, "Duplicate URLs counted once")
    check(basic.regions.first { $0.id == "NM" }?.count == 2, "Each article counted once in a region")
    check(basic.regions.first { $0.id == "CA" }?.count == 1, "Multi-region article belongs to both regions")
    check(basic.unmapped.map(\.id) == [third.id], "Unmapped articles remain inspectable")
    check(basic.items.allSatisfy { $0.assessment.tone == .unreviewed }, "No invented tone labels")
    check(basic.regions.allSatisfy { $0.ratedCount == 0 }, "Unreviewed tone does not become neutral")
    check(basic.regions.first { $0.id == "NM" }?.publisherCount == 1, "Publisher count deduplicated")
    let assignedOnly = CoverageReport.build(country: .unitedStates, stories: articles, assessments: [:], includeSuggestions: false)
    check(assignedOnly.unmapped.count == 3 && assignedOnly.regions.allSatisfy { $0.count == 0 }, "Disabling suggestions shows only assigned regions")
    var reviewed = CoverageAssessment(story: first, country: .unitedStates)
    reviewed.regions = ["NY", "NY"]; reviewed.tone = .mixed; reviewed.format = .analysis; reviewed.notes = "Fixture"
    let assigned = CoverageReport.build(country: .unitedStates, stories: [first], assessments: [reviewed.id: reviewed])
    check(assigned.items[0].regions == ["NY"] && !assigned.items[0].suggested, "Manual region replaces and deduplicates suggestions")
    check(assigned.regions.first { $0.id == "NY" }?.ratedCount == 1, "Manual tone annotation counted")
    reviewed.regions = []
    let excluded = CoverageReport.build(country: .unitedStates, stories: [first], assessments: [reviewed.id: reviewed])
    check(excluded.unmapped.count == 1, "Explicitly unmapped overrides location suggestions")
    let filtered = CoverageReport.build(country: .unitedStates, stories: articles, assessments: [:], query: "election")
    check(filtered.text.contains("Headline filter: election"), "Export records map filters")
    check(filtered.items.map(\.id) == [first.id], "Headline filter constrains map sample")
    let publisher = CoverageReport.build(country: .unitedStates, stories: articles, assessments: [:], publisher: "Other")
    check(publisher.items.map(\.id) == [third.id], "Publisher filter constrains map sample")
    var foreign = CoverageAssessment(story: first, country: .canada); foreign.regions = ["Ontario"]; foreign.tone = .concerned
    let isolated = CoverageReport.build(country: .unitedStates, stories: [first], assessments: [foreign.id: foreign])
    check(isolated.items[0].assessment.tone == .unreviewed, "Country annotations remain isolated")
    check(basic.text.contains("not viewer sentiment") && basic.text.contains("Suggested location") && basic.text.contains(first.url.absoluteString), "Export retains scope limits and source URLs")
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("CoverageChecks-\(UUID().uuidString)/news.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    do {
        var workspace = NewsWorkspace(); workspace.coverageAssessments = [reviewed.id: reviewed]
        try NewsFile.save(workspace, to: url)
        let restored = try NewsFile.load(url)
        check(restored == workspace && restored.coverageAssessments?[reviewed.id]?.regions == [], "Coverage notes and explicit unmapped persist")
        reviewed.regions = ["INVALID_REGION"]; workspace.coverageAssessments = [reviewed.id: reviewed]
        try NewsFile.save(workspace, to: url)
        do { _ = try NewsFile.load(url); check(false, "Reject invalid imported region") }
        catch { check(true, "Reject invalid imported region") }
        reviewed.regions = nil; workspace.coverageAssessments = ["wrong": reviewed]
        try NewsFile.save(workspace, to: url)
        do { _ = try NewsFile.load(url); check(false, "Reject mismatched coverage key") }
        catch { check(true, "Reject mismatched coverage key") }
    } catch { check(false, "Coverage persistence: \(error)") }
}
