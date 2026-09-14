import SwiftUI
import WorkshopCore

struct MultiCityStudyView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var newStudyCountry = NewsCountry.unitedStates
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Eyebrow(text: "RESEARCH / FICTION STUDIES", color: Theme.accent)
                    Spacer()
                    Picker("Saved study", selection: $store.selectedStudyID) {
                        ForEach(store.state.studies) { Text($0.title + " · " + $0.country.name).tag(Optional($0.id)) }
                    }.labelsHidden().frame(maxWidth: 300)
                    Button { store.exportStudy() } label: { Label("Export study", systemImage: "square.and.arrow.up") }.buttonStyle(ActionButton())
                }
                HStack {
                    CountryPicker(selection: $newStudyCountry, label: "New study country").frame(width: 300)
                    Button("New study") { store.newStudy(country: newStudyCountry) }.buttonStyle(ActionButton())
                    Spacer()
                }
            }.padding(22)
            Divider()
            if let study = store.selectedStudy { StudyEditor(study: study).id(study.id) }
            else { EmptyPanel(title: "Start a geographic study", message: "Add cities and reference articles to compare their metadata.") }
        }.background(Theme.background).onAppear { newStudyCountry = store.state.search.country }
    }
}

struct StudyEditor: View {
    @EnvironmentObject private var store: NewsStore
    @State var study: NewsStudy
    @State private var neighborCenterID: UUID?
    @State private var nearbyPlaces: [(NewsPlace, Double)] = []
    @State private var showSimilarity = false
    @FocusState private var themeFocused: Bool
    var center: StudyLocation? { study.locations.first { $0.id == neighborCenterID } ?? study.locations.first }
    var pairs: [(Int, Int)] { study.locations.indices.flatMap { i in study.locations.indices.filter { $0 > i }.map { (i, $0) } } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 11) {
                        TextField("Study title", text: $study.title).textFieldStyle(.plain).font(.system(size: 30, weight: .medium, design: .serif))
                        Text(study.country.name + " · A blank theme, a set of places, and inspectable comparisons.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(study.locations.count) CITIES").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.accent).padding(12).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                }
                HStack {
                    Button { showSimilarity = true } label: { Label("Similarity controls", systemImage: "slider.horizontal.3") }.buttonStyle(ActionButton())
                    Text("Conservative lexical comparison · \(study.activeSimilarity.minimumSharedTerms) shared terms required").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "OPTIONAL SEARCH VECTOR / THEME")
                    TextField("Leave blank, or enter a research topic or fictional premise", text: $study.theme).textFieldStyle(.roundedBorder).focused($themeFocused)
                    Text("Blank means no theme score. Keyword, phrase, and seed-coverage values measure headline language; they do not establish a shared event.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 16) {
                    summary("ASSIGNED REFERENCES", "\(study.assignedCount) / \(study.locations.count)")
                    summary("DISTINCT ARTICLES", "\(study.distinctArticleCount)")
                    summary("CONNECTION STATUS", "Unestablished")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    ForEach(Array(study.locations.enumerated()), id: \.element.id) { index, location in
                        locationCard(location, index: index)
                    }
                }
                if study.locations.count < 12 {
                    CityPicker(label: "Add city to study", selected: "Add another city (up to 12)", country: study.country) { place in
                        guard !study.locations.contains(where: { $0.place.id == place.id }) else { return }
                        study.locations.append(StudyLocation(place: place))
                    }.frame(width: 290)
                }
                neighborPanel
                DisclosureGroup("Pairwise similarity & geographic vectors · \(pairs.count) pairs") {
                    VStack(spacing: 0) {
                        Text("First city is the seed. K / P / C are keyword / phrase / seed-coverage values out of 100.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        HStack { Text("CITY PAIR").frame(maxWidth: .infinity, alignment: .leading); Text("K / P / C").frame(width: 110); Text("MILES").frame(width: 65); Text("PUB. GAP").frame(width: 75) }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted).padding(.vertical, 10)
                        ForEach(pairs.indices, id: \.self) { index in
                            let pair = pairs[index]
                            let a = study.locations[pair.0], b = study.locations[pair.1]
                            let vector = study.vector(from: a, to: b)
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(a.place.label) → \(b.place.label)").font(.system(size: 11))
                                    if let vector {
                                        Text(vector.eligible ? "Index \(Int(((vector.score ?? 0) * 100).rounded()))/100 · " + vector.sharedTerms.joined(separator: ", ") : vector.reasons.joined(separator: "; ")).font(.system(size: 9)).foregroundStyle(vector.eligible ? Theme.accent : Theme.amber)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Text([vector?.keyword, vector?.phrase, vector?.coverage].map { $0.map { String(Int(($0 * 100).rounded())) } ?? "—" }.joined(separator: " / ")).foregroundStyle(Theme.accent).frame(width: 110)
                                Text("\(Int(a.place.distanceMiles(to: b.place)))").frame(width: 65)
                                Text(gap(a.article, b.article)).frame(width: 75)
                            }.font(.system(size: 11, design: .monospaced)).padding(.vertical, 10)
                            Divider()
                        }
                    }.padding(.top, 10)
                }.font(.system(size: 14, weight: .medium))
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: "INTERPRETATION LIMITS", color: Theme.amber)
                    Text("Distances use catalog place coordinates. Time gaps use publication dates, not sighting or incident times. A matching city name can refer to another place. Neither similarity nor proximity establishes a shared event, suspect, cause, or coordinated activity.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
                    if study.assignedCount > study.distinctArticleCount { Text("The same article is assigned to multiple cities. It is one source, not independent corroboration.").font(.system(size: 11)).foregroundStyle(Theme.amber) }
                }.padding(16).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                Eyebrow(text: "STUDY NOTES / OPEN QUESTIONS")
                TextEditor(text: $study.notes).font(.system(size: 12)).scrollContentBackground(.hidden).padding(10).frame(height: 150).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7)).accessibilityLabel("Geographic study notes")
            }.padding(25)
        }
        .onChange(of: study) { _, updated in store.updateStudy(updated) }
        .onChange(of: study.radiusMiles) { _, _ in updateNeighbors() }
        .onChange(of: study.locations.map(\.place.id)) { _, _ in updateNeighbors() }
        .onChange(of: neighborCenterID) { _, _ in updateNeighbors() }
        .onAppear { updateNeighbors() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FocusNewsSearch"))) { _ in themeFocused = true }
        .sheet(isPresented: $showSimilarity) {
            SimilarityInspector(settings: Binding(get: { study.activeSimilarity }, set: { study.similaritySettings = $0.normalized }),
                                seedText: study.locations.first?.article?.title ?? "Albuquerque park opens a walking trail",
                                candidateText: study.locations.dropFirst().first?.article?.title ?? "Santa Fe laboratory studies distant galaxies",
                                places: study.locations.flatMap { [$0.place.name, $0.place.state] })
        }
    }
    private func summary(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Eyebrow(text: label); Text(value).font(.system(size: 19, weight: .medium, design: .monospaced)).foregroundStyle(Theme.accent) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
    }
    private func locationCard(_ location: StudyLocation, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Eyebrow(text: String(format: "CITY %02d", index + 1), color: Theme.accent); Spacer(); if study.locations.count > 2 { Button { study.locations.removeAll { $0.id == location.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Remove \(location.place.label) from study") } }
            CityPicker(label: "Study city \(index + 1)", selected: location.place.label, country: study.country) { place in
                guard !study.locations.contains(where: { $0.place.id == place.id && $0.id != location.id }), let position = study.locations.firstIndex(where: { $0.id == location.id }) else { return }
                study.locations[position].place = place
                // A geographic reassignment requires the reference to be selected again.
                study.locations[position].article = nil
            }
            if let article = location.article {
                Text(article.title).font(.system(size: 13, weight: .medium)).lineLimit(4)
                Text(article.publisher).font(.system(size: 10)).foregroundStyle(Theme.muted)
                Text(location.place.mentioned(in: article.title) ? "City name appears · location unverified" : "No city-name match in headline").font(.system(size: 10)).foregroundStyle(Theme.amber)
                let themeVector = HeadlineSimilarity.compare(seed: study.theme, candidate: article.title, places: [location.place.name, location.place.state], settings: study.activeSimilarity, shortQuery: true)
                Text(study.theme.isEmpty ? "Theme: none specified" : themeVector.eligible ? "Theme index: \(Int(((themeVector.score ?? 0) * 100).rounded()))/100" : "Theme: below similarity filters").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.accent)
            } else { Text("No reference assigned").font(.system(size: 13)).foregroundStyle(Theme.muted).frame(height: 47) }
            ArticleChooser(articles: store.stories(in: study.country), city: location.place, theme: study.theme, settings: study.activeSimilarity) { story in
                if let position = study.locations.firstIndex(where: { $0.id == location.id }) { study.locations[position].article = story }
            }
            if location.article != nil { Button("Clear reference") { if let position = study.locations.firstIndex(where: { $0.id == location.id }) { study.locations[position].article = nil } }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(Theme.muted) }
        }.padding(15).frame(maxWidth: .infinity, alignment: .topLeading).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line))
    }
    private var neighborPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Eyebrow(text: "GEOSPATIAL NEIGHBORS", color: Theme.accent); Spacer(); Text("Local catalog · no download").font(.system(size: 10)).foregroundStyle(Theme.muted) }
            HStack(spacing: 20) {
                RadiusDial(miles: $study.radiusMiles)
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Center", selection: Binding(get: { center?.id }, set: { neighborCenterID = $0 })) { ForEach(study.locations) { Text($0.place.label).tag(Optional($0.id)) } }
                    Slider(value: $study.radiusMiles, in: 10...1000, step: 1).accessibilityLabel("Study neighbor radius")
                    Text("\(nearbyPlaces.count.formatted()) nearby places within \(Int(study.radiusMiles)) miles. Showing the nearest 8 not already in this study.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))]) {
                ForEach(Array(nearbyPlaces.prefix(8)), id: \.0.id) { place, distance in
                    HStack { VStack(alignment: .leading, spacing: 3) { Text(place.label).font(.system(size: 11)); Text("\(distance, specifier: "%.1f") mi").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted) }; Spacer(); Button { study.locations.append(StudyLocation(place: place)) } label: { Image(systemName: "plus.circle") }.buttonStyle(.plain).foregroundStyle(Theme.accent).disabled(study.locations.count >= 12).accessibilityLabel("Add \(place.label) to study") }.padding(10).background(Theme.background, in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }.padding(17).background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
    }
    private func updateNeighbors() {
        if let center { nearbyPlaces = PlaceCatalog.neighbors(of: center.place, radius: study.radiusMiles, excluding: Set(study.locations.map(\.place.id))) }
    }
    private func gap(_ a: NewsStory?, _ b: NewsStory?) -> String {
        guard let a, let b, let value = TextSimilarity.publicationGapHours(a, b) else { return "—" }
        return String(format: "%.1fh", value)
    }
}

