import SwiftUI
import WorkshopCore

struct RegionalCoverageView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var query = ""
    @State private var publisher = ""
    @State private var includeSuggestions = true
    @State private var selectedRegion = "*"
    @State private var selectedArticle: String?
    @FocusState private var searchFocused: Bool
    var country: NewsCountry { store.state.search.country }
    @State private var report = CoverageReport.build(country: .unitedStates, stories: [], assessments: [:], includeSuggestions: false)
    private func rebuild() {
        report = CoverageReport.build(country: country, stories: store.state.activeSnapshot?.stories ?? [], assessments: store.state.coverageAssessments ?? [:], includeSuggestions: includeSuggestions, query: query, publisher: publisher, fetched: store.state.activeSnapshot?.fetched)
    }
    var visible: [CoverageItem] {
        if selectedRegion == "*" { return report.items }
        if selectedRegion == "?" { return report.unmapped }
        return report.regions.first { $0.id == selectedRegion }?.items ?? []
    }
    var selected: CoverageItem? { visible.first { $0.id == selectedArticle } ?? visible.first }
    var publishers: [String] { Array(Set((store.state.activeSnapshot?.stories ?? []).map(\.publisher))).sorted() }
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Eyebrow(text: "PUBLISHED COVERAGE / REGIONAL REVIEW", color: Theme.accent); Text("Coverage heat map").font(.system(size: 28, weight: .medium, design: .serif)) }
                    Spacer()
                    Button("Export review") { store.exportCoverage(report) }.buttonStyle(ActionButton())
                }
                HStack(spacing: 12) {
                    CountryPicker(selection: Binding(get: { country }, set: store.chooseCountry)).frame(width: 240)
                    TextField("Filter headlines · e.g. election", text: $query).textFieldStyle(.roundedBorder).focused($searchFocused)
                    Picker("Publisher", selection: $publisher) { Text("All publishers").tag(""); ForEach(publishers, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 180)
                }
                HStack {
                    Toggle("Include suggested locations", isOn: $includeSuggestions).font(.system(size: 11))
                    Spacer()
                    Text("\(report.items.count) articles · \(report.unmapped.count) unmapped · \(report.regions.filter { $0.count > 0 }.count) regions").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accent)
                }
                Text("Heat = article count in this cached sample. It does not measure viewers, voter sentiment, or intended audience. Suggested locations are unverified headline mentions.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                if let snapshot = store.state.activeSnapshot {
                    Text("\(country.name) · English · cached \(snapshot.fetched.formatted(date: .abbreviated, time: .shortened)) · \(snapshot.search.topic.isEmpty ? "top headlines" : snapshot.search.topic) · \(snapshot.search.window.rawValue)").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted)
                } else { Text("No country feed cached. Open News feed and refresh this country to populate the map.").font(.system(size: 11)).foregroundStyle(Theme.amber) }
            }.padding(20)
            Divider()
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        CoverageHeatMap(country: country, regions: report.regions, selected: $selectedRegion).frame(height: 290)
                        HStack { Text("ARTICLE COUNT"); Spacer(); Text("0"); LinearGradient(colors: [Theme.panel, Theme.accent], startPoint: .leading, endPoint: .trailing).frame(width: 85, height: 7); Text("\(report.regions.map(\.count).max() ?? 0)") }.font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
                        Text("Markers use average catalog place coordinates, not state boundaries or reader locations. Select a marker or region below. Natural Earth outlines · offline.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        HStack {
                            Button("All articles (\(report.items.count))") { selectedRegion = "*" }.buttonStyle(ActionButton(prominent: selectedRegion == "*"))
                            Button("Unmapped (\(report.unmapped.count))") { selectedRegion = "?" }.buttonStyle(ActionButton(prominent: selectedRegion == "?"))
                        }
                        ForEach(report.regions.sorted { $0.count == $1.count ? $0.region.name < $1.region.name : $0.count > $1.count }) { row in
                            Button { selectedRegion = row.id } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) { Text(row.region.name); Text("\(row.publisherCount) publishers · \(row.suggestedCount) suggested · \(row.ratedCount) tone-rated").font(.system(size: 9)).foregroundStyle(Theme.muted) }
                                    Spacer(); Text("\(row.count)").font(.system(size: 15, design: .monospaced)).foregroundStyle(Theme.accent)
                                }.font(.system(size: 12)).padding(10).background(selectedRegion == row.id ? Theme.accent.opacity(0.10) : Theme.panel, in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain)
                        }
                    }.padding(16)
                }.frame(minWidth: 410, idealWidth: 475)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: selectedRegion == "*" ? "ALL CACHED ARTICLES" : selectedRegion == "?" ? "UNMAPPED ARTICLES" : report.regions.first { $0.id == selectedRegion }?.region.name.uppercased() ?? "REGION")
                        Text("\(visible.count) articles · region totals may overlap").font(.system(size: 11)).foregroundStyle(Theme.muted)
                        Text("Tone annotations: " + ArticleTone.allCases.compactMap { tone in
                            let count = visible.filter { $0.assessment.tone == tone }.count
                            return count == 0 ? nil : "\(tone.rawValue) \(count)"
                        }.joined(separator: " · ")).font(.system(size: 10)).foregroundStyle(Theme.muted)
                        if !visible.isEmpty {
                            Picker("Article to inspect", selection: Binding(get: { selected?.id ?? "" }, set: { selectedArticle = $0 })) {
                                ForEach(visible) { item in Text(item.story.title).tag(item.id) }
                            }.labelsHidden()
                        }
                        if let selected { CoverageArticleEditor(item: selected, country: country).id(selected.id + country.rawValue) }
                        else { Text("No articles in this group. Try All articles or review unassigned locations.").foregroundStyle(Theme.muted).padding(.vertical, 30) }
                        Divider()
                        Eyebrow(text: "ARTICLES IN THIS GROUP")
                        ForEach(visible) { item in
                            Button { selectedArticle = item.id } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.story.title).font(.system(size: 12)).multilineTextAlignment(.leading)
                                    Text(item.story.publisher + " · " + item.assessment.tone.rawValue).font(.system(size: 10)).foregroundStyle(Theme.muted)
                                }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Theme.panel, in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain)
                        }
                    }.padding(18)
                }.frame(minWidth: 380, idealWidth: 420)
            }
        }.background(Theme.background)
            .onAppear { rebuild() }
            .onChange(of: country) { _, _ in publisher = ""; selectedRegion = "*"; selectedArticle = nil; rebuild() }
            .onChange(of: query) { _, _ in rebuild() }
            .onChange(of: publisher) { _, _ in rebuild() }
            .onChange(of: includeSuggestions) { _, _ in rebuild() }
            .onChange(of: store.state.activeSnapshot) { _, _ in rebuild() }
            .onChange(of: store.state.coverageAssessments) { _, _ in rebuild() }
            .onChange(of: selectedRegion) { _, _ in selectedArticle = nil }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FocusNewsSearch"))) { _ in searchFocused = true }
    }
}

