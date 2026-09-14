import SwiftUI
import AppKit
import PDFKit
import WorkshopCore

@main
struct DisinformationWorkshopApp: App {
    @StateObject private var store: WorkspaceStore
    @StateObject private var news = NewsStore()
    init() {
        if CommandLine.arguments.contains("--smoke-test") {
            do { try SmokeChecks.run(); exit(0) }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        }
        _store = StateObject(wrappedValue: WorkspaceStore())
    }
    var body: some Scene {
        Window("Syndrome™ — Disinformation Labs", id: "workshop") {
            ContentView().environmentObject(store).environmentObject(news)
        }.defaultSize(width: 1320, height: 890)
            .windowStyle(.titleBar)
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button("About Disinformation Labs") {
                        NSApp.orderFrontStandardAboutPanel(options: [
                            .applicationName: "Syndrome™ Disinformation Labs",
                            .applicationVersion: "1.5.1",
                            .credits: NSAttributedString(string: "A dossier archive, news research observatory, and fictional memorandum studio.\nA separate Syndrome companion app.\n\nThe Doty files · MJ12")
                        ])
                    }
                }
            }
    }
}

@MainActor
enum SmokeChecks {
    static func run() throws {
        var checks = 0
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw NSError(domain: "SmokeChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
            checks += 1
        }
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/pdf")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let sample = Draft.sample
        let data = try PaperRenderer.pdf(draft: sample)
        try data.write(to: output.appendingPathComponent("workshop-sample.pdf"))
        let pdf = PDFDocument(data: data)!
        try check(pdf.pageCount == 1, "Sample fits one page")
        try check(pdf.string?.contains("FICTIONAL SIMULATION") == true, "Simulation label in PDF")
        try check(pdf.string?.contains("custody log") == true, "Body text rendered")
        for medium in Medium.allCases {
            var long = sample; long.medium = medium
            long.body = (1...130).map { "Paragraph \($0). The fictional observer records only what can be independently checked. Preserve each source and its original wording.\n\n" }.joined() + "END-OF-LONG-DOCUMENT"
            let longData = try PaperRenderer.pdf(draft: long), document = PDFDocument(data: longData)!
            try check(document.pageCount > 1, "Long memo paginates for \(medium.rawValue)")
            try check(document.string?.contains("END-OF-LONG-DOCUMENT") == true, "Last paragraph survives pagination")
            for i in 0..<document.pageCount {
                let text = document.page(at: i)?.string ?? ""
                try check(text.contains("FICTIONAL SIMULATION") && text.contains("NOT AN AUTHENTIC"), "Every page has provenance")
            }
            if medium == .typewriter { try longData.write(to: output.appendingPathComponent("workshop-pagination-check.pdf")) }
        }
        var redacted = sample; redacted.body = "SENSITIVE_SENTINEL secret material"; redacted.redaction = 1
        let redactedPDF = PDFDocument(data: try PaperRenderer.pdf(draft: redacted))!
        try check(redactedPDF.string?.contains("SENSITIVE_SENTINEL") == false, "Redacted words not embedded in PDF")
        try check(redactedPDF.string?.contains("[REDACTED]") == true, "Visible redaction replacement")
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("WorkshopSmoke-\(UUID().uuidString)/workspace.json")
        defer { try? FileManager.default.removeItem(at: temporary.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: temporary)
        store.create(from: Vault.records[0]); let createdID = store.selectedDraftID
        var changed = store.selectedDraft!; changed.title = "Persistence check"; store.update(changed)
        store.setNote("Check original source", for: Vault.records[0]); store.toggleBookmark(Vault.records[0])
        let reloaded = WorkspaceStore(fileURL: temporary)
        try check(reloaded.workspace.drafts.first { $0.id == createdID }?.title == "Persistence check", "Draft survives relaunch")
        try check(reloaded.note(for: Vault.records[0]) == "Check original source", "Note survives relaunch")
        try check(reloaded.workspace.bookmarks.contains(Vault.records[0].id), "Bookmark survives relaunch")
        store.duplicate(); try check(store.selectedDraftID != createdID, "Duplicate gets new identity")
        let count = store.workspace.drafts.count; store.deleteSelected()
        try check(store.workspace.drafts.count == count - 1, "Deletion persisted")
        let newsURL = temporary.deletingLastPathComponent().appendingPathComponent("news.json")
        let news = NewsStore(fileURL: newsURL)
        let article = NewsStory(title: "Albuquerque observatory study", url: URL(string: "https://example.org/test-story")!, publisher: "Test fixture", published: Date())
        let entry = ReviewedStory(story: article, search: NewsSearch())
        news.review(entry) { $0.provenance = .partial; $0.notes = "Check source"; $0.saved = true }
        news.setSeed(article); news.setRadius(275)
        var study = news.selectedStudy!; study.locations[0].article = article; study.theme = "observatory"; news.updateStudy(study)
        let restoredNews = NewsStore(fileURL: newsURL)
        try check(restoredNews.state.reviews[entry.id]?.review.notes == "Check source", "News review persists")
        try check(restoredNews.state.seed == article && restoredNews.state.radiusMiles == 275, "Similarity seed and radius persist")
        try check(restoredNews.selectedStudy?.locations[0].article == article, "Study reference persists")
        try check(restoredNews.selectedStudy?.theme == "observatory", "Study theme persists")
        news.newStudy(); try check(news.state.studies.count == 2, "Multiple studies supported")
        news.chooseCountry(.canada)
        try check(news.selectedCity.country == .canada && news.state.seed == nil && news.state.activeSnapshot == nil, "Country switch clears active US context without a download")
        try check(news.entries(cityOnly: false, savedOnly: true, text: "", sort: .newest).isEmpty, "US reviews hidden in Canada")
        try check(!news.allStories.contains(article), "US reference articles hidden from Canada feed")
        let toronto = news.selectedCity
        news.chooseCity(toronto); news.setRadius(310)
        news.newStudy()
        try check(news.selectedStudy?.country == .canada && news.selectedStudy?.locations.count == 5, "New study follows selected country")
        news.chooseCountry(.unitedStates)
        try check(news.state.seed == article && news.state.radiusMiles == 275, "Returning to US restores seed and radius")
        try check(news.entries(cityOnly: false, savedOnly: true, text: "", sort: .newest).count == 1, "Returning to US restores saved review")
        news.chooseCountry(.canada)
        let countryReload = NewsStore(fileURL: newsURL)
        try check(countryReload.selectedCity == toronto && countryReload.state.radiusMiles == 310, "Country and radius survive store relaunch")
        news.assessCoverage(article, country: .unitedStates) { $0.regions = ["NM"]; $0.tone = .descriptive; $0.format = .reporting; $0.notes = "Source wording reviewed" }
        let coverageReload = NewsStore(fileURL: newsURL)
        let coverageKey = CoverageAssessment.key(story: article, country: .unitedStates)
        try check(coverageReload.state.coverageAssessments?[coverageKey]?.notes == "Source wording reviewed", "Coverage annotations survive store relaunch")
        try check(coverageReload.state.coverageAssessments?[coverageKey]?.regions == ["NM"], "Coverage region assignment persists independently of selected country")
        news.newPublicationProject()
        var publicationProject = news.selectedProject!
        publicationProject.title = "Native persistence fixture"
        let registered = ProjectPublication(title: "Published fixture", url: URL(string: "https://publisher.example/article")!)
        publicationProject.publications = [registered]
        publicationProject.analytics = [PublicationAnalytics(publicationID: registered.id, pageViews: 120, source: "Analytics fixture")]
        news.updatePublicationProject(publicationProject)
        let projectReload = NewsStore(fileURL: newsURL)
        try check(projectReload.selectedProject?.title == "Native persistence fixture", "Publication project survives relaunch")
        try check(projectReload.selectedProject?.reportedPageViews == 120, "Publication analytics survive relaunch")
        print("PASS: \(checks) native PDF and workspace checks. Sample PDFs: \(output.path)")
    }
}
