import SwiftUI
import MapKit
import CoreLocation

struct VenuePinPreviewCard: View {
    let place: String
    let height: CGFloat
    let loadingText: String
    let placeholderText: String
    let unresolvedText: String

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isResolving = false
    @State private var didAttemptResolve = false
    @State private var fallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )

    init(
        place: String,
        height: CGFloat = 170,
        loadingText: String = "Locating place...",
        placeholderText: String = "Add a place or address to preview it on map.",
        unresolvedText: String = "Unable to locate this place. Try a more specific address."
    ) {
        self.place = place
        self.height = height
        self.loadingText = loadingText
        self.placeholderText = placeholderText
        self.unresolvedText = unresolvedText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coordinate {
                mapContent(coordinate: coordinate)
            } else {
                Map(coordinateRegion: $fallbackRegion)
                .frame(height: height)
                .accessibilityLabel("Place map preview")
                .accessibilityValue(trimmedVenue.isEmpty ? "No place entered" : "Finding place")
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.35), lineWidth: 0.8)
                )
            }

            if trimmedVenue.isEmpty {
                Text(placeholderText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if isResolving {
                ProgressView(loadingText)
                    .font(.footnote)
            } else if didAttemptResolve && coordinate == nil {
                Text(unresolvedText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: trimmedVenue) {
            await resolvePin()
        }
    }

    private var trimmedVenue: String {
        place.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func mapContent(coordinate: CLLocationCoordinate2D) -> some View {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )

        VStack(alignment: .leading, spacing: 8) {
            Map(coordinateRegion: .constant(region), annotationItems: [VenuePoint(coordinate: coordinate)]) { point in
                MapMarker(coordinate: point.coordinate, tint: .red)
            }
            .frame(height: height)
            .accessibilityLabel("Place map preview")
            .accessibilityValue("Pin at \(trimmedVenue)")
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 0.8)
            )

            HStack(spacing: 8) {
                Label(trimmedVenue, systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if let mapsURL = makeAppleMapsURL(for: coordinate, query: trimmedVenue) {
                    Link("Open in Maps", destination: mapsURL)
                        .font(.footnote.weight(.semibold))
                        .accessibilityHint("Open this location in Apple Maps")
                }
            }
        }
    }

    private func resolvePin() async {
        guard !trimmedVenue.isEmpty else {
            coordinate = nil
            didAttemptResolve = false
            isResolving = false
            return
        }

        isResolving = true
        defer { isResolving = false }

        let resolved = await VenueGeocodingService.shared.coordinate(for: trimmedVenue)
        coordinate = resolved
        didAttemptResolve = true

        if let resolved {
            fallbackRegion = MKCoordinateRegion(
                center: resolved,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
    }

    private func makeAppleMapsURL(for coordinate: CLLocationCoordinate2D, query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "http://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(encodedQuery)"
        return URL(string: urlString)
    }
}

private struct VenuePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