private struct CoverageArticleEditor: View {
    @EnvironmentObject private var store: NewsStore
    let item: CoverageItem
    let country: NewsCountry
    @State private var regionQuery = ""
    var assessment: CoverageAssessment { store.state.coverageAssessments?[CoverageAssessment.key(story: item.story, country: country)] ?? item.assessment }
    var suggestions: [String] { CoverageCatalog.suggestedRegions(title: item.story.title, country: country) }
    func update(_ change: (inout CoverageAssessment) -> Void) { store.assessCoverage(item.story, country: country, change: change) }
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(item.story.title).font(.system(size: 21, weight: .medium, design: .serif)).textSelection(.enabled)
            Text(item.story.publisher).font(.system(size: 11)).foregroundStyle(Theme.muted)
            if let date = item.story.published { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(Theme.muted) }
            Link("Read source", destination: item.story.url).buttonStyle(ActionButton())
            Eyebrow(text: "WRITING ASSESSMENT / MANUAL", color: Theme.accent)
            Picker("Tone", selection: Binding(get: { assessment.tone }, set: { value in update { $0.tone = value } })) { ForEach(ArticleTone.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Format", selection: Binding(get: { assessment.format }, set: { value in update { $0.format = value } })) { ForEach(ArticleFormat.allCases) { Text($0.rawValue).tag($0) } }
            Text("Assess the source text. These labels describe writing, not the reactions or demographics of its readers. Unreviewed stays unreviewed.").font(.system(size: 10)).foregroundStyle(Theme.muted)
            Eyebrow(text: "REGIONAL GROUPING")
            Text(assessment.regions == nil ? "Headline suggestions · unverified" : "Analyst-assigned regions").font(.system(size: 11)).foregroundStyle(assessment.regions == nil ? Theme.amber : Theme.accent)
            Text(regionNames(assessment.regions ?? suggestions)).font(.system(size: 11)).foregroundStyle(Theme.muted)
            DisclosureGroup("Review region assignments") {
                VStack(alignment: .leading, spacing: 10) {
                    if !suggestions.isEmpty { Button("Assign headline suggestions") { update { $0.regions = suggestions } }.buttonStyle(ActionButton()) }
                    HStack {
                        Button("Mark unmapped") { update { $0.regions = [] } }
                        Button("Reset to unreviewed") { update { $0.regions = nil } }
                    }.font(.system(size: 10))
                    TextField("Find region", text: $regionQuery).textFieldStyle(.roundedBorder)
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(CoverageCatalog.regions(in: country).filter { regionQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(regionQuery) }) { region in
                                Toggle(region.name, isOn: Binding(get: { assessment.regions?.contains(region.code) ?? false }, set: { checked in
                                    update { value in var regions = Set(value.regions ?? []); if checked { regions.insert(region.code) } else { regions.remove(region.code) }; value.regions = regions.sorted() }
                                })).font(.system(size: 11))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: 140)
                }.padding(.top, 10)
            }.font(.system(size: 12))
            TextField("Assessment notes · wording, quotations, context", text: Binding(get: { assessment.notes }, set: { text in update { $0.notes = text } }), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(3...6)
        }
    }
    private func regionNames(_ codes: [String]) -> String {
        let names = CoverageCatalog.regions(in: country).filter { codes.contains($0.code) }.map(\.name)
        return names.isEmpty ? "No region assigned" : names.joined(separator: ", ")
    }
}
