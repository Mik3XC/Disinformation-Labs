import Foundation
import WorkshopCore

func runNewsChecks() {
    check(PlaceCatalog.places(in: .unitedStates).count == 32350, "All Census places loaded")
    check(PlaceCatalog.states.count == 52, "50 states, DC and Puerto Rico")
    check(PlaceCatalog.matches("Albuquerque", state: "NM").contains { $0.name == "Albuquerque" } && PlaceCatalog.matches("Albuquerque", state: "NM").allSatisfy { $0.state == "NM" }, "City and state search")
    let abq = PlaceCatalog.albuquerque
    let santa = PlaceCatalog.all.first { $0.name == "Santa Fe" && $0.state == "NM" }!
    let phoenix = PlaceCatalog.all.first { $0.name == "Phoenix" && $0.state == "AZ" }!
    check(abq.distanceMiles(to: abq) == 0, "Coincident city distance")
    check((50...70).contains(abq.distanceMiles(to: santa)), "Known Albuquerque to Santa Fe distance")
    check(abs(abq.distanceMiles(to: santa) - santa.distanceMiles(to: abq)) < 0.0001, "Distance symmetry")
    check(PlaceCatalog.neighbors(of: abq, radius: 80).contains { $0.0.id == santa.id }, "Radius includes nearby city")
    check(!PlaceCatalog.neighbors(of: abq, radius: 80).contains { $0.0.id == phoenix.id }, "Radius excludes distant city")
    var search = NewsSearch()
    let originalURL = search.feedURL
    search.place = "Phoenix"; search.region = "AZ"
    check(originalURL == search.feedURL, "Changing city never changes national request")
    check(!search.feedURL!.absoluteString.contains("Phoenix"), "Location stays local")
    search.topic = "space science"
    check(search.query == "\"space science\" when:7d", "Topic query encoding")
    check(search.feedURL != originalURL, "Topic changes national request")
    check(NewsStory.webURL("javascript:alert(1)") == nil, "Reject script URLs")
    check(NewsStory.webURL("file:///tmp/test") == nil, "Reject file URLs")
    check(NewsStory.webURL("https://user:password@example.org/a") == nil, "Reject URL credentials")
    check(NewsStory.canonicalURL(URL(string: "https://example.org/a?utm_source=x#z")!) == "https://example.org/a", "Tracking URL canonicalization")
    let xml = """
    <?xml version="1.0"?><rss version="2.0"><channel>
    <item><title>Albuquerque lights &amp; clouds - Example News</title><link>https://example.org/a?utm_source=feed</link><pubDate>Mon, 14 Sep 2026 15:00:00 GMT</pubDate><source url="https://example.org">Example News</source></item>
    <item><title>Duplicate</title><link>https://example.org/a</link></item>
    <item><title><![CDATA[Santa Fe lights and clouds]]></title><link>https://second.example/b</link><pubDate>bad-date</pubDate><source>Second News</source></item>
    <item><title>Invalid</title><link>javascript:alert(1)</link></item>
    </channel></rss>
    """
    do {
        let stories = try NewsFeed.parse(Data(xml.utf8))
        check(stories.count == 2, "RSS deduplication and invalid URL rejection")
        check(stories[0].title == "Albuquerque lights & clouds", "XML entities and publisher suffix")
        check(stories[0].published != nil && stories[1].published == nil, "Unknown date remains unknown")
        check(stories[1].title == "Santa Fe lights and clouds", "CDATA title")
        let narrow = NearbySearch.matches(stories: stories, center: abq, radius: 20, seed: stories[0])
        let wide = NearbySearch.matches(stories: stories, center: abq, radius: 80, seed: stories[0])
        check(narrow.isEmpty, "Seed excluded and narrow radius respected")
        check(wide.count == 1 && wide[0].place.id == santa.id, "Outward radius discovers matching reference")
        check((wide.first?.similarity ?? 0) > 0, "Headline similarity calculated")
        check(TextSimilarity.publicationGapHours(stories[0], stories[1]) == nil, "Missing timestamp gives unknown gap")
        let entry = ReviewedStory(story: stories[0], search: NewsSearch())
        var changedScope = NewsSearch(); changedScope.place = "Phoenix"; changedScope.region = "AZ"
        check(entry.id != ReviewedStory(story: stories[0], search: changedScope).id, "Reviews scoped to city")
        var state = NewsWorkspace(); state.snapshot = NewsSnapshot(search: NewsSearch(), stories: stories)
        state.reviews[entry.id] = entry
        state.studies[0].locations[0].article = stories[0]
        state.studies[0].notes = "Compare source accounts"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NewsChecks-\(UUID().uuidString)/news.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try NewsFile.save(state, to: url)
        let restored = try NewsFile.load(url)
        check(restored == state, "News, reviews and studies persist")
        check(state.studies[0].report.contains("not event times"), "Study export labels timestamp limits")
        check(state.studies[0].report.contains(stories[0].url.absoluteString), "Study export retains source URL")
    } catch { check(false, "News fixture failed: \(error)") }
    do { _ = try NewsFeed.parse(Data("<html>Provider error</html>".utf8)); check(false, "Reject non-RSS response") }
    catch { check(true, "Reject non-RSS response") }
    check(TextSimilarity.overlap("", "UFO") == nil, "Blank vector means unknown")
    check(TextSimilarity.overlap("cloud lights", "cloud lights") == 1, "Identical token sets")
    check(TextSimilarity.overlap("cloud lights", "water road") == 0, "Disjoint token sets")
    check(!TextSimilarity.containsPhrase("York", in: "Yorkshire headlines"), "Word-boundary geographic matching")
    check(TextSimilarity.containsPhrase("Santa Fe", in: "SANTA FE: new report"), "Case-insensitive place match")
    var review = NewsReview()
    check(review.confidence == nil && review.verificationPriority == 100, "Unknown evidence is unscored, high review need")
    review.provenance = .strong
    check(review.confidence == nil && review.reviewedCount == 1, "Partial review has no confidence value")
    for dimension in EvidenceDimension.allCases { review[dimension] = .partial }
    check(review.confidence == 50 && review.verificationPriority == 50, "Midpoint rubric")
    for dimension in EvidenceDimension.allCases { review[dimension] = .strong }
    check(review.confidence == 100 && review.verificationPriority == 0, "Completed strong evidence rubric")
    for dimension in EvidenceDimension.allCases { review[dimension] = .weak }
    check(review.confidence == 0 && review.verificationPriority == 100, "Weak evidence rubric")
    let study = NewsStudy()
    check(study.locations.count == 5 && study.theme.isEmpty && study.assignedCount == 0, "Blank five-city study defaults")
    check(Set(study.locations.map(\.place.id)).count == 5, "Unique default cities")
}
