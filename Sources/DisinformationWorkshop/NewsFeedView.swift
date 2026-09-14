import SwiftUI
import WorkshopCore

struct NewsFeedView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var mode = "City"
    @State private var filter = ""
    @State private var sort = NewsSort.priority
    @State private var selectedID: String?
    @State private var selectedEntryKey: String?
    @State private var seed: NewsStory?
    @State private var radius = 150.0
    @State private var nearby: [NearbyStory] = []
    @State private var showSimilarity = false
    @FocusState private var searchFocused: Bool
    var center: NewsPlace { store.selectedCity }
    var entries: [ReviewedStory] {
        if mode == "Radius" {
            return nearby.filter { filter.isEmpty || $0.story.title.localizedCaseInsensitiveContains(filter) }.map { store.state.entry(for: $0.story, search: $0.place.search) }
        }
        return store.entries(cityOnly: mode == "City", savedOnly: mode == "Saved", text: filter, sort: sort)
    }
    var selected: ReviewedStory? {
        if let entry = entries.first(where: { $0.id == selectedEntryKey }) { return entry }
        if mode == "Saved", let key = selectedEntryKey, let entry = store.state.reviews[key], entry.search.country == store.state.search.country { return entry }
        guard let story = store.allStories.first(where: { $0.id == selectedID }) else { return nil }
        return store.state.entry(for: story, search: store.state.search)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(22)
            Divider()
            HSplitView {
                articleList.frame(minWidth: 270, idealWidth: 305, maxWidth: 360)
                if let entry = selected {
                    ArticleReviewView(entry: entry, seedSelected: seed?.id == entry.story.id, comparison: comparison(for: entry.story)) {
                        seed = entry.story; store.setSeed(entry.story); mode = "Radius"; updateNearby()
                    }.frame(minWidth: 490)
                } else {
                    EmptyPanel(title: "Select a headline", message: "Inspect its evidence vector, save your review, or use it as the seed for nearby headline comparisons.").frame(minWidth: 490)
                }
            }
        }.background(Theme.background)
            .onChange(of: entries.map(\.id)) { _, _ in if selectedID == nil { selectedID = entries.first?.story.id } }
            .onChange(of: radius) { _, _ in store.setRadius(radius); updateNearby() }
            .onChange(of: store.state.search.country) { _, _ in
                selectedID = nil; selectedEntryKey = nil; seed = store.state.seed; radius = store.state.radiusMiles
                mode = seed == nil ? "City" : "Radius"; updateNearby()
                selectedID = entries.first?.story.id ?? seed?.id
            }
            .onChange(of: center.id) { _, _ in updateNearby() }
            .onChange(of: store.state.snapshot) { _, _ in updateNearby() }
            .onChange(of: store.state.activeSimilarity) { _, _ in updateNearby() }
            .onAppear { radius = store.state.radiusMiles; seed = store.state.seed; if seed != nil { mode = "Radius" }; updateNearby(); if selectedID == nil { selectedID = entries.first?.story.id ?? seed?.id } }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FocusNewsSearch"))) { _ in searchFocused = true }
            .sheet(isPresented: $showSimilarity) {
                SimilarityInspector(settings: Binding(get: { store.state.activeSimilarity }, set: store.setSimilarity),
                                    seedText: seed?.title ?? "Albuquerque park opens a walking trail",
                                    candidateText: selected?.story.title ?? "Albuquerque laboratory studies distant galaxies",
                                    places: comparisonPlaces(for: selected?.story))
            }
    }
    private func comparisonPlaces(for story: NewsStory?) -> [String] {
        let match = story.flatMap { NearbySearch.matches(stories: [$0], center: center, radius: radius, seed: nil).first }
        return [center.name, center.state, match?.place.name ?? "", match?.place.state ?? ""]
    }
    private func comparison(for story: NewsStory) -> HeadlineVector? {
        guard let seed, seed.id != story.id else { return nil }
        return HeadlineSimilarity.compare(seed: seed.title, candidate: story.title, places: comparisonPlaces(for: story), settings: store.state.activeSimilarity)
    }
    private func updateNearby() {
        nearby = NearbySearch.matches(stories: store.state.activeSnapshot?.stories ?? [], center: center, radius: radius, seed: seed, settings: store.state.activeSimilarity)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) { Eyebrow(text: "NATIONAL PARENT / LOCAL LENS", color: Theme.accent); Text("News observatory").font(.system(size: 28, weight: .medium, design: .serif)) }
                Spacer()
                Button { showSimilarity = true } label: { Label("Similarity", systemImage: "slider.horizontal.3") }.buttonStyle(ActionButton())
                if store.isLoading {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { store.cancel() }.buttonStyle(ActionButton())
                } else { Button { store.refresh() } label: { Label("Refresh national feed", systemImage: "arrow.clockwise") }.buttonStyle(ActionButton(prominent: true)) }
            }
            HStack(spacing: 12) {
                CountryPicker(selection: Binding(get: { store.state.search.country }, set: store.chooseCountry)).frame(width: 250)
                CityPicker(label: "News city", selected: center.label, country: store.state.search.country, choose: store.chooseCity).frame(width: 270)
                Spacer()
                Text("English edition").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 12) {
                TextField("Optional topic · blank for all news", text: Binding(get: { store.state.search.topic }, set: { var search = store.state.search; search.topic = $0; store.setSearch(search) })).textFieldStyle(.roundedBorder)
                Picker("Period", selection: Binding(get: { store.state.search.window }, set: { var search = store.state.search; search.window = $0; store.setSearch(search) })) { ForEach(NewsWindow.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 95)
            }
            HStack(alignment: .top, spacing: 16) {
                RadiusDial(miles: $radius)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Eyebrow(text: "OUTWARD FROM " + center.label.uppercased())
                        Spacer()
                        Stepper("\(Int(radius)) mi", value: $radius, in: 10...1000, step: 10).font(.system(size: 11, design: .monospaced)).fixedSize().accessibilityLabel("Radius in miles")
                    }
                    Slider(value: $radius, in: 10...1000, step: 1).accessibilityLabel("Radius slider")
                    HStack {
                        if let seed {
                            Text("SEED: " + seed.title).lineLimit(1).font(.system(size: 11)).foregroundStyle(Theme.accent)
                            Button { self.seed = nil; store.setSeed(nil); updateNearby() } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain).help("Clear similarity seed")
                        } else { Text("Select an article, then use it as a similarity seed.").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                    }
                }.padding(.top, 8)
            }
            HStack {
                if let snapshot = store.state.activeSnapshot {
                    Text("\(snapshot.stories.count) cached headlines · Google News \(snapshot.search.country.name) · English · \(snapshot.fetched.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 10, design: .monospaced))
                } else { Text("No \(store.state.search.country.name) feed cached. Refresh once, then filter locally.").font(.system(size: 11)) }
                Spacer()
            }.foregroundStyle(Theme.muted)
            if let snapshot = store.state.activeSnapshot, snapshot.search.topic != store.state.search.topic || snapshot.search.window != store.state.search.window {
                Text("Filters changed. Refresh to apply topic/date settings. Current cache: \(snapshot.search.topic.isEmpty ? "top headlines" : snapshot.search.topic), \(snapshot.search.window.rawValue).").font(.system(size: 10)).foregroundStyle(Theme.amber)
            }
            if let message = store.networkMessage { Text(message).font(.system(size: 10)).foregroundStyle(Theme.muted).lineLimit(2) }
        }
    }
    private var articleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Feed scope", selection: $mode) { ForEach(["City", "Radius", "National", "Saved"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented).labelsHidden()
            HStack { Image(systemName: "magnifyingglass"); TextField("Filter cached headlines", text: $filter).textFieldStyle(.plain).focused($searchFocused) }.padding(9).background(Theme.panel, in: RoundedRectangle(cornerRadius: 5))
            if mode == "Radius" {
                Eyebrow(text: seed == nil ? "NEAREST NAMED PLACE FIRST" : "LEXICAL INDEX / DESC")
                if seed != nil { Text("Minimum \(Int((store.state.activeSimilarity.minimumScore * 100).rounded()))/100 · \(store.state.activeSimilarity.minimumSharedTerms) shared terms\(store.state.activeSimilarity.showWeakMatches ? " · weak matches shown" : "")").font(.system(size: 9)).foregroundStyle(Theme.muted) }
            } else {
                Picker("Rank stories", selection: $sort) { ForEach(NewsSort.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden()
            }
            Text("\(entries.count) matches · place-name matches are unverified").font(.system(size: 10)).foregroundStyle(Theme.muted)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        Button { selectedID = entry.story.id; selectedEntryKey = entry.id } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack { Eyebrow(text: String(format: "%02d", index + 1), color: Theme.accent); Spacer(); Text(entry.story.publisher).font(.system(size: 10)).lineLimit(1).foregroundStyle(Theme.muted) }
                                Text(entry.story.title).font(.system(size: 13, weight: .medium)).lineLimit(4).multilineTextAlignment(.leading)
                                if let match = nearby.first(where: { $0.id == entry.story.id }), mode == "Radius" {
                                    Text("\(match.place.label) · \(Int(match.miles)) mi").font(.system(size: 10)).foregroundStyle(Theme.accent)
                                    if let vector = match.vector {
                                        Text(vector.eligible ? "Lexical index: \(Int(((vector.score ?? 0) * 100).rounded()))/100" : "Weak match · inspect before use").font(.system(size: 10, design: .monospaced)).foregroundStyle(vector.eligible ? Theme.accent : Theme.amber)
                                    }
                                } else {
                                    HStack { Text("Review priority \(entry.review.verificationPriority)"); Spacer(); Text("\(entry.review.reviewedCount)/4 reviewed") }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted)
                                }
                                if let date = entry.story.published { Text(date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.system(size: 9)).foregroundStyle(Theme.muted) }
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.panel, in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedID == entry.story.id ? Theme.accent.opacity(0.6) : Theme.line))
                        }.buttonStyle(.plain)
                    }
                    if entries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "newspaper").font(.title).foregroundStyle(Theme.accent)
                            Text("No matching cached headlines").font(.system(size: 13, weight: .medium))
                            Text("The national feed is a limited sample, not every city's local coverage. Broaden the radius or view the national parent to choose a seed.").font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                            Button("View national parent") { mode = "National" }.buttonStyle(ActionButton())
                            if seed != nil { Button("Inspect similarity filters") { showSimilarity = true }.buttonStyle(ActionButton()) }
                        }.padding(.vertical, 30)
                    }
                }
            }
            Text("One country edition at a time; it may include international stories. City/radius changes make no network requests.").font(.system(size: 9)).foregroundStyle(Theme.muted)
        }.padding(16)
    }
}

