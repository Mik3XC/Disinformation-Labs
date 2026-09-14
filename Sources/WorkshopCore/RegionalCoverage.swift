import Foundation

public enum ArticleTone: String, Codable, CaseIterable, Identifiable {
    case unreviewed = "Unreviewed", descriptive = "Descriptive", concerned = "Concerned / critical", optimistic = "Optimistic / approving", mixed = "Mixed"
    public var id: String { rawValue }
}
public enum ArticleFormat: String, Codable, CaseIterable, Identifiable {
    case unreviewed = "Unreviewed", reporting = "Reporting", analysis = "Analysis", opinion = "Opinion", satire = "Satire"
    public var id: String { rawValue }
}
public struct CoverageAssessment: Codable, Equatable {
    public var story: NewsStory
    public var country: NewsCountry
    /// nil means unreviewed location; [] means reviewed with no applicable region.
    public var regions: [String]?
    public var tone: ArticleTone = .unreviewed
    public var format: ArticleFormat = .unreviewed
    public var notes = ""
    public var modified = Date()
    public var id: String { Self.key(story: story, country: country) }
    public static func key(story: NewsStory, country: NewsCountry) -> String { country.rawValue + "|" + story.id }
    public init(story: NewsStory, country: NewsCountry) { self.story = story; self.country = country }
}
public struct CoverageRegion: Identifiable, Equatable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
}
public enum CoverageCatalog {
    private static let usNames = ["AL":"Alabama","AK":"Alaska","AZ":"Arizona","AR":"Arkansas","CA":"California","CO":"Colorado","CT":"Connecticut","DE":"Delaware","DC":"District of Columbia","FL":"Florida","GA":"Georgia","HI":"Hawaii","ID":"Idaho","IL":"Illinois","IN":"Indiana","IA":"Iowa","KS":"Kansas","KY":"Kentucky","LA":"Louisiana","ME":"Maine","MD":"Maryland","MA":"Massachusetts","MI":"Michigan","MN":"Minnesota","MS":"Mississippi","MO":"Missouri","MT":"Montana","NE":"Nebraska","NV":"Nevada","NH":"New Hampshire","NJ":"New Jersey","NM":"New Mexico","NY":"New York","NC":"North Carolina","ND":"North Dakota","OH":"Ohio","OK":"Oklahoma","OR":"Oregon","PA":"Pennsylvania","RI":"Rhode Island","SC":"South Carolina","SD":"South Dakota","TN":"Tennessee","TX":"Texas","UT":"Utah","VT":"Vermont","VA":"Virginia","WA":"Washington","WV":"West Virginia","WI":"Wisconsin","WY":"Wyoming","PR":"Puerto Rico"]
    private static let catalog: [NewsCountry: [CoverageRegion]] = Dictionary(uniqueKeysWithValues: NewsCountry.allCases.map { country in
        let groups = Dictionary(grouping: PlaceCatalog.places(in: country), by: \.state)
        let regions = groups.map { code, places in
            let lat = places.map(\.latitude).reduce(0, +) / Double(places.count)
            let sinSum = places.reduce(0.0) { $0 + sin($1.longitude * .pi / 180) }
            let cosSum = places.reduce(0.0) { $0 + cos($1.longitude * .pi / 180) }
            return CoverageRegion(code: code, name: country == .unitedStates ? usNames[code] ?? code : code,
                                  latitude: lat, longitude: atan2(sinSum, cosSum) * 180 / .pi)
        }.sorted { $0.name < $1.name }
        return (country, regions)
    })
    public static func regions(in country: NewsCountry) -> [CoverageRegion] { catalog[country] ?? [] }
    private struct PlacePhrase { let words: [String]; let regions: Set<String> }
    private static let indexes: [NewsCountry: [String: [PlacePhrase]]] = Dictionary(uniqueKeysWithValues: NewsCountry.allCases.map { country in
        let grouped = Dictionary(grouping: PlaceCatalog.places(in: country), by: { TextSimilarity.words($0.name).joined(separator: " ") })
        let phrases = grouped.map { name, places in PlacePhrase(words: TextSimilarity.words(name), regions: Set(places.map(\.state))) }.filter { !$0.words.isEmpty }
        return (country, Dictionary(grouping: phrases, by: { $0.words[0] }))
    })
    private static let countryNames: Set<String> = Set(Locale.Region.isoRegions.compactMap { Locale(identifier: "en_US").localizedString(forRegionCode: $0.identifier)?.lowercased() }).union(["china", "america", "usa", "uk", "britain"])
    /// Suggestions only. Prefer complete names; never also count a nested name.
    public static func suggestedRegions(title: String, country: NewsCountry) -> [String] {
        let words = TextSimilarity.words(title)
        let genericPlaces: Set<String> = ["national", "international", "union", "reading", "progress", "enterprise", "independence", "republic", "hope", "normal", "election", "vote", "science", "report", "news", "today", "tomorrow", "security", "industry", "economy", "leader", "winner", "freedom", "justice", "liberty"]
        let regionPhrases = regions(in: country).filter { $0.name != "Washington" }.map { ($0.code, TextSimilarity.words($0.name)) }
        func matches(_ phrase: [String], at start: Int) -> Bool {
            !phrase.isEmpty && phrase.count + start <= words.count && Array(words[start..<(start + phrase.count)]) == phrase
        }
        var result = Set<String>(), start = 0
        while start < words.count {
            let regionMatches = regionPhrases.filter { matches($0.1, at: start) }
            let cityMatches = (indexes[country]?[words[start]] ?? []).filter { phrase in
                guard matches(phrase.words, at: start) else { return false }
                if phrase.words.count == 1 {
                    // A unique catalog name can also be a person, brand, or country.
                    let hasLocationCue = start > 0 && ["in", "near", "around"].contains(words[start - 1])
                    return hasLocationCue && !genericPlaces.contains(phrase.words[0]) && !countryNames.contains(phrase.words[0])
                }
                return true
            }
            let longest = max(regionMatches.map { $0.1.count }.max() ?? 0, cityMatches.map { $0.words.count }.max() ?? 0)
            let explicit = regionMatches.filter { $0.1.count == longest }
            if !explicit.isEmpty { result.formUnion(explicit.map { $0.0 }) }
            else { for phrase in cityMatches where phrase.words.count == longest && phrase.regions.count == 1 { result.formUnion(phrase.regions) } }
            start += max(1, longest)
        }
        return result.sorted()
    }
    public static let outlines: [String: [[[Double]]]] = {
        let packaged = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("DisinformationWorkshop_WorkshopCore.bundle")) }
        guard let url = (packaged ?? Bundle.module).url(forResource: "CountryOutlines", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [[[Double]]]].self, from: data)) ?? [:]
    }()
}
public struct CoverageItem: Identifiable {
    public var id: String { story.id }
    public let story: NewsStory
    public let assessment: CoverageAssessment
    public let regions: [String]
    public let suggested: Bool
}
public struct RegionCoverage: Identifiable {
    public var id: String { region.id }
    public let region: CoverageRegion
    public let items: [CoverageItem]
    public var count: Int { items.count }
    public var suggestedCount: Int { items.filter(\.suggested).count }
    public var publisherCount: Int { Set(items.map { $0.story.publisher.lowercased() }).count }
    public var ratedCount: Int { items.filter { $0.assessment.tone != .unreviewed }.count }
}
public struct CoverageReport {
    public let filterDescription: String
    public let country: NewsCountry
    public let items: [CoverageItem]
    public let regions: [RegionCoverage]
    public var unmapped: [CoverageItem] { items.filter { $0.regions.isEmpty } }
    public static func build(country: NewsCountry, stories: [NewsStory], assessments: [String: CoverageAssessment], includeSuggestions: Bool = true, query: String = "", publisher: String = "", fetched: Date? = nil) -> Self {
        var seen = Set<String>()
        let items = stories.filter { seen.insert($0.id).inserted }.filter {
            (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) && (publisher.isEmpty || $0.publisher == publisher)
        }.map { story in
            let assessment = assessments[CoverageAssessment.key(story: story, country: country)] ?? CoverageAssessment(story: story, country: country)
            let regions = assessment.regions ?? (includeSuggestions ? CoverageCatalog.suggestedRegions(title: story.title, country: country) : [])
            let valid = Set(CoverageCatalog.regions(in: country).map(\.code))
            return CoverageItem(story: story, assessment: assessment, regions: Array(Set(regions).intersection(valid)).sorted(), suggested: assessment.regions == nil)
        }
        let filters = "Headline filter: \(query.isEmpty ? "None" : query); publisher: \(publisher.isEmpty ? "All" : publisher); suggested locations: \(includeSuggestions ? "included" : "excluded"); cache timestamp: \(fetched.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown")"
        return Self(filterDescription: filters, country: country, items: items, regions: CoverageCatalog.regions(in: country).map { region in
            RegionCoverage(region: region, items: items.filter { $0.regions.contains(region.code) })
        })
    }
    public var text: String {
        var lines = ["REGIONAL COVERAGE REVIEW", "Country: " + country.name, filterDescription,
                     "Selected cached sample: \(items.count) distinct articles; \(unmapped.count) unmapped.",
                     "Coverage volume is not viewer sentiment, political opinion, or audience composition. Region suggestions come from headline names and are unverified. Tone/format labels are manual assessments. Articles may appear in multiple regions; regional totals are not additive.", ""]
        for region in regions where region.count > 0 {
            lines.append("\(region.region.name): \(region.count) articles, \(region.publisherCount) publisher labels, \(region.suggestedCount) suggested locations, \(region.ratedCount) tone-rated")
            for item in region.items {
                lines += [item.story.title, "\(item.story.publisher) | \(item.suggested ? "Suggested location" : "Analyst-assigned location") | Tone: \(item.assessment.tone.rawValue) | Format: \(item.assessment.format.rawValue)", item.story.url.absoluteString]
                if !item.assessment.notes.isEmpty { lines.append("Assessment notes: " + item.assessment.notes) }
            }
            lines.append("")
        }
        lines.append("UNMAPPED ARTICLES")
        for item in unmapped { lines += [item.story.title, item.story.url.absoluteString] }
        return lines.joined(separator: "\n")
    }
}
