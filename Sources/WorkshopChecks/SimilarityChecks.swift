import Foundation
import WorkshopCore

func runSimilarityChecks() {
    let places = ["Albuquerque", "Santa Fe", "NM"]
    func compare(_ a: String, _ b: String, _ settings: SimilaritySettings = SimilaritySettings()) -> HeadlineVector {
        HeadlineSimilarity.compare(seed: a, candidate: b, places: places, settings: settings)
    }
    let cityOnly = compare("Albuquerque opens riverside walking trail", "Albuquerque studies distant galaxies")
    check(!cityOnly.eligible && cityOnly.sharedTerms.isEmpty && cityOnly.score == 0, "A shared city alone gives no topical score")
    let boilerplate = compare("Breaking local officials report bridge repairs", "Breaking local officials report school concert")
    check(!boilerplate.eligible && boilerplate.sharedTerms.isEmpty, "Reporting boilerplate does not imply topical similarity")
    let oneTerm = compare("Albuquerque railway station expands platforms", "Santa Fe space station photographs Jupiter")
    check(!oneTerm.eligible && oneTerm.sharedTerms == ["station"], "One ambiguous shared term is insufficient")
    let positive = compare("Albuquerque water treatment plant opens", "Santa Fe water treatment plant opens")
    check(positive.eligible && positive.score == 1, "Same content across city names passes")
    check(positive.sharedPhrases.contains("water treatment") && !positive.sharedTerms.contains("albuquerque"), "Explainable shared phrases and place exclusions")
    let ordering = compare("Sensors track storm clouds", "Storm clouds track sensors")
    check(ordering.keyword == 1 && (ordering.phrase ?? 1) < 1, "Phrase dimension distinguishes order")
    let denial = compare("Bridge inspection finds structural damage", "Bridge inspection finds no structural damage")
    check(denial.wordingConflict && !denial.eligible, "Negation difference held for review")
    var allowDenial = SimilaritySettings(); allowDenial.excludeWordingConflicts = false
    check(compare("Bridge inspection finds structural damage", "Bridge inspection finds no structural damage", allowDenial).eligible, "Wording review can be explicitly overridden")
    let gap = compare("Storm not clouds", "Storm clouds")
    check(!gap.sharedPhrases.contains("storm clouds"), "Exclusions never fabricate adjacent phrases")
    let empty = compare("Albuquerque news report", "Santa Fe latest local report")
    check(empty.score == nil && !empty.eligible, "No remaining content is unknown rather than a match")
    var zero = SimilaritySettings(); zero.keywordWeight = 0; zero.phraseWeight = 0; zero.coverageWeight = 0
    check(compare("water treatment", "water treatment", zero).score == nil, "Zero weights do not divide by zero")
    var keywordOnly = zero; keywordOnly.keywordWeight = 1
    let weighted = compare("water treatment plant", "water treatment study", keywordOnly)
    check(weighted.score == weighted.keyword && weighted.keyword == 0.5, "Weights connect to the score")
    var strict = SimilaritySettings(); strict.minimumScore = 0.95
    check(!compare("water treatment plant opens", "water treatment study opens", strict).eligible, "Raised threshold excludes loose matches")
    var custom = SimilaritySettings(); custom.ignoredTerms = "water, treatment"
    check(compare("water treatment plant", "water treatment bridge", custom).sharedTerms.isEmpty, "Custom ignored words remove shared boilerplate")
    let a = compare("water treatment", "water treatment plant opens")
    let b = compare("water treatment plant opens", "water treatment")
    check(a.keyword == b.keyword && a.phrase == b.phrase && a.coverage == 1 && b.coverage == 0.5, "Coverage has explicit seed direction")
    check(compare("NEW YORK sensor network", "sensor network", SimilaritySettings()).sharedTerms == ["network", "sensor"], "Other content remains available")
    check(HeadlineSimilarity.compare(seed: "New York sensor network", candidate: "York sensor network", places: ["New York"]).seedOnly.isEmpty, "Whole place phrase excluded without removing unrelated content")
    check(HeadlineSimilarity.compare(seed: "", candidate: "water treatment", shortQuery: true).score == nil, "Blank theme remains unscored")
    check(!compare("flood", "flood").eligible, "One-word article titles are insufficient by default")
    check(HeadlineSimilarity.compare(seed: "flood", candidate: "flood", shortQuery: true).eligible, "Explicit one-word theme can be used")
    var invalid = SimilaritySettings(); invalid.keywordWeight = .nan; invalid.phraseWeight = 9; invalid.coverageWeight = -8; invalid.minimumSharedTerms = 20
    check(invalid.normalized.keywordWeight == 0.6 && invalid.normalized.phraseWeight == 1 && invalid.normalized.coverageWeight == 0 && invalid.normalized.minimumSharedTerms == 5, "Settings are bounded and nonfinite values normalized")
    let abq = PlaceCatalog.albuquerque
    let seed = NewsStory(title: "Albuquerque water treatment plant opens", url: URL(string: "https://example.org/seed")!, publisher: "Fixture", published: nil)
    let weak = NewsStory(title: "Santa Fe railway station opens", url: URL(string: "https://example.org/weak")!, publisher: "Fixture", published: nil)
    let related = NewsStory(title: "Santa Fe water treatment plant opens", url: URL(string: "https://example.org/related")!, publisher: "Fixture", published: nil)
    let hidden = NearbySearch.matches(stories: [weak, related], center: abq, radius: 80, seed: seed)
    check(hidden.map(\.id) == [related.id], "Radius ranking excludes weak comparisons by default")
    var showWeak = SimilaritySettings(); showWeak.showWeakMatches = true
    let inspected = NearbySearch.matches(stories: [weak, related], center: abq, radius: 80, seed: seed, settings: showWeak)
    check(inspected.count == 2 && inspected.first?.id == related.id && inspected.last?.vector?.eligible == false, "Weak inspection keeps passing matches first")
    let wider = NearbySearch.matches(stories: [weak, related], center: abq, radius: 300, seed: seed)
    check(wider.first?.vector?.score == hidden.first?.vector?.score, "Radius expansion does not boost topical score")
    let dated = NewsStory(title: related.title, url: related.url, publisher: "Another publisher", published: Date())
    check(NearbySearch.matches(stories: [dated], center: abq, radius: 80, seed: seed).first?.vector?.score == hidden.first?.vector?.score, "Publisher and date do not boost index")
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("SimilarityChecks-\(UUID().uuidString)/news.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    do {
        var state = NewsWorkspace(); state.similaritySettings = strict; state.studies[0].similaritySettings = keywordOnly
        try NewsFile.save(state, to: file)
        let loaded = try NewsFile.load(file)
        check(loaded.activeSimilarity == strict && loaded.studies[0].activeSimilarity == keywordOnly, "Feed and per-study calibration persist independently")
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        json.removeValue(forKey: "similaritySettings")
        var studies = json["studies"] as! [[String: Any]]
        for index in studies.indices { studies[index].removeValue(forKey: "similaritySettings") }
        json["studies"] = studies
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        let legacy = try NewsFile.load(file)
        check(legacy.activeSimilarity == SimilaritySettings() && legacy.studies[0].activeSimilarity == SimilaritySettings(), "Version 1.1 archives open with safe defaults")
        check(loaded.studies[0].report.contains("SIMILARITY SETTINGS"), "Study export contains calibration settings")
    } catch { check(false, "Similarity persistence: \(error)") }
}
