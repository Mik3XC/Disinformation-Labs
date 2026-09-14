import SwiftUI
import WorkshopCore

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @EnvironmentObject private var news: NewsStore
    @State private var projectMode = false
    @State private var coverageMode = false
    @State private var newsMode = false
    @State private var studyMode = false
    @State private var workshop = false
    @State private var domain: Domain?
    @State private var bookmarkedOnly = false
    @State private var selectedRecordID: String? = Vault.records.first?.id
    @State private var query = ""
    @State private var draftQuery = ""
    @State private var showDelete = false
    @FocusState private var searchFocused: Bool
    var records: [Dossier] { Vault.search(query, domain: domain, bookmarks: bookmarkedOnly ? store.workspace.bookmarks : nil) }
    var selectedRecord: Dossier? { records.first { $0.id == selectedRecordID } }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                sidebar.frame(minWidth: 200, idealWidth: 218, maxWidth: 250)
                if projectMode {
                    PublicationProjectsView().frame(minWidth: 850, maxWidth: .infinity)
                } else if coverageMode {
                    RegionalCoverageView().frame(minWidth: 850, maxWidth: .infinity)
                } else if newsMode {
                    NewsFeedView().frame(minWidth: 850, maxWidth: .infinity)
                } else if studyMode {
                    MultiCityStudyView().frame(minWidth: 850, maxWidth: .infinity)
                } else if workshop {
                    draftList.frame(minWidth: 230, idealWidth: 260, maxWidth: 320)
                    if let draft = store.selectedDraft {
                        WorkshopView(draft: draft).id(draft.id).frame(minWidth: 630, maxWidth: .infinity)
                    } else {
                        VStack { EmptyPanel(title: "Your next story starts here", message: "Create a memorandum or send a dossier to the workshop.")
                            Button("New memorandum") { store.create() }.buttonStyle(ActionButton(prominent: true)).padding(.bottom, 50)
                        }.frame(minWidth: 630)
                    }
                } else {
                    dossierList.frame(minWidth: 230, idealWidth: 270, maxWidth: 340)
                    if let record = selectedRecord {
                        DossierView(record: record) { store.create(from: record); workshop = true }
                            .id(record.id).frame(minWidth: 630, maxWidth: .infinity)
                    } else { EmptyPanel(title: "No dossier selected", message: "Choose a record or adjust your search.").frame(minWidth: 630) }
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 8) {
                Circle().fill(store.saveStatus == "Changes not saved" || store.saveStatus == "Storage needs attention" ? Theme.amber : Theme.accent).frame(width: 5, height: 5)
                Text(newsMode || studyMode || coverageMode || projectMode ? news.saveStatus : store.saveStatus)
                Spacer()
                Text("LOCAL ARCHIVE")
                Text("/").foregroundStyle(Theme.line)
                Text("SYNDROME™   ·   MJ12")
            }.font(.system(size: 9, design: .monospaced)).tracking(0.8).foregroundStyle(Theme.muted).padding(.horizontal, 20).frame(height: 29).background(Theme.sidebar)
        }
        .background(Theme.background).foregroundStyle(Theme.text)
        .frame(minWidth: 1100, minHeight: 740)
        .preferredColorScheme(.dark).tint(Theme.accent)
        .navigationTitle("Syndrome™ — Disinformation Labs")
        .toolbar {
            ToolbarItemGroup {
                Button { store.create(); workshop = true; newsMode = false; studyMode = false; coverageMode = false; projectMode = false } label: { Label("New memorandum", systemImage: "square.and.pencil") }.keyboardShortcut("n")
                Button {
                    if newsMode || studyMode || coverageMode || projectMode { NotificationCenter.default.post(name: Notification.Name("FocusNewsSearch"), object: nil) }
                    else { searchFocused = true }
                } label: { Label("Search", systemImage: "magnifyingglass") }.keyboardShortcut("f")
                Menu {
                    Button("Export workspace backup…") { store.exportBackup() }
                    Button("Import workspace backup…") { store.importBackup() }
                    Divider()
                    Button("Export news & studies archive…") { news.exportArchive() }
                    Button("Import news & studies archive…") { news.importArchive() }
                } label: { Label("Workspace", systemImage: "externaldrive") }.accessibilityLabel("Workspace backups")
            }
        }
        .onChange(of: records.map(\.id)) { _, ids in
            if !ids.contains(selectedRecordID ?? "") { selectedRecordID = ids.first }
        }
        .alert("Workspace", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog("Delete this memorandum?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete memorandum", role: .destructive) { store.deleteSelected() }
        } message: { Text("This removes the saved draft from this workspace.") }
        .alert("News research", isPresented: Binding(get: { news.errorMessage != nil }, set: { if !$0 { news.errorMessage = nil } })) {
            Button("OK") { news.errorMessage = nil }
        } message: { Text(news.errorMessage ?? "") }
    }

    private var sidebar: some View {
        GeometryReader { geometry in
          ScrollView {
           VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                AlienLogo().frame(width: 30, height: 37)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SYNDROME™").font(.system(size: 16, weight: .bold, design: .monospaced)).tracking(1.3)
                    Eyebrow(text: "DISINFORMATION LABS", color: Theme.accent)
                }
            }.padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 33)
            Eyebrow(text: "COLLECTION / 01").padding(.horizontal, 20).padding(.bottom, 12)
            navRow("All dossiers", icon: "square.stack.3d.up", count: Vault.records.count, selected: !newsMode && !projectMode && !coverageMode && !studyMode && !workshop && domain == nil && !bookmarkedOnly) { newsMode = false; studyMode = false; coverageMode = false; projectMode = false; workshop = false; domain = nil; bookmarkedOnly = false }
            ForEach(Domain.allCases) { item in
                navRow(item.rawValue, icon: item.icon, count: Vault.records.filter { $0.domain == item }.count, selected: !newsMode && !projectMode && !coverageMode && !studyMode && !workshop && domain == item && !bookmarkedOnly) { newsMode = false; studyMode = false; coverageMode = false; projectMode = false; workshop = false; domain = item; bookmarkedOnly = false }
            }
            navRow("Bookmarked", icon: "bookmark", count: store.workspace.bookmarks.count, selected: !newsMode && !projectMode && !coverageMode && !studyMode && !workshop && bookmarkedOnly) { newsMode = false; studyMode = false; coverageMode = false; projectMode = false; workshop = false; domain = nil; bookmarkedOnly = true }
            Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 20).padding(.vertical, 14)
            Eyebrow(text: "NEWS & GEOGRAPHY").padding(.horizontal, 20).padding(.bottom, 10)
            navRow("News feed", icon: "newspaper", count: news.state.activeSnapshot?.stories.count ?? 0, selected: newsMode) { newsMode = true; studyMode = false; coverageMode = false; projectMode = false }
            navRow("Coverage map", icon: "map", count: news.state.activeSnapshot?.stories.count ?? 0, selected: coverageMode) { newsMode = false; studyMode = false; projectMode = false; coverageMode = true }
            navRow("Publication projects", icon: "doc.text.magnifyingglass", count: news.state.publicationProjects?.count ?? 0, selected: projectMode) { newsMode = false; studyMode = false; coverageMode = false; projectMode = true }
            navRow("Multi-city studies", icon: "point.3.connected.trianglepath.dotted", count: news.state.studies.count, selected: studyMode) { newsMode = false; coverageMode = false; projectMode = false; studyMode = true }
            Rectangle().fill(Theme.line).frame(height: 1).padding(20)
            Eyebrow(text: "AUTHORING").padding(.horizontal, 20).padding(.bottom, 12)
            navRow("Workshop", icon: "slider.horizontal.3", count: store.workspace.drafts.count, selected: !newsMode && !projectMode && !coverageMode && !studyMode && workshop) { newsMode = false; studyMode = false; coverageMode = false; projectMode = false; workshop = true }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "viewfinder").font(.system(size: 22)).foregroundStyle(Theme.accent)
                Text("Question the record.").font(.system(size: 13, weight: .medium))
                Text("Trace the source. Separate the claim. Build the story.").font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.panel, in: RoundedRectangle(cornerRadius: 8)).padding(14)
            Eyebrow(text: "VOL. 01   /   THE DOTY FILES").padding(.horizontal, 20).padding(.bottom, 18)
           }.frame(minHeight: geometry.size.height)
          }
        }.background(Theme.sidebar)
    }
    private func navRow(_ title: String, icon: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 19)
                Text(title).font(.system(size: 12, weight: selected ? .semibold : .regular))
                Spacer(minLength: 3)
                Text(String(format: "%02d", count)).font(.system(size: 10, design: .monospaced)).opacity(0.65)
            }.foregroundStyle(selected ? Theme.accent : Theme.muted).padding(.horizontal, 12).padding(.vertical, 11)
                .background(selected ? Theme.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.horizontal, 9).padding(.vertical, 2)
    }
    private var dossierList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "INTELLIGENCE VAULT").padding(.top, 29)
            HStack { Text(bookmarkedOnly ? "Bookmarks" : domain?.rawValue ?? "The Doty files").font(.system(size: 23, weight: .medium)); Spacer() }.padding(.top, 9)
            Text("\(records.count) \(records.count == 1 ? "record" : "records") in this collection").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.top, 7)
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted); TextField("Search dossiers", text: $query).textFieldStyle(.plain).focused($searchFocused)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("Clear search") }
            }.padding(10).background(Theme.panel, in: RoundedRectangle(cornerRadius: 6)).padding(.vertical, 21)
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(records) { record in
                        Button { selectedRecordID = record.id } label: {
                            VStack(alignment: .leading, spacing: 11) {
                                HStack { Eyebrow(text: record.id, color: selectedRecordID == record.id ? Theme.accent : Theme.muted); Spacer(); if store.workspace.bookmarks.contains(record.id) { Image(systemName: "bookmark.fill").font(.system(size: 10)).foregroundStyle(Theme.accent) } }
                                Text(record.title).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.text)
                                Text(record.subtitle).font(.system(size: 11)).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                                StatusBadge(status: record.status)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(15)
                                .background(selectedRecordID == record.id ? Theme.accent.opacity(0.06) : Theme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(selectedRecordID == record.id ? Theme.accent.opacity(0.45) : Theme.line))
                        }.buttonStyle(.plain)
                    }
                    if records.isEmpty { Text("No matching records. Try another search.").foregroundStyle(Theme.muted).padding(.top, 30) }
                }.padding(.bottom, 16)
            }
        }.padding(.horizontal, 17).background(Theme.background)
    }
    private var draftList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "YOUR WORKSPACE").padding(.top, 29)
            Text("Memoranda").font(.system(size: 23, weight: .medium)).padding(.top, 9)
            Text("\(store.workspace.drafts.count) locally saved \(store.workspace.drafts.count == 1 ? "draft" : "drafts")").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.top, 7)
            Button { store.create() } label: { Label("New memorandum", systemImage: "plus") }.buttonStyle(ActionButton(prominent: true)).padding(.vertical, 20)
            TextField("Search drafts", text: $draftQuery).textFieldStyle(.roundedBorder).focused($searchFocused).padding(.bottom, 15)
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(store.workspace.drafts.filter { draftQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(draftQuery) || $0.body.localizedCaseInsensitiveContains(draftQuery) }) { draft in
                        Button { store.selectedDraftID = draft.id } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { Image(systemName: "doc.text").foregroundStyle(Theme.accent); Spacer(); Eyebrow(text: "DRAFT") }
                                Text(draft.title.isEmpty ? "Untitled memorandum" : draft.title).font(.system(size: 15, weight: .medium)).lineLimit(2)
                                Text(draft.medium.rawValue).font(.system(size: 10)).foregroundStyle(Theme.muted)
                                Text(draft.modified, style: .date).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(15).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.selectedDraftID == draft.id ? Theme.accent.opacity(0.5) : Theme.line))
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Button { store.duplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                Spacer()
                Button { showDelete = true } label: { Image(systemName: "trash") }.accessibilityLabel("Delete memorandum")
            }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Theme.muted).disabled(store.selectedDraft == nil).padding(.vertical, 20)
        }.padding(.horizontal, 17).background(Theme.background)
    }
}
