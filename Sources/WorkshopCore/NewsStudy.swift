import Foundation

public struct NewsPlace: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let state: String
    public let latitude: Double
    public let longitude: Double
    public var countryCode: NewsCountry?
    public var country: NewsCountry { countryCode ?? .unitedStates }
    public init(id: String, name: String, state: String, latitude: Double, longitude: Double, country: NewsCountry = .unitedStates) {
        self.id = id; self.name = name; self.state = state; self.latitude = latitude; self.longitude = longitude
        self.countryCode = country == .unitedStates ? nil : country
    }
    public var label: String { name + ", " + state }
    public var search: NewsSearch { NewsSearch(place: name, region: state, country: country) }
    public func distanceMiles(to other: NewsPlace) -> Double {
        let rad = Double.pi / 180
        let dLat = (other.latitude - latitude) * rad, dLon = (other.longitude - longitude) * rad
        let a = pow(sin(dLat / 2), 2) + cos(latitude * rad) * cos(other.latitude * rad) * pow(sin(dLon / 2), 2)
        return 3958.7613 * 2 * atan2(sqrt(max(0, min(1, a))), sqrt(max(0, 1 - a)))
    }
    public func mentioned(in title: String) -> Bool { TextSimilarity.containsPhrase(name, in: title) }
}
public enum PlaceCatalog {
    private static func load(_ name: String, international: Bool) -> [NewsPlace] {
        let packaged = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("DisinformationWorkshop_WorkshopCore.bundle")) }
        let bundle = packaged ?? Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: "tsv"), let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t").map(String.init)
            guard f.count == (international ? 6 : 5), let lat = Double(f[3]), let lon = Double(f[4]) else { return nil }
            let country = international ? NewsCountry(rawValue: f[5]) : .unitedStates
            guard let country else { return nil }
            return NewsPlace(id: f[0], name: f[1], state: f[2], latitude: lat, longitude: lon, country: country)
        }
    }
    public static let all = load("USPlaces", international: false) + load("InternationalPlaces", international: true)
    private static let grouped = Dictionary(grouping: all, by: \.country)
    public static func places(in country: NewsCountry) -> [NewsPlace] { grouped[country] ?? [] }
    public static func regions(in country: NewsCountry) -> [String] { Array(Set(places(in: country).map(\.state))).sorted() }
    public static var states: [String] { regions(in: .unitedStates) }
    public static var albuquerque: NewsPlace { defaultPlace(for: .unitedStates) }
    public static func defaultPlace(for country: NewsCountry) -> NewsPlace {
        // Every supported edition has a checked, bundled default city.
        places(in: country).first { $0.name == country.defaultCityName }!
    }
    public static func matches(_ query: String, state: String = "", country: NewsCountry = .unitedStates) -> [NewsPlace] {
        let terms = query.split(whereSeparator: \.isWhitespace)
        return places(in: country).filter { place in
            (state.isEmpty || place.state == state) && terms.allSatisfy { place.label.localizedCaseInsensitiveContains($0) }
        }
    }
    public static func neighbors(of place: NewsPlace, radius: Double, excluding: Set<String> = []) -> [(NewsPlace, Double)] {
        places(in: place.country).compactMap { candidate -> (NewsPlace, Double)? in
            guard candidate.id != place.id, !excluding.contains(candidate.id) else { return nil }
            let distance = place.distanceMiles(to: candidate)
            return distance <= radius ? (candidate, distance) : nil
        }.sorted { $0.1 == $1.1 ? $0.0.id < $1.0.id : $0.1 < $1.1 }
    }
}

