import SwiftUI
import WorkshopCore

struct PublicationProjectsView: View {
    @EnvironmentObject private var store: NewsStore
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow(text: "PUBLICATIONS / OBSERVED DISTRIBUTION", color: Theme.accent)
                Spacer()
                Picker("Publication project", selection: $store.selectedProjectID) {
                    ForEach(store.state.publicationProjects ?? []) { Text($0.title + ($0.archived ? " · Archived" : "")).tag(Optional($0.id)) }
                }.labelsHidden().frame(maxWidth: 280)
                Button("New project") { store.newPublicationProject() }.buttonStyle(ActionButton(prominent: true))
                if store.selectedProject != nil { Button("Export") { store.exportPublicationProject() }.buttonStyle(ActionButton()) }
            }.padding(20)
            Divider()
            if let project = store.selectedProject { PublicationProjectEditor(project: project).id(project.id) }
            else {
                EmptyPanel(title: "Track a publication project", message: "Register your published URLs, record cumulative page views, and document linked mentions or republications.")
            }
        }.background(Theme.background)
    }
}
private struct PublicationProjectEditor: View {
    @EnvironmentObject private var store: NewsStore
    @State var project: PublicationProject
    @State private var publicationForm = false
    @State private var mentionForm = false
    @State private var analyticsForm = false
    @State private var editPublication: ProjectPublication?
    @State private var editMention: PublicationMention?
    @State private var editAnalytics: PublicationAnalytics?
    @State private var mapCountry = NewsCountry.unitedStates
    @State private var mapRegion = "*"
    @FocusState private var titleFocused: Bool
    var spread: ProjectSpread { project.spread }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    TextField("Project title", text: $project.title).textFieldStyle(.plain).font(.system(size: 28, weight: .medium, design: .serif)).focused($titleFocused)
                    Toggle("Archived", isOn: $project.archived).toggleStyle(.checkbox).font(.system(size: 11))
                }
                Text("Manual records · analytics reports and linked evidence. No analytics service or web monitor is connected.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 12)], spacing: 12) {
                    metric("PUBLICATIONS", "\(project.distinctPublications)", "Distinct registered URLs")
                    metric("REPORTED PAGE VIEWS", project.reportedPageViews.map { $0.formatted() } ?? "Unknown", "Latest cumulative counts · \(project.latestAnalytics.count)/\(project.distinctPublications) URLs measured")
                    metric("EXTERNAL MENTIONS", "\(spread.confirmed.count)", "Analyst-confirmed URLs · \(spread.hostCount) hostnames")
                    metric("SPRAWL INDEX", spread.index.map { String(format: "%.1f / 100", $0) } ?? "Unknown", "Regional dispersion · \(spread.located.count) located URLs")
                }
                DisclosureGroup("How the visibility and sprawl numbers work") {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Page views use the latest cumulative report per canonical publication URL. Snapshots are never summed. Missing metrics stay unknown; totals can be partial and have different as-of dates. Page views are not unique readers.")
                        Text("Sprawl = 100 × (1 − Σ regional share²). It uses distinct confirmed external URLs with one documented source locality. One region scores 0; two equally represented regions score 50; four score 75. No qualifying geography means unknown.")
                        Text("Geographic evidence: \(spread.located.count)/\(spread.confirmed.count) confirmed external URLs. \(spread.cityCount) places · \(spread.regionCount) regions · \(spread.countryCount) countries. Maximum source-place separation: \(spread.maximumMiles.map { String(format: "%.0f mi", $0) } ?? "Unknown").")
                        Text("Own publication hostnames, unreviewed/rejected mentions, and duplicate URLs do not inflate external counts. Conflicting locations on duplicate URLs are excluded from geography. Different hostnames can share ownership. This describes recorded distribution, not reader locations, influence, or complete web reach.")
                    }.font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(3).padding(.top, 10)
                }
                HStack {
                    Button("Add publication") { editPublication = nil; publicationForm = true }.buttonStyle(ActionButton(prominent: true))
                    Button("Record mention") { editMention = nil; mentionForm = true }.buttonStyle(ActionButton()).disabled(project.publications.isEmpty)
                    Button("Record analytics") { editAnalytics = nil; analyticsForm = true }.buttonStyle(ActionButton()).disabled(project.publications.isEmpty)
                }
                Eyebrow(text: "REGISTERED PUBLICATIONS")
                if project.publications.isEmpty { Text("Add a published URL to begin. This tracker does not publish or distribute content.").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                ForEach(project.publications) { publication in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(publication.title).font(.system(size: 16, weight: .medium))
                            Link(publication.url.absoluteString, destination: publication.url).font(.system(size: 11)).lineLimit(2)
                            Text(publication.status.rawValue + " · " + (publication.published.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Publication date unknown")).font(.system(size: 10)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button("Edit") { editPublication = publication; publicationForm = true }.buttonStyle(ActionButton())
                    }.padding(14).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                }
                HStack {
                    Eyebrow(text: "DOCUMENTED SOURCE LOCATIONS")
                    Spacer()
                    CountryPicker(selection: $mapCountry, label: "Map country").frame(width: 240)
                }
                CoverageHeatMap(country: mapCountry, regions: spread.mapRows(country: mapCountry), selected: $mapRegion, itemName: "documented URLs", showSuggestions: false).frame(height: 300)
                Text("Heat = distinct geographically documented external URLs in each region. Source locations are analyst-supplied evidence about the outlet/publication, not its audience. Index above covers every country in this project.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                if let row = spread.mapRows(country: mapCountry).first(where: { $0.id == mapRegion }) {
                    Text("\(row.region.name): \(row.count) documented URLs").font(.system(size: 12)).foregroundStyle(Theme.accent)
                }
                Eyebrow(text: "MENTIONS & REPUBLICATIONS / OBSERVATION HISTORY")
                if project.mentions.isEmpty { Text("No mentions recorded. Unknown web coverage is not zero audience.").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                ForEach(project.mentions.sorted { $0.observed > $1.observed }) { mention in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(mention.title).font(.system(size: 14, weight: .medium))
                            Link(mention.url.absoluteString, destination: mention.url).font(.system(size: 11)).lineLimit(2)
                            Text("\(mention.kind.rawValue) · \(mention.review.rawValue) · \(mention.observed.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 10)).foregroundStyle(Theme.muted)
                            Text("For: " + (project.publications.first { $0.id == mention.publicationID }?.title ?? "Unknown")).font(.system(size: 10)).foregroundStyle(Theme.muted)
                            if let location = mention.location { Text("Source: \(location.label), \(location.country.name) · \(mention.locationConfirmed ? "analyst-confirmed" : "unreviewed geography")").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                        }
                        Spacer(); Button("Edit") { editMention = mention; mentionForm = true }.buttonStyle(ActionButton())
                    }.padding(14).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                }
                Eyebrow(text: "ANALYTICS HISTORY / CUMULATIVE PAGE VIEWS")
                if project.analytics.isEmpty { Text("No site analytics recorded. Add an all-time page-view measurement with its date and source.").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                ForEach(project.analytics.sorted { $0.measured > $1.measured }) { sample in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(sample.pageViews.formatted()) page views · \(sample.measured.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 13, weight: .medium))
                            Text(project.publications.first { $0.id == sample.publicationID }?.title ?? "Unknown publication").font(.system(size: 11))
                            Text(sample.source).font(.system(size: 10)).foregroundStyle(Theme.muted)
                        }
                        Spacer(); Button("Edit") { editAnalytics = sample; analyticsForm = true }.buttonStyle(ActionButton())
                    }.padding(12).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                }
                Eyebrow(text: "PROJECT NOTES")
                TextField("Editorial context, measurement limits, corrections", text: $project.notes, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(3...8)
            }.padding(24)
        }.onChange(of: project) { _, updated in store.updatePublicationProject(updated) }
            .onAppear { mapCountry = project.country }
            .onChange(of: mapCountry) { _, _ in mapRegion = "*" }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FocusNewsSearch"))) { _ in titleFocused = true }
            .sheet(isPresented: $publicationForm) {
                ProjectPublicationForm(existing: editPublication) { publication in
                    if let index = project.publications.firstIndex(where: { $0.id == publication.id }) { project.publications[index] = publication }
                    else { project.publications.append(publication) }
                }
            }
            .sheet(isPresented: $mentionForm) {
                ProjectMentionForm(publications: project.publications, existing: editMention, defaultCountry: project.country) { mention in
                    if let index = project.mentions.firstIndex(where: { $0.id == mention.id }) { project.mentions[index] = mention }
                    else { project.mentions.append(mention) }
                }
            }
            .sheet(isPresented: $analyticsForm) {
                ProjectAnalyticsForm(publications: project.publications, existing: editAnalytics) { sample in
                    if let index = project.analytics.firstIndex(where: { $0.id == sample.id }) { project.analytics[index] = sample }
                    else { project.analytics.append(sample) }
                }
            }
    }
    private func metric(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Eyebrow(text: label); Text(value).font(.system(size: 23, weight: .medium, design: .monospaced)).foregroundStyle(Theme.accent); Text(detail).font(.system(size: 10)).foregroundStyle(Theme.muted) }.frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading).padding(14).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
    }
}
