import SwiftUI
import WorkshopCore

struct CityPicker: View {
    let label: String
    var selected: String
    var country: NewsCountry = .unitedStates
    var choose: (NewsPlace) -> Void
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: { HStack { Image(systemName: "mappin.and.ellipse"); Text(selected).lineLimit(1); Spacer(minLength: 3); Image(systemName: "chevron.down").font(.system(size: 9)) } }
            .buttonStyle(ActionButton()).accessibilityLabel(label + ": " + selected)
            .popover(isPresented: $showing) {
                CitySearchPanel(country: country) { place in choose(place); showing = false }.frame(width: 390, height: 460)
            }
    }
}
struct CitySearchPanel: View {
    let country: NewsCountry
    let choose: (NewsPlace) -> Void
    @State private var query = ""
    @State private var stateCode = ""
    @FocusState private var focused: Bool
    var matches: [NewsPlace] { PlaceCatalog.matches(query, state: stateCode, country: country) }
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Eyebrow(text: country.name.uppercased() + " / PLACES", color: Theme.accent)
            TextField("Search any city or place", text: $query).textFieldStyle(.roundedBorder).focused($focused)
            Picker("Region", selection: $stateCode) { Text("All regions").tag(""); ForEach(PlaceCatalog.regions(in: country), id: \.self) { Text($0).tag($0) } }
            Text("\(matches.count.formatted()) matches · \(PlaceCatalog.places(in: country).count.formatted()) places bundled").font(.system(size: 10)).foregroundStyle(Theme.muted)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(matches.prefix(150)) { place in
                        Button { choose(place) } label: {
                            HStack { Text(place.name); Spacer(); Text(place.state).foregroundStyle(Theme.accent) }.font(.system(size: 12)).padding(.vertical, 9).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                    if matches.count > 150 { Text("Showing first 150. Type more or select a region.").font(.caption).foregroundStyle(Theme.muted).padding(10) }
                    if matches.isEmpty { Text("No matching catalog place.").foregroundStyle(Theme.muted).padding(20) }
                }
            }
            Text(country.catalogCredit).font(.system(size: 9)).foregroundStyle(Theme.muted)
        }.padding(18).background(Theme.sidebar).onAppear { focused = true }
    }
}

struct CountryPicker: View {
    @Binding var selection: NewsCountry
    var label = "News country"
    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(NewsCountry.allCases) { country in Text(country.name).tag(country) }
        }.accessibilityLabel(label)
    }
}
