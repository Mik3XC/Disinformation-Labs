import Foundation
import WorkshopCore

func runPublicationChecks() {
    let publication = ProjectPublication(title: "Observatory report", url: URL(string: "https://owned.example/report")!)
    let abq = PlaceCatalog.albuquerque
    let phoenix = PlaceCatalog.places(in: .unitedStates).first { $0.name == "Phoenix" && $0.state == "AZ" }!
    let toronto = PlaceCatalog.defaultPlace(for: .canada)
    let london = PlaceCatalog.defaultPlace(for: .unitedKingdom)
    func mention(_ url: String, location: NewsPlace? = nil, confirmed: Bool = true) -> PublicationMention {
        var item = PublicationMention(publicationID: publication.id, title: "Linked report", url: URL(string: url)!)
        item.review = confirmed ? .confirmed : .unreviewed; item.evidence = confirmed ? "Link to registered report inspected" : ""
        item.location = location; item.locationConfirmed = location != nil; item.locationEvidence = location == nil ? "" : "Masthead locality inspected"
        return item
    }
    var project = PublicationProject(); project.publications = [publication]
    check(project.isValid && project.reportedPageViews == nil && project.spread.index == nil, "New project has unknown metrics and sprawl")
    project.mentions = [mention("https://other.example/one", location: abq, confirmed: false)]
    check(project.spread.confirmed.isEmpty && project.spread.index == nil, "Unreviewed mention excluded")
    project.mentions = [mention("https://owned.example/another-page", location: abq), mention("https://www.owned.example/copy", location: phoenix)]
    check(project.spread.confirmed.isEmpty, "Own hostname and www alias excluded from external counts")
    project.mentions = [mention("https://other.example/one")]
    check(project.spread.confirmed.count == 1 && project.spread.index == nil, "Location-free confirmed visibility remains counted")
    project.mentions = [mention("https://other.example/one", location: abq)]
    check(project.spread.index == 0 && project.spread.regionCount == 1, "One documented region yields zero dispersion")
    project.mentions.append(mention("https://second.example/two", location: phoenix))
    check(abs(project.spread.index! - 50) < 0.00001 && project.spread.cityCount == 2 && project.spread.regionCount == 2, "Two equally represented regions yield 50")
    project.mentions.append(mention("https://third.example/three", location: toronto))
    project.mentions.append(mention("https://fourth.example/four", location: london))
    check(abs(project.spread.index! - 75) < 0.00001 && project.spread.countryCount == 3, "Four equally represented regions yield 75")
    check((project.spread.maximumMiles ?? 0) > 4000, "Distance is a separate source-locality metric")
    check(project.spread.mapRows(country: .canada).reduce(0) { $0 + $1.count } == 1, "Project map is country-scoped")
    let before = project.spread.index
    project.mentions.append(mention("https://other.example/one?utm_source=test#fragment", location: abq))
    check(project.spread.confirmed.count == 4 && project.spread.index == before, "Tracking URL duplicate cannot inflate spread")
    project.mentions.append(mention("https://other.example/one", location: phoenix))
    check(project.spread.confirmed.count == 4 && project.spread.located.count == 3, "Conflicting duplicate geography excluded without erasing link evidence")
    let changed = PublicationProject.canonicalURL(URL(string: "https://EXAMPLE.org:443/a?b=2&a=1&utm_medium=x#fragment")!)
    check(changed == "https://example.org/a?a=1&b=2", "Stable host, port and query canonicalization")
    project.mentions[0].review = .rejected
    check(project.isValid, "Rejected evidence can be retained in history")
    var first = PublicationAnalytics(publicationID: publication.id, pageViews: 100, source: "Site analytics export")
    first.measured = Date(timeIntervalSince1970: 100)
    var second = PublicationAnalytics(publicationID: publication.id, pageViews: 175, source: "Later analytics export")
    second.measured = Date(timeIntervalSince1970: 200)
    project.analytics = [first, second]
    check(project.reportedPageViews == 175 && project.latestAnalytics.count == 1, "Latest cumulative views replace prior snapshot")
    second.pageViews = 80; project.analytics = [first, second]
    check(project.reportedPageViews == 80, "Later corrected analytics can decrease")
    let duplicatePublication = ProjectPublication(title: "Same registered URL", url: URL(string: "https://owned.example/report?utm_source=copy")!)
    project.publications.append(duplicatePublication)
    var duplicateAnalytics = PublicationAnalytics(publicationID: duplicatePublication.id, pageViews: 200, source: "Export")
    duplicateAnalytics.measured = Date(timeIntervalSince1970: 300)
    project.analytics.append(duplicateAnalytics)
    check(project.distinctPublications == 1 && project.reportedPageViews == 200, "Duplicate registered URL does not double-count views")
    let newPublication = ProjectPublication(title: "Another report", url: URL(string: "https://owned.example/second")!)
    project.publications.append(newPublication)
    check(project.latestAnalytics.count == 1 && project.distinctPublications == 2, "Partial measurement coverage stays explicit")
    project.analytics.append(PublicationAnalytics(publicationID: newPublication.id, pageViews: 0, source: "Zero views observed"))
    check(project.reportedPageViews == 200 && project.latestAnalytics.count == 2, "Measured zero differs from unknown")
    check(project.report.contains("not unique readers") && project.report.contains("regional dispersion") && project.report.contains("ANALYTICS HISTORY"), "Export includes metric definitions and history")
    check(project.report.contains("https://other.example/one") && project.report.contains("Masthead locality inspected"), "Export includes linked evidence and location rationale")
    var historical = project
    historical.mentions[1].location = NewsPlace(id: phoenix.id, name: phoenix.name, state: phoenix.state, latitude: phoenix.latitude + 0.0001, longitude: phoenix.longitude)
    check(historical.isValid, "Historical source coordinates survive catalog updates")
    var invalid = project; invalid.analytics[0].pageViews = -1
    check(!invalid.isValid, "Negative page views rejected")
    invalid = project; invalid.analytics[0].publicationID = UUID()
    check(!invalid.isValid, "Orphan analytics rejected")
    invalid = project; invalid.mentions[1].evidence = " "
    check(!invalid.isValid, "Confirmed mention requires evidence")
    invalid = project; invalid.mentions[1].locationEvidence = " "
    check(!invalid.isValid, "Confirmed geography requires evidence")
    invalid = project; invalid.publications.append(publication)
    check(!invalid.isValid, "Duplicate publication identities rejected")
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("PublicationChecks-\(UUID().uuidString)/news.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    do {
        var workspace = NewsWorkspace(); workspace.publicationProjects = [project]
        try NewsFile.save(workspace, to: file)
        let restored = try NewsFile.load(file)
        check(restored == workspace, "Publication project and evidence survive archive round trip")
        workspace.publicationProjects = [invalid]
        try NewsFile.save(workspace, to: file)
        do { _ = try NewsFile.load(file); check(false, "Invalid publication archive rejected") }
        catch { check(true, "Invalid publication archive rejected") }
        workspace.publicationProjects = nil
        try NewsFile.save(workspace, to: file)
        let legacy = try NewsFile.load(file)
        check(legacy.publicationProjects == nil, "Older archive has no invented projects")
    } catch { check(false, "Publication archive checks: \(error)") }
}
