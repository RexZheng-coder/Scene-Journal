import Foundation
import CoreLocation

@MainActor
final class VenueGeocodingService {
    static let shared = VenueGeocodingService()

    private var cache: [String: CLLocationCoordinate2D] = [:]
    private let geocoder = CLGeocoder()

    func coordinate(for rawVenue: String) async -> CLLocationCoordinate2D? {
        let trimmed = rawVenue.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.lowercased()
        guard !key.isEmpty else { return nil }

        if let cached = cache[key] {
            return cached
        }

        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)
            guard let coordinate = placemarks.first?.location?.coordinate else { return nil }
            cache[key] = coordinate
            return coordinate
        } catch {
            return nil
        }
    }
}
