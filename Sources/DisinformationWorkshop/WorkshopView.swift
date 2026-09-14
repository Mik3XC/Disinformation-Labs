import SwiftUI
import WorkshopCore

struct WorkshopView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State var draft: Draft
    @State private var mode = "Compose"
    @State private var pageIndex = 0
    var pages: [NSAttributedString] { PaperRenderer.pages(draft) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "EVIDENCE WORKSHOP", color: Theme.accent)
                Spacer()
                Menu {
                    Button("Export PDF…") { store.exportDraft(pdf: true) }
                    Button("Export plain text…") { store.exportDraft(pdf: false) }
                } label: { Label("Export memo", systemImage: "square.and.arrow.up") }.menuStyle(.borderlessButton).fixedSize().padding(9).background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }.padding(.bottom, 17)
            HStack(alignment: .firstTextBaseline) {
                Text("Disinformation Workshop").font(.system(size: 27, weight: .medium, design: .serif))
                Spacer()
                Eyebrow(text: "STUDIO / 01")
            }
            Text("Compose a story. Study the surface of authority.").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 7)
            HStack {
                Picker("Workspace mode", selection: $mode) { Text("Compose").tag("Compose"); Text("Preview").tag("Preview") }.pickerStyle(.segmented).labelsHidden().frame(width: 210)
                Spacer()
                Label("Fictional study copy", systemImage: "checkmark.seal").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
            }.padding(.vertical, 20)
            Rectangle().fill(Theme.line).frame(height: 1)
            if mode == "Compose" { compose }
            else { preview }
        }.padding(.horizontal, 27).padding(.top, 24).background(Theme.background)
        .onChange(of: draft) { _, updated in store.update(updated) }
        .onChange(of: draft.body) { _, _ in pageIndex = 0 }
        .onChange(of: draft.redaction) { _, _ in pageIndex = 0 }
        .onChange(of: draft.medium) { _, _ in pageIndex = 0 }
    }
    private var compose: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    field("DOCUMENT TITLE", text: limited(\Draft.title, 100))
                    field("REFERENCE", text: limited(\Draft.reference, 60)).frame(width: 160)
                }
                field("RECIPIENT", text: limited(\Draft.recipient, 120))
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "PRINT MEDIUM")
                        Picker("Print medium", selection: $draft.medium) { ForEach(Medium.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "LETTERHEAD")
                        Picker("Letterhead", selection: $draft.header) { ForEach(MemoHeader.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Eyebrow(text: "MEMORANDUM BODY"); Spacer(); Text("\(draft.body.count.formatted()) / 30,000").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted) }
                    TextEditor(text: limited(\Draft.body, Draft.bodyLimit)).font(.system(size: 12, design: .monospaced)).lineSpacing(5)
                        .scrollContentBackground(.hidden).padding(12).frame(height: 230).background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line)).accessibilityLabel("Memorandum body")
                }
                HStack(spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Eyebrow(text: "AGING & GRAIN"); Spacer(); percent(draft.distress) }
                        Slider(value: $draft.distress, in: 0...1).accessibilityLabel("Aging and grain")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Eyebrow(text: "REDACTION"); Spacer(); percent(draft.redaction) }
                        Slider(value: $draft.redaction, in: 0...1).accessibilityLabel("Memo redaction")
                    }
                }
                HStack {
                    Text("Every exported page is marked as a fictional simulation.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                    Spacer()
                    Button { mode = "Preview" } label: { Label("Preview document", systemImage: "doc.text.magnifyingglass") }.buttonStyle(ActionButton(prominent: true))
                }
            }.padding(.vertical, 24)
        }
    }
    private var preview: some View {
        let content = pages
        let index = min(pageIndex, content.count - 1)
        return VStack(spacing: 0) {
            HStack {
                Eyebrow(text: "US LETTER / LIVE PREVIEW")
                Spacer()
                Button { pageIndex = max(0, index - 1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0).accessibilityLabel("Previous page")
                Text("\(index + 1) / \(content.count)").font(.system(size: 11, design: .monospaced)).monospacedDigit()
                Button { pageIndex = min(content.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }.disabled(index == content.count - 1).accessibilityLabel("Next page")
            }.buttonStyle(.plain).padding(.vertical, 17)
            GeometryReader { geometry in
                let width = max(280, min(612, geometry.size.width - 36))
                ScrollView {
                    PaperPreview(draft: draft, page: content[index], index: index, count: content.count)
                        .frame(width: width, height: width * 792 / 612)
                        .shadow(color: .black.opacity(0.35), radius: 15, y: 7)
                        .padding(.vertical, 15).frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Fictional simulation, page \(index + 1) of \(content.count). \(draft.title). \(content[index].string)")
                }.background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Text(draft.medium.rawValue).font(.system(size: 10)).foregroundStyle(Theme.muted)
                Spacer()
                Button("Export PDF…") { store.exportDraft(pdf: true) }.buttonStyle(ActionButton(prominent: true)).keyboardShortcut("e", modifiers: [.command, .shift])
            }.padding(.vertical, 16)
        }
    }
    private func limited(_ path: WritableKeyPath<Draft, String>, _ count: Int) -> Binding<String> {
        Binding(get: { draft[keyPath: path] }, set: { draft[keyPath: path] = String($0.prefix(count)) })
    }
    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: label)
            TextField(label, text: text).textFieldStyle(.plain).font(.system(size: 13)).padding(10)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line))
        }
    }
    private func percent(_ value: Double) -> some View { Text(value, format: .percent.precision(.fractionLength(0))).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.accent).monospacedDigit() }
}
