import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WorkshopCore

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var workspace: Workspace
    @Published var saveStatus = "Saved on this Mac"
    @Published var errorMessage: String?
    @Published var selectedDraftID: UUID?
    let fileURL: URL
    private var canSave = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SyndromeDisinformationWorkshop/workspace.json")
        var loadError: String?
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do { workspace = try WorkspaceFile.load(from: self.fileURL) }
            catch {
                workspace = Workspace(drafts: [])
                canSave = false
                loadError = "Your saved workspace could not be read. It has been preserved at \(self.fileURL.path). Import a valid backup to resume saving.\n\n\(error.localizedDescription)"
            }
        } else { workspace = Workspace() }
        selectedDraftID = workspace.drafts.first?.id
        errorMessage = loadError
        if loadError != nil { saveStatus = "Storage needs attention" }
    }
    var selectedDraft: Draft? { workspace.drafts.first { $0.id == selectedDraftID } }
    func save() {
        guard canSave else { saveStatus = "Storage needs attention"; return }
        do { try WorkspaceFile.save(workspace, to: fileURL); saveStatus = "Saved on this Mac" }
        catch { saveStatus = "Changes not saved"; errorMessage = error.localizedDescription }
    }
    func update(_ draft: Draft) {
        guard let index = workspace.drafts.firstIndex(where: { $0.id == draft.id }) else { return }
        var clean = draft; clean.normalize(); clean.modified = Date()
        workspace.drafts[index] = clean
        save()
    }
    func create(from dossier: Dossier? = nil) {
        let draft: Draft
        if let dossier {
            draft = Draft(title: dossier.title, reference: dossier.id + " / SIM", body: dossier.memo, sourceDossierID: dossier.id)
        } else { draft = Draft(body: "MEMORANDUM FOR THE SPECIAL STUDY GROUP\n\nBegin your fictional memorandum here.") }
        workspace.drafts.insert(draft, at: 0); selectedDraftID = draft.id; save()
    }
    func duplicate() {
        guard var draft = selectedDraft else { return }
        draft.id = UUID(); draft.title = String((draft.title + " / copy").prefix(100)); draft.modified = Date()
        workspace.drafts.insert(draft, at: 0); selectedDraftID = draft.id; save()
    }
    func deleteSelected() {
        workspace.drafts.removeAll { $0.id == selectedDraftID }
        selectedDraftID = workspace.drafts.first?.id; save()
    }
    func note(for dossier: Dossier) -> String { workspace.notes[dossier.id] ?? "" }
    func setNote(_ text: String, for dossier: Dossier) {
        workspace.notes[dossier.id] = String(text.prefix(20_000)); save()
    }
    func toggleBookmark(_ dossier: Dossier) {
        if workspace.bookmarks.contains(dossier.id) { workspace.bookmarks.remove(dossier.id) }
        else { workspace.bookmarks.insert(dossier.id) }
        save()
    }
    func exportBackup() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Workshop-backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try WorkspaceFile.save(workspace, to: url); saveStatus = "Backup exported" }
        catch { errorMessage = error.localizedDescription }
    }
    func importBackup() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try WorkspaceFile.load(from: url)
            // Preserve unreadable storage before allowing writes again.
            if !canSave, FileManager.default.fileExists(atPath: fileURL.path) {
                let recovery = fileURL.deletingLastPathComponent().appendingPathComponent("workspace-unreadable-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: fileURL, to: recovery)
            }
            for var draft in imported.drafts {
                if workspace.drafts.contains(where: { $0.id == draft.id }) { draft.id = UUID() }
                workspace.drafts.append(draft)
            }
            for (id, note) in imported.notes {
                if let existing = workspace.notes[id], !existing.isEmpty, existing != note {
                    workspace.notes[id] = existing + "\n\n[Imported notes]\n" + note
                } else { workspace.notes[id] = note }
            }
            workspace.bookmarks.formUnion(imported.bookmarks)
            canSave = true
            selectedDraftID = workspace.drafts.last?.id; save()
        } catch { errorMessage = "Backup could not be imported: \(error.localizedDescription)" }
    }
    func exportDraft(pdf: Bool) {
        guard let draft = selectedDraft else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = pdf ? [.pdf] : [.plainText]
        let name = draft.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = (name.isEmpty ? "Workshop-memo" : name) + (pdf ? ".pdf" : ".txt")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if pdf { try PaperRenderer.pdf(draft: draft).write(to: url, options: .atomic) }
            else { try draft.plainText.write(to: url, atomically: true, encoding: .utf8) }
            saveStatus = pdf ? "PDF exported" : "Text exported"
        } catch { errorMessage = error.localizedDescription }
    }
}
