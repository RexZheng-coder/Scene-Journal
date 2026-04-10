import SwiftUI
import MapKit
import CoreLocation

struct MapPinsView: View {
    let entries: [JournalEntry]
    let onEditEntry: (JournalEntry) -> Void
    let onDeleteEntry: (UUID) -> Void

    @State private var pins: [MappedEntry] = []
    @State private var selectedPinID: UUID?
    @State private var isLoadingPins = false
    @State private var unresolvedCount = 0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: pins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    PinBadge(
                        type: pin.entry.type,
                        isSelected: selectedPinID == pin.id
                    ) {
                        withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                            selectedPinID = pin.id
                            centerOnPin(pin)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .accessibilityLabel("Entry locations map")
            .accessibilityHint("Shows pins for entries with a saved place")

            if isLoadingPins {
                ProgressView("Locating venues...")
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomPanel
        }
        .navigationTitle("Map Pins")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshToken) {
            await loadPins()
        }
    }

    private var refreshToken: String {
        entries
            .map { "\($0.id.uuidString)|\($0.venue)" }
            .joined(separator: ";")
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if let selected = selectedPin {
            SelectedPinCard(
                pin: selected,
                onCenter: { centerOnPin(selected) },
                onEditEntry: onEditEntry,
                onDeleteEntry: onDeleteEntry
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else if pins.isEmpty && !isLoadingPins {
            EmptyMapHint(unresolvedCount: unresolvedCount)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    private var selectedPin: MappedEntry? {
        guard let selectedPinID else { return nil }
        return pins.first(where: { $0.id == selectedPinID })
    }

    private func centerOnPin(_ pin: MappedEntry) {
        region = MKCoordinateRegion(
            center: pin.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    }

    @MainActor
    private func loadPins() async {
        isLoadingPins = true
        defer { isLoadingPins = false }

        var mapped: [MappedEntry] = []
        var unresolved = 0

        for entry in entries {
            let venue = entry.venue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !venue.isEmpty else {
                unresolved += 1
                continue
            }

            if let coordinate = await VenueGeocodingService.shared.coordinate(for: venue) {
                mapped.append(MappedEntry(entry: entry, coordinate: coordinate))
            } else {
                unresolved += 1
            }
        }

        pins = mapped
        unresolvedCount = unresolved

        if selectedPin == nil {
            selectedPinID = pins.first?.id
        }

        if let firstPin = pins.first {
            centerOnPin(firstPin)
        }
    }
}

private struct MappedEntry: Identifiable {
    let entry: JournalEntry
    let coordinate: CLLocationCoordinate2D

    var id: UUID { entry.id }
}

private struct PinBadge: View {
    let type: EntryType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isSelected ? "mappin.circle.fill" : "mappin.circle")
                .font(.title3)
                .foregroundStyle(type.badgeColor)
                .frame(minWidth: 44, minHeight: 44)
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.displayName) pin")
        .accessibilityHint("Select this location")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct SelectedPinCard: View {
    let pin: MappedEntry
    let onCenter: () -> Void
    let onEditEntry: (JournalEntry) -> Void
    let onDeleteEntry: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pin.entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(pin.entry.type.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(pin.entry.type.badgeColor.opacity(0.22), in: Capsule())
            }

            if !pin.entry.venue.isEmpty {
                Label(pin.entry.venue, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                NavigationLink {
                    EntryDetailView(
                        entry: pin.entry,
                        onEdit: { onEditEntry(pin.entry) },
                        onDelete: { onDeleteEntry(pin.entry.id) }
                    )
                } label: {
                    Label("Open Entry", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Open full details for this pin")

                Button("Center") { onCenter() }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Center map on this location")
                    .frame(minHeight: 44)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct EmptyMapHint: View {
    let unresolvedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No map pins yet")
                .font(.headline)
            Text("Add a precise venue or address in your entries to place pins on the map.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if unresolvedCount > 0 {
                Text("\(unresolvedCount) entries could not be located.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
