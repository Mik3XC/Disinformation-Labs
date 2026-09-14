import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WorkshopCore

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var state: NewsWorkspace
    @Published var isLoading = false
    @Published var networkMessage: String?
    @Published var errorMessage: String?
    @Published var saveStatus = "News saved on this Mac"
    @Published var selectedStudyID: UUID?
    @Published var selectedProjectID: UUID?
    private let fileURL: URL
    private var maySave = true
    private var requestID = UUID()
    private var fetchTask: Task<Void, Never>?
    private var lastRequest = Date.distantPast

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SyndromeDisinformationWorkshop/news.json")
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do { state = try NewsFile.load(self.fileURL) }
            catch { state = NewsWorkspace(); maySave = false; errorMessage = "The news archive could not be read and was preserved. Import a valid news archive to recover.\n\(error.localizedDescription)"; saveStatus = "News storage needs attention" }
        } else { state = NewsWorkspace() }
        selectedStudyID = state.studies.first?.id
        selectedProjectID = state.publicationProjects?.first?.id
    }
    func save() {
        guard maySave else { return }
        do { try NewsFile.save(state, to: fileURL); saveStatus = "News saved on this Mac" }
        catch { saveStatus = "News changes not saved"; errorMessage = error.localizedDescription }
    }
    func setSearch(_ search: NewsSearch) {
        if search.country != state.search.country { chooseCountry(search.country) }
        state.search = search.normalized; save()
    }
    func chooseCountry(_ country: NewsCountry) {
        guard country != state.search.country else { return }
        cancel(); state.selectCountry(country)
        networkMessage = state.activeSnapshot == nil ? "No cached feed for \(country.name). Refresh to download this edition." : "Using the saved \(country.name) feed. No download."
        save()
    }
    func setRadius(_ miles: Double) { state.radiusMiles = max(10, min(1000, miles)); save() }
    func setSeed(_ story: NewsStory?) { state.seed = story; save() }
    func setSimilarity(_ settings: SimilaritySettings) { state.similaritySettings = settings.normalized; save() }
    func chooseCity(_ place: NewsPlace) {
        if place.country != state.search.country { chooseCountry(place.country) }
        state.search.place = place.name; state.search.region = place.state; save()
    }
    func refresh() {
        guard !isLoading else { return }
        guard Date().timeIntervalSince(lastRequest) >= 10 else { networkMessage = "Please leave 10 seconds between refreshes."; return }
        lastRequest = Date(); isLoading = true; networkMessage = nil
        let search = state.search, token = UUID(); requestID = token
        fetchTask = Task { [weak self] in
            do {
                let snapshot = try await NewsFeed.fetch(search: search)
                guard let self, self.requestID == token, self.state.search.country == search.country, !Task.isCancelled else { return }
                self.state.snapshot = snapshot; self.isLoading = false; self.networkMessage = "Updated \(snapshot.stories.count) \(search.country.name) headlines. City changes use this cache."; self.save()
            } catch {
                guard let self, self.requestID == token else { return }
                self.isLoading = false
                if !Task.isCancelled { self.networkMessage = "Refresh failed: \(error.localizedDescription) Previous headlines remain cached." }
            }
        }
    }
    func cancel() { requestID = UUID(); fetchTask?.cancel(); isLoading = false; networkMessage = "Refresh cancelled. Previous cache retained." }
    func review(_ entry: ReviewedStory, change: (inout NewsReview) -> Void) {
        var updated = state.entry(for: entry.story, search: entry.search)
        change(&updated.review); updated.review.modified = Date()
        updated.review.notes = String(updated.review.notes.prefix(20_000)); updated.review.evidenceLinks = String(updated.review.evidenceLinks.prefix(10_000))
        state.reviews[updated.id] = updated; save()
    }
    func assessCoverage(_ story: NewsStory, country: NewsCountry, change: (inout CoverageAssessment) -> Void) {
        let key = CoverageAssessment.key(story: story, country: country)
        var assessment = state.coverageAssessments?[key] ?? CoverageAssessment(story: story, country: country)
        change(&assessment); assessment.modified = Date(); assessment.notes = String(assessment.notes.prefix(20_000))
        if let regions = assessment.regions {
            let valid = Set(CoverageCatalog.regions(in: country).map(\.code))
            assessment.regions = Array(Set(regions).intersection(valid)).sorted()
        }
        if state.coverageAssessments == nil { state.coverageAssessments = [:] }
        state.coverageAssessments?[key] = assessment; save()
    }
    func exportCoverage(_ report: CoverageReport) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "Regional-coverage-" + report.country.rawValue + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try report.text.write(to: url, atomically: true, encoding: .utf8); saveStatus = "Coverage report exported" }
        catch { errorMessage = error.localizedDescription }
    }
    var selectedCity: NewsPlace { PlaceCatalog.places(in: state.search.country).first { $0.name == state.search.place && $0.state == state.search.region } ?? PlaceCatalog.defaultPlace(for: state.search.country) }
    var allStories: [NewsStory] { stories(in: state.search.country) }
    func stories(in country: NewsCountry) -> [NewsStory] {
        var seen = Set<String>()
        let snapshot = state.snapshot?.search.country == country ? state.snapshot : state.countrySnapshots?[country.rawValue]
        let seed = country == state.search.country ? state.seed : state.countryContexts?[country.rawValue]?.seed
        let reviewed = state.reviews.values.filter { $0.search.country == country }.map(\.story)
        let studied = state.studies.flatMap { $0.locations.filter { $0.place.country == country }.compactMap(\.article) }
        return ((snapshot?.stories ?? []) + reviewed + studied + [seed].compactMap { $0 }).filter { seen.insert($0.id).inserted }
    }
    func entries(cityOnly: Bool, savedOnly: Bool, text: String, sort: NewsSort) -> [ReviewedStory] {
        let entries: [ReviewedStory]
        if savedOnly { entries = state.reviews.values.filter { $0.review.saved && $0.search.country == state.search.country } }
        else { entries = (state.activeSnapshot?.stories ?? []).map { state.entry(for: $0, search: state.search) } }
        return sort.order(entries.filter { entry in
            (!cityOnly || TextSimilarity.containsPhrase(state.search.place, in: entry.story.title)) &&
            (text.isEmpty || (entry.story.title + " " + entry.story.publisher).localizedCaseInsensitiveContains(text))
        })
    }
    var selectedProject: PublicationProject? { state.publicationProjects?.first { $0.id == selectedProjectID } }
    func newPublicationProject() {
        let project = PublicationProject(country: state.search.country)
        if state.publicationProjects == nil { state.publicationProjects = [] }
        state.publicationProjects?.insert(project, at: 0); selectedProjectID = project.id; save()
    }
    func updatePublicationProject(_ project: PublicationProject) {
        guard let index = state.publicationProjects?.firstIndex(where: { $0.id == project.id }), project.isValid else { return }
        var clean = project; clean.title = String(clean.title.prefix(160)); clean.notes = String(clean.notes.prefix(20_000)); clean.modified = Date()
        state.publicationProjects?[index] = clean; save()
    }
    func exportPublicationProject() {
        guard let project = selectedProject else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "Publication-project.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try project.report.write(to: url, atomically: true, encoding: .utf8); saveStatus = "Publication project exported" }
        catch { errorMessage = error.localizedDescription }
    }
    var selectedStudy: NewsStudy? { state.studies.first { $0.id == selectedStudyID } }
    func updateStudy(_ value: NewsStudy) {
        guard let index = state.studies.firstIndex(where: { $0.id == value.id }) else { return }
        var clean = value; clean.title = String(clean.title.prefix(120)); clean.theme = String(clean.theme.prefix(300)); clean.notes = String(clean.notes.prefix(20_000))
        clean.radiusMiles = max(10, min(1000, clean.radiusMiles)); clean.modified = Date()
        if let settings = clean.similaritySettings { clean.similaritySettings = settings.normalized }
        state.studies[index] = clean; save()
    }
    func newStudy(country: NewsCountry? = nil) { let study = NewsStudy(country: country ?? state.search.country); state.studies.insert(study, at: 0); selectedStudyID = study.id; save() }
    func exportStudy() {
        guard let study = selectedStudy else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "Geographic-study.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try study.report.write(to: url, atomically: true, encoding: .utf8); saveStatus = "Study exported" }
        catch { errorMessage = error.localizedDescription }
    }
    func exportArchive() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "News-research-archive.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try NewsFile.save(state, to: url); saveStatus = "News archive exported" }
        catch { errorMessage = error.localizedDescription }
    }
    func importArchive() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let incoming = try NewsFile.load(url)
            if !maySave, FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.copyItem(at: fileURL, to: fileURL.deletingLastPathComponent().appendingPathComponent("news-unreadable-\(UUID().uuidString).json"))
            }
            for (key, value) in incoming.reviews {
                if let current = state.reviews[key] {
                    // Preserve existing assessment; append imported notes for inspection.
                    var merged = current
                    if value.review != current.review {
                        merged.review.notes += "\n\nIMPORTED ASSESSMENT\nP: \(value.review.provenance.rawValue); C: \(value.review.corroboration.rawValue); X: \(value.review.context.rawValue); G: \(value.review.geography.rawValue)\n" + value.review.notes
                        merged.review.evidenceLinks += "\n" + value.review.evidenceLinks
                        merged.review.saved = merged.review.saved || value.review.saved
                    }
                    state.reviews[key] = merged
                } else { state.reviews[key] = value }
            }
            for var project in incoming.publicationProjects ?? [] {
                if state.publicationProjects == nil { state.publicationProjects = [] }
                if state.publicationProjects?.contains(where: { $0.id == project.id }) == true { project.id = UUID() }
                state.publicationProjects?.append(project)
            }
            for var study in incoming.studies {
                if state.studies.contains(where: { $0.id == study.id }) { study.id = UUID() }
                state.studies.append(study)
            }
            for (key, value) in incoming.coverageAssessments ?? [:] where state.coverageAssessments?[key] == nil {
                if state.coverageAssessments == nil { state.coverageAssessments = [:] }
                state.coverageAssessments?[key] = value
            }
            var caches = incoming.countrySnapshots ?? [:]
            if let snapshot = incoming.snapshot { caches[snapshot.search.country.rawValue] = snapshot }
            for (key, value) in caches where state.countrySnapshots?[key] == nil {
                if state.countrySnapshots == nil { state.countrySnapshots = [:] }
                state.countrySnapshots?[key] = value
            }
            if state.activeSnapshot == nil { state.snapshot = state.countrySnapshots?[state.search.country.rawValue] }
            for (key, value) in incoming.countryContexts ?? [:] where state.countryContexts?[key] == nil && key != state.search.country.rawValue {
                if state.countryContexts == nil { state.countryContexts = [:] }
                state.countryContexts?[key] = value
            }
            maySave = true; selectedStudyID = state.studies.last?.id; save()
        } catch { errorMessage = "News archive could not be imported: \(error.localizedDescription)" }
    }
}
