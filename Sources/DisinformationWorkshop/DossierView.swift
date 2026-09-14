import SwiftUI
import WorkshopCore

struct DossierView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let record: Dossier
    let openWorkshop: () -> Void
    @State private var redaction = 0.0
    @State private var tab = "Briefing"
    private let tabs = ["Briefing", "Study memo", "Analyst notes"]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "DOSSIER / " + record.id)
                Spacer()
                Button { store.toggleBookmark(record) } label: {
                    Image(systemName: store.workspace.bookmarks.contains(record.id) ? "bookmark.fill" : "bookmark")
                }.buttonStyle(ActionButton()).help("Bookmark dossier").accessibilityLabel("Bookmark dossier")
                Button(action: openWorkshop) { Label("Open in workshop", systemImage: "arrow.up.right") }.buttonStyle(ActionButton(prominent: true))
            }.padding(.bottom, 25)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(record.title).font(.system(size: 38, weight: .medium, design: .serif))
                    Text(record.subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                DossierGlyph(domain: record.domain).frame(width: 80, height: 80)
            }
            HStack(spacing: 12) { StatusBadge(status: record.status); Text(record.period).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted) }.padding(.top, 21).padding(.bottom, 24)
            HStack(spacing: 24) {
                ForEach(tabs, id: \.self) { title in
                    Button { tab = title } label: {
                        VStack(spacing: 11) {
                            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(tab == title ? Theme.accent : Theme.muted)
                            Rectangle().fill(tab == title ? Theme.accent : .clear).frame(height: 2)
                        }.fixedSize(horizontal: true, vertical: false)
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    if tab == "Briefing" {
                        section("SUBJECT / CONNECTION", record.subject, prominent: true)
                        section("THE NARRATIVE", record.summary)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Image(systemName: "scope").foregroundStyle(Theme.accent); Eyebrow(text: "EVIDENCE ASSESSMENT", color: Theme.accent) }
                            Text(record.assessment).font(.system(size: 13)).lineSpacing(6).foregroundStyle(Theme.text)
                        }.padding(19).frame(maxWidth: .infinity, alignment: .leading).background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                        section("PROVENANCE", record.provenance)
                        if !record.sources.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Eyebrow(text: "SOURCE REFERENCES")
                                ForEach(record.sources, id: \.url) { source in
                                    if let url = URL(string: source.url) {
                                        Link(destination: url) { HStack { Image(systemName: "arrow.up.right.square"); Text(source.title); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 10)) } }.font(.system(size: 12)).foregroundStyle(Theme.accent)
                                    }
                                }
                                Text("Source pages open in your browser.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                            }
                        }
                    } else if tab == "Study memo" {
                        HStack { Eyebrow(text: "FICTIONAL ANALYSIS EXERCISE", color: Theme.amber); Spacer() }
                        Text("An original teaching memo inspired by this dossier. It is not an archival transcript.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        HStack { Text("Redaction").font(.system(size: 12)); Slider(value: $redaction, in: 0...1).accessibilityLabel("Study memo redaction"); Text(redaction, format: .percent.precision(.fractionLength(0))).monospacedDigit().frame(width: 40) }
                        Text(Redaction.apply(record.memo, level: redaction))
                            .font(.system(size: 13, design: .monospaced)).lineSpacing(8).foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(22).background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                            .textSelection(.enabled)
                    } else {
                        Eyebrow(text: "ANALYST'S NOTEBOOK")
                        Text("Keep questions, alternative explanations, and source leads alongside the record. Notes save as you type.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        TextEditor(text: Binding(get: { store.note(for: record) }, set: { store.setNote($0, for: record) }))
                            .font(.system(size: 13, design: .monospaced)).scrollContentBackground(.hidden).padding(14)
                            .frame(minHeight: 310).background(Theme.panel, in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel("Analyst notes")
                        Text("\(store.note(for: record).count.formatted()) / 20,000 characters").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
                    }
                }.padding(.top, 26).padding(.bottom, 30).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.horizontal, 32).padding(.top, 24).background(Theme.background)
    }
    private func section(_ label: String, _ text: String, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Eyebrow(text: label)
            Text(text).font(.system(size: prominent ? 16 : 13, weight: prominent ? .medium : .regular)).lineSpacing(6).textSelection(.enabled)
        }
    }
}

struct DossierGlyph: View {
    let domain: Domain
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Theme.panel)
            Circle().stroke(Theme.accent.opacity(0.22), lineWidth: 1).padding(10)
            Circle().stroke(Theme.accent.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 4])).padding(3)
            Image(systemName: domain.icon).font(.system(size: 26, weight: .ultraLight)).foregroundStyle(Theme.accent)
            Rectangle().fill(Theme.accent.opacity(0.2)).frame(height: 0.5)
            Rectangle().fill(Theme.accent.opacity(0.2)).frame(width: 0.5)
        }.accessibilityHidden(true)
    }
}
