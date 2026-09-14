import Foundation

public enum Domain: String, CaseIterable, Codable, Identifiable {
    case alien = "Alien retrieval"
    case aerial = "UFO deception"
    case paranormal = "Paranormal psyops"
    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .alien: return "shippingbox"
        case .aerial: return "airplane.circle"
        case .paranormal: return "waveform.path"
        }
    }
}

public enum EvidenceStatus: String, Codable, CaseIterable {
    case sourced = "SOURCED CONTEXT"
    case disputed = "UNVERIFIED CLAIM"
    case fictional = "FICTIONAL SCENARIO"
}

public struct SourceReference: Codable, Hashable {
    public let title: String
    public let url: String
}

public struct Dossier: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let domain: Domain
    public let status: EvidenceStatus
    public let period: String
    public let subject: String
    public let summary: String
    public let assessment: String
    public let provenance: String
    public let memo: String
    public let sources: [SourceReference]
    public var searchableText: String { [id, title, subtitle, domain.rawValue, status.rawValue, subject, summary, assessment].joined(separator: " ") }
}

public enum Medium: String, CaseIterable, Codable, Identifiable {
    case typewriter = "Typewriter / 1983"
    case telefax = "Thermal fax / 1989"
    case xerox = "Photocopy / third generation"
    public var id: String { rawValue }
}

public enum MemoHeader: String, CaseIterable, Codable, Identifiable {
    case majestic = "MJ-12 / story department"
    case field = "Field office / study copy"
    case technical = "Technical division / draft"
    public var id: String { rawValue }
}

public struct Draft: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var recipient: String
    public var reference: String
    public var body: String
    public var medium: Medium
    public var header: MemoHeader
    public var distress: Double
    public var redaction: Double
    public var modified: Date
    public var sourceDossierID: String?
    public static let bodyLimit = 30_000

    public init(id: UUID = UUID(), title: String = "Untitled memorandum", recipient: String = "Special study group", reference: String = "MJ12-001", body: String = "", medium: Medium = .typewriter, header: MemoHeader = .majestic, distress: Double = 0.35, redaction: Double = 0, modified: Date = Date(), sourceDossierID: String? = nil) {
        self.id = id; self.title = title; self.recipient = recipient; self.reference = reference
        self.body = body; self.medium = medium; self.header = header; self.distress = distress
        self.redaction = redaction; self.modified = modified; self.sourceDossierID = sourceDossierID
    }
    public static var sample: Draft {
        Draft(title: "Project Aquarius", reference: "AQ-083 / SIM", body: "MEMORANDUM FOR THE SPECIAL STUDY GROUP\n\nThe recovered object has been transferred to the fictional North Range facility. Its origin remains undetermined. Preliminary observations describe an unfamiliar alloy and a repeating signal.\n\nThe review team requests an independent materials analysis, a complete custody log, and the original instrument readings before drawing a conclusion.\n\nAPPENDIX A\nThe witness account and the telemetry report disagree on the time of recovery. Record both versions. Do not resolve the discrepancy by assumption.\n\nEND OF SIMULATED MEMORANDUM")
    }
    public var redactedBody: String { Redaction.apply(body, level: redaction) }
    public var plainText: String {
        "FICTIONAL SIMULATION - SYNDROME DISINFORMATION WORKSHOP\n\n\(header.rawValue.uppercased())\n\(title)\nTO: \(recipient)\nREF: \(reference)\n\n\(redactedBody)\n\nCREATIVE STUDY COPY - NOT AN AUTHENTIC GOVERNMENT RECORD\n"
    }
    public mutating func normalize() {
        title = String(title.prefix(100)); recipient = String(recipient.prefix(120)); reference = String(reference.prefix(60))
        body = String(body.prefix(Self.bodyLimit))
        distress = distress.isFinite ? min(1, max(0, distress)) : 0
        redaction = redaction.isFinite ? min(1, max(0, redaction)) : 0
    }
}

