import SwiftUI
import MapKit

struct PlacePickerSheet: View {
    let initialQuery: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = PlaceSearchModel()
    @State private var query = ""
    @State private var selectedItem: MKMapItem?
    @State private var isResolving = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search places in Apple Maps", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Search places")
                        .accessibilityHint("Type a venue, address, or point of interest")
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .contain)

                mapPreview

                resultsList
            }
            .padding(12)
            .navigationTitle("Find on Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Place") {
                        guard let selectedItem else { return }
                        onSelect(formattedPlace(from: selectedItem))
                        dismiss()
                    }
                    .disabled(selectedItem == nil)
                    .accessibilityHint("Use the selected location and return to editor")
                }
            }
        }
        .onAppear {
            query = initialQuery
            searchModel.updateQuery(initialQuery)
        }
        .onChange(of: query) { newQuery in
            searchModel.updateQuery(newQuery)
        }
    }

    @ViewBuilder
    private var mapPreview: some View {
        let pinItems = selectedItem.map { [SelectedPlacePin(coordinate: $0.placemark.coordinate)] } ?? []

        Map(coordinateRegion: $region, annotationItems: pinItems) { pin in
            MapMarker(coordinate: pin.coordinate, tint: .red)
        }
        .frame(height: 210)
        .accessibilityLabel("Place preview map")
        .accessibilityValue(selectedItem == nil ? "No place selected" : "Place selected")
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private var resultsList: some View {
        if isResolving {
            ProgressView("Loading place...")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }

        if searchModel.completions.isEmpty {
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Start typing to find places." : "No results.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
        } else {
            List {
                ForEach(Array(searchModel.completions.enumerated()), id: \.offset) { _, completion in
                    Button {
                        Task { await select(completion: completion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(completion.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        completion.subtitle.isEmpty
                            ? "Place result: \(completion.title)"
                            : "Place result: \(completion.title), \(completion.subtitle)"
                    )
                    .accessibilityHint("Select this place and update map preview")
                }
            }
            .listStyle(.plain)
        }
    }

    @MainActor
    private func select(completion: MKLocalSearchCompletion) async {
        isResolving = true
        defer { isResolving = false }

        guard let mapItem = await searchModel.mapItem(for: completion) else { return }
        selectedItem = mapItem
        region = MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    }

    private func formattedPlace(from item: MKMapItem) -> String {
        let title = item.placemark.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty {
            return title
        }
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty {
            return name
        }
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SelectedPlacePin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

@MainActor
private final class PlaceSearchModel: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published var completions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            completions = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
    }

    func mapItem(for completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }
}
