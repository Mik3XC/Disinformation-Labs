import Foundation
import WorkshopCore

func runCountryChecks() {
    let rss = Data("<rss><channel><language>en-CA</language></channel></rss>".utf8)
    do { _ = try NewsFeed.parse(rss, expectedLanguage: "en-CA"); check(true, "Accept selected English edition") }
    catch { check(false, "Selected edition rejected") }
    do { _ = try NewsFeed.parse(rss, expectedLanguage: "en-GB"); check(false, "Reject provider edition fallback") }
    catch { check(true, "Reject provider edition fallback") }
    let countries = NewsCountry.allCases
    check(countries.count == 9, "Nine English country editions")
    check(Set(PlaceCatalog.all.map(\.id)).count == PlaceCatalog.all.count, "International and Census IDs do not collide")
    for country in countries {
        let places = PlaceCatalog.places(in: country)
        check(!places.isEmpty && places.allSatisfy { $0.country == country }, "Catalog isolated: \(country.name)")
        let city = PlaceCatalog.defaultPlace(for: country)
        check(city.name == country.defaultCityName && city.country == country, "Default city: \(country.name)")
        let neighbors = PlaceCatalog.neighbors(of: city, radius: 1000)
        check(neighbors.allSatisfy { $0.0.country == country && $0.1 <= 1000 }, "Radius stays in country: \(country.name)")
        let search = city.search
        let params = Dictionary(uniqueKeysWithValues: URLComponents(url: search.feedURL!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
        check(params["hl"] == country.language && params["gl"] == country.rawValue && params["ceid"] == country.edition, "English country feed URL: \(country.name)")
        var moved = search; moved.place = "Another city"; moved.region = "Another region"
        check(search.feedURL == moved.feedURL, "Local city changes do not change request: \(country.name)")
        moved.topic = "astronomy"
        let topicParams = URLComponents(url: moved.feedURL!, resolvingAgainstBaseURL: false)!.queryItems!
        check(topicParams.contains { $0.name == "ceid" && $0.value == country.edition } && topicParams.contains { $0.name == "q" }, "Topic retains country: \(country.name)")
        let study = NewsStudy(country: country)
        check(study.locations.count == 5 && study.locations.allSatisfy { $0.place.country == country }, "Five-city study: \(country.name)")
        check(study.report.contains("Country: " + country.name), "Export retains country: \(country.name)")
    }
    let londonUK = PlaceCatalog.matches("London", country: .unitedKingdom).first { $0.name == "London" }!
    let londonCA = PlaceCatalog.matches("London", country: .canada).first { $0.name == "London" }!
    check(londonUK.id != londonCA.id && londonUK.country != londonCA.country, "Same-name cities remain distinct")
    let windsor = PlaceCatalog.matches("Windsor", state: "Ontario", country: .canada).first { $0.name == "Windsor" }!
    check(PlaceCatalog.neighbors(of: windsor, radius: 50).allSatisfy { $0.0.country == .canada }, "Windsor radius never includes Detroit")
    let usSearch = NewsSearch(place: "London", region: "Region")
    let caSearch = NewsSearch(place: "London", region: "Region", country: .canada)
    check(usSearch.scopeID != caSearch.scopeID, "Country separates identical city/region review scopes")
    check(NewsSearch().scopeID == NewsStory.digest("albuquerque, nm"), "Legacy US review keys unchanged")
    let usArticle = NewsStory(title: "Albuquerque research", url: URL(string: "https://example.org/us")!, publisher: "Fixture", published: nil)
    let caArticle = NewsStory(title: "Toronto research", url: URL(string: "https://example.org/ca")!, publisher: "Fixture", published: nil)
    var state = NewsWorkspace()
    state.snapshot = NewsSnapshot(search: state.search, stories: [usArticle]); state.seed = usArticle; state.radiusMiles = 493
    state.selectCountry(.canada)
    check(state.search.country == .canada && state.search.place == "Toronto" && state.snapshot == nil && state.seed == nil && state.radiusMiles == 150, "New country never reuses old feed or seed")
    state.snapshot = NewsSnapshot(search: state.search, stories: [caArticle]); state.seed = caArticle; state.radiusMiles = 220
    state.search.topic = "science"
    state.selectCountry(.unitedStates)
    check(state.snapshot?.stories == [usArticle] && state.seed == usArticle && state.radiusMiles == 493, "US cache and context restored locally")
    state.selectCountry(.canada)
    check(state.snapshot?.stories == [caArticle] && state.seed == caArticle && state.radiusMiles == 220 && state.search.topic == "science", "Canada cache and context restored locally")
    let before = state; state.selectCountry(.canada)
    check(before == state, "Selecting active country does not mutate context")
    var mismatched = state; mismatched.snapshot = NewsSnapshot(search: NewsSearch(), stories: [usArticle])
    check(mismatched.activeSnapshot == nil, "Mismatched snapshot is never displayed")
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("CountryChecks-\(UUID().uuidString)/news.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    do {
        try NewsFile.save(state, to: url)
        let restored = try NewsFile.load(url)
        check(restored == state, "Country caches and contexts survive relaunch")
    } catch { check(false, "Country persistence: \(error)") }
    do {
        let legacy = NewsWorkspace()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        json.removeValue(forKey: "countrySnapshots"); json.removeValue(forKey: "countryContexts")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let loaded = try NewsFile.load(url)
        check(loaded.search.country == .unitedStates && loaded.studies[0].country == .unitedStates, "Legacy country-less archives stay US")
        var invalid = state
        invalid.countrySnapshots = ["GB": NewsSnapshot(search: NewsSearch(), stories: [usArticle])]
        try NewsFile.save(invalid, to: url)
        do { _ = try NewsFile.load(url); check(false, "Reject incorrectly keyed country cache") }
        catch { check(true, "Reject incorrectly keyed country cache") }
        invalid = state
        invalid.countryContexts = ["US": CountryNewsContext(search: NewsSearch(), radiusMiles: -10, seed: nil)]
        try NewsFile.save(invalid, to: url)
        do { _ = try NewsFile.load(url); check(false, "Reject invalid saved country radius") }
        catch { check(true, "Reject invalid saved country radius") }
    } catch { check(false, "Country archive validation: \(error)") }
}