public enum Redaction {
    /// Replaces whole words before preview/export so hidden content is not embedded in the PDF.
    public static func apply(_ text: String, level: Double) -> String {
        guard level.isFinite, level > 0 else { return text }
        let threshold = Int(min(1, level) * 100)
        var index = 0
        return text.components(separatedBy: "\n").map { line in
            line.components(separatedBy: " ").map { word in
                guard !word.isEmpty else { return word }
                defer { index += 1 }
                return ((index * 37 + 17) % 100) < threshold ? "[REDACTED]" : word
            }.joined(separator: " ")
        }.joined(separator: "\n")
    }
}

public struct Workspace: Codable, Equatable {
    public var version: Int = 1
    public var drafts: [Draft]
    public var notes: [String: String]
    public var bookmarks: Set<String>
    public init(drafts: [Draft] = [.sample], notes: [String: String] = [:], bookmarks: Set<String> = []) {
        self.drafts = drafts; self.notes = notes; self.bookmarks = bookmarks
    }
}

public enum WorkspaceError: LocalizedError {
    case unsupportedVersion(Int)
    public var errorDescription: String? {
        switch self { case .unsupportedVersion(let version): return "This workspace uses version \(version). Open it with a newer Workshop app." }
    }
}

public enum WorkspaceFile {
    public static func load(from url: URL) throws -> Workspace {
        let data = try Data(contentsOf: url)
        var state = try JSONDecoder().decode(Workspace.self, from: data)
        guard state.version == 1 else { throw WorkspaceError.unsupportedVersion(state.version) }
        for index in state.drafts.indices { state.drafts[index].normalize() }
        return state
    }
    public static func save(_ workspace: Workspace, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(workspace).write(to: url, options: .atomic)
    }
}

