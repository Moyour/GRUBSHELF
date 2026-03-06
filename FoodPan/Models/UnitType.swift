import Foundation

enum UnitType: String, Codable, CaseIterable, Sendable {
    case g
    case kg
    case ml
    case l
    case pcs

    var displayName: String {
        switch self {
        case .g: "grams"
        case .kg: "kilograms"
        case .ml: "millilitres"
        case .l: "litres"
        case .pcs: "pieces"
        }
    }

    var abbreviation: String { rawValue }
}