public enum TextSimilarity {
    private static let stop: Set<String> = ["a", "an", "the", "in", "on", "at", "and", "or", "to", "of", "for", "from", "with", "by", "is", "are", "was", "were", "as", "it", "its", "this", "that", "after", "before", "over", "new", "news", "says", "say", "about", "has", "have", "be", "will"]
    public static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
    public static func tokens(_ text: String) -> Set<String> { Set(words(text).filter { $0.count > 1 && !stop.contains($0) }) }
    public static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let needle = words(phrase), haystack = words(text)
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }
        return (0...(haystack.count - needle.count)).contains { Array(haystack[$0..<($0 + needle.count)]) == needle }
    }
    /// Jaccard token overlap. No semantic model, truth inference, or event identity inference.
    public static func overlap(_ a: String, _ b: String) -> Double? {
        let x = tokens(a), y = tokens(b)
        guard !x.isEmpty, !y.isEmpty else { return nil }
        return Double(x.intersection(y).count) / Double(x.union(y).count)
    }
    public static func sharedTerms(_ a: String, _ b: String) -> [String] { tokens(a).intersection(tokens(b)).sorted() }
    public static func publicationGapHours(_ a: NewsStory, _ b: NewsStory) -> Double? {
        guard let first = a.published, let second = b.published else { return nil }
        return abs(first.timeIntervalSince(second)) / 3600
    }
}
public struct StudyLocation: Identifiable, Codable, Equatable {
    public var id: UUID
    public var place: NewsPlace
    public var article: NewsStory?
    public init(place: NewsPlace, article: NewsStory? = nil) { id = UUID(); self.place = place; self.article = article }
}
public struct NewsStudy: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var title = "Untitled geographic study"
    public var theme = ""
    public var notes = ""
    public var radiusMiles = 150.0
    public var locations: [StudyLocation]
    public var modified = Date()
    public var similaritySettings: SimilaritySettings?
    public var activeSimilarity: SimilaritySettings { (similaritySettings ?? SimilaritySettings()).normalized }
    public func vector(from a: StudyLocation, to b: StudyLocation) -> HeadlineVector? {
        guard let aa = a.article, let bb = b.article else { return nil }
        return HeadlineSimilarity.compare(seed: aa.title, candidate: bb.title, places: [a.place.name, a.place.state, b.place.name, b.place.state], settings: activeSimilarity)
    }
    public var country: NewsCountry { locations.first?.place.country ?? .unitedStates }
    public init(country: NewsCountry = .unitedStates) {
        locations = ["Albuquerque", "Santa Fe", "Roswell", "Las Cruces", "Phoenix"].compactMap { name in
            PlaceCatalog.all.first { $0.name == name && ["NM", "AZ"].contains($0.state) }.map { StudyLocation(place: $0) }
        }
        if country != .unitedStates {
            let center = PlaceCatalog.defaultPlace(for: country)
            locations = [StudyLocation(place: center)] + PlaceCatalog.neighbors(of: center, radius: 1000).prefix(4).map { StudyLocation(place: $0.0) }
        }
    }
    public var assignedCount: Int { locations.filter { $0.article != nil }.count }
    public var distinctArticleCount: Int { Set(locations.compactMap { $0.article?.id }).count }
    public var report: String {
        var lines = ["GEOGRAPHIC RESEARCH / FICTION STUDY", title, "Country: " + country.name, "Theme: " + (theme.isEmpty ? "None specified" : theme), "", "Headline overlap is not corroboration. Dates are publication dates, not event times. Distances are between place centroids, not reported event locations.", ""]
        for (i, item) in locations.enumerated() {
            lines.append("\(i + 1). \(item.place.label)")
            if let article = item.article {
                lines += [article.title, "Publisher: \(article.publisher)", article.url.absoluteString, "City-name mention in headline: \(item.place.mentioned(in: article.title) ? "yes (unverified)" : "no")"]
            } else { lines.append("No article assigned.") }
        }
        lines += ["", "SIMILARITY SETTINGS", activeSimilarity.summary, "Ignored terms: " + activeSimilarity.ignoredTerms,
                  "PAIRWISE VECTOR: K=keywords, P=phrases, C=first-city seed coverage; indices are lexical, not truth probabilities. City distance and publication gap do not increase the index."]
        for i in locations.indices { for j in locations.indices where j > i {
            let a = locations[i], b = locations[j]
            let comparison = vector(from: a, to: b)
            let gap = a.article.flatMap { aa in b.article.flatMap { TextSimilarity.publicationGapHours(aa, $0) } }.map { String(format: "%.1fh", $0) } ?? "unknown"
            lines.append("\(a.place.label) → \(b.place.label): \(comparison?.summary ?? "unknown") / \(Int(a.place.distanceMiles(to: b.place))) mi / \(gap)")
            if let comparison { lines.append("Shared terms: " + comparison.sharedTerms.joined(separator: ", ")); lines.append("Shared phrases: " + comparison.sharedPhrases.joined(separator: ", ")) }
        } }
        lines += ["", "ANALYST NOTES", notes]
        return lines.joined(separator: "\n")
    }
}

public struct NearbyStory: Identifiable {
    public var id: String { story.id }
    public let story: NewsStory
    public let place: NewsPlace
    public let miles: Double
    public let vector: HeadlineVector?
    public var similarity: Double? { vector?.score }
}
public enum NearbySearch {
    public static func matches(stories: [NewsStory], center: NewsPlace, radius: Double, seed: NewsStory?, settings: SimilaritySettings = SimilaritySettings()) -> [NearbyStory] {
        let places = ([(center, 0.0)] + PlaceCatalog.neighbors(of: center, radius: radius)).map { ($0.0, $0.1, " " + TextSimilarity.words($0.0.name).joined(separator: " ") + " ") }
        return stories.compactMap { article -> NearbyStory? in
            guard article.id != seed?.id else { return nil }
            let headline = " " + TextSimilarity.words(article.title).joined(separator: " ") + " "
            guard let place = places.first(where: { headline.contains($0.2) }) else { return nil }
            let vector = seed.map { HeadlineSimilarity.compare(seed: $0.title, candidate: article.title, places: [center.name, center.state, place.0.name, place.0.state], settings: settings) }
            if let vector, !vector.eligible && !settings.showWeakMatches { return nil }
            return NearbyStory(story: article, place: place.0, miles: place.1, vector: vector)
        }.sorted { a, b in
            if a.vector?.eligible != b.vector?.eligible { return a.vector?.eligible == true }
            if (a.similarity ?? -1) != (b.similarity ?? -1) { return (a.similarity ?? -1) > (b.similarity ?? -1) }
            if a.miles != b.miles { return a.miles < b.miles }
            return a.id < b.id
        }
    }
}
