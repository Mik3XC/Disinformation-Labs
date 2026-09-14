import Foundation

public enum PublicationStatus: String, Codable, CaseIterable, Identifiable {
    case published = "Published", corrected = "Corrected", retracted = "Retracted"
    public var id: String { rawValue }
}
public enum MentionKind: String, Codable, CaseIterable, Identifiable {
    case link = "Link / citation", republication = "Republication", discussion = "Discussion"
    public var id: String { rawValue }
}
public enum MentionReview: String, Codable, CaseIterable, Identifiable {
    case unreviewed = "Unreviewed", confirmed = "Analyst-confirmed", rejected = "Rejected"
    public var id: String { rawValue }
}
public struct ProjectPublication: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var title: String
    public var url: URL
    public var published: Date?
    public var status = PublicationStatus.published
    public var notes = ""
    public init(title: String, url: URL, published: Date? = nil) { self.title = title; self.url = url; self.published = published }
}
public struct PublicationMention: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var publicationID: UUID
    public var title: String
    public var url: URL
    public var observed = Date()
    public var kind = MentionKind.link
    public var review = MentionReview.unreviewed
    public var evidence = ""
    public var location: NewsPlace?
    public var locationConfirmed = false
    public var locationEvidence = ""
    public init(publicationID: UUID, title: String, url: URL) { self.publicationID = publicationID; self.title = title; self.url = url }
    public var canonicalURL: String { PublicationProject.canonicalURL(url) }
}
public struct PublicationAnalytics: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var publicationID: UUID
    public var pageViews: Int64
    public var measured = Date()
    public var source: String
    public init(publicationID: UUID, pageViews: Int64, source: String) { self.publicationID = publicationID; self.pageViews = pageViews; self.source = source }
}
public struct PublicationProject: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var title = "Untitled publication project"
    public var notes = ""
    public var country: NewsCountry
    public var archived = false
    public var publications: [ProjectPublication] = []
    public var mentions: [PublicationMention] = []
    public var analytics: [PublicationAnalytics] = []
    public var modified = Date()
    public init(country: NewsCountry = .unitedStates) { self.country = country }
    public static func canonicalURL(_ url: URL) -> String {
        let base = NewsStory.canonicalURL(url)
        guard var parts = URLComponents(string: base) else { return base }
        parts.scheme = parts.scheme?.lowercased(); parts.host = parts.host?.lowercased()
        if (parts.scheme == "https" && parts.port == 443) || (parts.scheme == "http" && parts.port == 80) { parts.port = nil }
        parts.queryItems = parts.queryItems?.sorted { $0.name == $1.name ? ($0.value ?? "") < ($1.value ?? "") : $0.name < $1.name }
        return parts.url?.absoluteString ?? base
    }
    public static func host(_ url: URL) -> String {
        let host = (url.host ?? "").lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    public var isValid: Bool {
        let ids = Set(publications.map(\.id))
        return ids.count == publications.count && Set(mentions.map(\.id)).count == mentions.count && Set(analytics.map(\.id)).count == analytics.count &&
            publications.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && NewsStory.webURL($0.url.absoluteString) != nil } &&
            mentions.allSatisfy { item in
                ids.contains(item.publicationID) && !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && NewsStory.webURL(item.url.absoluteString) != nil &&
                (item.review != .confirmed || !item.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
                (!item.locationConfirmed || (item.location != nil && !item.locationEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) &&
                (item.location.map { location in !location.id.isEmpty && (-90...90).contains(location.latitude) && (-180...180).contains(location.longitude) && CoverageCatalog.regions(in: location.country).contains { $0.code == location.state } } ?? true)
            } && analytics.allSatisfy { ids.contains($0.publicationID) && (0...999_999_999_999).contains($0.pageViews) && !$0.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    /// Latest cumulative count per canonical publication URL, never sum snapshots.
    public var latestAnalytics: [PublicationAnalytics] {
        let publicationsByID = Dictionary(uniqueKeysWithValues: publications.map { ($0.id, $0) })
        let valid = analytics.filter { publicationsByID[$0.publicationID] != nil }
        let groups = Dictionary(grouping: valid) { PublicationProject.canonicalURL(publicationsByID[$0.publicationID]!.url) }
        return groups.values.compactMap { $0.sorted { $0.measured == $1.measured ? $0.id.uuidString > $1.id.uuidString : $0.measured > $1.measured }.first }
    }
    public var reportedPageViews: Int64? {
        let latest = latestAnalytics
        return latest.isEmpty ? nil : latest.reduce(Int64(0)) { $0 + $1.pageViews }
    }
    public var distinctPublications: Int { Set(publications.map { PublicationProject.canonicalURL($0.url) }).count }
    public var spread: ProjectSpread { ProjectSpread(project: self) }
    public var report: String {
        let spread = spread
        var lines = ["PUBLICATION PROJECT / OBSERVED DISTRIBUTION", title, "Home edition: \(country.name) | \(archived ? "Archived" : "Active")", "",
                     "\(distinctPublications) distinct publication URLs; reported cumulative page views: \(reportedPageViews.map(String.init) ?? "unknown") (\(latestAnalytics.count)/\(distinctPublications) URLs measured). Counts are manually recorded, may have different as-of dates, and are not unique readers.",
                     "\(spread.confirmed.count) distinct analyst-confirmed external URLs; \(spread.hostCount) hostnames; \(spread.located.count) geographically documented URLs; \(spread.regionCount) regions; \(spread.cityCount) places; \(spread.countryCount) countries.",
                     "Sprawl index: \(spread.index.map { String(format: "%.1f", $0) } ?? "unknown"). 100 × (1 − sum of squared regional shares), using one confirmed source location per distinct external URL. This is observed regional dispersion, not audience reach, influence, truth, or comprehensive web coverage.",
                     "Geographic evidence coverage: \(spread.located.count)/\(spread.confirmed.count). Conflicting locations on duplicate URLs are excluded. Hostnames do not establish independent ownership. Maximum source-place separation: \(spread.maximumMiles.map { String(format: "%.0f miles", $0) } ?? "unknown").", "", "PROJECT NOTES", notes, "", "PUBLICATIONS"]
        for publication in publications {
            lines += [publication.title, publication.url.absoluteString, "\(publication.status.rawValue) | Published: \(publication.published.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown")", publication.notes]
        }
        lines += ["", "OBSERVATIONS"]
        for mention in mentions.sorted(by: { $0.observed < $1.observed }) {
            lines += [mention.title, mention.url.absoluteString, "Publication: \(publications.first { $0.id == mention.publicationID }?.title ?? "Unknown") | \(mention.kind.rawValue) | \(mention.review.rawValue) | Observed: \(ISO8601DateFormatter().string(from: mention.observed))", "Relationship evidence: " + mention.evidence,
                      "Source location: \(mention.location.map { $0.label + ", " + $0.country.name } ?? "unknown") | \(mention.locationConfirmed ? "Analyst-confirmed" : "Unreviewed")", "Location evidence: " + mention.locationEvidence]
        }
        lines += ["", "ANALYTICS HISTORY / CUMULATIVE PAGE VIEWS"]
        for sample in analytics.sorted(by: { $0.measured < $1.measured }) { lines.append("\(publications.first { $0.id == sample.publicationID }?.title ?? "Unknown") | \(sample.pageViews) | \(ISO8601DateFormatter().string(from: sample.measured)) | \(sample.source)") }
        return lines.joined(separator: "\n")
    }
}
public struct ProjectSpread {
    public let confirmed: [PublicationMention]
    public let located: [PublicationMention]
    public var hostCount: Int { Set(confirmed.map { PublicationProject.host($0.url) }).count }
    public var cityCount: Int { Set(located.compactMap { $0.location?.id }).count }
    public var countryCount: Int { Set(located.compactMap { $0.location?.country }).count }
    private var regionCounts: [String: Int] { Dictionary(grouping: located) { $0.location!.country.rawValue + "|" + $0.location!.state }.mapValues(\.count) }
    public var regionCount: Int { regionCounts.count }
    public var index: Double? {
        guard !located.isEmpty else { return nil }
        let n = Double(located.count)
        return max(0, min(100, 100 * (1 - regionCounts.values.reduce(0.0) { $0 + pow(Double($1) / n, 2) })))
    }
    public var maximumMiles: Double? {
        let places = Array(Set(located.compactMap(\.location)))
        guard places.count >= 2 else { return nil }
        var maxDistance = 0.0
        for i in places.indices { for j in places.indices where j > i { maxDistance = max(maxDistance, places[i].distanceMiles(to: places[j])) } }
        return maxDistance
    }
    public init(project: PublicationProject) {
        let ownedHosts = Set(project.publications.map { PublicationProject.host($0.url) })
        let usable = project.mentions.filter { $0.review == .confirmed && !$0.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !ownedHosts.contains(PublicationProject.host($0.url)) }
        let groups = Dictionary(grouping: usable, by: \.canonicalURL)
        confirmed = groups.values.compactMap { $0.sorted { $0.observed == $1.observed ? $0.id.uuidString < $1.id.uuidString : $0.observed < $1.observed }.first }.sorted { $0.canonicalURL < $1.canonicalURL }
        located = groups.values.compactMap { group in
            let geocoded = group.filter { $0.locationConfirmed && $0.location != nil && !$0.locationEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard Set(geocoded.compactMap { $0.location?.id }).count == 1 else { return nil }
            return geocoded.sorted { $0.observed == $1.observed ? $0.id.uuidString < $1.id.uuidString : $0.observed < $1.observed }.first
        }.sorted { $0.canonicalURL < $1.canonicalURL }
    }
    public func mapRows(country: NewsCountry) -> [RegionCoverage] {
        CoverageCatalog.regions(in: country).map { region in
            let items = located.filter { $0.location?.country == country && $0.location?.state == region.code }.map { mention in
                let story = NewsStory(title: mention.title, url: mention.url, publisher: PublicationProject.host(mention.url), published: nil)
                var assessment = CoverageAssessment(story: story, country: country); assessment.regions = [region.code]
                return CoverageItem(story: story, assessment: assessment, regions: [region.code], suggested: false)
            }
            return RegionCoverage(region: region, items: items)
        }
    }
}