public enum Vault {
    public static func search(_ query: String, domain: Domain? = nil, bookmarks: Set<String>? = nil) -> [Dossier] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return records.filter { record in
            (domain == nil || record.domain == domain) &&
            (bookmarks == nil || bookmarks!.contains(record.id)) &&
            terms.allSatisfy { record.searchableText.localizedCaseInsensitiveContains($0) }
        }
    }
    public static let records: [Dossier] = [
        Dossier(id: "AQ-083", title: "Project Aquarius", subtitle: "Bennewitz / EBE narrative", domain: .alien, status: .disputed, period: "1980s narrative", subject: "Richard Doty · Paul Bennewitz", summary: "The supplied brief connects Richard Doty, Paul Bennewitz, and stories of alien beings and underground installations. This dossier preserves that narrative as a claim to investigate.", assessment: "The brief's specific assertions about counterfeit telemetry, autopsy reports, equipment changes, and operational motives are not established by the sources included here. A convincing memo is not independent corroboration.", provenance: "Adapted from the user's Gemini concept brief. No authenticated Aquarius memo or first-hand record was supplied. The memo below is original fiction.", memo: "PROJECT AQUARIUS / NARRATIVE STUDY\n\nA report describes an underground installation and an unidentified biological entity. The source offers neither original telemetry nor an independently verifiable custody record.\n\nANALYST TASK: Separate the observer's report, the intermediary's account, and the later retelling. Leave unsupported links unresolved.", sources: []),
        Dossier(id: "MJ-012", title: "Majestic 12", subtitle: "The authority of a document", domain: .alien, status: .sourced, period: "1988 / archive context", subject: "Purported MJ-12 briefing papers", summary: "The FBI's public archive describes receiving versions of a purported classified MJ-12 memo in 1988. Its archive summary reports that an Air Force investigation found the document to be fake.", assessment: "An official-looking classification banner does not authenticate a document. The archive finding concerns the purported memo; it does not establish who made it or independently connect Richard Doty to its authorship.", provenance: "Source: FBI Vault, Unexplained Phenomenon index and Majestic 12 collection. Summary paraphrased; the workshop memo is not a transcription.", memo: "DOCUMENT AUTHENTICITY / STUDY COPY\n\nExamine the chain of custody before interpreting the contents. Compare formatting, dates, signatures, and the provenance of the earliest available copy.\n\nA repeated claim is not a second independent source.", sources: [SourceReference(title: "FBI Vault / archive summary", url: "https://vault.fbi.gov/unexplained-phenomenon/search"), SourceReference(title: "FBI Vault / Majestic 12", url: "https://vault.fbi.gov/Majestic%2012")]),
        Dossier(id: "SR-012", title: "Serpo exchange", subtitle: "An expanding alien travel story", domain: .aerial, status: .disputed, period: "Undated / supplied account", subject: "Richard Doty attribution in the brief", summary: "The concept brief describes a supposed human-alien exchange and attributes fabricated briefings to Richard Doty. This entry is a narrative index, not verification of that attribution or of the exchange.", assessment: "No primary evidence supplied with the brief establishes the alleged journey, authorship, or satellite-related motive. Track each assertion separately and request the earliest source for each.", provenance: "Adapted from the user's Gemini concept brief. Its specific claims remain unverified in this app.", memo: "EXCHANGE PROGRAM / FICTIONAL EXERCISE\n\nAn anonymous correspondent supplies an itinerary for a distant-world exchange. Each new installment adds detail, but the original travel log remains unavailable.\n\nANALYST TASK: List independently testable statements. Distinguish new evidence from narrative elaboration.", sources: []),
        Dossier(id: "UF-019", title: "The signal ledger", subtitle: "Observation vs. interpretation", domain: .aerial, status: .fictional, period: "Workshop exercise 02", subject: "A fictional civilian observer", summary: "A fictional observer records lights over a test range. Three retellings turn the same observation into incompatible accounts. Use this exercise to keep measurements separate from interpretation.", assessment: "Ask what was recorded, which equipment was used, and whether independent observers saw the same thing. An unexplained observation does not establish an extraterrestrial cause.", provenance: "Original fictional teaching scenario. No historical incident or real person's conduct is asserted.", memo: "NORTH RANGE / OBSERVATION LOG\n\n21:14 - Three lights recorded above the western ridge. Distance and altitude unknown.\n21:16 - Lights no longer visible.\n\nNOTE: The witness described appearance and motion. The later account added an origin, a mission, and a crew without additional observations.", sources: []),
        Dossier(id: "GD-004", title: "Ghost Dance", subtitle: "Psychotronics / fictional scenario", domain: .paranormal, status: .fictional, period: "Workshop exercise 03", subject: "Fictional test-range reports", summary: "The brief proposes a paranormal cover story involving apparitions and radio-frequency testing. Here it is treated as a fictional scenario, not a documented Richard Doty operation.", assessment: "The supplied text does not substantiate its claims about induced hallucinations, acoustic effects, or a named campaign. A mechanism proposed in a story is not a demonstrated scientific result.", provenance: "Fictionalized from the Gemini concept brief. The title is a story label, not an authenticated operation name.", memo: "GHOST DANCE / STORY DEVELOPMENT\n\nReports of an apparition circulate near a fictional research facility. A second account attributes the reports to an experimental device, but provides no measurements.\n\nANALYST TASK: Identify what evidence would distinguish rumor, perception, environmental causes, and deliberate storytelling.", sources: []),
        Dossier(id: "SG-095", title: "Stargate review", subtitle: "A real program, a limited conclusion", domain: .paranormal, status: .sourced, period: "1972–1995 / program context", subject: "Remote-viewing research", summary: "CIA's historical account describes government research into remote viewing and a 1995 independent evaluation. CIA says the results were too unreliable for intelligence use and it did not restore the program.", assessment: "The existence of a research program does not establish the validity of every paranormal claim. This record provides historical context only; it does not connect Richard Doty to Stargate or to a haunting operation.", provenance: "Paraphrased from CIA's 2021 historical account. The memo below is an original analysis exercise.", memo: "PROGRAM REVIEW / ANALYSIS EXERCISE\n\nSeparate three questions: Was a program funded? What results did its studies report? Were those results useful in practice?\n\nAn archival release establishes the existence of a record. It does not automatically validate every claim inside it.", sources: [SourceReference(title: "CIA / Did CIA really study psychic powers?", url: "https://www.cia.gov/stories/story/ask-molly-did-cia-really-study-psychic-powers/")])
    ]
}
