import Foundation

public enum NewsFeed {
    public static func fetch(search: NewsSearch) async throws -> NewsSnapshot {
        guard let url = search.feedURL else { throw NewsError.invalidLocation }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("SyndromeWorkshop/1.3 (personal news reader)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw NewsError.noConnection((response as? HTTPURLResponse)?.statusCode ?? 0) }
        if response.expectedContentLength > 5_000_000 { throw NewsError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 5_000_000 else { throw NewsError.tooLarge }
            data.append(byte)
        }
        try Task.checkCancellation()
        let now = Date()
        let days: Double = search.window == .day ? 1 : search.window == .week ? 7 : 30
        let cutoff = now.addingTimeInterval(-days * 86_400)
        let stories = try parse(data, expectedLanguage: search.country.language).filter { $0.published.map { $0 >= cutoff && $0 <= now.addingTimeInterval(3600) } ?? true }
        return NewsSnapshot(search: search.normalized, fetched: now, stories: stories)
    }
    public static func parse(_ data: Data, expectedLanguage: String? = nil) throws -> [NewsStory] {
        guard data.count <= 5_000_000 else { throw NewsError.tooLarge }
        let reader = RSSReader()
        let parser = XMLParser(data: data); parser.shouldResolveExternalEntities = false; parser.delegate = reader
        guard parser.parse(), reader.isRSS else { throw NewsError.invalidFeed }
        if let expectedLanguage, reader.language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != expectedLanguage.lowercased() { throw NewsError.wrongEdition }
        return reader.stories
    }
}

private final class RSSReader: NSObject, XMLParserDelegate {
    var stories: [NewsStory] = []
    var isRSS = false
    var language = ""
    private var inLanguage = false
    private var inItem = false
    private var field = ""
    private var fields: [String: String] = [:]
    private var sourceURL = ""
    private var seen: Set<String> = []
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "rss" { isRSS = true }
        if name == "language", !inItem { inLanguage = true }
        if name == "item" { inItem = true; fields = [:]; sourceURL = "" }
        guard inItem else { return }
        field = name
        if name == "source" { sourceURL = attributes["url"] ?? "" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inLanguage { language += string }
        if inItem, ["title", "link", "pubDate", "source"].contains(field) { fields[field, default: ""] += string }
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) { self.parser(parser, foundCharacters: string) }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "language" { inLanguage = false }
        defer { field = "" }
        guard name == "item" else { return }
        inItem = false
        guard stories.count < 100, let url = NewsStory.webURL(fields["link"] ?? "") else { return }
        var title = (fields["title"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let publisher = (fields["source"] ?? "Unknown publisher").trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = " - " + publisher
        if title.hasSuffix(suffix) { title.removeLast(suffix.count) }
        let story = NewsStory(title: title, url: url, publisher: publisher, publisherURL: NewsStory.webURL(sourceURL), published: Self.date(fields["pubDate"] ?? ""))
        if seen.insert(story.id).inserted { stories.append(story) }
    }
    static func date(_ raw: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, d MMM yyyy HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }
}
