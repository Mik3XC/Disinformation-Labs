import Foundation
import CryptoKit

public enum NewsWindow: String, Codable, CaseIterable, Identifiable {
    case day = "24 hours", week = "7 days", month = "30 days"
    public var id: String { rawValue }
    public var queryValue: String { switch self { case .day: return "1d"; case .week: return "7d"; case .month: return "30d" } }
}

public struct NewsSearch: Codable, Equatable {
    public var place: String
    public var region: String
    public var topic: String
    public var window: NewsWindow
    public var countryCode: NewsCountry?
    public var country: NewsCountry {
        get { countryCode ?? .unitedStates }
        set { countryCode = newValue == .unitedStates ? nil : newValue }
    }
    public init(place: String = "Albuquerque", region: String = "NM", topic: String = "", window: NewsWindow = .week, country: NewsCountry = .unitedStates) {
        self.place = place; self.region = region; self.topic = topic; self.window = window; self.country = country
    }
    public static func clean(_ value: String) -> String {
        String(value.unicodeScalars.filter { CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: " '-.,")).contains($0) }.map(String.init).joined().split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(100))
    }
    public var normalized: Self { Self(place: Self.clean(place), region: Self.clean(region), topic: Self.clean(topic), window: window, country: country) }
    public var locationLabel: String { [normalized.place, normalized.region].filter { !$0.isEmpty }.joined(separator: ", ") }
    public var scopeID: String { NewsStory.digest((country == .unitedStates ? locationLabel : country.rawValue + "|" + locationLabel).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))) }
    public var query: String {
        let n = normalized
        return (n.topic.isEmpty ? "" : "\"\(n.topic)\" ") + "when:" + window.queryValue
    }
    public var feedURL: URL? {
        var components = URLComponents(string: normalized.topic.isEmpty ? "https://news.google.com/rss" : "https://news.google.com/rss/search")!
        components.queryItems = [URLQueryItem(name: "hl", value: country.language), URLQueryItem(name: "gl", value: country.rawValue), URLQueryItem(name: "ceid", value: country.edition)]
        if !normalized.topic.isEmpty { components.queryItems?.append(URLQueryItem(name: "q", value: query)) }
        return components.url
    }
}

public struct NewsStory: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let url: URL
    public let publisher: String
    public let publisherURL: URL?
    public let published: Date?
    public init(title: String, url: URL, publisher: String, publisherURL: URL? = nil, published: Date?) {
        self.id = Self.digest(Self.canonicalURL(url)); self.title = String(title.prefix(1000)); self.url = url
        self.publisher = String(publisher.prefix(160)); self.publisherURL = publisherURL; self.published = published
    }
    public static func digest(_ string: String) -> String { SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined() }
    public static func webURL(_ string: String) -> URL? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
    public static func canonicalURL(_ url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        parts.fragment = nil
        parts.queryItems = parts.queryItems?.filter { !$0.name.lowercased().hasPrefix("utm_") && !["oc", "fbclid", "gclid"].contains($0.name.lowercased()) }
        if parts.queryItems?.isEmpty == true { parts.queryItems = nil }
        return parts.string ?? url.absoluteString
    }
}

