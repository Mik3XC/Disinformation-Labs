import SwiftUI
import WorkshopCore

struct CoverageHeatMap: View {
    let country: NewsCountry
    let regions: [RegionCoverage]
    @Binding var selected: String
    var itemName = "articles"
    var showSuggestions = true
    @State private var zoom = 1.0
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(country.name).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("Zoom").font(.system(size: 10))
                Slider(value: $zoom, in: 1...4).frame(width: 85).accessibilityLabel("Coverage map zoom")
                Button("Reset") { zoom = 1 }.font(.system(size: 10))
            }.foregroundStyle(Theme.muted)
            GeometryReader { geometry in
                let projection = MapProjection(country: country, regions: regions, size: geometry.size, zoom: zoom, selected: selected)
                ZStack {
                    Theme.sidebar
                    Path { path in
                        for ring in CoverageCatalog.outlines[country.rawValue] ?? [] where ring.count > 2 {
                            let points = ring.map { projection.point(latitude: $0[1], longitude: $0[0]) }
                            path.move(to: points[0]); for point in points.dropFirst() { path.addLine(to: point) }; path.closeSubpath()
                        }
                    }.fill(Theme.text.opacity(0.07))
                    Path { path in
                        for ring in CoverageCatalog.outlines[country.rawValue] ?? [] where ring.count > 2 {
                            path.move(to: projection.point(latitude: ring[0][1], longitude: ring[0][0]))
                            for point in ring.dropFirst() { path.addLine(to: projection.point(latitude: point[1], longitude: point[0])) }; path.closeSubpath()
                        }
                    }.stroke(Theme.text.opacity(0.18), lineWidth: 0.7)
                    ForEach(regions) { row in
                        let intensity = Double(row.count) / Double(max(1, regions.map(\.count).max() ?? 0))
                        let diameter = row.count == 0 ? 7.0 : 14 + 22 * sqrt(intensity)
                        Button { selected = row.id } label: {
                            ZStack {
                                if row.count > 0 { Circle().fill(RadialGradient(colors: [Theme.accent.opacity(0.3 + 0.6 * intensity), Theme.accent.opacity(0.03)], center: .center, startRadius: 0, endRadius: diameter / 2)) }
                                Circle().fill(row.count == 0 ? Theme.muted.opacity(0.45) : Theme.accent).frame(width: row.count == 0 ? 5 : 7, height: row.count == 0 ? 5 : 7)
                                if selected == row.id { Circle().stroke(Theme.text, lineWidth: 1.5) }
                            }.frame(width: diameter, height: diameter).contentShape(Circle())
                        }.buttonStyle(.plain).position(projection.point(latitude: row.region.latitude, longitude: row.region.longitude))
                            .help("\(row.region.name): \(row.count) \(itemName)" + (showSuggestions ? "; \(row.suggestedCount) suggested locations" : ""))
                            .accessibilityLabel("\(row.region.name), \(row.count) \(itemName)" + (showSuggestions ? ", \(row.suggestedCount) suggested locations" : ""))
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line))
            }
        }.onChange(of: country) { _, _ in zoom = 1 }
    }
}

private struct MapProjection {
    let longitudeOrigin: Double
    let latitudeScale: Double
    let centerX: Double
    let centerY: Double
    let scale: Double
    let size: CGSize
    init(country: NewsCountry, regions: [RegionCoverage], size: CGSize, zoom: Double, selected: String) {
        let origin = PlaceCatalog.defaultPlace(for: country).longitude
        longitudeOrigin = origin
        func unwrap(_ lon: Double) -> Double {
            var value = lon - origin
            while value > 180 { value -= 360 }; while value < -180 { value += 360 }
            return value
        }
        let coords = (CoverageCatalog.outlines[country.rawValue] ?? []).flatMap { $0 } + regions.map { [$0.region.longitude, $0.region.latitude] }
        let latitudes = coords.map { $0[1] }
        let minLat = latitudes.min() ?? 0, maxLat = latitudes.max() ?? 1
        let correction = max(0.2, cos((minLat + maxLat) / 2 * .pi / 180))
        latitudeScale = correction
        let xs = coords.map { unwrap($0[0]) * correction }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
        if zoom > 1, let region = regions.first(where: { $0.id == selected })?.region {
            centerX = unwrap(region.longitude) * latitudeScale; centerY = -region.latitude
        } else { centerX = (minX + maxX) / 2; centerY = -(minLat + maxLat) / 2 }
        self.size = size
        scale = max(0, min((size.width - 30) / max(0.05, maxX - minX), (size.height - 30) / max(0.05, maxLat - minLat))) * zoom
    }
    func point(latitude: Double, longitude: Double) -> CGPoint {
        var lon = longitude - longitudeOrigin
        while lon > 180 { lon -= 360 }; while lon < -180 { lon += 360 }
        return CGPoint(x: size.width / 2 + (lon * latitudeScale - centerX) * scale, y: size.height / 2 + (-latitude - centerY) * scale)
    }
}
