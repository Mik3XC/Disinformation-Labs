import Foundation

public enum NewsCountry: String, Codable, CaseIterable, Identifiable {
    case unitedStates = "US", unitedKingdom = "GB", canada = "CA", australia = "AU"
    case newZealand = "NZ", ireland = "IE", india = "IN", singapore = "SG", southAfrica = "ZA"
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .unitedStates: return "United States"
        case .unitedKingdom: return "United Kingdom"
        case .canada: return "Canada"
        case .australia: return "Australia"
        case .newZealand: return "New Zealand"
        case .ireland: return "Ireland"
        case .india: return "India"
        case .singapore: return "Singapore"
        case .southAfrica: return "South Africa"
        }
    }
    public var defaultCityName: String {
        switch self {
        case .unitedStates: return "Albuquerque"
        case .unitedKingdom: return "London"
        case .canada: return "Toronto"
        case .australia: return "Sydney"
        case .newZealand: return "Auckland"
        case .ireland: return "Dublin"
        case .india: return "New Delhi"
        case .singapore: return "Singapore"
        case .southAfrica: return "Cape Town"
        }
    }
    public var language: String { "en-" + rawValue }
    public var edition: String { rawValue + ":en" }
    public var catalogCredit: String {
        self == .unitedStates ? "2025 US Census Gazetteer · cities, towns, villages, and census-designated places." : "GeoNames · CC BY 4.0 · population over 500 or administrative seats; not every locality."
    }
}

public struct CountryNewsContext: Codable, Equatable {
    public var search: NewsSearch
    public var radiusMiles: Double
    public var seed: NewsStory?
    public init(search: NewsSearch, radiusMiles: Double, seed: NewsStory?) {
        self.search = search; self.radiusMiles = radiusMiles; self.seed = seed
    }
}