struct ArticleChooser: View {
    let articles: [NewsStory]
    let city: NewsPlace
    let theme: String
    let settings: SimilaritySettings
    let choose: (NewsStory) -> Void
    @State private var showing = false
    @State private var query = ""
    var sorted: [NewsStory] {
        articles.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }.sorted { a, b in
            let am = city.mentioned(in: a.title), bm = city.mentioned(in: b.title)
            if am != bm { return am }
            let av = HeadlineSimilarity.compare(seed: theme, candidate: a.title, places: [city.name, city.state], settings: settings, shortQuery: true).rankScore ?? -1
            let bv = HeadlineSimilarity.compare(seed: theme, candidate: b.title, places: [city.name, city.state], settings: settings, shortQuery: true).rankScore ?? -1
            if av != bv { return av > bv }
            return a.id < b.id
        }
    }
    var body: some View {
        Button("Choose reference article") { showing = true }.buttonStyle(ActionButton()).popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "CACHED & SAVED ARTICLES", color: Theme.accent)
                TextField("Filter headlines", text: $query).textFieldStyle(.roundedBorder)
                Text("City-name matches first; then passing theme indices. Unscored and weak references remain selectable for research. Assignments need geographic verification.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(sorted) { article in
                            Button { choose(article); showing = false } label: {
                                VStack(alignment: .leading, spacing: 6) { Text(article.title).font(.system(size: 12)).multilineTextAlignment(.leading); Text(article.publisher + (city.mentioned(in: article.title) ? " · city-name match" : " · geography unverified")).font(.system(size: 10)).foregroundStyle(Theme.muted) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Theme.panel, in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain)
                        }
                        if sorted.isEmpty { Text("No cached articles. Refresh the national feed in News feed first.").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 25) }
                    }
                }
            }.padding(18).frame(width: 410, height: 460).background(Theme.sidebar)
        }
    }
}