public enum EvidenceDimension: String, CaseIterable, Codable, Identifiable {
    case provenance = "Provenance", corroboration = "Corroboration", context = "Context", geography = "Geographic relevance"
    public var id: String { rawValue }
    public var code: String { switch self { case .provenance: return "P"; case .corroboration: return "C"; case .context: return "X"; case .geography: return "G" } }
    public var prompt: String {
        switch self {
        case .provenance: return "Can you trace the report to identifiable authors and inspect the original evidence?"
        case .corroboration: return "Do independent sources support the specific claim? Syndicated copies do not count as independent confirmation."
        case .context: return "Have you checked the date, quotation context, qualifications, and relevant corrections?"
        case .geography: return "Is the reported event actually relevant to the selected place, rather than just a passing or ambiguous mention?"
        }
    }
}
public enum EvidenceLevel: String, CaseIterable, Codable, Identifiable {
    case unknown = "Unreviewed", weak = "Weak", partial = "Partial", strong = "Strong"
    public var id: String { rawValue }
    public var value: Double? { switch self { case .unknown: return nil; case .weak: return 0; case .partial: return 0.5; case .strong: return 1 } }
}
public struct NewsReview: Codable, Equatable {
    public var provenance: EvidenceLevel = .unknown
    public var corroboration: EvidenceLevel = .unknown
    public var context: EvidenceLevel = .unknown
    public var geography: EvidenceLevel = .unknown
    public var notes = ""
    public var evidenceLinks = ""
    public var saved = false
    public var modified: Date?
    public init() {}
    public subscript(_ dimension: EvidenceDimension) -> EvidenceLevel {
        get { switch dimension { case .provenance: return provenance; case .corroboration: return corroboration; case .context: return context; case .geography: return geography } }
        set { switch dimension { case .provenance: provenance = newValue; case .corroboration: corroboration = newValue; case .context: context = newValue; case .geography: geography = newValue } }
    }
    public var reviewedCount: Int { EvidenceDimension.allCases.filter { self[$0] != .unknown }.count }
    /// This is a rubric average, not a calibrated probability of truth.
    public var confidence: Int? {
        guard reviewedCount == 4 else { return nil }
        return Int((EvidenceDimension.allCases.reduce(0.0) { $0 + (self[$1].value ?? 0) } * 25).rounded())
    }
    /// Unknown evidence is work to do, not proof of a false article.
    public var verificationPriority: Int {
        Int((EvidenceDimension.allCases.reduce(0.0) { $0 + (1 - (self[$1].value ?? 0)) } * 25).rounded())
    }
    public var priorityReasons: [String] {
        EvidenceDimension.allCases.compactMap { dimension in
            switch self[dimension] {
            case .unknown: return "\(dimension.rawValue) is unreviewed (+25)."
            case .weak: return "\(dimension.rawValue) was rated weak (+25)."
            case .partial: return "\(dimension.rawValue) was rated partial (+12.5)."
            case .strong: return nil
            }
        }
    }
}
public struct ReviewedStory: Identifiable, Codable, Equatable {
    public var id: String { Self.key(story: story, search: search) }
    public var story: NewsStory
    public var search: NewsSearch
    public var review: NewsReview
    public init(story: NewsStory, search: NewsSearch, review: NewsReview = NewsReview()) { self.story = story; self.search = search; self.review = review }
    public static func key(story: NewsStory, search: NewsSearch) -> String { story.id + "-" + search.scopeID }
}
public enum NewsSort: String, CaseIterable, Identifiable {
    case priority = "Verification priority", newest = "Newest first", confidence = "Evidence confidence"
    public var id: String { rawValue }
    public func order(_ entries: [ReviewedStory]) -> [ReviewedStory] {
        entries.sorted { a, b in
            switch self {
            case .priority:
                if a.review.verificationPriority != b.review.verificationPriority { return a.review.verificationPriority > b.review.verificationPriority }
            case .confidence:
                if (a.review.confidence ?? -1) != (b.review.confidence ?? -1) { return (a.review.confidence ?? -1) > (b.review.confidence ?? -1) }
            case .newest: break
            }
            let aDate = a.story.published ?? .distantPast, bDate = b.story.published ?? .distantPast
            return aDate == bDate ? a.id < b.id : aDate > bDate
        }
    }
}
public struct NewsSnapshot: Codable, Equatable {
    public var search: NewsSearch
    public var fetched: Date
    public var stories: [NewsStory]
    public init(search: NewsSearch, fetched: Date = Date(), stories: [NewsStory]) { self.search = search; self.fetched = fetched; self.stories = stories }
}
public struct NewsWorkspace: Codable, Equatable {
    public var version = 1
    public var search = NewsSearch()
    public var snapshot: NewsSnapshot?
    public var publicationProjects: [PublicationProject]?
    public var coverageAssessments: [String: CoverageAssessment]?
    public var countrySnapshots: [String: NewsSnapshot]?
    public var countryContexts: [String: CountryNewsContext]?
    public var activeSnapshot: NewsSnapshot? { snapshot?.search.country == search.country ? snapshot : nil }
    public mutating func selectCountry(_ country: NewsCountry) {
        guard country != search.country else { return }
        if let snapshot { countrySnapshots = (countrySnapshots ?? [:]).merging([snapshot.search.country.rawValue: snapshot]) { _, new in new } }
        let context = CountryNewsContext(search: search, radiusMiles: radiusMiles, seed: seed)
        countryContexts = (countryContexts ?? [:]).merging([search.country.rawValue: context]) { _, new in new }
        if let saved = countryContexts?[country.rawValue] {
            search = saved.search; radiusMiles = saved.radiusMiles; seed = saved.seed
        } else {
            search = PlaceCatalog.defaultPlace(for: country).search; radiusMiles = 150; seed = nil
        }
        snapshot = countrySnapshots?[country.rawValue]
    }
    public var reviews: [String: ReviewedStory] = [:]
    public var studies: [NewsStudy] = [NewsStudy()]
    public var radiusMiles = 150.0
    public var seed: NewsStory?
    public var similaritySettings: SimilaritySettings?
    public var activeSimilarity: SimilaritySettings { (similaritySettings ?? SimilaritySettings()).normalized }
    public init() {}
    public func entry(for story: NewsStory, search: NewsSearch) -> ReviewedStory {
        reviews[ReviewedStory.key(story: story, search: search)] ?? ReviewedStory(story: story, search: search)
    }
}
public enum NewsFile {
    public static func load(_ url: URL) throws -> NewsWorkspace {
        let data = try Data(contentsOf: url)
        guard data.count <= 25_000_000 else { throw NewsError.invalidArchive }
        let state = try JSONDecoder().decode(NewsWorkspace.self, from: data)
        guard state.version == 1 else { throw WorkspaceError.unsupportedVersion(state.version) }
        guard (state.countrySnapshots ?? [:]).allSatisfy({ key, value in key == value.search.country.rawValue }),
              (state.countryContexts ?? [:]).allSatisfy({ key, value in key == value.search.country.rawValue && value.radiusMiles.isFinite && (10...1000).contains(value.radiusMiles) }) else { throw NewsError.invalidArchive }
        let projects = state.publicationProjects ?? []
        guard Set(projects.map(\.id)).count == projects.count && projects.allSatisfy(\.isValid) else { throw NewsError.invalidArchive }
        let cachedStories = (state.countrySnapshots ?? [:]).values.flatMap(\.stories)
        let coverageStories = (state.coverageAssessments ?? [:]).values.map(\.story)
        let cachedSeeds = (state.countryContexts ?? [:]).values.compactMap(\.seed)
        let entries = coverageStories + cachedStories + cachedSeeds + (state.snapshot?.stories ?? []) + state.reviews.values.map(\.story) + [state.seed].compactMap { $0 } + state.studies.flatMap { $0.locations.compactMap(\.article) }
        guard (state.coverageAssessments ?? [:]).allSatisfy({ key, assessment in
            key == assessment.id && (assessment.regions ?? []).allSatisfy { code in CoverageCatalog.regions(in: assessment.country).contains { $0.code == code } }
        }) else { throw NewsError.invalidArchive }
        guard entries.allSatisfy({ NewsStory.webURL($0.url.absoluteString) != nil && $0.id == NewsStory.digest(NewsStory.canonicalURL($0.url)) }), state.reviews.allSatisfy({ $0.key == $0.value.id }),
            state.studies.allSatisfy({ study in
                study.locations.count <= 12 && study.radiusMiles.isFinite && (10...1000).contains(study.radiusMiles) &&
                Set(study.locations.map(\.id)).count == study.locations.count && Set(study.locations.map(\.place.id)).count == study.locations.count &&
                study.locations.allSatisfy { location in
                    (-90...90).contains(location.place.latitude) && (-180...180).contains(location.place.longitude) &&
                    (location.article.map { NewsStory.webURL($0.url.absoluteString) != nil } ?? true)
                }
            }), Set(state.studies.map(\.id)).count == state.studies.count, state.radiusMiles.isFinite, (10...1000).contains(state.radiusMiles) else { throw NewsError.invalidArchive }
        return state
    }
    public static func save(_ state: NewsWorkspace, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
public enum NewsError: LocalizedError {
    case wrongEdition, invalidLocation, invalidFeed, noConnection(Int), tooLarge, invalidArchive
    public var errorDescription: String? {
        switch self {
        case .wrongEdition: return "The provider returned a different language or edition. The selected country cache was preserved."
        case .invalidLocation: return "Enter a city, region, or country with at least two characters."
        case .invalidFeed: return "The provider returned an unreadable feed. Try again later; cached stories are preserved."
        case .noConnection(let status): return "The news provider returned HTTP \(status). Try again later."
        case .tooLarge: return "The news response exceeded the 5 MB download limit."
        case .invalidArchive: return "This is not a valid news research archive."
        }
    }
}