struct ArticleReviewView: View {
    @EnvironmentObject private var store: NewsStore
    let entry: ReviewedStory
    let seedSelected: Bool
    var comparison: HeadlineVector? = nil
    let useSeed: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HStack { Eyebrow(text: "STORY / EVIDENCE REVIEW", color: Theme.accent); Spacer(); Button { store.review(entry) { $0.saved.toggle() } } label: { Image(systemName: entry.review.saved ? "bookmark.fill" : "bookmark") }.buttonStyle(ActionButton()).accessibilityLabel("Save news story") }
                Text(entry.story.title).font(.system(size: 25, weight: .medium, design: .serif)).textSelection(.enabled)
                Text(entry.story.publisher + " · " + entry.search.locationLabel).font(.system(size: 11)).foregroundStyle(Theme.muted)
                HStack {
                    Link(destination: entry.story.url) { Label("Read source", systemImage: "arrow.up.right.square") }.buttonStyle(ActionButton())
                    Button(action: useSeed) { Label(seedSelected ? "Comparison seed" : "Use as similarity seed", systemImage: "scope") }.buttonStyle(ActionButton(prominent: true))
                }
                if let comparison { VectorBreakdown(vector: comparison) }
                HStack(spacing: 15) {
                    metric("REVIEW PRIORITY", "\(entry.review.verificationPriority)/100", color: Theme.amber)
                    metric("EVIDENCE CONFIDENCE", entry.review.confidence.map { "\($0)/100" } ?? "Unreviewed", color: Theme.accent)
                }
                Text("Confidence is an analyst-rated rubric, not a probability that a story is true. It appears after all four dimensions are reviewed. Unknown evidence raises review priority; it does not mean the article is false.").font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(3)
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "CONFIDENCE VECTOR  [ P, C, X, G ]")
                    ForEach(EvidenceDimension.allCases) { dimension in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(dimension.code).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.accent).frame(width: 20)
                                Text(dimension.rawValue).font(.system(size: 12, weight: .medium))
                                Spacer()
                                Picker(dimension.rawValue, selection: Binding(get: { entry.review[dimension] }, set: { value in store.review(entry) { $0[dimension] = value } })) { ForEach(EvidenceLevel.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 128)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) { Capsule().fill(Theme.line); Capsule().fill(Theme.accent.opacity(0.7)).frame(width: geo.size.width * (entry.review[dimension].value ?? 0)) }
                            }.frame(height: 3)
                            Text(dimension.prompt).font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(2)
                        }
                    }
                }.padding(15).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                DisclosureGroup("Why this review priority?") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(entry.review.priorityReasons, id: \.self) { Text($0) }
                        Text("Four equal weights. Unreviewed/weak: 25 each; partial: 12.5; strong: 0. Total rounded to 0–100.")
                    }.font(.system(size: 10)).foregroundStyle(Theme.muted).padding(.top, 8)
                }.font(.system(size: 12))
                Eyebrow(text: "EVIDENCE LINKS / ONE PER LINE")
                TextEditor(text: Binding(get: { entry.review.evidenceLinks }, set: { text in store.review(entry) { $0.evidenceLinks = text } })).font(.system(size: 11, design: .monospaced)).scrollContentBackground(.hidden).padding(8).frame(height: 70).background(Theme.panel, in: RoundedRectangle(cornerRadius: 5)).accessibilityLabel("Evidence links")
                Eyebrow(text: "REVIEW NOTES")
                TextEditor(text: Binding(get: { entry.review.notes }, set: { text in store.review(entry) { $0.notes = text } })).font(.system(size: 12)).scrollContentBackground(.hidden).padding(8).frame(height: 120).background(Theme.panel, in: RoundedRectangle(cornerRadius: 5)).accessibilityLabel("News review notes")
                Text("The app has not read the full article or independently verified these claims. Reviews and geographic scope save locally.").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }.padding(24)
        }
    }
    private func metric(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) { Eyebrow(text: label); Text(value).font(.system(size: 22, weight: .medium, design: .monospaced)).foregroundStyle(color) }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
    }
}
