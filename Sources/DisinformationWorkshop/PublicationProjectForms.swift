import SwiftUI
import WorkshopCore

struct ProjectPublicationForm: View {
    let existing: ProjectPublication?
    let save: (ProjectPublication) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var url = ""
    @State private var dated = false
    @State private var published = Date()
    @State private var status = PublicationStatus.published
    @State private var notes = ""
    var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && NewsStory.webURL(url) != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "Register a published article" : "Edit publication").font(.title2)
            TextField("Article title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Published URL · https://…", text: $url).textFieldStyle(.roundedBorder).disabled(existing != nil)
            Text(existing == nil ? "Register a URL you published. Nothing is uploaded or posted by this form." : "The URL stays fixed so linked observations retain their identity. Register a new URL as a separate publication.").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Toggle("Publication date known", isOn: $dated)
            if dated { DatePicker("Published", selection: $published) }
            Picker("Status", selection: $status) { ForEach(PublicationStatus.allCases) { Text($0.rawValue).tag($0) } }
            TextField("Editorial notes / corrections", text: $notes, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(3...7)
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save publication") {
                guard let link = NewsStory.webURL(url) else { return }
                var value = existing ?? ProjectPublication(title: title, url: link)
                value.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000)); value.published = dated ? published : nil; value.status = status; value.notes = String(notes.prefix(20_000))
                save(value); dismiss()
            }.buttonStyle(ActionButton(prominent: true)).disabled(!valid) }
        }.padding(25).frame(width: 610).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark)
            .onAppear { if let existing { title = existing.title; url = existing.url.absoluteString; dated = existing.published != nil; published = existing.published ?? Date(); status = existing.status; notes = existing.notes } }
    }
}

struct ProjectMentionForm: View {
    let publications: [ProjectPublication]
    let existing: PublicationMention?
    let defaultCountry: NewsCountry
    let save: (PublicationMention) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var publicationID: UUID?
    @State private var title = ""
    @State private var url = ""
    @State private var observed = Date()
    @State private var kind = MentionKind.link
    @State private var review = MentionReview.unreviewed
    @State private var evidence = ""
    @State private var country = NewsCountry.unitedStates
    @State private var location: NewsPlace?
    @State private var locationConfirmed = false
    @State private var locationEvidence = ""
    var valid: Bool {
        publicationID != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && NewsStory.webURL(url) != nil &&
        (review != .confirmed || !evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        (!locationConfirmed || (location != nil && !locationEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "Record a linked mention" : "Edit mention evidence").font(.title2)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Your publication", selection: $publicationID) { ForEach(publications) { Text($0.title).tag(Optional($0.id)) } }
                    TextField("Mention or republication title", text: $title).textFieldStyle(.roundedBorder)
                    TextField("Evidence page URL · https://…", text: $url).textFieldStyle(.roundedBorder)
                    DatePicker("Observed", selection: $observed)
                    HStack { Picker("Kind", selection: $kind) { ForEach(MentionKind.allCases) { Text($0.rawValue).tag($0) } }; Picker("Review", selection: $review) { ForEach(MentionReview.allCases) { Text($0.rawValue).tag($0) } } }
                    TextField("Relationship evidence · explain the link to your publication", text: $evidence, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
                    Text("Confirmation requires evidence notes. Only distinct analyst-confirmed external URLs count toward visibility; a hostname is not proof of independent ownership.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                    Divider()
                    Eyebrow(text: "OPTIONAL DOCUMENTED SOURCE LOCATION")
                    CountryPicker(selection: $country, label: "Source country")
                    CityPicker(label: "Source locality", selected: location?.label ?? "Choose source locality", country: country) { location = $0; locationConfirmed = false }
                    if location != nil { Button("Clear location") { location = nil; locationConfirmed = false }.font(.system(size: 10)) }
                    Toggle("I checked evidence for this source location", isOn: $locationConfirmed).disabled(location == nil)
                    TextField("Location evidence · e.g. outlet address or masthead URL", text: $locationEvidence, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
                    Text("Use the documented outlet/publication locality, not a place named in the article and not inferred reader locations. Without a confirmed locality, the URL is excluded from geographic sprawl.").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }.padding(.trailing, 3)
            }
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save mention") {
                guard let id = publicationID, let link = NewsStory.webURL(url) else { return }
                var value = existing ?? PublicationMention(publicationID: id, title: title, url: link)
                value.publicationID = id; value.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000)); value.url = link; value.observed = observed
                value.kind = kind; value.review = review; value.evidence = String(evidence.prefix(20_000)); value.location = location; value.locationConfirmed = locationConfirmed; value.locationEvidence = String(locationEvidence.prefix(20_000))
                save(value); dismiss()
            }.buttonStyle(ActionButton(prominent: true)).disabled(!valid) }
        }.padding(25).frame(width: 670, height: 680).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark)
            .onAppear {
                publicationID = existing?.publicationID ?? publications.first?.id; country = existing?.location?.country ?? defaultCountry
                if let existing { title = existing.title; url = existing.url.absoluteString; observed = existing.observed; kind = existing.kind; review = existing.review; evidence = existing.evidence; location = existing.location; locationConfirmed = existing.locationConfirmed; locationEvidence = existing.locationEvidence }
            }
            .onChange(of: country) { _, new in if let current = location, current.country != new { location = nil; locationConfirmed = false } }
    }
}

struct ProjectAnalyticsForm: View {
    let publications: [ProjectPublication]
    let existing: PublicationAnalytics?
    let save: (PublicationAnalytics) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var publicationID: UUID?
    @State private var views = ""
    @State private var measured = Date()
    @State private var source = ""
    var number: Int64? { Int64(views.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var valid: Bool { publicationID != nil && number.map { (0...999_999_999_999).contains($0) } == true && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "Record site analytics" : "Edit analytics record").font(.title2)
            Picker("Publication", selection: $publicationID) { ForEach(publications) { Text($0.title).tag(Optional($0.id)) } }
            TextField("Cumulative page views · whole number", text: $views).textFieldStyle(.roundedBorder)
            DatePicker("Measured as of", selection: $measured)
            TextField("Analytics source / report reference", text: $source, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...5)
            Text("Enter the all-time page-view total for this URL as of the measurement date. The dashboard uses only its latest snapshot. Daily totals and unique visitors are different metrics and should not be entered here.").font(.system(size: 11)).foregroundStyle(Theme.muted)
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save measurement") {
                guard let id = publicationID, let count = number else { return }
                var value = existing ?? PublicationAnalytics(publicationID: id, pageViews: count, source: source)
                value.publicationID = id; value.pageViews = count; value.measured = measured; value.source = String(source.prefix(20_000)); save(value); dismiss()
            }.buttonStyle(ActionButton(prominent: true)).disabled(!valid) }
        }.padding(25).frame(width: 610).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark)
            .onAppear { publicationID = existing?.publicationID ?? publications.first?.id; if let existing { views = String(existing.pageViews); measured = existing.measured; source = existing.source } }
    }
}
