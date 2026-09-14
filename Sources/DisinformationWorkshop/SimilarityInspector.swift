import SwiftUI
import WorkshopCore

struct SimilarityInspector: View {
    @Binding var settings: SimilaritySettings
    @State var seedText: String
    @State var candidateText: String
    var places: [String] = []
    @Environment(\.dismiss) private var dismiss
    var vector: HeadlineVector { HeadlineSimilarity.compare(seed: seedText, candidate: candidateText, places: places, settings: settings) }
    var body: some View {
        VStack(spacing: 0) {
            HStack { VStack(alignment: .leading, spacing: 5) { Eyebrow(text: "SIMILARITY CALIBRATION", color: Theme.accent); Text("Why do these headlines match?").font(.system(size: 24, weight: .medium, design: .serif)) }; Spacer(); Button("Done") { dismiss() }.buttonStyle(ActionButton(prominent: true)) }.padding(22)
            Divider()
            HStack(alignment: .top, spacing: 24) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 19) {
                        Eyebrow(text: "INDEX WEIGHTS")
                        weight("Keywords (K)", path: \.keywordWeight)
                        weight("Adjacent phrases (P)", path: \.phraseWeight)
                        weight("Seed coverage (C)", path: \.coverageWeight)
                        Text("Available weights are normalized. A missing dimension stays unknown; all weights at zero produces no index.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        Divider()
                        HStack { Eyebrow(text: "MINIMUM INDEX"); Spacer(); Text("\(Int((settings.minimumScore * 100).rounded()))/100").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accent) }
                        Slider(value: $settings.minimumScore, in: 0...1, step: 0.01).accessibilityLabel("Minimum similarity index")
                        Stepper("\(settings.minimumSharedTerms) meaningful shared terms", value: $settings.minimumSharedTerms, in: 1...5).font(.system(size: 12))
                        Toggle("Exclude selected place names", isOn: $settings.excludePlaceNames)
                        Toggle("Exclude possible negation conflicts", isOn: $settings.excludeWordingConflicts)
                        Toggle("Show weak matches for inspection", isOn: $settings.showWeakMatches)
                        Eyebrow(text: "ADDITIONAL WORDS TO IGNORE")
                        TextField("e.g. police, council, incident", text: $settings.ignoredTerms, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
                        Text("Applied as individual words. Place exclusions use full phrases, preserving other word meanings.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        Button("Reset conservative defaults") { settings = SimilaritySettings() }.buttonStyle(ActionButton())
                    }.font(.system(size: 12)).padding(.trailing, 4)
                }.frame(width: 290)
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Eyebrow(text: "LOCAL COMPARISON PAD")
                        TextField("Seed headline", text: $seedText, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4).accessibilityLabel("Comparison seed headline")
                        TextField("Candidate headline", text: $candidateText, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4).accessibilityLabel("Comparison candidate headline")
                        Text("Editing these examples does not change saved articles. All calculations run locally.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        VectorBreakdown(vector: vector)
                        DisclosureGroup("Excluded words") { Text(vector.ignored.isEmpty ? "None" : vector.ignored.joined(separator: ", ")).font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.top, 7) }
                        Text("K is shared keywords / union. P is shared adjacent phrases / union. C is shared keywords / seed keywords, so reversing the comparison can change C and the index. No synonym, semantic, or event-identity model is applied.").font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
                    }
                }.frame(maxWidth: .infinity)
            }.padding(22)
        }.frame(width: 830, height: 670).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark).tint(Theme.accent)
    }
    private func weight(_ label: String, path: WritableKeyPath<SimilaritySettings, Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(label); Spacer(); Text("\(Int((settings[keyPath: path] * 100).rounded()))").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accent) }
            Slider(value: Binding(get: { settings[keyPath: path] }, set: { settings[keyPath: path] = $0 }), in: 0...1, step: 0.05).accessibilityLabel(label + " weight")
        }
    }
}

struct VectorBreakdown: View {
    let vector: HeadlineVector
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Eyebrow(text: "LEXICAL INDEX", color: Theme.accent); Spacer(); Text(vector.score.map { "\(Int(($0 * 100).rounded()))/100" } ?? "Unknown").font(.system(size: 23, weight: .medium, design: .monospaced)) }
            Text(vector.eligible ? "Passes comparison filters" : "Not a passing match").font(.system(size: 12, weight: .semibold)).foregroundStyle(vector.eligible ? Theme.accent : Theme.amber)
            if !vector.reasons.isEmpty { Text(vector.reasons.joined(separator: "\n")).font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4) }
            axis("K · Keywords", value: vector.keyword)
            axis("P · Phrases", value: vector.phrase)
            axis("C · Seed coverage", value: vector.coverage)
            terms("SHARED TERMS", vector.sharedTerms)
            terms("SHARED PHRASES", vector.sharedPhrases)
            terms("ONLY IN SEED", vector.seedOnly)
            terms("ONLY IN CANDIDATE", vector.candidateOnly)
            if vector.wordingConflict { Text("Negation/denial language differs. This is a wording flag, not a determination that the claims contradict.").font(.system(size: 10)).foregroundStyle(Theme.amber) }
            Text("Text similarity is separate from evidence confidence. Proximity and timing do not increase this index.").font(.system(size: 10)).foregroundStyle(Theme.muted)
        }.padding(15).background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
    }
    private func axis(_ label: String, value: Double?) -> some View {
        VStack(spacing: 5) {
            HStack { Text(label).font(.system(size: 11)); Spacer(); Text(value.map { "\(Int(($0 * 100).rounded()))" } ?? "—").font(.system(size: 11, design: .monospaced)) }
            GeometryReader { geometry in ZStack(alignment: .leading) { Capsule().fill(Theme.line); Capsule().fill(Theme.accent.opacity(0.6)).frame(width: geometry.size.width * (value ?? 0)) } }.frame(height: 4)
        }
    }
    private func terms(_ label: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) { Eyebrow(text: label); Text(values.isEmpty ? "None" : values.joined(separator: ", ")).font(.system(size: 11)).textSelection(.enabled) }
    }
}
